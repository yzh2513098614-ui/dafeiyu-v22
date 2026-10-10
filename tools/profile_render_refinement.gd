extends SceneTree
var game

func _initialize() -> void:call_deferred("measure")

func sample(enabled: bool) -> void:
	game.atmosphere.environment.ssao_enabled=enabled
	for i in 24:await process_frame
	var start:=Time.get_ticks_usec()
	for i in 60:
		await process_frame
		await RenderingServer.frame_post_draw
	var ms: float=float(Time.get_ticks_usec()-start)/60000.0
	print("CONTACT PROFILE enabled=",enabled," ms/frame=",ms," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func measure() -> void:
	root.size=Vector2i(1000,750)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="pack26_hospital"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	game.set_physics_process(false);game.atmosphere.set_time(12);game.atmosphere.cycle_enabled=false
	game.pack26_controller.floor_cutaway=true;game.pack26_controller.level.set_floor_view(0,true)
	game.ui.hide();game.pack26_controller.root.hide()
	game.camera.size=22;game.view_center=game.player.position;game._camera()
	await sample(false);await sample(true)
	quit()
