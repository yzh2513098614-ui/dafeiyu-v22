extends RefCounted
## Every live actor resolves against one slot snapshot. UI only consumes events.
const Grid = preload("res://expedition/tactical_grid.gd")
const EnemyPlanner = preload("res://expedition/enemy_planner.gd")
var data: Dictionary
var cards: Dictionary = {}
var grid
var units: Dictionary = {}
var hand: Array = []
var draw_pile: Array = []
var discard: Array = []
var queue: Array = []
# Primary alias retained for v1 saves and callers.
var enemy_plan: Array = []
var enemy_plans: Dictionary = {}
var resources: Dictionary = {}
var window := 0
var compute := 3
var result := ""
var events: Array = []
var history: Array = []
var last_card := ""
var last_target := ""
var checkpoint: Dictionary = {}
var resolved := false
var rng := RandomNumberGenerator.new()

func _init(rules: Dictionary, seed_value: int = 1) -> void:
	data=rules; rng.seed=seed_value
	for c in data.cards: cards[str(c.id)]=c

func start(kind: String, hp: int, supply: Dictionary, walls: Array, shelters: Array, player_cell: Array, enemy_cell: Array, unlocks: Array = [], wall_edges: Array = [], companions: Array = [], equipment_cards: Array = []) -> void:
	grid=Grid.new(walls,shelters);grid.blocked_edges=wall_edges.duplicate(true)
	units={"player":_unit(hp,player_cell),"enemy":_unit(int(data.enemies[kind].hp),enemy_cell,kind)}
	units.player.max_hp=int(data.rules.integrity)
	var index:=2
	for spec in companions:
		var at: Vector2i=Grid.cell(spec.pos)
		if not data.enemies.has(spec.kind) or not grid.walkable(at) or at in occupied_cells():continue
		units["enemy_%d"%index]=_unit(int(data.enemies[spec.kind].hp),spec.pos,spec.kind);index+=1
	_set_retreat()
	resources=supply.duplicate(true);draw_pile=data.deck.duplicate()
	hand=[];discard=[];queue=[];enemy_plans={};history=[];events=[]
	window=0;result="";last_card="";last_target="";checkpoint={}
	for id in unlocks:
		if cards.has(id) and not id in draw_pile:draw_pile.append(id)
	for id in equipment_cards:
		if cards.has(id):draw_pile.append(id)
	if int(resources.get("medical",0))>0:draw_pile.append("medical_patch")
	_shuffle(draw_pile);begin_window()

func _unit(hp: int, pos: Array, kind: String = "") -> Dictionary:
	return {"kind":kind,"hp":hp,"max_hp":hp,"pos":pos.duplicate(),"shield":0,"jam":0,"sandbox":false,"weakness":0,"gradient":0}

func enemy_ids(living_only: bool = true) -> Array:
	var ids: Array=[]
	for id in units:
		if id!="player" and (not living_only or int(units[id].hp)>0):ids.append(id)
	return ids

func default_target() -> String:
	var ids: Array=enemy_ids()
	return str(ids[0]) if not ids.is_empty() else ""

func actor_name(id: String) -> String:
	if id=="player":return "我方"
	if not units.has(id):return "失效目标"
	var number: int=enemy_ids(false).find(id)+1
	return "%d · %s"%[number,data.enemies[units[id].kind].name]

func occupied_cells(excluding: String = "") -> Array:
	var output: Array=[]
	for id in units:
		if id!=excluding and int(units[id].hp)>0:output.append(Grid.cell(units[id].pos))
	return output

func _set_retreat() -> void:
	var retreat: Array=[];var boundary_reachable:=false
	var start_cell: Vector2i=Grid.cell(units.player.pos)
	for y in grid.side:
		for x in grid.side:
			var c:=Vector2i(x,y)
			if not grid.path(start_cell,c,64,occupied_cells("player")).is_empty():
				retreat.append(c)
				if grid.at_exit(c):boundary_reachable=true
	if not boundary_reachable and not retreat.is_empty():
		retreat.sort_custom(func(a,b):return grid.distance(a,start_cell)*64+a.y*8+a.x>grid.distance(b,start_cell)*64+b.y*8+b.x)
		grid.escape_cells=[Grid.packed(retreat[0])]

