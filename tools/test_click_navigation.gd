extends SceneTree
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("PASS ", label)
	else: failures += 1; push_error("FAIL " + label)

func frames(count: int) -> void:
	for i in count: await physics_frame

func arrive(limit: int = 900) -> bool:
	for i in limit:
		await physics_frame
		if not game.click_navigation.searching and game.click_navigation.path.is_empty():
			return game.click_navigation.status == "已到达"
	return false

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var prefs = root.get_node("HarborPrefs")
	prefs.values.music = false; prefs.values.sfx = false; prefs.values.ambience = false
	prefs.starting_place = "city"; prefs.continue_game = false
	prefs.world_save_path = "user://click_navigation_test_world.json"
	game = load("res://district/continuous_world.tscn").instantiate()
	root.add_child(game); current_scene = game
	game.set_physics_process(false)
	game.character_controller.set_process(false)
	await frames(4)
	game.autosave_clock = -10000
	# An isolated obstacle on a real floor tests path planning and native movement.
	game._travel("city")
	game.player.position = Vector3(0, 0, 12)
	game._queue_collision_recovery(true)
	await frames(3)
	var obstacle := StaticBody3D.new()
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size = Vector3(2.0, 3.0, 1.0); shape.shape = box
	obstacle.position = Vector3(0, 1.5, 10); obstacle.add_child(shape); game.world.add_child(obstacle)
	await frames(3)
	game.set_physics_process(true)
	var nav = game.click_navigation
	check(nav.request(Vector3(0, 0, 8)), "obstacle route accepted")
	for i in 600:
		await physics_frame
		if not nav.searching: break
	check(not nav.path.is_empty() and nav.path.size() > 1, "A star plans around collider")
	check(await arrive(), "actor reaches target around obstacle")
	check(game.player.position.distance_to(Vector3(0, 0, 8)) < 0.25, "stops at destination")
	check(game._collision_point_allowed(game.player.position, false), "arrival keeps collision clearance")
	var stopped: Vector3 = game.player.position
	await frames(20)
	check(game.player.position.distance_to(stopped) < 0.02, "no movement after arrival")
	obstacle.queue_free(); await frames(2)
	var screen: Vector2 = game.camera.unproject_position(Vector3(4, 0, 8))
	check(nav.click_screen(screen), "screen click projects to ground")
	check(await arrive(), "screen click drives actual movement")
	game.world_minimap._rebuild()
	var target := Vector3(0, 0, 8)
	check(game.world_minimap.unproject(game.world_minimap.project(target)).distance_to(target) < 0.001, "minimap coordinates round trip")
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_RIGHT; click.pressed = true
	click.position = game.world_minimap.project(target)
	game.world_minimap._gui_input(click)
	check(await arrive(), "minimap right click drives movement")
	nav.request(Vector3(8, 0, 8)); game.settings_panel.show(); await frames(3)
	check(nav.path.is_empty() and not nav.searching and game.movement == Vector2.ZERO, "modal cancels navigation")
	game.settings_panel.hide(); nav.request(Vector3(8, 0, 8))
	var key := InputEventKey.new(); key.physical_keycode = KEY_W; key.pressed = true
	Input.parse_input_event(key); await frames(3)
	check(nav.path.is_empty() and not nav.searching, "keyboard takes over navigation")
	key = InputEventKey.new(); key.physical_keycode = KEY_W; key.pressed = false
	Input.parse_input_event(key); await frames(2)
	nav.request(Vector3(8, 0, 8))
	game._travel("whale_home"); await frames(6)
	check(nav.path.is_empty() and not nav.searching, "travel clears old route")
	game.set_physics_process(false)
	var stairs: Array = []
	for node in game.home_controller.level.find_children("*", "Node3D", true, false):
		if node.has_meta("home_stair"): stairs.append(node.get_meta("home_stair"))
	var stair: Dictionary = stairs[0]
	game.player.position = Vector3(stair.x, stair.base + 0.025, stair.front + 0.8)
	game._queue_collision_recovery(true); game._recover_character(true)
	await frames(3)
	game.set_physics_process(true)
	var upstairs := Vector3(stair.x, stair.top + 0.025, stair.back - 0.8)
	check(nav.request(upstairs), "upper floor destination accepted")
	check(await arrive(1800), "navigation traverses physical staircase")
	check(absf(game.player.position.y - upstairs.y) < 0.2, "actor arrives on upper floor")
	check(nav.request(Vector3(stair.x, stair.base + 0.025, stair.front + 0.8)), "downstairs route accepted")
	check(await arrive(1800), "navigation descends physical staircase")
	check(not nav.request(Vector3(999, 0, 999)), "outside destination rejected")
	print("CLICK NAVIGATION CHECKS ", checks, " PASSED ", checks - failures, " FAILED ", failures)
	game.queue_free(); await frames(2)
	quit(1 if failures else 0)
