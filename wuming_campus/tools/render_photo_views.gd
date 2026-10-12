extends SceneTree

func _initialize() -> void:
	call_deferred("render_photos")

func render_photos() -> void:
	var packed: PackedScene = load("res://wuming_campus/scenes/world/campus.tscn")
	if packed == null:quit(1);return
	var campus: Node3D = packed.instantiate()
	root.add_child(campus)
	root.size=Vector2i(1600,1000)
	root.msaa_3d=Viewport.MSAA_4X
	await process_frame
	campus.set_process(false)
	campus.hud.visible=false
	for index in [12,15,16,17,18,13,14]:
		campus.set_view(index)
		campus.get_node("AfternoonSun").rotation_degrees=Vector3(-48,145 if index==12 else -35,0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://wuming_campus/preview/"+campus.layout.views[index].id+".png"
		var err: Error = root.get_texture().get_image().save_png(path)
		print("PHOTO_RENDER ",campus.layout.views[index].id," ",err)
	root.remove_child(campus)
	campus.free()
	var showroom: Node3D=load("res://wuming_campus/scenes/world/props_showroom.tscn").instantiate()
	root.add_child(showroom)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://wuming_campus/preview/20_photo_props.png")
	quit()