func _shuffle(pile: Array) -> void:
	for i in range(pile.size()-1,0,-1):
		var j:=rng.randi_range(0,i);var swap: Variant=pile[i];pile[i]=pile[j];pile[j]=swap

func begin_window() -> void:
	if result!="":return
	window+=1;compute=int(data.rules.compute);queue.clear();resolved=false
	for id in units:units[id].shield=0;units[id].sandbox=false
	units.player["revealed"]=int(units.player.get("intel_windows",0))>0
	units.player["intel_windows"]=maxi(0,int(units.player.get("intel_windows",0))-1)
	discard.append_array(hand);hand.clear()
	for i in int(data.rules.draw):
		if draw_pile.is_empty():draw_pile=discard.duplicate();discard.clear();_shuffle(draw_pile)
		if not draw_pile.is_empty() and hand.size()<int(data.rules.hand_limit):hand.append(draw_pile.pop_back())
	enemy_plans={}
	var snapshot_units: Dictionary=units.duplicate(true)
	for id in enemy_ids():enemy_plans[id]=EnemyPlanner.plan(snapshot_units,grid,window,id)
	enemy_plan=enemy_plans.get("enemy",[])

func used_compute() -> int:
	var total:=0
	for cmd in queue:total+=int(cmd.cost)
	return total

func used_slots() -> int:
	var total:=0
	for cmd in queue:total+=int(cmd.get("slots",1))
	return total

func predicted_position() -> Vector2i:
	var at: Vector2i=Grid.cell(units.player.pos)
	for cmd in queue:
		if cmd.kind=="move":at=Grid.cell(cmd.target)
		elif cmd.kind=="card" and str(cards[cmd.id].type)=="movement" and cards[cmd.id].target=="cell":at=Grid.cell(cmd.target)
	return at

func reserve_cost(extra: Dictionary) -> bool:
	var spent: Dictionary=extra.duplicate(true)
	for cmd in queue:
		if cmd.kind=="card":
			for key in cards[cmd.id].resource_cost:spent[key]=int(spent.get(key,0))+int(cards[cmd.id].resource_cost[key])
	for key in spent:
		if int(spent[key])>int(resources.get(key,0)):return false
	return true

func enqueue(index: int, target: Array = [], target_actor: String = "") -> String:
	if result!="" or resolved:return "当前窗口已结束"
	if index<0 or index>=hand.size():return "没有这张手牌"
	for cmd in queue:
		if int(cmd.get("hand_index",-1))==index:return "这张牌已进入队列"
	var c: Dictionary=cards[hand[index]]
	if used_slots()+int(c.slots)>int(data.rules.slots):return "指令槽已满"
	if used_compute()+int(c.cost)>compute:return "算力不足"
	if not reserve_cost(c.resource_cost):return "背包中的消耗品不足"
	if c.target=="cell":
		if target.size()!=2:return "先点选地面目标格"
		if grid.path(predicted_position(),Grid.cell(target),int(c.range),occupied_cells("player")).is_empty():return "目标不可到达，最多移动两格"
	if c.target=="enemy":
		if target_actor=="":target_actor=default_target()
		if not target_actor in enemy_ids():return "请选择一个仍在场的敌人"
	queue.append({"kind":"card","id":c.id,"cost":c.cost,"slots":c.slots,"hand_index":index,"target":target,"target_actor":target_actor})
	return ""

func enqueue_basic(kind: String, target: Array = []) -> String:
	if not kind in ["move","escape","wait"]:return "无效指令"
	if result!="" or resolved or used_slots()>=int(data.rules.slots):return "指令槽已满"
	var cost:=1 if kind=="move" else 0
	if used_compute()+cost>compute:return "算力不足"
	if kind=="move":
		if target.size()!=2 or grid.path(predicted_position(),Grid.cell(target),2,occupied_cells("player")).is_empty():return "请点选两格以内可到达的地面"
	if kind=="escape" and not grid.at_exit(predicted_position()):return "先移动到绿色退路，再安排脱离"
	queue.append({"kind":kind,"cost":cost,"slots":1,"target":target})
	return ""

func pop_command() -> void:
	if not resolved and not queue.is_empty():queue.pop_back()

