extends SceneTree
## Capture the actual world, fixed clock and camera, using isolated preview saves.
var game
var prefix := "光影_修正后"

func _initialize() -> void:call_deferred("capture_world")

func snapshot(tag: String, place: String, hour: float, zoom: float, center: Vector3) -> void:
	game._travel(place)
	game.set_physics_process(false)
	game.atmosphere.set_time(hour)
	game.atmosphere.cycle_enabled=false
	game.ui.hide()
	game.pack26_controller.root.hide()
	for label in game.world.find_children("*","Label3D",true,false):label.hide()
	game.camera.size=zoom
	game.view_size=zoom
	if tag.ends_with("跟随"):
		center=game.player.position
		if game.pack26_controller.is_active():
			game.pack26_controller.floor_cutaway=true
			game.pack26_controller.level.set_floor_view(0,true)
	game.view_center=center
	game._camera()
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/"+prefix+"_"+tag+".png")
	print("LIGHTING ",tag," lamps=",game.atmosphere.lamps.size()," fills=",game.atmosphere.fills.size()," camera_far=",game.camera.far)

func fixture_floor() -> void:
	await snapshot("餐厅_灯光","pack26_foodhall",22,14,Vector3.ZERO)
	var lamp: OmniLight3D=game.atmosphere.lamps[0]
	game.view_center=Vector3(lamp.global_position.x,0,lamp.global_position.z)
	game.pack26_controller.floor_cutaway=true
	game.pack26_controller.level.set_floor_view(0,true)
	game._camera()
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/"+prefix+"_餐厅_灯光.png")
	game.pack26_controller.level.set_floor_view(-1,true)
	for i in 12:await process_frame
	var hidden_halos:=0
	for glow in game.atmosphere.glows:
		if glow.visible and not glow.get_meta("source_lamp").is_visible_in_tree():hidden_halos+=1
	print("HIDDEN STOREY HALOS: ",hidden_halos)

func moving_shadows() -> void:
	await snapshot("餐厅_日间","pack26_foodhall",12,22,Vector3(0,0,8))
	for i in 16:
		game.view_center=Vector3(.045*i,0,8+.030*i)
		game._camera()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(Rect2i(255,140,480,360)).save_png("res://预览/光影_移动%02d.png"%i)

func capture_world() -> void:
	root.size=Vector2i(1000,750)
	if "--before" in OS.get_cmdline_user_args():prefix="光影_修正前"
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="pack26_foodhall"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate()
	root.add_child(game);current_scene=game
	if "--details" in OS.get_cmdline_user_args():
		await snapshot("餐厅_跟随","pack26_foodhall",12,22,Vector3.ZERO)
		await snapshot("医院_跟随","pack26_hospital",18,22,Vector3.ZERO)
		await snapshot("街区_夜间","city",22,24,Vector3.ZERO)
		await fixture_floor()
		await moving_shadows()
		quit();return
	await snapshot("餐厅_日间","pack26_foodhall",12,22,Vector3(0,0,8))
	await snapshot("餐厅_总览","pack26_foodhall",12,90,Vector3.ZERO)
	await snapshot("公寓_日间","apt_1",12,22,Vector3.ZERO)
	await snapshot("公寓_黄昏","apt_1",18,22,Vector3.ZERO)
	await snapshot("公寓_夜间","apt_1",22,22,Vector3.ZERO)
	await snapshot("街区_日间","city",12,24,Vector3.ZERO)
	quit()
