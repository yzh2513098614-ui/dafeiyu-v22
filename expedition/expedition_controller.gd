extends Node
const State=preload("res://expedition/run_state.gd")
const Simulator=preload("res://expedition/combat_simulator.gd")
const Grid=preload("res://expedition/tactical_grid.gd")
const Site=preload("res://expedition/research_site.gd")
const Director=preload("res://expedition/encounter_director.gd")
const Presenter=preload("res://expedition/combat_presenter.gd")
const ExpeditionStyle=preload("res://ui/whale_skin.gd")
const Fit=preload("res://ui/ui_fit.gd")
var game
var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/expedition/rules.json"))
var state
var running:=false
var mode:=""
var root: Control
var surface: Control
var hud: Panel
var modal: Panel
var close_button: Button
var status_label: Label
var status:=""
var entry: Button
var nearby: Dictionary={}
var selected_object: Dictionary={}
var nodes: Dictionary={}
var engine
var presenter
var selected_cell: Array=[]
var selected_card:=-1
var basic_move:=false
var battle_signal:=""
var board_origin:=Vector3.ZERO
var elapsed_tick:=0.0
var update_tick:=0.0
var paused_mode:=""
var settling_saved:=true
var fast:=false
var selected_enemy:="enemy"
var battle_stats: Label
var enemy_buttons: Dictionary={}

func configure(owner_game) -> void:
	game=owner_game;state=State.new(data)
	if "--test-expedition" in OS.get_cmdline_user_args(): state.save_path="res://预览/expedition_test_save.json"
	state.load_save()
	var layer:=CanvasLayer.new();layer.layer=75;add_child(layer)
	root=Control.new();root.theme=ExpeditionStyle.theme(game._game_font());root.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root);Fit.fill(root)
	surface=Control.new();surface.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(surface);Fit.pin_center(surface,1448,0,1086)
	entry=game._button("F11 研究中心 · 搜打撤",Vector2(48,402),Vector2(450,50),game.district_canvas,briefing)
	if game.location_id=="research": briefing()
	else:root.hide()

func is_active() -> bool:
	return running

func blocked() -> bool:
	return mode!=""

func briefing() -> void:
	if running: return
	game.ui.hide()
	if game.location_id=="research" and is_instance_valid(game.dialogue_controller.companion):game.dialogue_controller.companion.hide()
	mode="briefing";root.show();_clear_surface()
	modal=ExpeditionStyle.panel(surface,Vector2(330,175),Vector2(788,716))
	ExpeditionStyle.mascot(modal,Vector2(29,26),Vector2(86,74))
	_label(modal,"离线研究中心",Vector2(128,30),Vector2(620,46),34)
	_label(modal,"AI 指令 · 搜索 / 交战 / 撤离",Vector2(129,84),Vector2(590,34),21)
	_label(modal,"委托：带回原始研究样本\n\n靠近柜子按 E 搜索；用侦察工具看清异常。\n战斗先排列最多三条指令，再同步执行。\n完整性耗尽会失去未保护的战利品。\n只有成功撤离，物资才进入港口仓库。",Vector2(37,159),Vector2(711,246),25)
	_label(modal,"基础牌组 20 张  ·  算力 3  ·  保险仓 2 格\nWASD 移动 / E 互动 / I 远征背包 / Esc 暂停\n出发补给借用，结算扣除 12 Token 和 1 修补组件。",Vector2(38,410),Vector2(711,98),20)
	_button(modal,"放弃上局，开始新远征" if bool(state.run.get("active",false)) else "开始新远征",Vector2(38,519),Vector2(337,57),func():start_run(false))
	var resume:=_button(modal,"继续未完成的远征",Vector2(411,519),Vector2(337,57),func():start_run(true));resume.disabled=not bool(state.run.get("active",false))
	_label(modal,"仓库物资价值 %d  ·  已带回样本 %d 次  ·  永久蓝图 %d"%[state.value_of(state.profile.warehouse),int(state.profile.quest_completed),state.profile.blueprints.size()],Vector2(40,594),Vector2(705,34),20)
	_button(modal,"返回港口",Vector2(38,644),Vector2(337,43),_return_harbor)
	_button(modal,"仓库 / 制作与配装",Vector2(411,644),Vector2(337,43),open_warehouse)

func start_run(resume: bool) -> void:
	if not resume:
		if bool(state.run.get("active",false)):state.finish(false)
		state.new_run(int(Time.get_unix_time_from_system()))
	running=true;mode="";game.ui.hide()
	if game.location_id!="research":await game.request_travel("research")
	game.overview_mode=false;game.view_size=27.0;game.camera.size=27
	_rebuild_nodes()
	if is_instance_valid(game.dialogue_controller.companion):game.dialogue_controller.companion.hide()
	game.player.position=Vector3(state.run.position[0],0,state.run.position[1]);game.player.velocity=Vector3.ZERO
	if not state.run.combat.is_empty():
		var saved: Dictionary=state.run.combat
		engine=Simulator.new(data,int(state.run.seed));engine.restore(saved.engine)
		if engine.resolved and engine.result=="":engine.begin_window()
		battle_signal=str(saved.signal);board_origin=Vector3(saved.origin[0],0,saved.origin[1])
		if engine.result!="":_end_combat()
		else:_present_battle()
	else:_render_explore()
	checkpoint_save()

func world_changed() -> void:
	if not game:return
	if running and game.location_id=="research":_rebuild_nodes()
	elif game.location_id=="research" and mode!="briefing":call_deferred("briefing")

