extends "res://tools/preview_map_surfaces.gd"

func _initialize() -> void:
	prefix="餐厅构图_修改后_" if "--after" in OS.get_cmdline_user_args() else "餐厅构图_修改前_"
	call_deferred("capture")

func restaurant_view(center: Vector3,size: float) -> void:
	game.set_physics_process(false);game.view_center=center;game.view_size=size;game.camera.size=size;game._camera()
	for branch in [game.world,game.shell]:
		for label in branch.find_children("*","Label3D",true,false):label.hide()

func passage_check() -> void:
	var shape:=SphereShape3D.new();shape.radius=.36
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.exclude=[game.player.get_rid()]
	var floor: PackedVector2Array=game.shell.get_meta("floor_contours")[0]
	var cells: Dictionary={};var step:=.5
	for z in range(-28,27):
		for x in range(-32,33):
			var point:=Vector2(x,z)*step
			if not Geometry2D.is_point_in_polygon(point,floor) or game.SpaceShape.distance_to_edge(point,floor)<.40:continue
			query.transform=Transform3D(Basis.IDENTITY,Vector3(point.x,.60,point.y))
			if game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():cells[Vector2i(x,z)]=point
	var origin:=Vector2i(roundi(game.player.position.x/step),roundi(game.player.position.z/step))
	var reached: Dictionary={origin:true};var queue: Array[Vector2i]=[origin];var cursor:=0
	while cursor<queue.size():
		var cell: Vector2i=queue[cursor];cursor+=1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+direction
			if cells.has(next) and not reached.has(next):reached[next]=true;queue.append(next)
	var targets: Array=[]
	for zone in game.room_zones:
		var cell:=Vector2i(roundi(zone.center.x/step),roundi(zone.center.z/step))
		targets.append({"room":zone.name,"reachable":reached.has(cell)})
	for edge in game.shell.get_meta("room_connections"):
		var point: Vector2=edge.point if edge.owners.size()==2 else Vector2(game.portals[0].pos.x,game.portals[0].pos.z)
		var cell:=Vector2i(roundi(point.x/step),roundi(point.y/step))
		targets.append({"door":str(edge.point),"interaction_point":str(point),"width":edge.width,"reachable":reached.has(cell)})
	var interaction: Array=[]
	var original: Vector3=game.player.position
	for spec in [["restaurant_06",Vector3(11.1,0,-2.3)],["restaurant_10",Vector3(12.8,0,-11.7)],["restaurant_09",Vector3(14.3,0,-11.7)]]:
		game.player.position=spec[1]
		var object=game.ContainerRooms.nearest(game)
		var matches: bool=object!=null and str(object.asset_id)==str(spec[0])
		if matches:game._interact()
		interaction.append({"equipment":spec[0],"found":matches,"opened":object.opened if matches else false})
	game.player.position=original
	print("RESTAURANT INTERACTIONS ",JSON.stringify(interaction))
	var report: Dictionary={"clearance_radius":shape.radius,"rooms_and_doors":targets,"interactions":interaction,"free_cells":cells.size(),"reached_cells":reached.size()}
	FileAccess.open("res://预览/餐厅构图_通路检查.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RESTAURANT PASSAGES ",JSON.stringify(report))

func capture() -> void:
	root.size=Vector2i(1200,850)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="restaurant_1"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	game.set_physics_process(false);game.atmosphere.set_time(15);game.atmosphere.cycle_enabled=false;game.ui.hide()
	for i in 3:await process_frame
	restaurant_view(Vector3(0,0,-.5),34);await frame("整层")
	passage_check()
	restaurant_view(Vector3(-6,0,3),22);await frame("就餐区")
	restaurant_view(Vector3(6,0,-6),22);await frame("工作区")
	restaurant_view(Vector3(10.8,0,7.5),12);await frame("窗边小餐室")
	game.atmosphere.set_time(21);restaurant_view(Vector3(-6,0,4),22);await frame("晚间就餐区")
	FileAccess.open("res://预览/"+prefix+"记录.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	quit()
