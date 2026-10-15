extends SceneTree
const Safety = preload("res://character/collision_safety.gd")
const OUTPUT = "res://预览/大肥鱼之家_庭院露台_20261015/"
var game
var checks := 0
var failed := 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("review")

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("OUTDOOR PASS: ", label)
	else: failed += 1; push_error("OUTDOOR FAIL: " + label)

func settle(frames: int = 4) -> void:
	for i in frames: await physics_frame

func place(point: Vector3) -> void:
	game.player.position = point; game.player.velocity = Vector3.ZERO
	game.silhouette_body.global_position = point
	game.home_controller.set_layers()

func route(points: Array) -> bool:
	for segment in points.size() - 1:
		var a: Vector3 = points[segment]
		var end: Vector3 = points[segment + 1]
		var steps := ceili(a.distance_to(end) / .20)
		for i in steps + 1:
			var point: Vector3 = a.lerp(end, float(i) / steps)
			if not Safety.clear_at(game.player, point) or not Safety.supported(game.player, point):
				print("OUTDOOR ROUTE BLOCKED: ", point); return false
	return true

func review() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.get_node("MusicDirector").set_process(false)
	var prefs = root.get_node("HarborPrefs")
	prefs.continue_game = false; prefs.starting_place = "whale_home"
	prefs.world_save_path = OUTPUT + "world.json"; prefs.settings_path = OUTPUT + "settings.cfg"
	prefs.values.music = false; prefs.values.sfx = false; prefs.values.ambience = false
	prefs.values.follow = true; prefs.values.day_cycle = false; prefs.values.fullscreen = false
	game = load("res://district/continuous_world.tscn").instantiate()
	root.add_child(game); current_scene = game
	game.life_booted = false; game.set_physics_process(false)
	game.loot.save_path = OUTPUT + "inventory.json"
	game.dialogue_controller.save_path = OUTPUT + "dialogue.json"
	game.dialogue_controller.state.seen["welcome"] = true
	await settle(8)
	game.dialogue_controller.close(); game.dialog_open = false
	var activities := [
		["balcony_tea", Vector3(-15, 5.25, 3.3)],
		["balcony_rest", Vector3(11, 10.45, -.2)],
		["garden_watering", Vector3(35, .05, -25.3)],
		["garden_chime", Vector3(-6.8, .05, 21.2)]]
	for spec: Array in activities:
		place(spec[1]); await settle()
		var node: Node3D = game.world.get_node("HomeAction_" + spec[0])
		check(Safety.clear_at(game.player, spec[1]) and Safety.supported(game.player, spec[1]), spec[0] + " approach is clear and supported")
		var picked: Dictionary = game.map_interactions._pick()
		var before: float = game.atmosphere.hour
		check(picked.get("node") == node and game.map_interactions.try_interact(), spec[0] + " activates through E")
		await settle(65)
		var valid: bool = not node.busy and not node.get_meta("map_busy", false)
		if node.kind == "sea_rest": valid = valid and is_equal_approx(game.atmosphere.hour, fposmod(before + .5, 24.0))
		elif node.kind == "water": valid = valid and node.opened and node.parts[1].scale.is_equal_approx(Vector3.ONE) and not node.parts[0].get_node("PouringWater").visible
		elif node.kind == "chime": valid = valid and not node.opened and not node.parts[0].visible
		check(valid, spec[0] + " completes its intended effect")
	# Test the public walking lanes, keeping each doorway's own swing unchanged.
	place(Vector3(-15, 5.25, 3.3)); await settle()
	check(route([Vector3(-6.8, 5.25, 4.2), Vector3(-10, 5.25, 3.3), Vector3(-15, 5.25, 3.3)]), "second-floor terrace door connects to the tea seats")
	place(Vector3(11, 10.45, -.2)); await settle()
	check(route([Vector3(8.5, 10.45, .3), Vector3(11, 10.45, -.2), Vector3(17, 10.45, -.2)]), "third-floor terrace retains a lane behind the recliner")
	place(Vector3(35, .05, -25.3)); await settle()
	check(route([Vector3(31, .05, -25.3), Vector3(35, .05, -25.3)]), "side garden walk connects to the watering box")
	place(Vector3(-6.8, .05, 21.2)); await settle()
	check(route([Vector3(0, .05, 22.75), Vector3(-6.8, .05, 22.75), Vector3(-6.8, .05, 21.2)]), "front promenade connects to the wind chime")
	check(game._save(), "isolated outdoor save succeeds")
	game._travel("city"); await settle()
	check(game._restore(), "outdoor save restores through normal map travel")
	await settle()
	var water: Node3D = game.world.get_node("HomeAction_garden_watering")
	var chime: Node3D = game.world.get_node("HomeAction_garden_chime")
	check(water.opened and water.parts[1].scale.is_equal_approx(Vector3.ONE), "watered flower growth survives map reconstruction")
	check(not chime.opened and not chime.parts[0].visible, "stored wind chime stays put away after restoration")
	chime.interact(); await settle(15)
	var angle: float = chime.parts[0].rotation.z
	await settle(20)
	check(chime.opened and chime.parts[0].visible and not is_equal_approx(angle, chime.parts[0].rotation.z), "rehanging the wind chime resumes its sway")
	print("HOME OUTDOOR CHECK: ", checks, " CHECKS, ", checks - failed, " PASSED, ", failed, " FAILED")
	game.queue_free(); await settle(6)
	quit(1 if failed else 0)