func _rebuild_nodes() -> void:
	nodes.clear()
	for child in game.world.get_children():
		if child.has_meta("expedition_id"):nodes[str(child.get_meta("expedition_id"))]=child
	for id in nodes:
		if id.begins_with("signal_"):nodes[id].visible=not bool(state.run.cleared.get(id,false))
		if id.begins_with("door_") and bool(state.run.opened.get(id,false)): _set_door(id,true)
		elif bool(state.run.cleared.get(id,false)):nodes[id].visible=false
		elif bool(state.run.opened.get(id,false)) and nodes[id].has_method("set_open"):nodes[id].set_open(true)
	for spec in Site.OBJECTS:
		if spec.kind=="encounter" and nodes.has(spec.id) and int(state.run.known.get(spec.id,0))==2:
			for child in nodes[spec.id].get_children():
				if child is Label3D:child.text=_signal_name(spec)

func _signal_name(spec: Dictionary) -> String:
	var kind: String=str(state.run.known.get("event_"+str(spec.id),spec.enemy))
	if data.enemies.has(kind):
		var members: Array=Director.members(state,spec.id,kind)
		return "%s · %d体"%[data.enemies[kind].name,members.size()]
	return {"empty":"设备残留 · 无活动目标","resource":"遗留数据缓存"}.get(kind,"未知信号")

func _process(delta: float) -> void:
	if not game:return
	entry.visible=not running and mode=="" and game.character_controller.free_world()
	if not running or mode!="":return
	state.run.elapsed=float(state.run.elapsed)+delta;elapsed_tick+=delta;update_tick+=delta
	if elapsed_tick>=40:
		elapsed_tick=0;state.trace(1,"持续停留");checkpoint_save()
	if update_tick<.18:return
	update_tick=0;nearby={}
	var best:=2.15
	for spec in Site.OBJECTS+Site.DOORS:
		if bool(state.run.cleared.get(spec.id,false)):continue
		var p:=Vector3(spec.pos[0],0,spec.pos[1]);var distance: float=game.player.position.distance_to(p)
		if distance<best and _reachable(p,spec.id):best=distance;nearby=spec
	if is_instance_valid(status_label):
		status_label.text="E · "+str(nearby.get("name","开合门")) if not nearby.is_empty() else (status if status!="" else "保持警觉，搜集物资后从维护出口或权限电梯撤离。")
	_refresh_hud()

func _reachable(p: Vector3,id: String) -> bool:
	var a: Vector3=game.player.position+Vector3(0,.5,0)
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,p+Vector3(0,.5,0),1,[game.player.get_rid()]))
	return hit.is_empty() or (nodes.has(id) and (nodes[id]==hit.collider or nodes[id].is_ancestor_of(hit.collider)))

func _clear_surface() -> void:
	for child in surface.get_children():surface.remove_child(child);child.queue_free()
	hud=null;status_label=null;modal=null

func _label(parent: Node,text: String,pos: Vector2,dimensions: Vector2,font_size: int=21) -> Label:
	return ExpeditionStyle.label(parent,text,pos,dimensions,font_size)

func _button(parent: Node,text: String,pos: Vector2,dimensions: Vector2,action: Callable) -> Button:
	var b:=Button.new();b.text=text;b.position=pos;b.size=dimensions;b.add_theme_font_size_override("font_size",20);b.pressed.connect(action);parent.add_child(b);return b

func _render_explore() -> void:
	mode="";root.show();_clear_surface()
	hud=ExpeditionStyle.panel(surface,Vector2(28,24),Vector2(1392,117),"paper")
	_refresh_hud()
	var tools:=ExpeditionStyle.panel(surface,Vector2(28,912),Vector2(1392,149),"paper")
	status_label=_label(tools,status,Vector2(20,14),Vector2(1352,36),23)
	var buttons: Array=[["E 互动",interact],["R 扫描 · Token 1",scan],["T 倾听",listen],["H 修补",heal],["I 远征背包",open_bag],["Esc 暂停",pause]]
	for i in buttons.size():_button(tools,buttons[i][0],Vector2(20+i*227,69),Vector2(214,51),buttons[i][1])
	var badge:=ExpeditionStyle.panel(surface,Vector2(1120,169),Vector2(296,172),"sky")
	_label(badge,"本局目标",Vector2(16,13),Vector2(260,30),22)
	_label(badge,"样本已取得\n选择南侧维护出口\n或东侧权限电梯" if bool(state.run.quest) else "去东侧样本冷藏区\n带回原始研究样本\n权限钥匙在档案终端",Vector2(16,55),Vector2(260,97),20)
	_button(badge,"Z 总览 / 跟随",Vector2(0,191),Vector2(296,43),func():game._toggle_view())

func _refresh_hud() -> void:
	if not is_instance_valid(hud):return
	for child in hud.get_children():child.free()
	_label(hud,"离线研究中心   /   %s"%("已取得样本，准备撤离" if bool(state.run.quest) else "取回原始研究样本"),Vector2(22,14),Vector2(950,36),25)
	_label(hud,"完整性 %d/%d   ·   Trace %d · %s   ·   背包 %d/%d   ·   Token %d   ·   已探索 %.1f 分钟"%[state.run.hp,data.rules.integrity,state.run.trace,state.threat(),state.occupied(),data.rules.capacity,int(state.run.bag.get("token",0)),float(state.run.elapsed)/60],Vector2(24,67),Vector2(1346,31),21)

func interact() -> void:
	if not running or mode!="" or nearby.is_empty():return
	selected_object=nearby.duplicate(true)
	var id: String=selected_object.id
	if id.begins_with("door_"):
		var opened: bool=not bool(state.run.opened.get(id,false));state.run.opened[id]=opened;_set_door(id,opened);status="门已打开" if opened else "门已关闭";checkpoint_save();return
	match str(selected_object.kind):
		"loot":
			if bool(selected_object.get("locked",false)) and int(state.run.bag.get("key",0))<=0:status="需要权限密钥，去研究档案终端寻找。";return
			if not bool(state.run.opened.get(id,false)):
				state.run.opened[id]=true;state.trace(2,"搜索 "+str(selected_object.name));state.loot_for(id,selected_object.table)
				if nodes.has(id):nodes[id].set_open(true)
			_open_loot()
		"encounter":_encounter()
		"exit":_extraction()
	checkpoint_save()

