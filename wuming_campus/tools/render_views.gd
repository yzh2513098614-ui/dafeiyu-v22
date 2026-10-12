extends SceneTree

func _initialize() -> void:
	call_deferred("render_all")

func render_all() -> void:
	var packed: PackedScene = load("res://wuming_campus/scenes/world/campus.tscn")
	if packed == null:quit(1);return
	var campus: Node3D = packed.instantiate()
	root.add_child(campus)
	root.size = Vector2i(1600,1000)
	await process_frame
	campus.set_process(false)
	campus.hud.visible = false
	var diagnostic: Dictionary = {"sun_energy":campus.get_node("AfternoonSun").light_energy,"ambient":campus.get_node("WorldEnvironment").environment.ambient_light_energy,"meshes":[]}
	for path in ["res://wuming_campus/assets/meshes/B1_318.res","res://wuming_campus/assets/meshes/campus_ground_1458.res"]:
		if ResourceLoader.exists(path):
			var mesh: Mesh = load(path)
			var mats: Array = []
			for surf in range(mesh.get_surface_count()):
				var mat: BaseMaterial3D = mesh.surface_get_material(surf)
				mats.append({"name":mat.resource_name,"color":str(mat.albedo_color),"emission":mat.emission_enabled,"energy":mat.emission_energy_multiplier})
			diagnostic.meshes.append({"path":path,"materials":mats})
	var f := FileAccess.open("res://wuming_campus/data/render_diagnostic.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(diagnostic,"\t"))
	for i in range(campus.layout.views.size()):
		campus.set_view(i)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var path: String = "res://wuming_campus/preview/"+campus.layout.views[i].id+".png"
		var err: Error = img.save_png(path)
		print("RENDER_VIEW ",i," ",path," ",img.get_size()," ",err)
	root.remove_child(campus)
	campus.free()
	var showroom: Node3D=load("res://wuming_campus/scenes/world/props_showroom.tscn").instantiate()
	root.add_child(showroom)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://wuming_campus/preview/13_props_showroom.png")
	quit()