func _action(cmd: Dictionary, side: String = "player") -> Dictionary:
	var target_id:=str(cmd.get("target_actor",""))
	if target_id=="":target_id=default_target() if side=="player" else "player"
	if cmd.get("kind","")=="card":
		var c: Dictionary=cards[cmd.id]
		return {"name":c.name,"effects":c.effects.duplicate(true),"range":c.range,"interruptible":c.interruptible,"id":c.id,"target":cmd.get("target",[]),"target_actor":target_id,"resource_cost":c.resource_cost}
	var kind:=str(cmd.get("kind","wait"))
	return {"name":str(cmd.get("name",{"move":"基础移动","escape":"脱离战斗","wait":"待机"}.get(kind,kind))),"effects":[{"kind":kind,"value":cmd.get("value",2 if kind=="move" else 1)}],"range":cmd.get("range",0),"interruptible":true,"id":"","target":cmd.get("target",[]),"target_actor":target_id,"resource_cost":{}}

func execute() -> Array:
	if result!="" or resolved:return []
	events=[]
	var slots: Array=[]
	for cmd in queue:
		slots.append(cmd)
		for occupied in range(1,int(cmd.get("slots",1))):slots.append({"kind":"wait"})
	var used: Array=[]
	for cmd in queue:
		if cmd.kind=="card":used.append(int(cmd.hand_index))
	used.sort();used.reverse()
	for i in used:discard.append(hand[i]);hand.remove_at(i)
	for slot in int(data.rules.slots):
		if result!="":break
		var pc: Dictionary=slots[slot] if slot<slots.size() else {"kind":"wait"}
		var actions: Dictionary={"player":_action(pc)}
		for id in enemy_ids():
			var plan: Array=enemy_plan if id=="enemy" else enemy_plans.get(id,[])
			actions[id]=_action(plan[slot] if slot<plan.size() else {"kind":"wait"},id)
		_resolve_slot(actions,slot)
	history.append_array(events.duplicate(true));resolved=true;queue.clear()
	return events.duplicate(true)

func _record(slot: int, kind: String, side: String, note: String, value: int = 0, target: String = "") -> void:
	var positions: Dictionary={};var health: Dictionary={};var shields: Dictionary={}
	for id in units:
		positions[id]=units[id].pos.duplicate();health[id]=units[id].hp;shields[id]=units[id].shield
	events.append({"window":window,"slot":slot+1,"kind":kind,"side":side,"target_actor":target,"note":note,"value":value,"positions":positions,"health":health,"shields":shields})

