extends SceneTree
## Fixed production views and frame timings, using isolated session saves.
var game
var phase := "before"
var output := "C:/Users/Administrator/Documents/Codex/2026-10-10/restaurant-render-v22/results"
var report: Array = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="):phase=argument.trim_prefix("--phase=")
	call_deferred("capture")

func view(id: String, center: Vector3, size: float, hour: float) -> void:
	if game.location_id!=id:game._travel(id)
	game.set_physics_process(false);game.life_booted=false
	game.atmosphere.set_time(hour);game.atmosphere.cycle_enabled=false
	game.ui.hide()
	if game.pack26_controller:game.pack26_controller.root.hide()
	game.view_center=center;game.view_size=size;game.camera.size=size;game._camera()
	for branch in [game.world,game.shell]:
		for label in branch.find_children("*","Label3D",true,false):label.hide()

func frame(tag: String) -> void:
	for i in 48:await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output+"/"+phase+"_"+tag+".png")
	if error!=OK:push_error("Preview screenshot failed: "+str(error))
	var samples: Array[float]=[]
	var draws: Array[int]=[]
	for i in 72:
		var start:=Time.get_ticks_usec()
		await process_frame;await RenderingServer.frame_post_draw
		samples.append(float(Time.get_ticks_usec()-start)/1000.0)
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	samples.sort();draws.sort()
	var lights: Array=[]
	for lamp in game.atmosphere.lamps:
		lights.append({"name":str(lamp.name),"position":str(lamp.global_position),"energy":lamp.light_energy,"color":str(lamp.light_color),"specular":lamp.light_specular,"shadows":lamp.shadow_enabled})
	var row: Dictionary={"view":tag,"median_ms":samples[36],"p95_ms":samples[68],"draw_calls":draws[36],"location":game.location_id,"lights":lights,"finish":game.shell.get_meta("restaurant_finish",{})}
	report.append(row);print("RESTAURANT FINISH ",JSON.stringify(row))

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1200,850);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_mute(0,true)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="restaurant_1"
	prefs.world_save_path=output+"/isolated_world.json";prefs.settings_path=output+"/isolated_settings.cfg"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true;prefs.values.follow=true
	var script: Script=load("res://district/continuous_world.gd")
	if script==null or not script.can_instantiate():quit(1);return
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	game.life_booted=false;game.set_physics_process(false)
	for i in 5:await process_frame
	view("restaurant_1",Vector3(-10,0,5),18,14);await frame("dining_day")
	view("restaurant_1",Vector3(10,0,-10),14,14);await frame("kitchen_day")
	view("restaurant_1",Vector3(-10,0,5),18,21);await frame("dining_night")
	view("restaurant_1",Vector3(10,0,-10),14,21);await frame("kitchen_night")
	view("restaurant_2",Vector3(-8,0,-3),14,14);await frame("upstairs_day")
	if phase!="before":
		view("restaurant_1",Vector3(-10,0,5),18,14)
		for i in 10:
			game.view_center=Vector3(-10+.055*i,0,5+.025*i);game._camera()
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/movement_%02d.png"%i)
		game.atmosphere.set_effects(false);await frame("effects_off")
		game.atmosphere.set_effects(true)
		var interactions: Array=[]
		for id in ["restaurant_06","restaurant_09","restaurant_10"]:
			var object: Node3D
			for candidate in game.world.get_children():
				if str(candidate.get("asset_id"))==id:object=candidate;break
			var valid: bool=object!=null and object.has_method("set_open") and object.has_action()
			if valid:
				object.set_open(true)
				for i in 60:await physics_frame
				valid=object.opened
				object.set_open(false)
			interactions.append({"equipment":id,"opens":valid})
			if not valid:push_error("Restaurant interaction failed: "+id)
		report.append({"interactions":interactions,"collision_shapes":game.world.find_children("*","CollisionShape3D",true,false).size()+game.shell.find_children("*","CollisionShape3D",true,false).size()})
		view("restaurant_b1",Vector3(0,0,0),32,14);await frame("basement")
		view("hospital_1",Vector3.ZERO,22,14);await frame("hospital_regression")
	FileAccess.open(output+"/"+phase+"_metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RESTAURANT FINISH CAPTURE COMPLETE ",phase)
	game.queue_free();current_scene=null
	for i in 5:await process_frame
	quit()
