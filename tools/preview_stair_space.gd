extends SceneTree
## Real engine art plates and a continuous walk with isolated save files.
var game
var output:="C:/Users/Administrator/Documents/Codex/2026-10-11/stair-space-v22/results"
var original:=false
var stair: Node3D
var trace: Array=[]

func _initialize() -> void:call_deferred("capture")

func _view() -> void:
	game.view_center=stair.to_global(Vector3(0,1.2,0));game.camera.size=15.5;game.view_size=15.5
	game.camera_angle=28;game._camera()
	game.character_material.set_shader_parameter("floor_height",game.player.position.y+game.CHARACTER_FLOOR_Y)
	game.pack26_controller.level.set_floor_view(0,true)

func _plate(filename: String) -> void:
	_view()
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+filename+".png")
	print("STAIR ART PLATE: ",filename)

func _walk(target: Vector3,tag: String) -> void:
	var point:=stair.to_global(target)
	for frame in 260:
		var delta: Vector3=point-game.player.position;delta.y=0
		if delta.length()<.065:break
		game.movement=game._character_screen_travel(delta.normalized()).normalized()
		await physics_frame
		game.pack26_controller.physics(1.0/60.0);_view()
		if frame%15==0:
			var local:=stair.to_local(game.player.position)
			trace.append({"map":game.pack26_controller.current_id,"stair":str(stair.name),"segment":tag,"frame":frame,"x":local.x,"y":local.y,"z":local.z})
	game.movement=Vector2.ZERO
	var local:=stair.to_local(game.player.position)
	print("STAIR WALK POSITION: ",tag," ",local)
	trace.append({"map":game.pack26_controller.current_id,"stair":str(stair.name),"segment":tag,"position":[local.x,local.y,local.z]})
	await _plate(tag)

func capture() -> void:
	original="--capture-original" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1200,675);AudioServer.set_bus_mute(0,true)
	var prefs=root.get_node("HarborPrefs");prefs.continue_game=false;prefs.starting_place="pack26_datacenter"
	prefs.world_save_path=output+"/isolated_world.json";prefs.settings_path=output+"/isolated_settings.cfg"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.follow=true;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	game.life_booted=false;game.set_physics_process(false)
	game.pack26_controller.save_path=output+"/isolated_pack26.json"
	for i in 8:await process_frame
	game.atmosphere.cycle_enabled=false;game.atmosphere.set_time(12)
	game.ui.hide();game.map_interactions.root.hide();game.pack26_controller.root.hide()
	if game.dialogue_controller and is_instance_valid(game.dialogue_controller.companion):game.dialogue_controller.companion.hide()
	for branch in [game.world,game.shell]:
		for label in branch.find_children("*","Label3D",true,false):label.hide()
	stair=game.pack26_controller.level.get_node("Architecture/DataWestDogleg")
	game.player.position=stair.to_global(Vector3(-2.6,1.84,.4));game.player.velocity=Vector3.ZERO
	await _plate("stairs_before" if original else "stairs_after")
	if not original:
		game.player.position=stair.to_global(Vector3(-2.6,.04,-4.2));game.player.velocity=Vector3.ZERO
		await _walk(Vector3(-2.6,1.84,1.7),"stairs_first_flight")
		await _walk(Vector3(2.6,1.84,1.7),"stairs_landing_turn")
		await _walk(Vector3(2.6,3.64,-4.2),"stairs_upper_floor")
		await _walk(Vector3(2.6,1.84,1.7),"stairs_return_landing")
		await _walk(Vector3(-2.6,1.84,1.7),"stairs_return_turn")
		await _walk(Vector3(-2.6,.04,-4.2),"stairs_return_ground")
		if "--capture-all" in OS.get_cmdline_user_args():await _other_stairs()
		var file:=FileAccess.open(output+"/walk_positions.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace,"\t"));file.close()
	game.queue_free()
	for i in 6:await process_frame
	quit()

func _other_stairs() -> void:
	for spec in game.pack26_controller.maps():
		if not spec.id in ["school","datacenter","sports","foodhall","emergency","media","expo"]:continue
		game._travel("pack26_"+str(spec.id))
		for i in 8:await process_frame
		for candidate in game.pack26_controller.level.get_node("Architecture").get_children():
			if candidate.get_meta("stair_kind","")!="dogleg":continue
			if str(candidate.name)=="DataWestDogleg":continue
			stair=candidate;_view()
			game.ui.hide();game.map_interactions.root.hide();game.pack26_controller.root.hide()
			for label in game.world.find_children("*","Label3D",true,false):label.hide()
			game.player.position=stair.to_global(Vector3(-2.6,.04,-4.2));game.player.velocity=Vector3.ZERO
			var tag:=str(stair.name)
			await _walk(Vector3(-2.6,1.84,1.7),tag+"_first")
			await _walk(Vector3(2.6,1.84,1.7),tag+"_turn")
			await _walk(Vector3(2.6,3.64,-4.2),tag+"_upper")