func _set_door(id: String, opened: bool) -> void:
	if not nodes.has(id):return
	var door: Node3D=nodes[id]
	for mesh in door.find_children("*","MeshInstance3D",true,false):mesh.visible=not opened
	for body in door.find_children("*","CollisionObject3D",true,false):body.collision_layer=0 if opened else 1

func _open_panel(title: String, dimensions:=Vector2(860,670)) -> void:
	_clear_surface();modal=ExpeditionStyle.panel(surface,Vector2((1448-dimensions.x)/2,185),dimensions)
	_label(modal,title,Vector2(26,18),Vector2(dimensions.x-52,44),30)
	status_label=_label(modal,status,Vector2(27,dimensions.y-106),Vector2(dimensions.x-54,46),19)
	close_button=_button(modal,"关闭",Vector2(27,dimensions.y-54),Vector2(dimensions.x-54,38),_close_panel)

func _close_panel() -> void:
	if mode=="pause":_resume_pause();return
	if mode=="battle" or mode=="executing" or mode=="settlement":return
	if not running:briefing();return
	_render_explore();checkpoint_save()

func _open_loot() -> void:
	mode="loot";_open_panel(selected_object.name)
	var remaining: Dictionary=state.run.rolled.get(selected_object.id,{})
	var i:=0
	for id in remaining:
		if int(remaining[id])<=0:continue
		var row:=ExpeditionStyle.panel(modal,Vector2(25,90+i*75),Vector2(810,66),"sky")
		_label(row,"%s ×%d  ·  每件占 %d 格 / 价值 %d"%[data.resources[id].name,remaining[id],data.resources[id].size,data.resources[id].value],Vector2(15,16),Vector2(605,35),22)
		_button(row,"收取一件",Vector2(635,12),Vector2(159,43),func():
			status=state.take(selected_object.id,id,1);if status=="":status="物资已收入远征背包（尚未撤离）。"
			checkpoint_save();_open_loot())
		i+=1
	_label(modal,"背包 %d/%d  ·  要带出去才会进入仓库"%[state.occupied(),data.rules.capacity],Vector2(28,477),Vector2(799,32),21)

func open_bag() -> void:
	if mode!="":return
	mode="bag";_open_panel("远征背包 · 保险仓 %d/2 格"%state.insurance_used(),Vector2(1060,815))
	var i:=0
	for id in state.run.bag:
		if int(state.run.bag[id])<=0:continue
		var row:=ExpeditionStyle.panel(modal,Vector2(25,83+i*49),Vector2(1010,44),"sky")
		_label(row,"%s ×%d  ·  保护 %d  ·  每件%d格"%[data.resources[id].name,state.run.bag[id],int(state.run.insured.get(id,0)),data.resources[id].size],Vector2(13,8),Vector2(561,28),20)
		_button(row,"保护",Vector2(584,4),Vector2(127,35),func():status=state.insure(id);checkpoint_save();mode="";open_bag())
		var unprotect:=_button(row,"取消保护",Vector2(722,4),Vector2(137,35),func():state.uninsure(id);status="已释放一格保险容量。";checkpoint_save();mode="";open_bag());unprotect.disabled=int(state.run.insured.get(id,0))==0
		_button(row,"丢弃",Vector2(870,4),Vector2(126,35),func():state.drop(id);checkpoint_save();mode="";open_bag())
		i+=1
	var module_id:=str(state.run.module)
	var protection: String="已保护 · 占用一格保险仓" if state.run.protected_module else "装备随失败丢失；可用一格保险容量保护"
	if module_id=="":protection="基础核心不会丢失，可在出发前制作额外装备。"
	_label(modal,"本局装备："+(str(data.modules[module_id].name) if module_id!="" else "基础核心")+"\n"+protection,Vector2(29,588),Vector2(737,67),20)
	var protect:=_button(modal,"取消装备保护" if state.run.protected_module else "保护装备",Vector2(799,599),Vector2(232,45),func():
		if state.run.protected_module:state.uninsure("module");status="已取消装备保护。"
		else:status=state.insure_module()
		checkpoint_save();mode="";open_bag());protect.disabled=module_id==""
	_label(modal,"物资价值 %d · 样本占2格；保护物资与装备共享2格保险仓。"%state.value_of(state.run.bag),Vector2(29,662),Vector2(1001,32),21)

func open_warehouse() -> void:
	status="只有安全带回的物资进入仓库，永久蓝图不会因失败丢失。"
	mode="warehouse";_open_panel("港口仓库 · 已安全带回的物资",Vector2(900,780))
	var i:=0
	for id in state.profile.warehouse:
		if int(state.profile.warehouse[id])<=0 or not data.resources.has(id):continue
		_label(modal,"%s   ×%d"%[data.resources[id].name,state.profile.warehouse[id]],Vector2(32,91+i*42),Vector2(828,35),22);i+=1
	_label(modal,"永久蓝图："+("上下文溢出 · 已加入后续交战牌组" if "context_overflow" in state.profile.blueprints else "尚未找到"),Vector2(32,525),Vector2(828,36),22)
	_button(modal,"制作装备 / 选择下次配装",Vector2(32,583),Vector2(828,62),func():status="";open_loadout())

