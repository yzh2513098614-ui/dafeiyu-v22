extends SceneTree
const Grid=preload("res://expedition/tactical_grid.gd")
var Site
var failures:=0
var game
var expedition

func _initialize() -> void:call_deferred("run")

func check(ok: bool,note: String) -> void:
	if ok:print("PASS: "+note)
	else:failures+=1;printerr("FAIL: "+note)

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/GDD骨架_"+name+".png")

func run() -> void:
	Site=load("res://expedition/research_site.gd")
	root.size=Vector2i(1000,750)
	var prefs=root.get_node("HarborPrefs");prefs.continue_game=false;prefs.starting_place="research";prefs.values.fullscreen=false;prefs.values.day_cycle=false
	var menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu)
	check(menu.menu_buttons.has("research"),"actual title screen exposes research expedition")
	await capture("标题入口");menu.free()
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	for i in 10:await process_frame
	expedition=game.expedition_controller
	check(game.location_id=="research" and expedition.mode=="briefing","research scene starts at briefing")
	await capture("委托说明")
	expedition.start_run(false)
	for i in 4:await physics_frame
	check(expedition.running and not game.ui.visible,"dedicated expedition HUD freezes life-mode interfaces")
	check(expedition.nodes.size()==18,"seven loot containers, two exits, four signals and five doors wired")
	check(not game.character_controller.free_world(),"life inventory and survival ticks cannot leak into expedition")
	for i in 24:await physics_frame
	await capture("探索")
	var beginning: Vector3=game.player.position;game.movement=Vector2.RIGHT
	for i in 12:await physics_frame
	game.movement=Vector2.ZERO
	check(game.player.position.distance_to(beginning)>.1,"existing eight-direction character moves in research scene")
	for door in Site.DOORS:
		game.player.position=Vector3(door.pos[0]-(1.1 if door.axis=="z" else 0),0,door.pos[1]+(1.1 if door.axis=="x" else 0))
		for i in 2:await physics_frame
		expedition._process(.3);expedition.interact()
		check(expedition.state.run.opened.get(door.id,false),"E interaction opens "+str(door.id))
	for i in 3:await physics_frame
	_check_navigation()
	game.player.position=Vector3(16,0,-2.9)
	for i in 3:await physics_frame
	expedition._process(.3);expedition.interact()
	check(expedition.mode=="loot" and expedition.selected_object.id=="samples","E opens the physical sample container")
	await capture("搜索容器")
	for button in expedition.modal.find_children("*","Button",true,false):
		if button.text=="收取一件":button.pressed.emit();break
	check(int(expedition.state.run.bag.get("sample",0))==1,"actual loot button collects quest sample")
	expedition._close_panel()
	expedition.open_bag();await capture("远征背包");expedition._close_panel()
	game.player.position=Vector3(-9,0,-6)
	for i in 3:await physics_frame
	var before_token:=int(expedition.state.run.bag.get("token",0));expedition.scan()
	check(int(expedition.state.run.bag.get("token",0))==before_token-1 and expedition.state.run.known.has("event_signal_lab"),"persistent scanner spends a real Token and resolves full signal intelligence")
	expedition.start_combat("hallucination","signal_lab")
	check(expedition.mode=="battle" and expedition.presenter!=null,"actual geometry opens local tactical combat")
	if expedition.engine==null:quit(1);return
	expedition.engine.hand=["async_jump","sandbox","token_burst","data_probe","gradient_descent"]
	expedition._render_battle();await capture("同步指令")
	var before_hp: int=expedition.engine.units.enemy.hp
	expedition.choose_card(2)
	check(expedition.engine.queue.size()==1 and int(expedition.engine.units.enemy.hp)==before_hp,"UI queues card instead of applying immediate damage")
	expedition.fast=true;expedition.presenter.fast=true
	await expedition.execute_queue()
	check(expedition.mode in ["battle","loot",""],"real simulator event log plays and returns to planning")
	if expedition.engine!=null:
		check(expedition.checkpoint_save(),"active battle checkpoint saves")
		var saved: Dictionary=expedition.state.run.combat.duplicate(true)
		var reload=load("res://expedition/combat_simulator.gd").new(expedition.data);reload.restore(JSON.parse_string(JSON.stringify(saved.engine)))
		check(int(reload.units.player.hp)==int(expedition.engine.units.player.hp) and Grid.cell(reload.units.player.pos)==Grid.cell(expedition.engine.units.player.pos) and int(reload.units.enemy.hp)==int(expedition.engine.units.enemy.hp) and reload.hand==expedition.engine.hand,"JSON reload preserves tactical state")
		expedition.engine.result="disengaged";expedition._end_combat()
	check(expedition.running and expedition.mode=="","combat disengagement leaves expedition active")
	expedition.state.run.bag.sample=1;expedition.state.run.quest=true;expedition.finish_run(true)
	check(expedition.mode=="settlement" and not expedition.running and expedition.state.profile.quest_completed>0,"extraction completes quest and enters safe settlement")
	await capture("撤离结算")
	expedition._return_harbor()
	for i in 3:await physics_frame
	check(game.location_id=="city" and game.ui.visible,"return to existing harbor world")
	print("EXPEDITION SCENE FAILURES: ",failures);quit(1 if failures else 0)

func _check_navigation() -> void:
	var shape:=SphereShape3D.new();shape.radius=.36
	var free: Dictionary={}
	var polygons: Array=game.shell.get_meta("floor_contours",[])
	for y in range(-24,25):
		for x in range(-32,37):
			var p:=Vector3(x*.5,0,y*.5);var inside:=false
			for poly in polygons:
				if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),poly) and Site.Shape.distance_to_edge(Vector2(p.x,p.z),poly)>.43:inside=true
			if not inside:continue
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=p+Vector3(0,.5,0);query.collision_mask=1;query.exclude=[game.player.get_rid()]
			if game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():free[Vector2i(x,y)]=true
	var start:=Vector2i(-20,16);var visited: Dictionary={start:true};var queue: Array=[start];var cursor:=0
	while cursor<queue.size():
		var at: Vector2i=queue[cursor];cursor+=1
		for d in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var next: Vector2i=at+d
			if free.has(next) and not visited.has(next):visited[next]=true;queue.append(next)
	for object in Site.OBJECTS:
		var reached:=false
		var reachable_interaction:=false
		for cell: Vector2i in visited:
			if (Vector2(cell)*.5).distance_to(Vector2(object.pos[0],object.pos[1]))<1.8:
				reached=true;game.player.position=Vector3(cell.x*.5,0,cell.y*.5)
				if expedition._reachable(Vector3(object.pos[0],0,object.pos[1]),object.id):reachable_interaction=true;break
		check(reached,"navigation reaches "+str(object.name))
		check(reachable_interaction,"walls permit actual interaction with "+str(object.name))