func _resolve_slot(actions: Dictionary, slot: int) -> void:
	for side in actions:
		var actor: Dictionary=units[side];var action: Dictionary=actions[side]
		if int(actor.jam)>0 and bool(action.interruptible):
			actor.jam-=1;action.effects=[];_record(slot,"interrupt",side,"指令受干扰")
		else:
			var payable:=true
			for key in action.resource_cost:
				if int(resources.get(key,0))<int(action.resource_cost[key]):payable=false
			if side=="player" and not payable:action.effects=[];_record(slot,"invalid",side,"消耗品不足，指令失效")
			elif side=="player":
				for key in action.resource_cost:resources[key]=int(resources.get(key,0))-int(action.resource_cost[key])
		_record(slot,"command",side,str(action.name))
		if side=="player" and _has(action,"cache"):
			if cards.has(last_card):
				var previous: Dictionary=cards[last_card]
				action.effects=previous.effects.duplicate(true);action.range=previous.range
				if previous.target=="enemy":action.target_actor=last_target
				_record(slot,"cache",side,"复用 · "+str(previous.name))
			else:action.effects=[];_record(slot,"invalid",side,"尚无可缓存的已完成指令")
	_resolve_movement(actions,slot)
	# Every defense is established before any control or attack.
	for side in actions:
		for effect in actions[side].effects:
			match str(effect.kind):
				"shield":units[side].shield+=int(effect.value);_record(slot,"shield",side,"获得护盾",int(effect.value))
				"sandbox":units[side].sandbox=true;_record(slot,"shield",side,"隔离异常指令")
	var canceled: Dictionary={}
	for side in actions:canceled[side]=false
	for side in actions:
		var action: Dictionary=actions[side];var other:=str(action.target_actor)
		for effect in action.effects:
			if effect.kind in ["jam","corrupt"] and _hit(side,int(action.range),other):
				if units[other].sandbox:_record(slot,"resist",other,"沙箱阻止异常")
				elif effect.kind=="jam":
					canceled[other]=bool(actions[other].interruptible)
					units[other].jam=maxi(int(units[other].jam),int(effect.value)-1)
					_record(slot,"jam",side,"干扰 "+actor_name(other),int(effect.value),other)
				elif other=="player":discard.append("hallucination");_record(slot,"corrupt",side,"一张污染指令进入弃牌堆",0,other)
	var damage: Dictionary={};var heals: Dictionary={}
	for id in units:damage[id]=0;heals[id]=0
	var escape_requested:=false
	for side in actions:
		var actor: Dictionary=units[side];var action: Dictionary=actions[side];var other:=str(action.target_actor)
		if canceled[side]:_record(slot,"interrupt",side,"当前指令被中断");continue
		for effect in action.effects:
			var amount:=int(effect.value)
			match str(effect.kind):
				"damage","gradient","attack":
					if _hit(side,int(action.range),other):
						if effect.kind=="gradient":
							if actor.get("gradient_target","")!=other:actor.gradient=0
							actor["gradient_target"]=other;amount+=int(actor.gradient)*3;actor.gradient+=1
						amount+=int(units[other].weakness)
						if side!="player":amount+=int(actor.get("charge",0));actor["charge"]=0
						if Grid.packed(Grid.cell(units[other].pos)) in grid.cover:amount=maxi(0,amount-3)
						damage[other]+=amount;_record(slot,"attack",side,"命中 "+actor_name(other),amount,other)
					else:_record(slot,"miss",side,"目标已退场、离开范围或被墙体遮挡",0,other)
				"heal":heals[side]+=amount
				"self_damage":damage[side]+=amount
				"self_corrupt":discard.append("hallucination");_record(slot,"corrupt",side,"超载产生污染指令")
				"scan":units.player["revealed"]=true;units.player["intel_windows"]=1;_record(slot,"scan",side,"本窗口与下个窗口的全部敌方意图已识别")
				"weakness":
					if _hit(side,int(action.range),other):units[other].weakness=maxi(int(units[other].weakness),amount);_record(slot,"scan",side,"发现 "+actor_name(other)+" 的弱点",amount,other)
				"charge":actor["charge"]=amount;_record(slot,"charge",side,"下一次攻击增强",amount)
				"checkpoint":checkpoint={"pos":actor.pos.duplicate(),"hp":actor.hp};_record(slot,"cache",side,"记录当前位置与完整性")
				"rollback":
					if not checkpoint.is_empty() and side=="player":
						if grid.walkable(Grid.cell(checkpoint.pos)) and not Grid.cell(checkpoint.pos) in occupied_cells("player"):actor.pos=checkpoint.pos.duplicate()
						heals[side]+=mini(amount,maxi(0,int(checkpoint.hp)-int(actor.hp)));_record(slot,"cache",side,"恢复检查点（最多修补10）")
				"cleanse":
					actor.jam=0;var removed:=0
					for pile in [hand,draw_pile,discard]:
						while "hallucination" in pile and removed<amount:pile.erase("hallucination");removed+=1
					_record(slot,"cleanse",side,"清除污染指令",removed)
				"escape":
					if side=="player":escape_requested=grid.at_exit(Grid.cell(actor.pos))
		if side=="player" and cards.has(action.id) and bool(cards[action.id].cacheable) and cards[action.id].resource_cost.is_empty():
			last_card=action.id;last_target=other
	# Commit all HP before emitting health snapshots: mutual defeat stays simultaneous.
	for side in actions:
		var actor: Dictionary=units[side]
		var absorbed:=mini(int(actor.shield),int(damage[side]));actor.shield-=absorbed
		actor.hp=clampi(int(actor.hp)-int(damage[side])+absorbed+int(heals[side]),0,int(actor.max_hp))
	for side in actions:
		if int(damage[side])>0 or int(heals[side])>0:_record(slot,"health",side,"完整性变化",int(units[side].hp))
		if int(units[side].hp)<=0:_record(slot,"defeated",side,actor_name(side)+" 已退场")
	if int(units.player.hp)<=0:result="defeat"
	elif escape_requested:result="disengaged"
	elif enemy_ids().is_empty():result="victory"
	elif window>=30 and slot==2:result="disengaged";_record(slot,"timeout","player","通信窗口终止，脱离本次遭遇")
	if result!="":_record(slot,"result","player",result)