func open_loadout() -> void:
	mode="loadout";_open_panel("装备工坊 · 使用仓库材料制作",Vector2(1110,815))
	_label(modal,"每次携带一个模块，额外获得两张技能牌。成功撤离会带回装备；失败会失去未保护的装备。",Vector2(30,83),Vector2(1050,65),21)
	var selected:=str(state.profile.loadout)
	var selection: String=str(data.modules[selected].name) if selected!="" else "基础核心（无额外装备）"
	_label(modal,"下次出发："+selection+(" · 本局配装已锁定" if running else ""),Vector2(30,155),Vector2(1050,36),24)
	var i:=0
	for id in ["barrier","recon","mobility"]:
		var spec: Dictionary=data.modules[id];var card:=ExpeditionStyle.panel(modal,Vector2(30+i*357,215),Vector2(336,366),"sky")
		var art:=TextureRect.new();art.texture=load("res://assets/cards/"+str(spec.art)+".png");art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.position=Vector2(20,14);art.size=Vector2(296,112);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(art)
		_label(card,spec.name,Vector2(16,135),Vector2(304,35),25)
		_label(card,spec.description,Vector2(16,178),Vector2(304,55),21)
		var costs: Array=[]
		for resource in spec.cost:costs.append("%s %d/%d"%[data.resources[resource].name,int(state.profile.warehouse.get(resource,0)),spec.cost[resource]])
		_label(card," / ".join(costs)+"\n库存 %d 件"%int(state.profile.modules.get(id,0)),Vector2(16,240),Vector2(304,68),19)
		var craft:=_button(card,"制作",Vector2(15,318),Vector2(146,36),func():status=state.craft_module(id);state.save();open_loadout())
		for resource in spec.cost:
			if int(state.profile.warehouse.get(resource,0))<int(spec.cost[resource]):craft.disabled=true
		var equip:=_button(card,"已选择" if selected==id else "选用",Vector2(174,318),Vector2(146,36),func():status=state.equip_module(id);state.save();open_loadout())
		equip.disabled=running or bool(state.run.get("active",false)) or int(state.profile.modules.get(id,0))<=0
		i+=1
	var basic:=_button(modal,"使用基础核心",Vector2(30,611),Vector2(328,56),func():status=state.equip_module("");state.save();open_loadout());basic.disabled=running or bool(state.run.get("active",false))
	_button(modal,"查看仓库材料",Vector2(391,611),Vector2(328,56),open_warehouse)
	_button(modal,"返回远征" if running else "返回出发说明",Vector2(752,611),Vector2(328,56),_close_panel)

func scan() -> void:
	if mode!="" or not running:return
	if int(state.run.bag.get("token",0))<1:status="扫描需要一个 Token";return
	state.run.bag.token-=1;state.trace(3,"扫描信号")
	var found:=0
	for spec in Site.OBJECTS:
		if spec.kind=="encounter" and game.player.position.distance_to(Vector3(spec.pos[0],0,spec.pos[1]))<9:
			var found_kind: String=Director.inspect(state,spec.id,spec.enemy)
			if data.enemies.has(found_kind):Director.members(state,spec.id,found_kind)
			state.run.known[spec.id]=2;found+=1
			if nodes.has(spec.id):
				for child in nodes[spec.id].get_children():
					if child is Label3D:child.text=_signal_name(spec)
	status="扫描完成，识别 %d 处信号。敌方后续战斗意图仍需数据探针确认。"%found;checkpoint_save()

func listen() -> void:
	if mode!="" or not running:return
	var nearest: Dictionary={};var distance:=INF
	for spec in Site.OBJECTS:
		if spec.kind!="encounter" or state.run.cleared.get(spec.id,false):continue
		var d: float=game.player.position.distance_to(Vector3(spec.pos[0],0,spec.pos[1]))
		if d<distance:distance=d;nearest=spec
	if nearest.is_empty() or distance>12:status="附近暂时没有明显动静。"
	else:
		state.run.known[nearest.id]=maxi(1,int(state.run.known.get(nearest.id,0)));status=data.enemies[nearest.enemy].hint
	state.run.elapsed+=4;checkpoint_save()

func heal() -> void:
	if mode!="" or not running:return
	if int(state.run.bag.get("medical",0))<1:status="需要修补组件，可搜索维护工具柜。";return
	if int(state.run.hp)>=int(data.rules.integrity):status="完整性已经充足。";return
	state.run.bag.medical-=1;state.sync_bag(state.run.bag);state.run.hp=mini(int(data.rules.integrity),int(state.run.hp)+14);status="消耗一件修补组件，恢复14点完整性。";checkpoint_save()

func _encounter() -> void:
	mode="encounter";status=""
	var identified:=int(state.run.known.get(selected_object.id,0))
	_open_panel("异常信号 · "+(_signal_name(selected_object) if identified==2 else "尚未完全识别"),Vector2(820,500))
	_label(modal,data.enemies[selected_object.enemy].hint,Vector2(30,102),Vector2(760,103),25)
	_label(modal,"可以绕开。主动检查可能发现空房、物资或异常体。\n检查后仍可放弃，不会立即强制开始战斗。",Vector2(30,226),Vector2(760,80),21)
	_button(modal,"检查信号",Vector2(30,326),Vector2(368,49),_inspect_signal)
	_button(modal,"绕开，保留物资",Vector2(421,326),Vector2(368,49),_close_panel)

