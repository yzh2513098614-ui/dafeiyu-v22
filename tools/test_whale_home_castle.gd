extends SceneTree
## Focused real-map checks for the expanded island, garden gates and roof access.
const Safety = preload("res://character/collision_safety.gd")
var game
var checks := 0
var failed := 0
var samples := 0
var report: Array = []

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("review")

func check(ok: bool, label: String) -> void:
	checks += 1
	report.append({"pass": ok, "check": label})
	if ok: print("CASTLE PASS: ", label)
	else: failed += 1; push_error("CASTLE FAIL: " + label)

func settle(n: int = 4) -> void:
	for i in n: await physics_frame

func place(point: Vector3) -> void:
	game.player.position = point; game.player.velocity = Vector3.ZERO
	game.silhouette_body.global_position = point
	game.home_controller.set_layers()

func route(points: Array[Vector3]) -> bool:
	for segment in points.size() - 1:
		var steps: int = maxi(1, ceili(points[segment].distance_to(points[segment + 1]) / .35))
		for i in steps + 1:
			var point: Vector3 = points[segment].lerp(points[segment + 1], float(i) / steps)
			samples += 1
			if not Safety.clear_at(game.player, point) or not Safety.supported(game.player, point):
				print("CASTLE ROUTE BLOCKED: ", point)
				return false
	return true

func stairs(node: Node3D, up: bool) -> bool:
	var spec: Dictionary=node.get_meta("home_stair")
	var front: float=spec.front;var back: float=spec.back;var height: float=spec.base
	place(Vector3(spec.x,height+(.05 if up else 5.25),front+.7 if up else back-.7))
	await settle()
	var arrived := false
	for i in 240:
		game.player.velocity = Vector3(0, -2, -4.2 if up else 4.2)
		game._move_character(1.0/60.0,true)
		game.silhouette_body.global_position = game.player.position
		game.home_controller.set_layers()
		await physics_frame
		if (up and game.player.position.z < back - .5) or (not up and game.player.position.z > front + .4):
			arrived = true; break
	if not arrived: print("CASTLE STAIR BLOCKED: ", spec, " up=", up, " ", game.player.position)
	return arrived and absf(game.player.position.y-(height+5.2 if up else height))<.30 and Safety.supported(game.player,game.player.position)

