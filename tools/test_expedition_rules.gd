extends SceneTree
const Sim=preload("res://expedition/combat_simulator.gd")
const State=preload("res://expedition/run_state.gd")
const Grid=preload("res://expedition/tactical_grid.gd")
const Director=preload("res://expedition/encounter_director.gd")
var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/expedition/rules.json"))
var failures:=0
var checks:=0

func expect(condition: bool,note: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: "+note)

func battle(seed_value:=1):
	var sim=Sim.new(data,seed_value)
	sim.start("guardian",48,{"token":12,"medical":1},[],[],[3,4],[3,2]);return sim

func idle_plan() -> Array:
	return [{"kind":"wait"},{"kind":"wait"},{"kind":"wait"}]

func _initialize() -> void:
	var sim=battle();sim.hand=["token_burst","firewall","data_probe","rate_limit","async_jump"]
	var plan: Array=sim.enemy_plan.duplicate(true)
	expect(sim.enqueue(0)=="","enqueue a card")
	expect(sim.units.enemy.hp==36,"planning never deals immediate damage")
	expect(sim.enqueue(0)!="","cannot reserve same hand card twice")
	expect(sim.enqueue(1)=="" and sim.enqueue(2)=="","three independent slots")
	expect(sim.used_compute()==2 and sim.used_slots()==3,"compute and slots are distinct")
	expect(sim.enqueue(3)!="","slot budget rejects fourth command")
	expect(sim.enemy_plan==plan,"enemy plan cannot react to player queue")
	sim.enemy_plan=idle_plan();sim.execute()
	expect(sim.units.enemy.hp==24,"queued attack resolves once")
	expect(sim.resources.token==11,"consumable ammo really spent")
	expect(sim.hand.size()==2,"used cards leave hand")
	expect(sim.execute().is_empty() and sim.resources.token==11,"completed window cannot execute twice")
	var copy=Sim.new(data);copy.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
	sim.begin_window();copy.begin_window()
	expect(copy.hand==sim.hand and copy.enemy_plan==sim.enemy_plan,"resume preserves draw order and enemy plan")
	expect(bool(sim.units.player.revealed),"recon provides actionable intent information in the next planning window")
	var collision=battle();collision.units.player.pos=[2,3];collision.units.enemy.pos=[4,3]
	collision.enqueue_basic("move",[3,3]);collision.enemy_plan=[{"kind":"move","target":[3,3],"value":2},{"kind":"wait"},{"kind":"wait"}];collision.execute()
	expect(collision.units.player.pos==[2,3] and collision.units.enemy.pos==[4,3],"same cell conflict blocks both simultaneously")
	var crossing=battle();crossing.units.player.pos=[0,1];crossing.units.enemy.pos=[1,0]
	crossing.enqueue_basic("move",[2,1]);crossing.enemy_plan=[{"kind":"move","target":[1,2],"value":2},{"kind":"wait"},{"kind":"wait"}];crossing.execute()
	expect(crossing.units.player.pos==[0,1] and crossing.units.enemy.pos==[1,0],"crossing trajectories conflict at simultaneous intermediate cell")
	var room_walls: Array=[]
	for y in 8:
		for x in 8:
			if x<2 or x>5 or y<2 or y>5:room_walls.append([x,y])
	var enclosed=Sim.new(data);enclosed.start("guardian",48,{},room_walls,[],[3,4],[3,2])
	expect(not enclosed.grid.escape_cells.is_empty() and not enclosed.grid.path(Vector2i(3,4),Grid.cell(enclosed.grid.escape_cells[0]),64,[Vector2i(3,2)]).is_empty(),"small enclosed rooms retain a reachable retreat cell")
	var mutual=battle();mutual.units.player.hp=6;mutual.units.enemy.hp=6;mutual.hand=["token_burst"]
	mutual.enqueue(0);mutual.enemy_plan=[{"kind":"attack","value":8,"range":5},{"kind":"wait"},{"kind":"wait"}];mutual.execute()
	expect(mutual.units.player.hp==0 and mutual.units.enemy.hp==0 and mutual.result=="defeat","simultaneous lethal damage, no player-first advantage")
	var sandbox=battle();sandbox.hand=["sandbox","token_burst"]
	sandbox.enqueue(0);sandbox.enqueue(1);sandbox.enemy_plan=[{"kind":"corrupt","value":1,"range":8},{"kind":"jam","value":1,"range":8},{"kind":"wait"}];sandbox.execute()
	expect(not "hallucination" in sandbox.discard and sandbox.units.enemy.hp==24,"sandbox resists pollution and interrupt")
	var jam=battle();jam.hand=["prompt_injection"];jam.enqueue(0);jam.enemy_plan=[{"kind":"attack","value":20,"range":8},{"kind":"wait"},{"kind":"wait"}];jam.execute()
	expect(jam.units.player.hp==48,"control phase interrupts same-slot attack")
	var escape=battle();escape.units.player.pos=[1,4];escape.units.enemy.pos=[4,4]
	escape.enqueue_basic("move",[0,4]);expect(escape.enqueue_basic("escape")=="","escape available without drawing a card");escape.enemy_plan=idle_plan();escape.execute()
	expect(escape.result=="disengaged","grid edge enables combat disengagement")
	var walls=Grid.new([[2,2]])
	expect(not walls.sight(Vector2i(1,2),Vector2i(3,2)),"wall blocks attacks")
	expect(walls.path(Vector2i(1,2),Vector2i(3,2),2).is_empty(),"movement cannot cross wall")
	var thin=Grid.new();thin.blocked_edges=[Grid.edge(Vector2i(1,1),Vector2i(1,2))]
	expect(thin.path(Vector2i(1,1),Vector2i(1,2),1).is_empty() and not thin.sight(Vector2i(1,1),Vector2i(1,2)),"thin walls between grid centers block both movement and attacks")
	var state=State.new(data);state.new_run(17)
	expect(state.occupied(state.run.insured)==0,"empty insurance has zero capacity usage")
	var loot: Dictionary=state.loot_for("sample","sample")
	expect(state.loot_for("sample","sample")==loot,"loot generated once per container")
	expect(state.take("sample","sample",1)=="","quest sample can be collected")
	expect(state.profile.warehouse.is_empty(),"unextracted loot never enters permanent warehouse")
	expect(state.insure("sample").begins_with("已保护"),"two slot sample fits insurance")
	expect(state.insure("medical")=="保险仓只有两格容量","insurance capacity cannot be exceeded")
	state.profile.blueprints.append("test_unlock");var summary: Dictionary=state.finish(false)
	expect(summary.secured.sample==1 and int(state.profile.warehouse.get("medical",0))==0,"death returns insured items only")
	expect("test_unlock" in state.profile.blueprints,"permanent blueprints retained")
	var unlock=battle();unlock.start("guardian",48,{},[],[],[3,4],[3,2],["context_overflow"])
	expect("context_overflow" in unlock.hand+unlock.draw_pile,"permanent blueprints grant actual combat cards")
	var warehouse: Dictionary=state.profile.warehouse.duplicate(true);state.finish(false)
	expect(state.profile.warehouse==warehouse,"settlement cannot grant duplicate rewards")
	state.new_run(20);state.loot_for("samples","sample");state.take("samples","sample",1);summary=state.finish(true)
	expect(summary.quest and int(state.profile.warehouse.token)==30,"quest reward added only after extraction; loaned supplies excluded")
	var free_run=State.new(data);free_run.new_run(10);free_run.finish(true)
	expect(free_run.value_of(free_run.profile.warehouse)==0,"empty expeditions cannot farm issued consumables")
	for seed_value in 80:
		var test=battle(seed_value)
		for turn in 30:
			if test.result!="":break
			for i in test.hand.size():test.enqueue(i)
			test.execute()
			expect(test.units.player.hp>=0 and test.units.enemy.hp>=0,"health remains nonnegative")
			if test.result=="":test.begin_window()
		expect(test.result!="","encounters terminate within bounded windows")
	print("EXPEDITION RULES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