func _resolve_movement(actions: Dictionary, slot: int) -> void:
	var origins: Dictionary={};var proposals: Dictionary={};var paths: Dictionary={};var conflicts: Dictionary={}
	for side in actions:
		origins[side]=Grid.cell(units[side].pos);proposals[side]=origins[side];paths[side]=[];conflicts[side]=false
		for effect in actions[side].effects:
			if effect.kind=="move" and actions[side].target.size()==2:
				var target: Vector2i=Grid.cell(actions[side].target)
				paths[side]=grid.path(origins[side],target,int(effect.value))
				if not paths[side].is_empty():proposals[side]=target
	var ids: Array=actions.keys()
	for i in ids.size():
		for j in range(i+1,ids.size()):
			var a: String=ids[i];var b: String=ids[j];var conflict: bool=proposals[a]==proposals[b]
			var prev_a: Vector2i=origins[a];var prev_b: Vector2i=origins[b]
			for tick in range(1,maxi(paths[a].size(),paths[b].size())):
				var next_a: Vector2i=paths[a][mini(tick,paths[a].size()-1)] if not paths[a].is_empty() else origins[a]
				var next_b: Vector2i=paths[b][mini(tick,paths[b].size()-1)] if not paths[b].is_empty() else origins[b]
				if next_a==next_b or (next_a==prev_b and next_b==prev_a):conflict=true
				prev_a=next_a;prev_b=next_b
			if origins[b] in paths[a] or origins[a] in paths[b]:conflict=true
			if conflict:conflicts[a]=true;conflicts[b]=true
	for side in actions:
		if proposals[side]!=origins[side]:
			if conflicts[side]:_record(slot,"blocked",side,"位移冲突，留在原位")
			else:units[side].pos=Grid.packed(proposals[side])
	# All accepted positions are committed before events are sent to presentation.
	for side in actions:
		if proposals[side]!=origins[side] and not conflicts[side]:_record(slot,"move",side,"移动到 [%d,%d]"%[proposals[side].x+1,proposals[side].y+1])

func _has(action: Dictionary, kind: String) -> bool:
	for effect in action.effects:
		if effect.kind==kind:return true
	return false

func _hit(side: String, reach: int, other: String = "") -> bool:
	if other=="":other=default_target() if side=="player" else "player"
	if not units.has(other) or int(units[other].hp)<=0:return false
	var a: Vector2i=Grid.cell(units[side].pos);var b: Vector2i=Grid.cell(units[other].pos)
	return grid.distance(a,b)<=reach and grid.sight(a,b)

func snapshot() -> Dictionary:
	return {"version":2,"units":units.duplicate(true),"hand":hand.duplicate(),"draw":draw_pile.duplicate(),"discard":discard.duplicate(),"queue":queue.duplicate(true),"enemy_plan":enemy_plan.duplicate(true),"enemy_plans":enemy_plans.duplicate(true),"resources":resources.duplicate(true),"window":window,"compute":compute,"result":result,"resolved":resolved,"history":history.duplicate(true),"last_card":last_card,"last_target":last_target,"checkpoint":checkpoint.duplicate(true),"rng_state":str(rng.state),"blocked":grid.blocked,"cover":grid.cover,"exits":grid.escape_cells,"edges":grid.blocked_edges}

func restore(value: Dictionary) -> void:
	units=value.units.duplicate(true);hand=value.hand.duplicate();draw_pile=value.draw.duplicate();discard=value.discard.duplicate();queue=value.queue.duplicate(true);enemy_plan=value.enemy_plan.duplicate(true)
	enemy_plans=value.get("enemy_plans",{"enemy":enemy_plan}).duplicate(true)
	resources=value.resources.duplicate(true);window=int(value.window);compute=int(value.compute);result=str(value.result);history=value.history.duplicate(true)
	last_card=str(value.last_card);last_target=str(value.get("last_target","enemy"));checkpoint=value.checkpoint.duplicate(true);rng.state=int(value.rng_state);grid=Grid.new(value.blocked,value.cover)
	for cmd in queue:
		if cmd.kind=="card" and cards[cmd.id].target=="enemy" and not cmd.has("target_actor"):cmd["target_actor"]="enemy"
	resolved=bool(value.get("resolved",false));grid.escape_cells=value.get("exits",[]).duplicate(true);grid.blocked_edges=value.get("edges",[]).duplicate(true)