func review() -> void:
	var prefs = root.get_node("HarborPrefs")
	prefs.continue_game = false; prefs.starting_place = "whale_home"
	prefs.world_save_path = "user://castle_check_world.json"; prefs.settings_path = "user://castle_check_settings.cfg"
	prefs.values.music = false; prefs.values.sfx = false; prefs.values.ambience = false
	prefs.values.follow = true; prefs.values.day_cycle = false
	game = load("res://district/continuous_world.tscn").instantiate()
	root.add_child(game); current_scene = game
	game.life_booted = false; game.set_physics_process(false); game.set_process(false)
	game.loot.save_path = "user://castle_check_inventory.json"
	game.dialogue_controller.save_path = "user://castle_check_dialogue.json"
	game.home_controller.set_process(false)
	await settle(8)
	game.dialogue_controller.close(); game.dialog_open = false
	var home: Node3D = game.home_controller.level
	check(game.location_id == "whale_home", "real continuous-world home entry")
	check(is_equal_approx(home.get_meta("island_area_m2"), 9504.0), "island enlarged to 9504 square metres")
	check(home.get_meta("island_area_multiplier") > 1.6, "island area increased by more than sixty percent")
	var bounds: Rect2 = home.get_meta("estate_boundary")
	var trees := 0; var trees_inside := true; var grass_inside := true
	for node: Node in home.find_children("*", "Node3D", true, false):
		if node.scene_file_path.begins_with("res://models/whale_home/tree_"):
			trees += 1
			var p: Vector3 = node.global_position
			if not bounds.grow(-2.0).has_point(Vector2(p.x, p.z)): trees_inside = false
		if node is MultiMeshInstance3D and node.name.begins_with("GardenGrassTufts_"):
			for i in node.multimesh.visible_instance_count:
				var p: Vector3 = node.global_transform * node.multimesh.get_instance_transform(i).origin
				if not bounds.grow(-.5).has_point(Vector2(p.x, p.z)): grass_inside = false
	check(trees >= 14 and trees_inside, "all planted trees are inside the garden wall")
	check(grass_inside, "all visible grass tufts are inside the garden wall")
	check(home.get_meta("castle_tower_count") == 9, "main spire, house turrets and garden sentries exist")
	check(home.get_meta("upper_roof_footprint").size == Vector2(17, 21), "upper terrace belongs to observatory footprint")
	place(Vector3(0, .05, 30))
	check(route([Vector3(-49.5,.05,30),Vector3(-49.5,.05,-49),Vector3(49.5,.05,-49),Vector3(49.5,.05,30),Vector3(-49.5,.05,30)]), "expanded outer promenade is a clear supported loop")
	check(route([Vector3(-31,.05,22.75),Vector3(-31,.05,-42),Vector3(31,.05,-42),Vector3(31,.05,22.75)]), "original side and rear garden routes remain connected")
	var gate: Node3D = home.get_meta("garden_gate")
	gate.set_open(false); await settle(60)
	place(Vector3(3.5,.05,29.4)); await settle()
	check(not Safety.clear_at(game.player, Vector3(3.5,.05,27)), "closed garden gate has collision")
	check(game.map_interactions._pick().get("node") == gate and game.map_interactions.try_interact(), "garden gate opens through the real E resolver")
	await settle(65)
	check(gate.opened and gate.is_passable(), "garden gate animation leaves a passable opening")
	check(route([Vector3(3.5,.05,30),Vector3(3.5,.05,22),Vector3(0,.05,22),Vector3(0,.05,13),Vector3(3.5,.05,13)]), "gate and fountain have a clear route to the castle entrance")
	var front_door: Node3D = home.get_meta("grand_gate")
	front_door.set_open(true); await settle(65)
	check(route([Vector3(3.5,.05,13),Vector3(3.5,.05,6)]), "existing castle front door remains usable")
	check(route([Vector3(0,.05,30),Vector3(0,.05,43.1)]), "relocated main dock connects to the exit")
	check(route([Vector3(0,.05,39.5),Vector3(-19.1,.05,39.5),Vector3(-19.1,.05,42)]), "relocated bridge and west dock remain connected")
	check(game.home_controller.boats.size() == 2 and home.get_meta("home_moorings").size() == 2, "both boats retain their mooring lines")
	for mooring: Dictionary in home.get_meta("home_moorings"):
		check(mooring.dock.z > 38.0, "mooring anchor follows the expanded shoreline")
	for door: Node3D in home.get_meta("home_room_doors"):
		door.set_open(true)
	await settle(65)
	place(Vector3(-24,10.45,-31))
	check(route([Vector3(-24,10.45,-32.5),Vector3(-24,10.45,5),Vector3(24,10.45,5),Vector3(24,10.45,-32.5),Vector3(-24,10.45,-32.5)]), "third-floor routes pass through the new roof galleries")
	place(Vector3(-16,20.85,-27))
	check(route([Vector3(-16,20.85,-27),Vector3(-4,20.85,-27),Vector3(-4,20.85,-18.6),Vector3(-10.8,20.85,-18.6)]), "upper terrace route clears the main spire and stair landing")
	for path: String in ["Floor0/SeaBreezeStairs_1F_2F","Floor1/StarLightStairs_2F_3F","Floor2/MoonriseStairs_3F_4F","Floor3/LanternStairs_4F_Roof"]:
		var stair: Node3D=home.get_node(path)
		check(await stairs(stair,true),"actual player reaches the upper floor via "+stair.name)
		check(await stairs(stair,false),"actual player returns to the lower floor via "+stair.name)
	place(Vector3(-10.8,15.65,-18.7))
	check(route([Vector3(-10.8,15.65,-18.7),Vector3(-4.2,15.65,-18.7),Vector3(-4.2,15.65,-18.3)]), "fourth-floor landing connects to the telescope approach")
	var ring_supported:=true
	for point: Vector3 in [Vector3(-19.4,15.65,-25),Vector3(-10,15.65,-29.5),Vector3(-.6,15.65,-25),Vector3(-17,15.65,-6.3),Vector3(-3.5,15.65,-6.3)]:
		ring_supported=ring_supported and Safety.supported(game.player,point)
	check(ring_supported,"setback between storeys has continuous structural floor support")
	game.home_controller.exterior_showcase=false;game.home_controller.cutaway=true
	place(Vector3(9,10.45,-8))
	check(home.get_meta("observatory_floor_closure").is_visible_in_tree() and home.get_node("Floor3").visible,"storey closure and observatory floor remain visible from the third-floor outdoor terrace")
	place(Vector3(-5.2,20.85,-11))
	check(not home.get_node("TowerExterior").visible,"covered roof gallery cuts away around the player")
	place(Vector3(-4,20.85,-27))
	check(home.get_node("TowerExterior").visible,"open spire garden keeps the castle roof visible")
	for spec: Array in [["observatory_scope",Vector3(-4.2,15.65,-18.3)],["roof_deck_tea",Vector3(-5.2,20.85,-8.8)],["roof_weather_station",Vector3(-5.1,20.85,-24.0)]]:
		place(spec[1]); await settle()
		print("CASTLE E PROBE: ", spec[0], " at ", game.player.position, " clear=", Safety.clear_at(game.player,spec[1]), " support=", Safety.supported(game.player,spec[1]), " picked=", game.map_interactions._pick().get("node"))
		check(Safety.clear_at(game.player,spec[1]) and Safety.supported(game.player,spec[1]) and game.map_interactions._pick().get("node") == game.world.get_node("HomeAction_"+spec[0]), "accessible E target " + spec[0])
	place(Vector3(3.5,.05,30))
	check(game._save(), "isolated world save succeeds after expansion")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefs.world_save_path))
	check(saved.location == "whale_home", "save keeps original map identity")
	check(game.portals.any(func(portal): return portal.target == "city" and portal.pos.z > 43), "city return portal follows the relocated dock")
	# A save on the retired oversized roof returns safely through the existing
	# layout migration while keeping facility flags and storage identifiers.
	game.visited["whale_home:facility:garden_chime"] = true
	check(game._save(), "isolated save records persistent facility state")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefs.world_save_path))
	legacy.layout_revision = "whale_home_rooftop_tower_v3"
	legacy.position = [22, -17]; legacy.position_y = 20.85
	var legacy_file := FileAccess.open(prefs.world_save_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy)); legacy_file.close()
	check(game._restore(), "previous roof-layout save restores")
	await settle(8)
	check(game.player.position.y < 1 and Safety.supported(game.player,game.player.position), "retired roof save returns to supported entrance")
	check(game.visited.get("whale_home:facility:garden_chime",false), "facility state survives castle layout migration")
	var output := FileAccess.open("user://castle_check_report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":report,"passed":checks-failed,"failed":failed,"route_samples":samples}, "  "))
	print("CASTLE CHECK: ",checks," CHECKS, ",checks-failed," PASSED, ",failed," FAILED; route samples=",samples)
	game.queue_free(); await settle(5)
	quit(1 if failed else 0)
