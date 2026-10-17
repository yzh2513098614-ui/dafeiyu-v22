extends SceneTree
## Real doorway, room-route and saved-container checks after the suite refit.
const Safety=preload("res://character/collision_safety.gd")
const OUT="res://预览/三层城堡内装_20261017/check/"
var game
var checks:=0
var failures:=0
var samples:=0

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true);call_deferred("review")

func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("SUITE PASS: ",label)
	else:failures+=1;push_error("SUITE FAIL: "+label)

func settle(n: int=4) -> void:
	for i in n:await physics_frame

func place(point: Vector3) -> void:
	game.player.position=point;game.player.velocity=Vector3.ZERO
	game.silhouette_body.global_position=point
	game.home_controller.set_layers()

func route(points: Array[Vector3]) -> bool:
	for i in points.size()-1:
		var count: int=maxi(1,ceili(points[i].distance_to(points[i+1])/.20))
		for j in count+1:
			var point: Vector3=points[i].lerp(points[i+1],float(j)/count)
			samples+=1
			if not Safety.clear_at(game.player,point) or not Safety.supported(game.player,point):
				print("SUITE BLOCKED: ",point);return false
	return true

func review() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="whale_home"
	prefs.world_save_path=OUT+"world.json";prefs.settings_path=OUT+"settings.cfg"
	prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false
	prefs.values.follow=true;prefs.values.day_cycle=false;prefs.values.fullscreen=false
	game=load("res://district/continuous_world.tscn").instantiate()
	root.add_child(game);current_scene=game
	game.life_booted=false;game.set_physics_process(false);game.set_process(false)
	game.loot.save_path=OUT+"inventory.json";game.dialogue_controller.save_path=OUT+"dialogue.json"
	game.home_controller.set_process(false)
	await settle(8)
	game.dialogue_controller.close();game.dialog_open=false
	var home: Node3D=game.home_controller.level
	game.home_controller.exterior_showcase=false;game.home_controller.cutaway=true
	var by_name: Dictionary={}
	for door: Node3D in home.get_meta("home_room_doors"):by_name[String(door.name)]=door
	for spec: Array in [["floor_3_west_rear",Vector3(-11.2,10.45,-21)],["bedroom",Vector3(-10.8,10.45,-20.2)],["bathroom",Vector3(-10.8,10.45,-26)],["rooftop_entry",Vector3(-16.75,10.45,-3.7)]]:
		var door: Node3D=by_name["RoomDoor_"+spec[0]]
		place(spec[1]);door.set_open(false);await settle(50)
		var clear: bool=Safety.clear_at(game.player,game.player.position) and Safety.supported(game.player,game.player.position)
		var blocks: bool=not Safety.clear_at(game.player,door.global_position+Vector3(0,.05,0))
		var picked: bool=game.map_interactions._pick().get("node")==door
		if not picked:print("SUITE E PICK: ",spec[0]," ",game.map_interactions._pick())
		var used: bool=game.map_interactions.try_interact() if picked else false
		await settle(50)
		check(clear and blocks and used and door.is_passable(),"closed door blocks and real E opens "+spec[0])
		if not door.opened:door.set_open(true);await settle(50)
		var crossing: Array[Vector3]=[]
		for i in 25:crossing.append(door.to_global(Vector3(0,.05,-2.4+i*.2)))
		check(route(crossing),"actual silhouette clears dressed doorway "+spec[0])
	place(Vector3(-10.8,10.45,-18.4))
	check(route([Vector3(-10.8,10.45,-18.4),Vector3(-10.8,10.45,-28.2)]),"landing connects bedroom and bathroom doors")
	check(route([Vector3(-10.8,10.45,-20.2),Vector3(-6.1,10.45,-20.2),Vector3(-6.1,10.45,-19.15),Vector3(-1.25,10.45,-19.15),Vector3(-1.25,10.45,-11.5),Vector3(-4.25,10.45,-11.5)]),"master bed and bench keep a full-width walking route")
	check(route([Vector3(-10.8,10.45,-21),Vector3(-16,10.45,-21)]),"guest bed approach stays clear of its desk")
	check(route([Vector3(-16,10.45,-20.5),Vector3(-18.5,10.45,-20.5),Vector3(-18.5,10.45,-27.15),Vector3(-14.8,10.45,-27.15)]),"guest bed keeps access to both bedside containers")
	check(route([Vector3(-10.8,10.45,-26),Vector3(-6.8,10.45,-26),Vector3(-1.5,10.45,-26.5)]),"bath entrance connects tub, basin and shower")
	check(route([Vector3(-10.8,10.45,-18.4),Vector3(-10.8,10.45,-16.3),Vector3(-16.7,10.45,-16.3),Vector3(-16.7,10.45,-8.2),Vector3(-16.75,10.45,-3.7)]),"upper landing connects wardrobe and terrace entrance")
	for spec: Array in [["whale_bed",Vector3(-4.25,10.45,-11.5)],["guest_bed",Vector3(-16,10.45,-20.5)],["guest_wardrobe",Vector3(-16.8,10.45,-15.4)],["cabinet_m4p8_10p4_m18p9",Vector3(-3.7,10.45,-19.15)],["cabinet_1p1_10p4_m14p4",Vector3(-2,10.45,-19.15)]]:
		place(spec[1]);await settle()
		var action: Node3D=game.world.get_node("HomeAction_"+spec[0])
		var reachable: bool=Safety.clear_at(game.player,game.player.position) and Safety.supported(game.player,game.player.position)
		var picked: bool=game.map_interactions._pick().get("node")==action
		if not picked:print("SUITE ACTION PICK: ",spec[0]," ",game.map_interactions._pick())
		check(reachable and picked,"existing E target remains reachable "+spec[0])
	var wardrobe: Node3D=game.world.get_node("HomeAction_guest_wardrobe")
	place(Vector3(-16.8,10.45,-15.4));await settle()
	game.map_interactions.try_interact();await settle()
	check(game.loot.current_chest==wardrobe and game.loot.mode=="loot","wardrobe opens the original shared storage UI")
	game.loot.close();await settle(50)
	var stock_id: String=wardrobe.container_id
	game.loot.stocks[stock_id]={"crystal_cluster":3}
	var storage_ids: Array[String]=[]
	for chest in game.loot.chests:storage_ids.append(chest.container_id)
	storage_ids.sort()
	check(game.loot.save_state() and game._save(),"suite save keeps cabinet stock and opened room doors")
	game._travel("city");await settle(6)
	check(game._restore(),"real map travel restores the suite save")
	await settle(8)
	var restored_ids: Array[String]=[]
	for chest in game.loot.chests:restored_ids.append(chest.container_id)
	restored_ids.sort()
	check(restored_ids==storage_ids and game.loot.stocks[stock_id].crystal_cluster==3,"all original container IDs and contents survive travel")
	var kept: bool=true
	for door: Node3D in game.home_controller.level.get_meta("home_room_doors"):
		if String(door.name) in ["RoomDoor_bedroom","RoomDoor_bathroom","RoomDoor_floor_3_west_rear","RoomDoor_rooftop_entry"]:kept=kept and door.opened
	check(kept,"each refitted room keeps its saved door state")
	print("SUITE CHECK: ",checks," CHECKS, ",checks-failures," PASSED, ",failures," FAILED; route samples=",samples)
	quit(1 if failures else 0)
