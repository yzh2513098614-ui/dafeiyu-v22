extends SceneTree
## Exercise new annex activities through the game's actual proximity resolver.
const Safety = preload("res://character/collision_safety.gd")
const OUTPUT = "res://预览/大肥鱼之家_室内生活细节_20261015/"
var game
var failed := 0
var checks := 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("review")

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("INTERIOR PASS: ", label)
	else: failed += 1; push_error("INTERIOR FAIL: " + label)

func settle(frames: int = 4) -> void:
	for i in frames: await physics_frame

func furnishing_pose(node: Node3D) -> bool:
	if node.kind == "room_lamp":
		return node.parts[0].visible == node.opened and node.parts[1].material_override.emission_enabled == node.opened
	if node.kind == "wardrobe":
		return is_equal_approx(node.parts[0].position.x, .95 if node.opened else -.95)
	for part: Node3D in node.parts:
		if not is_equal_approx(part.scale.x, .22 if node.opened else 1.0): return false
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
		["star_oven", Vector3(25, .05, -19.9)],
		["flower_wrapping", Vector3(24, .05, -6.9)],
		["bay_journal", Vector3(-21, 5.25, -8.9)],
		["bay_easel", Vector3(24.5, 5.25, -15.9)]]
	for spec: Array in activities:
		var activity: Node3D = game.world.get_node("HomeAction_" + spec[0])
		game.player.position = spec[1]; game.player.velocity = Vector3.ZERO
		game.silhouette_body.global_position = spec[1]
		game.home_controller.set_layers()
		await settle()
		check(Safety.clear_at(game.player, spec[1]) and Safety.supported(game.player, spec[1]), spec[0] + " has a supported, unobstructed approach")
		var origin: Vector3 = activity.parts[0].position
		var picked: Dictionary = game.map_interactions._pick()
		var used: bool = game.map_interactions.try_interact()
		check(picked.get("node") == activity and used and activity.busy, spec[0] + " activates through E proximity interaction")
		await settle(50)
		var finished: bool = not activity.busy and not activity.get_meta("map_busy", false)
		if activity.kind == "read": finished = finished and activity.opened and is_equal_approx(activity.parts[0].rotation.z, PI)
		else: finished = finished and activity.parts[0].position.is_equal_approx(origin)
		check(finished and not game.home_controller.notice.is_empty(), spec[0] + " finishes its animation and releases interaction")
	var furnishings := [
		["lounge_curtain", Vector3(-24.4, .05, -24)],
		["studio_curtain", Vector3(24.4, 5.25, -29)],
		["guest_curtain", Vector3(-24.4, 10.45, -23.5)],
		["lounge_reading_lamp", Vector3(-22.7, .05, -20.5)],
		["library_reading_lamp", Vector3(-24.7, 5.25, -15.4)],
		["rest_reading_lamp", Vector3(25, 10.45, -7.9)],
		["guest_wardrobe", Vector3(-21, 10.45, -18.3)]]
	var saved_states := {}
	game.atmosphere.set_time(22.0)
	for spec: Array in furnishings:
		var furnishing: Node3D = game.world.get_node("HomeAction_" + spec[0])
		game.player.position = spec[1]; game.player.velocity = Vector3.ZERO
		game.silhouette_body.global_position = spec[1]
		game.home_controller.set_layers()
		await settle()
		check(Safety.clear_at(game.player, spec[1]) and Safety.supported(game.player, spec[1]), spec[0] + " approach stays clear at original character size")
		var before: bool = furnishing.opened
		var picked: Dictionary = game.map_interactions._pick()
		var used: bool = game.map_interactions.try_interact()
		check(picked.get("node") == furnishing and used and furnishing.opened != before, spec[0] + " responds to the actual E resolver")
		await settle(58)
		check(not furnishing.busy and furnishing_pose(furnishing), spec[0] + " settles into its switched pose")
		saved_states[spec[0]] = furnishing.opened
	# Keep both lit/unlit and open/closed examples in the same save.
	game.world.get_node("HomeAction_lounge_reading_lamp").interact()
	saved_states["lounge_reading_lamp"] = false
	game.world.get_node("HomeAction_studio_curtain").interact()
	saved_states["studio_curtain"] = true
	await settle(58)
	game.player.position = Vector3(-9.6, .05, 11)
	game.silhouette_body.global_position = game.player.position
	game.home_controller.cutaway = true; game.home_controller.set_layers()
	var upper_lamp: Node3D = game.world.get_node("HomeAction_rest_reading_lamp")
	check(upper_lamp.opened and not upper_lamp.parts[0].is_visible_in_tree(), "upper-floor reading light follows the floor cutaway")
	check(game._save(), "isolated save stores journal, curtains, lamps and wardrobe")
	game._travel("city"); await settle()
	check(game._restore(), "saved home restores after city travel")
	await settle()
	var journal: Node3D = game.world.get_node("HomeAction_bay_journal")
	check(journal.opened and is_equal_approx(journal.parts[0].rotation.z, PI), "journal page pose survives map reconstruction")
	for spec: Array in furnishings:
		var furnishing: Node3D = game.world.get_node("HomeAction_" + spec[0])
		check(furnishing.opened == saved_states[spec[0]] and furnishing_pose(furnishing), spec[0] + " state and pose restore after city travel")
	print("HOME INTERIOR CHECK: ", checks, " CHECKS, ", checks - failed, " PASSED, ", failed, " FAILED")
	game.queue_free(); await settle(6)
	quit(1 if failed else 0)