func _inspect_signal() -> void:
	var found: String=Director.inspect(state,selected_object.id,selected_object.enemy)
	checkpoint_save()
	if found=="empty":
		state.run.cleared[selected_object.id]=true;nodes[selected_object.id].hide();status="只是损坏的设备，没有敌人。";_close_panel();return
	if found=="resource":
		state.run.cleared[selected_object.id]=true;nodes[selected_object.id].hide();state.loot_for(selected_object.id,"server");selected_object.name="遗留数据缓存";_open_loot();return
	selected_object.enemy=found;state.run.known[selected_object.id]=2
	var members: Array=Director.members(state,selected_object.id,found)
	status="确认敌群数量与类型。现在可以交战，也可以关闭界面绕开。"
	mode="encounter";_open_panel("发现 · %d 个异常体"%members.size(),Vector2(900,565))
	for i in members.size():
		var spec: Dictionary=data.enemies[members[i]]
		_label(modal,"%d  %s · 完整性 %d"%[i+1,spec.name,spec.hp],Vector2(32,95+i*48),Vector2(836,41),25)
	_label(modal,"敌人按同一窗口同时行动。先控制高威胁目标，或走到绿色退路脱离。\nTrace 25 起新信号出现双敌，65 起三敌；已识别的敌群不会突然增员。",Vector2(32,268),Vector2(836,80),21)
	_button(modal,"编排指令，进入交战",Vector2(30,373),Vector2(840,54),func():start_combat(found,selected_object.id))
	checkpoint_save()

func _extraction() -> void:
	if bool(selected_object.permission) and int(state.run.bag.get("key",0))<=0:status="权限电梯需要密钥，档案终端可以找到。";return
	mode="extraction";var risk: bool=Director.extraction_risk(state,selected_object.id)
	status="出口附近有追踪信号；可用诱饵转移它，或者选择另一个出口。" if risk else "路线畅通，可以安全带回当前物资。"
	_open_panel(selected_object.name,Vector2(860,560))
	_label(modal,"物资价值 %d  ·  背包 %d/%d\n%s\n权限密钥可重复使用，撤离不会消耗它。"%[state.value_of(state.run.bag),state.occupied(),data.rules.capacity,"样本委托完成后额外奖励30 Token" if bool(state.run.quest) else "未找到样本也可以撤离，保住已有物资"],Vector2(30,106),Vector2(800,137),23)
	if risk:
		var pursuers: Array=Director.members(state,"pursuit_"+str(selected_object.id),"guardian")
		_label(modal,"追踪方：%d 个异常体。交战不会自动完成撤离。"%pursuers.size(),Vector2(30,244),Vector2(800,34),21)
		var bait:=_button(modal,"投放诱饵 · Token 3，然后撤离",Vector2(30,293),Vector2(800,50),func():state.run.bag.token-=3;state.trace(-8,"诱饵转移追踪");finish_run(true));bait.disabled=int(state.run.bag.get("token",0))<3
		_button(modal,"抵抗追踪 · 战斗后再撤离",Vector2(30,354),Vector2(800,46),func():start_combat("guardian","pursuit_"+str(selected_object.id)))
	else:_button(modal,"安全撤离，结算战利品",Vector2(30,293),Vector2(800,62),func():finish_run(true))
	checkpoint_save()

func start_combat(kind: String, signal_id: String) -> void:
	# Sample collision geometry at foot height; walls and furniture are actual blockers.
	board_origin=Vector3(snappedf(game.player.position.x,1.5)-4.5,0,snappedf(game.player.position.z,1.5)-6)
	var blocked_cells: Array=[];var covers: Array=[]
	var shape:=SphereShape3D.new();shape.radius=.34
	var polygons: Array=game.shell.get_meta("floor_contours",[])
	for y in 8:
		for x in 8:
			var p: Vector3=board_origin+Vector3(x*1.5,0,y*1.5);var on_floor:=false
			for poly in polygons:
				if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),poly) and Site.Shape.distance_to_edge(Vector2(p.x,p.z),poly)>.40:on_floor=true
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=p+Vector3(0,.52,0);query.collision_mask=1;query.exclude=[game.player.get_rid()]
			if not on_floor or not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():blocked_cells.append([x,y])
	var grid=Grid.new(blocked_cells)
	# A thin partition can fall between cell centers. Sweep the foot volume
	# between adjacent cells so both movement and line-of-sight respect it.
	for y in 8:
		for x in 8:
			var cell:=Vector2i(x,y)
			if not grid.walkable(cell):continue
			for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
				var next: Vector2i=cell+direction
				if not grid.walkable(next):continue
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=board_origin+Vector3(x*1.5,.52,y*1.5);query.motion=Vector3(direction.x*1.5,0,direction.y*1.5);query.collision_mask=1;query.exclude=[game.player.get_rid()]
				var fractions: PackedFloat32Array=game.get_world_3d().direct_space_state.cast_motion(query)
				if not fractions.is_empty() and fractions[0]<.999:grid.blocked_edges.append(Grid.edge(cell,next))
	var pc:=Vector2i(3,4)
	if not grid.walkable(pc):status="当前位置不足以展开战术网格，移动到开阔处再交战。";_render_explore();return
	var candidates: Array=[]
	for y in 8:
		for x in 8:
			var cell:=Vector2i(x,y)
			if cell!=pc and not grid.path(pc,cell,10).is_empty():candidates.append(cell)
			if grid.walkable(cell):
				for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					if grid.inside(cell+d) and not grid.can_step(cell,cell+d):covers.append(Grid.packed(cell));break
	if candidates.is_empty():status="附近被阻挡，换个位置交战。";_render_explore();return
	candidates.sort_custom(func(a,b):return absi(grid.distance(a,pc)-3)<absi(grid.distance(b,pc)-3))
	var members: Array=Director.members(state,signal_id,kind)
	var companions: Array=[]
	var used: Array=[candidates[0]]
	for i in range(1,members.size()):
		for cell in candidates:
			if not cell in used and grid.distance(cell,used[0])>=1:
				companions.append({"kind":members[i],"pos":Grid.packed(cell)});used.append(cell);break
	engine=Simulator.new(data,int(state.run.seed)+state.run.cleared.size());engine.start(kind,int(state.run.hp),state.run.bag,blocked_cells,covers,Grid.packed(pc),Grid.packed(candidates[0]),state.profile.blueprints,grid.blocked_edges,companions,state.equipment_cards());battle_signal=signal_id
	state.trace(3,"展开交战");_present_battle();checkpoint_save()

