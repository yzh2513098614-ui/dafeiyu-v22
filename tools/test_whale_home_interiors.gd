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
	check(game._save(), "isolated save stores journal page")
	game._travel("city"); await settle()
	check(game._restore(), "saved home restores after city travel")
	await settle()
	var journal: Node3D = game.world.get_node("HomeAction_bay_journal")
	check(journal.opened and is_equal_approx(journal.parts[0].rotation.z, PI), "journal page pose survives map reconstruction")
	print("HOME INTERIOR CHECK: ", checks, " CHECKS, ", checks - failed, " PASSED, ", failed, " FAILED")
	game.queue_free(); await settle(6)
	quit(1 if failed else 0)
