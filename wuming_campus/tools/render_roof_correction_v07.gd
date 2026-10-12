extends SceneTree

func _initialize() -> void:
	call_deferred("render_correction")

func render_correction() -> void:
	root.size=Vector2i(1600,1000)
	root.msaa_3d=Viewport.MSAA_4X
	var stage: Node3D=load("res://wuming_campus/scenes/world/photo_roof_detail.tscn").instantiate()
	root.add_child(stage)
	await process_frame
	stage.hud.visible=false
	for index in [1,2]:
		stage.set_view(index)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var id: String="v07_02_clock_roof" if index==1 else "v07_03_tower_roof"
		var result: Error=root.get_texture().get_image().save_png("res://wuming_campus/preview/"+id+".png")
		print("ROOF_CORRECTION ",id," ",result)
	root.remove_child(stage)
	stage.free()
	stage=null
	for i in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	quit()
