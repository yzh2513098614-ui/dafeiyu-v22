extends SceneTree
## Actual engine captures: isolated saves, fixed clock, same framing as the baseline.
var game

func _initialize() -> void:call_deferred("capture")

func frame(tag: String) -> void:
	for i in 18:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/渲染强化_完成_"+tag+".png")
	print("RENDER FINAL ",tag," contact_radius=",game.atmosphere.environment.ssao_radius)

func place(id: String,hour: float=12) -> void:
	game._travel(id);game.set_physics_process(false)
	game.atmosphere.set_time(hour);game.atmosphere.cycle_enabled=false
	game.ui.hide();game.pack26_controller.root.hide()
	if game.pack26_controller.is_active():
		game.pack26_controller.floor_cutaway=true;game.pack26_controller.level.set_floor_view(0,true)
	for label in game.world.find_children("*","Label3D",true,false):label.hide()
	game.camera.size=22;game.view_size=22
	game.view_center=game.player.position if id.begins_with("pack26") else Vector3.ZERO
	game._camera()

func capture() -> void:
	root.size=Vector2i(1000,750)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="pack26_hospital"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	place("pack26_hospital");await frame("医院")
	game.camera.size=12;game._camera();await frame("医院_放大")
	game.camera.size=44;game._camera();await frame("医院_缩小")
	place("apt_1");await frame("公寓")
	game.atmosphere.set_time(22);await frame("公寓_夜间")
	place("pack26_foodhall");await frame("餐厅")
	place("city",18);game.camera.size=24;game._camera();await frame("街区_黄昏")
	# A short camera pan checks contact stability without exercising unrelated gameplay.
	place("pack26_hospital")
	var origin: Vector3=game.view_center
	for i in 12:
		game.view_center=origin+Vector3(.035*i,0,.025*i);game._camera()
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(Rect2i(250,100,500,375)).save_png("res://预览/渲染强化_移动%02d.png"%i)
	game.atmosphere.set_effects(false)
	print("CONTACT EFFECT OFF ",not game.atmosphere.environment.ssao_enabled)
	quit()
