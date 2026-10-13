extends "res://tools/preview_map_surfaces.gd"
## Production-world comparison, isolated saves and silent audio.

func _initialize() -> void:
	call_deferred("capture")

func shot(tag: String) -> void:
	for i in 16:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/人物光照_20261013_"+tag+".png")
	print("CHARACTER LIGHTING ",tag)

func comparison(tag: String, hour: float) -> void:
	place("pack26_hospital",hour,7)
	game.atmosphere.set_process(false)
	game.view_center=game.player.position
	game._camera()
	game.facing="down";game._set_character_pose(false)
	game.avatar.pause()
	var material: ShaderMaterial=game.character_material
	var source: Texture2D=game.frames.get_frame_texture(game.avatar.animation,game.avatar.frame)
	assert(source.resource_path.begins_with("res://assets/character/download_walk_20261013/"),"Preview must use the new character frames")
	print("CHARACTER SOURCE ",source.resource_path," SHADER ",material.shader.resource_path)
	material.set_shader_parameter("illumination_gain",1.25)
	material.set_shader_parameter("direct_light_limit",0.80)
	material.set_shader_parameter("illustration_fill",0.0)
	material.set_shader_parameter("soft_contour_strength",0.42)
	await shot(tag+"_调整前")
	material.set_shader_parameter("illumination_gain",1.45)
	material.set_shader_parameter("direct_light_limit",1.05)
	material.set_shader_parameter("illustration_fill",0.10)
	material.set_shader_parameter("soft_contour_strength",0.28)
	await shot(tag+"_调整后")
	game.facing="up_left";game._set_character_pose(false);game.avatar.pause()
	await shot(tag+"_斜背面")

func capture() -> void:
	root.size=Vector2i(1000,750)
	AudioServer.set_bus_mute(0,true)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="pack26_hospital"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false
	prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false
	game=load("res://district/continuous_world.tscn").instantiate()
	root.add_child(game);current_scene=game
	# Let deferred guide setup finish before replacing the starting map.
	for i in 2:await process_frame
	game.set_process(false)
	if game.blink_controller:
		game.blink_controller.set_process(false)
		game.blink_controller.phase="open"
	await comparison("日间",12)
	await comparison("夜间",22)
	quit()
