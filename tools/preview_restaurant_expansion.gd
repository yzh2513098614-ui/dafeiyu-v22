extends "res://tools/preview_restaurant_composition.gd"
## One production render pass and the routes that the new floors actually use.
var routes: Array=[]

func _initialize() -> void:
	prefix="餐厅扩建_"
	call_deferred("capture")

func check_routes(tag: String,secret_open: bool=false) -> void:
	var shape:=SphereShape3D.new();shape.radius=.36
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.exclude=[game.player.get_rid()]
	var contours: Array=game.shell.get_meta("floor_contours")
	var cells: Dictionary={};var step:=.5
	for z in range(-46,49):
		for x in range(-40,51):
			var point:=Vector2(x,z)*step
			var on_floor:=false
			for contour in contours:
				if Geometry2D.is_point_in_polygon(point,contour) and game.SpaceShape.distance_to_edge(point,contour)>.40:on_floor=true;break
			if not on_floor:continue
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
	for n in game.room_zones.size():
		var zone: Dictionary=game.room_zones[n]
		var cell:=Vector2i(roundi(zone.center.x/step),roundi(zone.center.z/step))
		var expected: bool=game.location_id!="restaurant_b1" or n!=6 or secret_open
		targets.append({"room":zone.name,"reachable":reached.has(cell),"expected":expected,"ok":reached.has(cell)==expected})
	for edge in game.shell.get_meta("room_connections"):
		if edge.owners.size()!=2:continue
		var point: Vector2=edge.point
		var cell:=Vector2i(roundi(point.x/step),roundi(point.y/step))
		var expected: bool=not edge.hidden or secret_open
		targets.append({"door":str(point),"reachable":reached.has(cell),"expected":expected,"ok":reached.has(cell)==expected})
	for portal in game.portals:
		var cell:=Vector2i(roundi(portal.pos.x/step),roundi(portal.pos.z/step))
		targets.append({"stairs_or_exit":portal.label,"reachable":reached.has(cell),"ok":reached.has(cell)})
	for chest in game.loot.chests:
		var point: Vector3=chest.global_position+Vector3(0,0,1.3)
		var cell:=Vector2i(roundi(point.x/step),roundi(point.z/step))
		var expected: bool=game.location_id!="restaurant_b1" or secret_open
		targets.append({"container":chest.display_name,"reachable":reached.has(cell),"expected":expected,"ok":reached.has(cell)==expected})
	var failures: Array=targets.filter(func(target):return not target.ok)
	routes.append({"floor":tag,"targets":targets,"failures":failures,"spawn_clear":cells.has(origin),"free_cells":cells.size(),"reached_cells":reached.size()})
	print("RESTAURANT FLOOR ",tag," FAILURES ",JSON.stringify(failures))

func floor_view(id: String,center: Vector3,size: float) -> void:
	game._travel(id);game.set_physics_process(false);game.atmosphere.set_time(15);game.atmosphere.cycle_enabled=false;game.ui.hide()
	restaurant_view(center,size)

func capture() -> void:
	root.size=Vector2i(1200,850)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="restaurant_1"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	game.set_physics_process(false);game.atmosphere.set_time(15);game.atmosphere.cycle_enabled=false;game.ui.hide()
	game.visited.erase("restaurant_b1:hidden_door_open")
	game.visited.erase("restaurant_b1:hidden_room_discovered")
	game.loot.stocks.restaurant_hidden_cache=game.loot.INITIAL_STOCK.restaurant_hidden_cache.duplicate()
	for i in 3:await process_frame
	restaurant_view(Vector3(3,0,-.5),40);await frame("一层整图");check_routes("1F")
	floor_view("restaurant_2",Vector3(0,0,3),43);await frame("二层包间与露台");check_routes("2F")
	routes.append({"travel":"1F -> 2F","spawn":str(game.player.position),"ok":game.player.position.distance_to(Vector3(18,0,-1.3))<.01})
	game._travel("restaurant_1");game.set_physics_process(false)
	routes.append({"travel":"2F -> 1F","spawn":str(game.player.position),"ok":game.player.position.distance_to(Vector3(21,0,-1.4))<.01})
	floor_view("restaurant_b1",Vector3(0,0,-3),40);await frame("地下层暗门关闭");check_routes("B1 closed")
	var gate: Node3D=game.world.get_node("RestaurantHiddenDoor")
	game.player.position=Vector3(1,0,-13.5);game.nearest_portal={}
	var candidate=game.ContainerRooms.nearest(game)
	game._interact()
	for i in 55:await process_frame
	routes.append({"interaction":"E opens hidden shelf","found":candidate==gate,"opened":gate.opened,"room_visible":gate.room.visible,"equipment_visible":gate.room_equipment.all(func(item):return item.visible),"ok":candidate==gate and gate.opened})
	game.player.position=Vector3(0,0,7.5);check_routes("B1 open",true)
	restaurant_view(Vector3(0,0,-3),40);await frame("地下层暗门打开")
	game.player.position=Vector3(1,0,-17);restaurant_view(Vector3(1.5,0,-17),14);await frame("隐藏暗室")
	var cache: Node3D=game.loot.chests[0]
	game.player.position=cache.global_position+Vector3(0,0,1.3)
	game.loot.nearby=cache;game.loot.open_chest()
	var took: bool=game.loot.transfer("cache_book",1)
	game._travel("restaurant_1");game.set_physics_process(false)
	routes.append({"travel":"B1 -> 1F","spawn":str(game.player.position),"ok":game.player.position.distance_to(Vector3(20.7,0,-9))<.01})
	game._travel("restaurant_b1");game.set_physics_process(false)
	gate=game.world.get_node("RestaurantHiddenDoor")
	routes.append({"persistence":"hidden door and empty book stock after travel","opened":gate.opened,"took_book":took,"remaining":game.loot.stocks.restaurant_hidden_cache.cache_book,"ok":gate.opened and took and game.loot.stocks.restaurant_hidden_cache.cache_book==0})
	FileAccess.open("res://预览/餐厅扩建_通路与暗门检查.json",FileAccess.WRITE).store_string(JSON.stringify(routes,"\t"))
	FileAccess.open("res://预览/餐厅扩建_灯光记录.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	print("RESTAURANT EXPANSION COMPLETE ",JSON.stringify(routes.filter(func(item):return item.has("ok") and not item.ok)))
	quit()