func _present_battle() -> void:
	mode="battle";game.player.velocity=Vector3.ZERO
	status="选牌排列指令；绿色边框格是合法退路。"
	for spec in Site.OBJECTS:
		if spec.kind=="encounter" and nodes.has(spec.id):nodes[spec.id].hide()
	presenter=Presenter.new();game.world.add_child(presenter);presenter.configure(game,engine,board_origin);presenter.fast=fast
	game.overview_mode=false;game.view_center=board_origin+Vector3(5.25,0,5.25);game.camera.size=22;game.view_size=22;game._camera()
	game.camera.position-=game.camera.global_basis.y*3.7
	selected_cell=[];selected_card=-1;selected_enemy=engine.default_target();basic_move=false;presenter.select_actor(selected_enemy);_render_battle()

func _card_description(c: Dictionary) -> String:
	var lines: Array=[]
	for effect in c.effects:
		if effect.kind=="self_corrupt":lines.append("产生一张污染指令");continue
		if effect.kind=="scan":lines.append("揭示下个窗口意图");continue
		lines.append({"damage":"伤害 %d","gradient":"伤害 %d，连续命中+3","shield":"护盾 %d","sandbox":"隔离异常","move":"移动 %d 格","scan":"揭示后续意图","weakness":"敌人受伤 +%d","jam":"干扰 %d 格指令","cache":"复用上个有效指令","checkpoint":"记录状态","rollback":"最多修补 %d，恢复站位","cleanse":"清除 %d 张污染","escape":"在网格边缘脱离","heal":"修补 %d","self_damage":"损失完整性 %d"}.get(effect.kind,effect.kind)%effect.value if effect.kind in ["damage","gradient","shield","move","weakness","jam","rollback","cleanse","heal","self_damage"] else {"sandbox":"隔离异常","scan":"揭示后续意图","cache":"复用上个有效指令","checkpoint":"记录状态","escape":"在网格边缘脱离"}.get(effect.kind,effect.kind))
	for id in c.resource_cost:lines.append("消耗 %s ×%d"%[data.resources[id].name,c.resource_cost[id]])
	if c.target=="enemy":lines.append("射程 %d 格"%int(c.range))
	return " / ".join(lines)

func _render_battle() -> void:
	_clear_surface()
	enemy_buttons={}
	var top:=ExpeditionStyle.panel(surface,Vector2(24,20),Vector2(1400,117),"paper")
	_label(top,"同步指令交战   /   窗口 %d   /   %d 个敌人   /   当前目标 %s"%[engine.window,engine.enemy_ids().size(),engine.actor_name(selected_enemy)],Vector2(20,11),Vector2(1355,40),27)
	battle_stats=_label(top,_battle_stats_text(engine.units.player.hp,engine.units.player.shield),Vector2(21,68),Vector2(1355,32),22)
	var left:=ExpeditionStyle.panel(surface,Vector2(24,158),Vector2(297,457),"paper")
	_label(left,"选择敌人 / 查看意图",Vector2(18,14),Vector2(261,35),23)
	var ids: Array=engine.enemy_ids(false)
	for i in ids.size():
		var id: String=ids[i]
		var button:=_button(left,_enemy_button_text(id,engine.units[id].hp,engine.units[id].shield),Vector2(15,59+i*63),Vector2(267,57),func():choose_enemy(id))
		button.add_theme_font_size_override("font_size",18);button.disabled=int(engine.units[id].hp)<=0
		if id==selected_enemy:button.modulate=Color("e9d49f")
		enemy_buttons[id]=button
	_label(left,"当前目标的三条指令",Vector2(18,258),Vector2(261,27),21)
	var intent: Array=engine.enemy_plan if selected_enemy=="enemy" else engine.enemy_plans[selected_enemy]
	for i in 3:
		var known: bool=i==0 or engine.units.player.get("revealed",false)
		var line: String=str(intent[i].name) if known else "未识别 · 数据探针"
		if known and intent[i].kind=="attack":line+=" %d"%int(intent[i].value)
		_label(left,"%d  %s"%[i+1,line],Vector2(19,295+i*33),Vector2(260,30),19)
	_label(left,"移动 → 防御/控制 → 伤害\n掩体减伤3 · 绿色格可脱离",Vector2(18,400),Vector2(263,50),18)
	var plan:=ExpeditionStyle.panel(surface,Vector2(1097,158),Vector2(327,455),"paper")
	_label(plan,"我的三条指令",Vector2(16,15),Vector2(294,35),26)
	for i in 3:
		var text: String="%d  空槽 · 执行时待机"%(i+1)
		if i<engine.queue.size():
			var cmd: Dictionary=engine.queue[i];text="%d  %s"%[i+1,engine.cards[cmd.id].name if cmd.kind=="card" else {"move":"基础移动","escape":"脱离战斗","wait":"待机"}.get(cmd.kind,cmd.kind)]
			if cmd.kind=="card" and engine.cards[cmd.id].target=="enemy":text+=" → 目标%d"%(ids.find(cmd.target_actor)+1)
		_label(plan,text,Vector2(18,72+i*54),Vector2(291,47),20)
	_button(plan,"撤回最后一条",Vector2(16,242),Vector2(295,43),func():engine.pop_command();_render_battle())
	var submit:=_button(plan,"执行同步指令  ▶",Vector2(16,299),Vector2(295,58),execute_queue);submit.disabled=mode=="executing"
	_button(plan,"%s演出"%("快速" if fast else "正常"),Vector2(16,374),Vector2(295,42),func():fast=not fast;presenter.fast=fast;_render_battle())
	var commands:=ExpeditionStyle.panel(surface,Vector2(24,637),Vector2(1400,96),"paper")
	_button(commands,"基础移动",Vector2(14,14),Vector2(197,45),func():selected_card=-1;basic_move=true;status="点选两格以内地面，安排移动。";_render_battle())
	_button(commands,"基础脱离",Vector2(225,14),Vector2(197,45),func():status=engine.enqueue_basic("escape");_render_battle())
	_button(commands,"待机",Vector2(436,14),Vector2(156,45),func():status=engine.enqueue_basic("wait");_render_battle())
	status_label=_label(commands,status if status!="" else "选牌排列指令；移动牌需要再点击地面目标格。",Vector2(611,14),Vector2(764,67),20)
	for i in engine.hand.size():
		var c: Dictionary=engine.cards[engine.hand[i]]
		var b:=_button(surface,"",Vector2(24+i*199,751),Vector2(186,291),func():choose_card(i))
		b.tooltip_text=c.english+"\n"+_card_description(c);ExpeditionStyle.card_button(b,i==selected_card)
		var art:=TextureRect.new();art.texture=load("res://assets/cards/"+str(c.art)+".png");art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.position=Vector2(10,39);art.size=Vector2(166,130);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(art)
		_label(b,"算力 %d · 槽 %d"%[c.cost,c.slots],Vector2(11,7),Vector2(166,30),18)
		_label(b,c.name,Vector2(11,175),Vector2(166,31),23)
		_label(b,_card_description(c),Vector2(11,213),Vector2(166,72),17)
		for cmd in engine.queue:
			if int(cmd.get("hand_index",-1))==i:b.disabled=true;b.modulate=Color(.7,.8,.85)
	if mode=="executing":
		for button in surface.find_children("*","Button",true,false):button.disabled=true

