extends SceneTree
## Contact sheet rendered from the actual GLB wrapper scenes in Godot.
const OUT := "res://预览/餐厅学校医院_3D_v22/九件模型_近景总览.png"
const Decor=preload("res://district/decor_library.gd")
const IDS := [
	["restaurant_pastry_display", "糕点展示柜"],
	["restaurant_booth_set", "双人餐厅卡座"],
	["restaurant_service_cart", "餐车"],
	["school_learning_board", "教学展示板"],
	["school_twin_desks", "双人课桌"],
	["school_science_bench", "科学实验台"],
	["hospital_reception_desk", "医院接待台"],
	["hospital_exam_bay", "检查诊疗位"],
	["hospital_medicine_cart", "药品推车"],
]

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440, 900)
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("17283a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("91a9bb")
	env.ambient_light_energy = .24
	world.environment = env
	scene.add_child(world)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(17,17)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("687f8d")
	mat.roughness = .94
	floor.material_override = mat
	scene.add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53,-38,0)
	sun.light_energy = .38
	sun.shadow_enabled = true
	scene.add_child(sun)
	for i in IDS.size():
		var id: String = IDS[i][0]
		var model: Node3D = Decor.instance(id)
		if model == null: quit(1); return
		var x: float = (i%3-1)*4.5
		var z: float = (int(i/3)-1)*4.2
		model.position = Vector3(x,.02,z)
		scene.add_child(model)
		var plinth := MeshInstance3D.new()
		var tile := BoxMesh.new()
		tile.size = Vector3(4.15,.08,3.65)
		plinth.mesh = tile
		plinth.position = Vector3(x,.02,z)
		var tile_mat := StandardMaterial3D.new()
		tile_mat.albedo_color = Color("aebfc5") if i < 6 else Color("a5b8c2")
		plinth.material_override = tile_mat
		scene.add_child(plinth)
		var label := Label3D.new()
		label.text = str(IDS[i][1])
		label.font_size = 34
		label.pixel_size = .008
		label.modulate = Color("243c53")
		label.outline_size = 3
		label.outline_modulate = Color("f3f3e9")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(x,.30,z+1.55)
		scene.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.8
	camera.position = Vector3(0,12.0,17.0)
	scene.add_child(camera)
	camera.look_at(Vector3(0,.65,0))
	camera.current = true
	for n in 14: await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT)
	print("THEMED MODEL SHEET ", "OK" if err==OK else "FAILED")
	quit(0 if err==OK else 1)
