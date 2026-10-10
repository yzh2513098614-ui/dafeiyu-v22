extends SceneTree
var game

func _initialize() -> void:call_deferred("capture")

func frame(tag: String) -> void:
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/渲染强化_"+tag+".png")
	print("RENDER ",tag," SSAO=",game.atmosphere.environment.ssao_enabled," FPS=",Engine.get_frames_per_second())

func place(id: String) -> void:
	game._travel(id);game.set_physics_process(false)
	game.atmosphere.set_time(12);game.atmosphere.cycle_enabled=false
	game.ui.hide();game.pack26_controller.root.hide()
	if game.pack26_controller.is_active():
		game.pack26_controller.floor_cutaway=true;game.pack26_controller.level.set_floor_view(0,true)
	for label in game.world.find_children("*","Label3D",true,false):label.hide()
	game.camera.size=22;game.view_size=22
	game.view_center=game.player.position if id.begins_with("pack26") else Vector3.ZERO
	game._camera()

func ao(env: Environment) -> void:
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_ULTRA,false,.5,0,0,100)
	env.ssao_enabled=true;env.ssao_radius=.016;env.ssao_intensity=.55
	env.ssao_power=1.25;env.ssao_detail=1.0;env.ssao_sharpness=.95
	env.ssao_light_affect=.12;env.ssao_horizon=.08

func reflections(env: Environment) -> void:
	var sky:=Sky.new();sky.radiance_size=Sky.RADIANCE_SIZE_128
	var material:=ProceduralSkyMaterial.new()
	material.sky_top_color=Color("9bb9d0");material.sky_horizon_color=Color("b4c2ca")
	material.ground_bottom_color=Color("324453");material.ground_horizon_color=Color("82939e")
	material.sky_energy_multiplier=.32;material.ground_energy_multiplier=.20
	material.sun_angle_max=0.0
	sky.sky_material=material;env.sky=sky;env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY

func capture() -> void:
	root.size=Vector2i(1000,750)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="pack26_hospital"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	var env: Environment=game.atmosphere.environment
	for spec in [["pack26_hospital","医院"],["apt_1","公寓"],["pack26_foodhall","餐厅"]]:
		place(spec[0]);env.ssao_enabled=false;env.sky=null;env.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
		await frame("修改前_"+spec[1])
		ao(env);await frame("接触阴影_"+spec[1])
		reflections(env);await frame("组合_"+spec[1])
	quit()