func _battle_stats_text(hp: int, shield: int) -> String:
	return "完整性 %d/%d · 护盾 %d    算力 %d/%d    指令 %d/3    Trace %d"%[hp,engine.units.player.max_hp,shield,engine.compute-engine.used_compute(),engine.compute,engine.used_slots(),state.run.trace]

func _enemy_button_text(id: String,hp: int,shield: int) -> String:
	var number: int=engine.enemy_ids(false).find(id)+1
	var name: String="溢出狂战体" if engine.units[id].kind=="berserker" else data.enemies[engine.units[id].kind].name
	return "%d · %s\n%d/%d  护盾%d"%[number,name,hp,engine.units[id].max_hp,shield] if hp>0 else "%d · %s · 已退场"%[number,name]

func choose_enemy(id: String) -> void:
	if mode!="battle":return
	selected_enemy=id;presenter.select_actor(id)
	status="已选择 "+engine.actor_name(id)+"；攻击与控制牌将锁定这个目标。"
	_render_battle()

func _combat_event(event: Dictionary) -> void:
	var note: String=event.note
	if event.kind=="result":note={"victory":"敌群已清除","defeat":"完整性耗尽","disengaged":"已脱离交战"}.get(note,note)
	status_label.text="第%d条 · %s：%s"%[event.slot,engine.actor_name(event.side),note]
	battle_stats.text=_battle_stats_text(int(event.health.player),int(event.shields.player))
	for id in enemy_buttons:enemy_buttons[id].text=_enemy_button_text(id,int(event.health[id]),int(event.shields[id]))

func choose_card(index: int) -> void:
	if mode!="battle":return
	var c: Dictionary=engine.cards[engine.hand[index]]
	if c.target=="cell":selected_card=index;basic_move=false;status="点选两格以内地面，安排 "+str(c.name)
	else:status=engine.enqueue(index,[],selected_enemy);selected_card=-1
	_render_battle()

func pick_cell(point: Vector3) -> void:
	if mode!="battle":return
	var p: Vector2i=presenter.pick(point)
	if not engine.grid.walkable(p):status="这里被墙体或家具阻挡。";_render_battle();return
	selected_cell=Grid.packed(p);presenter.select(p)
	if selected_card>=0:status=engine.enqueue(selected_card,selected_cell);selected_card=-1
	elif basic_move:status=engine.enqueue_basic("move",selected_cell);basic_move=false
	else:
		for id in engine.enemy_ids():
			if Grid.cell(engine.units[id].pos)==p:choose_enemy(id);return
		status="选中格 [%d,%d]；先选择移动牌或基础移动。"%[p.x+1,p.y+1]
	_render_battle()

func execute_queue() -> void:
	if mode!="battle":return
	mode="executing";_render_battle()
	var log: Array=engine.execute();state.run.hp=int(engine.units.player.hp);state.sync_bag(engine.resources)
	var noise:=0
	for event in log:
		if event.side=="player" and event.kind=="attack":noise+=3
	state.trace(noise,"攻击暴露位置");checkpoint_save()
	await presenter.replay(log,_combat_event)
	if engine.result!="":_end_combat();return
	engine.begin_window()
	if not selected_enemy in engine.enemy_ids():selected_enemy=engine.default_target()
	presenter.select_actor(selected_enemy);mode="battle";status="窗口结算完毕。护盾清空，每个敌人已重新规划。";checkpoint_save();_render_battle()

