extends SceneTree

func _initialize() -> void:
	call_deferred("render_roofs")

func capture(id: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error=root.get_texture().get_image().save_png("res://wuming_campus/preview/"+id+".png")
	print("ROOF_RENDER ",id," ",error)

func render_roofs() -> void:
	root.size=Vector2i(1600,1000)
	root.msaa_3d=Viewport.MSAA_4X
	var roof_stage: Node3D=load("res://wuming_campus/scenes/world/photo_roof_detail.tscn").instantiate()
	root.add_child(roof_stage)
	await process_frame
	roof_stage.hud.visible=false
	var ids: Array[String]=["v07_01_teaching_roof","v07_02_clock_roof","v07_03_tower_roof","v07_04_library_roof"]
	for index in range(4):
		roof_stage.set_view(index)
		await capture(ids[index])
	root.remove_child(roof_stage)
	roof_stage.queue_free()
	await process_frame
	var stage: Node3D=load("res://wuming_campus/scenes/world/photo_teaching_detail.tscn").instantiate()
	root.add_child(stage)
	await process_frame
	stage.hud.visible=false
	stage.set_view(0)
	await capture("v07_05_teaching_and_independent_clock")
	stage.set_view(1)
	await capture("v07_06_teaching_front")
	root.remove_child(stage)
	stage.queue_free()
	await process_frame
	await process_frame
	quit()
