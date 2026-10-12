extends SceneTree

func _initialize() -> void:
	call_deferred("render_details")

func render_details() -> void:
	root.size=Vector2i(1600,1000)
	root.msaa_3d=Viewport.MSAA_4X
	var stage: Node3D=load("res://wuming_campus/scenes/world/photo_teaching_detail.tscn").instantiate()
	root.add_child(stage)
	await process_frame
	stage.hud.visible=false
	for index in range(3):
		stage.set_view(index)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var id: String=["21_independent_teaching_and_clock","22_teaching_facade_close","23_clocktower_close"][index]
		var error: Error=root.get_texture().get_image().save_png("res://wuming_campus/preview/"+id+".png")
		print("DETAIL_RENDER ",id," ",error)
	root.remove_child(stage)
	stage.free()
	var campus: Node3D=load("res://wuming_campus/scenes/world/campus.tscn").instantiate()
	root.add_child(campus)
	await process_frame
	campus.hud.visible=false
	campus.set_process(false)
	for index in [13,14,15,17,19]:
		campus.set_view(index)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var id: String="v06_"+campus.layout.views[index].id
		var error: Error=root.get_texture().get_image().save_png("res://wuming_campus/preview/"+id+".png")
		print("DETAIL_RENDER ",id," ",error)
	root.remove_child(campus)
	campus.queue_free()
	await process_frame
	await process_frame
	quit()