func _end_combat() -> void:
	var outcome: String=engine.result
	for event in engine.history:
		if event.kind in ["defeated","result"]:state.log_event("交战%d窗口/第%d条 · %s"%[int(event.get("window",engine.window)),event.slot,event.note])
	if is_instance_valid(presenter):presenter.queue_free()
	presenter=null;engine=null;state.run.combat={}
	if outcome=="defeat":finish_run(false);return
	if outcome=="victory":state.run.cleared[battle_signal]=true
	_rebuild_nodes()
	if battle_signal.begins_with("pursuit_"):
		if outcome=="victory":state.run.known["exit_risk_"+battle_signal.trim_prefix("pursuit_")]=false
		else:status="已脱离追踪战斗，出口风险还在，可以换路。"
	elif outcome=="victory":
		selected_object={"id":"reward_"+battle_signal,"name":"异常体遗留缓存"};state.loot_for(selected_object.id,"server");status="战斗获胜。战利品需要安全撤离。";_open_loot();checkpoint_save();return
	else:status="已脱离本次战斗。敌群仍在，可以保持距离绕开。"
	mode="";_render_explore();checkpoint_save()

func finish_run(success: bool) -> void:
	var summary: Dictionary=state.finish(success);settling_saved=state.save();running=false;mode="settlement"
	_open_panel("撤离成功 · 已返回安全区" if success else "完整性耗尽 · 保险物资已回收",Vector2(940,790))
	modal.remove_child(close_button);close_button.queue_free()
	_label(modal,"%s   ·   带回价值 %d\n探索 %.1f 分钟   ·   最终痕迹 %d\n永久蓝图保留 %d 张"%["样本委托完成 +30 Token" if summary.quest else "本次远征已结算",summary.value,float(summary.elapsed)/60,summary.trace,summary.blueprints.size()],Vector2(30,95),Vector2(880,121),24)
	var list:=PackedStringArray()
	for id in summary.secured:
		if int(summary.secured[id])>0:list.append("%s ×%d"%[data.resources[id].name,summary.secured[id]])
	var gear: String=str(summary.get("module",""))
	var gear_note: String="\n"+str(data.modules[gear].name)+(" · 装备已带回" if summary.module_returned else " · 装备遗失") if gear!="" else ""
	_label(modal,"带回物资：\n"+"   /   ".join(list)+gear_note,Vector2(30,241),Vector2(880,113),23)
	_label(modal,"行动记录：\n"+"\n".join(summary.log.slice(maxi(0,summary.log.size()-7))),Vector2(30,385),Vector2(880,242),19)
	status_label.text="物资已存入独立港口仓库。" if settling_saved else state.last_error
	# The generic close does nothing in settlement; replace it with an explicit safe exit.
	var return_button:=_button(modal,"返回港口",Vector2(30,722),Vector2(425,43),_return_harbor);return_button.disabled=not settling_saved
	_button(modal,"保存并刷新结算",Vector2(485,722),Vector2(425,43),func():settling_saved=state.save();status_label.text="结算已保存。" if settling_saved else state.last_error;return_button.disabled=not settling_saved)

func checkpoint_save() -> bool:
	if running:
		state.run.position=[game.player.position.x,game.player.position.z]
		if engine!=null:state.run.combat={"engine":engine.snapshot(),"signal":battle_signal,"origin":[board_origin.x,board_origin.z]}
	var ok: bool=state.save()
	if not ok:status=state.last_error
	return ok

func pause() -> void:
	if mode=="executing" or mode=="settlement":return
	paused_mode=mode;mode="pause";_open_panel("远征暂停",Vector2(780,430))
	_label(modal,"本局可保存继续，战利品仍需撤离才能获得。",Vector2(30,94),Vector2(720,77),24)
	_button(modal,"继续远征",Vector2(30,187),Vector2(350,51),_resume_pause)
	_button(modal,"保存并回到标题",Vector2(400,187),Vector2(350,51),func():if checkpoint_save():preload("res://ui/loading_transition.gd").instance(get_tree()).change_scene("res://ui/start_menu.tscn","标题界面"))
	_button(modal,"放弃远征，回收保险物资",Vector2(30,254),Vector2(720,47),func():finish_run(false))

func _resume_pause() -> void:
	if paused_mode=="battle":mode="battle";_render_battle()
	else:_render_explore()

func _return_harbor() -> void:
	mode="";running=false;root.hide();game.ui.show()
	if game.location_id=="research":game.request_travel("city")

func handle_input(event: InputEvent) -> bool:
	if not running and mode=="":return false
	if event is InputEventKey and event.pressed and not event.echo:
		if mode=="executing":return true
		if mode=="battle" and event.physical_keycode in [KEY_ENTER,KEY_SPACE]:execute_queue();return true
		if event.physical_keycode==KEY_ESCAPE:
			if mode=="pause":_resume_pause()
			elif mode=="":pause()
			elif mode=="battle":pause()
			elif mode=="briefing":_return_harbor()
			else:_close_panel()
			return true
		if mode=="":
			match event.physical_keycode:
				KEY_E:interact()
				KEY_I:open_bag()
				KEY_R:scan()
				KEY_T:listen()
				KEY_H:heal()
				KEY_Z:game._toggle_view()
				KEY_F5:checkpoint_save()
		return true
	if event is InputEventMouseButton and event.pressed and mode=="battle" and event.button_index==MOUSE_BUTTON_LEFT:
		var mouse: Vector2=game.get_viewport().get_mouse_position()
		var point: Variant=Plane(Vector3.UP,0).intersects_ray(game.camera.project_ray_origin(mouse),game.camera.project_ray_normal(mouse))
		if point!=null:pick_cell(point)
		return true
	if event is InputEventMouseButton and event.pressed and mode=="" and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		game.overview_mode=false;game.view_size=clampf(game.view_size+(-2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 2),14,game.overview_size);return true
	return event is InputEventMouseButton
