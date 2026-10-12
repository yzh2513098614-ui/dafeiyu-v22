extends SceneTree
## Actual world rendering, isolated saves, with matched before/after poses.
const OUTPUT="res://预览/diagonal_edge_surface_20261012/"
var game
var checks:=0
var failures:=0

func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	DisplayServer.window_set_position(Vector2i(-9999,-9999))
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if ok:print("PASS ",message)
	else:failures+=1;push_error("FAIL "+message)

func capture(name: String) -> Image:
	for i in 4:await process_frame
	RenderingServer.force_draw(false)
	var result:=root.get_texture().get_image()
	result.save_png(OUTPUT+name+".png")
	return result

func run() -> void:
	if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	AudioServer.set_bus_mute(0,true)
	var prefs=root.get_node("HarborPrefs")
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.continue_game=false;prefs.starting_place="apt_2"
	prefs.settings_path=OUTPUT+"isolated_settings.cfg";prefs.world_save_path=OUTPUT+"isolated_world.json"
	root.size=Vector2i(1000,750)
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	for i in 35:await process_frame
	game.set_physics_process(false);game.atmosphere.set_process(false);game.atmosphere.set_time(12)
	for child in game.get_children():
		if child is CanvasLayer:child.hide()
	for label in game.world.find_children("*","Label3D",true,false):label.hide()
	game.view_center=game.player.position;game.view_size=6.0;game.camera.size=6.0;game._camera()
	var sheet:=Image.create(1500,750,false,Image.FORMAT_RGB8)
	sheet.fill(Color("27303e"))
	for direction in ["up_right","up_left"]:
		game.facing=direction;game._set_character_pose(false)
		var maps: Array=game.character_manifest.surface_profiles_by_direction[direction].edge_surface_maps
		check(game.character_material.get_shader_parameter("edge_surface_map")==load(maps[9]),direction+" idle uses matching frame 09 map")
		game.character_material.set_shader_parameter("edge_surface_enabled",false)
		var before:=await capture(direction+"_before")
		game._set_character_pose(false)
		var after:=await capture(direction+"_after")
		var changed:=0
		for y in 750:
			for x in 1000:
				var a:=after.get_pixel(x,y);var b:=before.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.025:changed+=1
		check(changed>100,direction+" actual GPU pixels show normal and vignette")
		var all_maps:=true
		var fixed_position: Vector3=game.avatar.position
		var selected: Array=[0,6,12,18,25]
		for i in maps.size():
			game.gait_phase=(float(i)+.25)/maps.size();game._set_character_pose(true)
			all_maps=all_maps and game.avatar.frame==i and game.character_material.get_shader_parameter("edge_surface_map")==load(maps[i]) and game.avatar.position==fixed_position
			if selected.has(i):
				var snapshot:=await capture(direction+"_walk_%02d"%i)
				snapshot.convert(Image.FORMAT_RGB8)
				var foot: Vector2=game.camera.unproject_position(game.player.global_position)
				foot*=Vector2(snapshot.get_width(),snapshot.get_height())/game.camera.get_viewport().get_visible_rect().size
				var rect:=Rect2i(Vector2i(foot)-Vector2i(150,350),Vector2i(300,375))
				sheet.blit_rect(snapshot,rect,Vector2i(selected.find(i)*300,0 if direction=="up_right" else 375))
		check(all_maps,direction+" all 26 walk frames match maps and preserve pivot")
	game.facing="down";game._set_character_pose(false)
	check(not game.character_material.get_shader_parameter("edge_surface_enabled"),"turning to another direction clears edge lighting")
	game.facing="up_right";game._set_character_pose(false);game.view_size=14.0;game.camera.size=14.0;game._camera()
	await capture("up_right_normal_zoom")
	sheet.save_png(OUTPUT+"walk_contact_sheet.png")
	var records: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/diagonal_edge_surface_20261012/source_hashes.json"))
	var unchanged:=true
	for record in records:unchanged=unchanged and FileAccess.get_sha256(record.path)==record.sha256
	check(unchanged and records.size()==52,"all 52 original RGBA drawings remain unchanged")
	print("DIAGONAL EDGE REVIEW: ",checks," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(0 if failures==0 else 1)
