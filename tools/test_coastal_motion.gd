extends SceneTree
const Safety = preload("res://character/collision_safety.gd")
var game
var checked := 0
var failed := 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://预览/波浪潮汐_20261014"))
	call_deferred("review")

func check(value: bool, label: String) -> void:
	checked += 1
	if value:
		print("COASTAL PASS: ", label)
	else:
		failed += 1
		push_error("COASTAL FAIL: " + label)

func review() -> void:
	var prefs = root.get_node("HarborPrefs")
	prefs.continue_game = false
	prefs.starting_place = "whale_home"
	prefs.world_save_path = "res://预览/波浪潮汐_20261014/world.json"
	prefs.settings_path = "res://预览/波浪潮汐_20261014/settings.cfg"
	prefs.values.music = false; prefs.values.sfx = false; prefs.values.ambience = false
	prefs.values.day_cycle = false; prefs.values.follow = true; prefs.values.fullscreen = false
	game = load("res://district/continuous_world.tscn").instantiate()
	root.add_child(game); current_scene = game
	game.life_booted = false; game.set_physics_process(false)
	game.loot.save_path = "res://预览/波浪潮汐_20261014/inventory.json"
	game.dialogue_controller.save_path = "res://预览/波浪潮汐_20261014/dialogue.json"
	var home = game.home_controller
	home.set_process(false)
	for i in 6: await physics_frame
	game.dialogue_controller.close(); game.dialog_open = false
	game.atmosphere.set_time(12)
	var water: ShaderMaterial = home.level.get_meta("sea_material")
	var settings: Dictionary = home.sea_motion.settings
	var period: float = settings.tide_period
	var levels: Array[float] = []
	var boat_levels: Array[float] = []
	var clock_ok := true
	var rope_error := 0.0
	for time in [0.0, period * 0.25, period * 0.5, period * 0.75, period]:
		home.sea_clock = time
		home._process(0.0)
		await process_frame
		levels.append(home.sea_surface.position.y)
		boat_levels.append(home.boats[0].position.y)
		clock_ok = clock_ok and is_equal_approx(float(water.get_shader_parameter("wave_time")), time)
		for mooring: Dictionary in home.moorings:
			var mesh: MultiMesh = mooring.line.multimesh
			var first := mesh.get_instance_transform(0)
			var last := mesh.get_instance_transform(mesh.instance_count - 1)
			var start: Vector3 = mooring.line.global_transform * (first.origin - first.basis.y * 0.5)
			var end: Vector3 = mooring.line.global_transform * (last.origin + last.basis.y * 0.5)
			rope_error = maxf(rope_error, maxf(start.distance_to(mooring.dock), end.distance_to(mooring.eye.global_position)))
	check(is_equal_approx(levels[1], float(settings.base_level) + float(settings.tide_amplitude)), "high tide raises the actual ocean mesh")
	check(is_equal_approx(levels[3], float(settings.base_level) - float(settings.tide_amplitude)), "low tide lowers the actual ocean mesh")
	check(is_equal_approx(levels[0], levels[4]), "tide returns smoothly after one cycle")
	check(clock_ok, "GPU wave clock follows the controller at every tide phase")
	check(boat_levels[1] - boat_levels[3] > 0.10, "moored boat follows the rising and falling sea")
	check(rope_error < 0.001, "both mooring ends remain attached through the tide")
	var slopes_ok := true
	for point in [Vector2(28.8, 24.1), Vector2(31.5, 28.0), Vector2(36, 40)]:
		var sample: Vector3 = home.sea_motion.sample(point, 13.0)
		var dx: float = (home.sea_motion.sample(point + Vector2(0.02, 0), 13.0).x - home.sea_motion.sample(point - Vector2(0.02, 0), 13.0).x) / 0.04
		var dz: float = (home.sea_motion.sample(point + Vector2(0, 0.02), 13.0).x - home.sea_motion.sample(point - Vector2(0, 0.02), 13.0).x) / 0.04
		slopes_ok = slopes_ok and absf(sample.y - dx) < 0.001 and absf(sample.z - dz) < 0.001
	check(slopes_ok, "boat tilt matches the water slope near shore and offshore")
	home.sea_clock = period * 0.5; home._process(0.0)
	var wet_ok := true
	for material: ShaderMaterial in home.coastal_materials:
		wet_ok = wet_ok and float(material.get_shader_parameter("wet_level")) > float(material.get_shader_parameter("water_level")) + 0.1
	check(wet_ok, "ebb tide leaves wet marks on rock and timber materials")
	var boat_before: Vector3 = home.boats[0].position
	var clock_before: float = water.get_shader_parameter("wave_time")
	game.pause_menu.active = true
	home._process(1.0)
	check(home.boats[0].position.is_equal_approx(boat_before) and is_equal_approx(float(water.get_shader_parameter("wave_time")), clock_before), "pause freezes the boat and all shader motion together")
	game.pause_menu.active = false
	home._process(0.25)
	check(float(water.get_shader_parameter("wave_time")) > clock_before, "resuming continues the sea clock")
	var slabs: Array = home.level.get_meta("walkable_slabs")
	var maximum_water: float = levels[1] + float(settings.wave_height) * (1.0 + float(settings.crest_sharpness) * 0.5)
	check(maximum_water < float(slabs.back().get_meta("walkable_top")) - 0.35 and Safety.clear_at(game.player, Vector3(0, 0.05, 33.7)) and Safety.supported(game.player, Vector3(0, 0.05, 33.7)), "high tide keeps the dock return passage dry and supported")
	print("COASTAL PROBE: renderer=", RenderingServer.get_video_adapter_name(), " levels=", levels, " boat_levels=", boat_levels, " rope_error=", rope_error)
	game._travel("city")
	check(home.sea_surface == null and home.coastal_materials.is_empty(), "leaving the map clears the sea references")
	print("COASTAL MOTION: ", checked, " CHECKS, ", checked - failed, " PASSED, ", failed, " FAILED")
	game.queue_free()
	for i in 6: await process_frame
	quit(1 if failed else 0)
