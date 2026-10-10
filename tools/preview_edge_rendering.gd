extends "res://tools/preview_map_surfaces.gd"
## Compare the actual production view with directional contact on/off.
var stage := "改善后"

func _initialize() -> void:
	call_deferred("capture")

func shot(tag: String) -> void:
	for i in 16:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/边缘渲染_"+stage+"_"+tag+".png")
	print("EDGE CAPTURE ",tag)

func capture() -> void:
	root.size=Vector2i(1000,750)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="pack26_hospital"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	place("pack26_hospital",12,16)
	var closest: Node3D
	var distance: float=INF
	for prop: Node3D in game.world.find_children("*","Node3D",true,false):
		if not str(prop.name).contains("cabinet") or not prop.is_visible_in_tree():continue
		var away: float=Vector2(prop.global_position.x-game.player.position.x,prop.global_position.z-game.player.position.z).length_squared()
		if away<distance:closest=prop;distance=away
	print("EDGE SUBJECT ",closest.get_path()," position=",closest.global_position)
	var subject_position: Vector3=closest.global_position
	game.view_center=Vector3(subject_position.x,0,subject_position.z)
	game.camera.size=7;game._camera()
	await shot("近景")
	game.atmosphere.contact_shading.hide();await shot("关闭定向暗边")
	game.atmosphere.contact_shading.show()
	var sun: DirectionalLight3D=game.get_node("Sun")
	sun.rotation_degrees.y+=180
	game.atmosphere.contact_shading.material_override.set_shader_parameter("key_direction",sun.global_basis.z.normalized())
	await shot("反向光照")
	game.atmosphere.contact_shading.hide();await shot("反向光照_关闭暗边")
	game.atmosphere.contact_shading.show();game.atmosphere.set_time(12)
	game.camera.size=22;game._camera();await shot("正常视角")
	game.camera.size=7
	var origin: Vector3=game.view_center
	for i in 6:
		game.view_center=origin+Vector3(.04*i,0,.02*i);game._camera()
		await shot("移动%02d"%i)
	place("pack26_hospital",22,12);near_fixture();await shot("夜间灯具")
	game.pack26_controller.level.set_floor_view(3.6,true)
	game.view_center=Vector3(subject_position.x,3.6,subject_position.z);game.camera.size=18;game._camera()
	await shot("上层房间")
	quit()
