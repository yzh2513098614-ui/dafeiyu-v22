extends SceneTree

var catalog: Array = []
var layout: Dictionary = {}
var assets: Dictionary = {}
var metric_scale: float = 1.256
var font: Font
var errors: Array = []
var native_mesh_count: int = 0
var mesh_cache: Dictionary = {}

func _initialize() -> void:
	call_deferred("bake")

func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func wp(p: Array) -> Vector3:
	return Vector3((float(p[0])-750.0)/metric_scale,0.0,(float(p[1])-1400.0)/metric_scale)

func owned(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():owned(child,root)

func clone_meshes(src: Node, dst: Node3D, id: String) -> void:
	for old in src.get_children():
		var child: Node3D
		if old is MeshInstance3D:
			child = MeshInstance3D.new()
			var mesh: Mesh = old.mesh.duplicate(true)
			mesh.resource_path = ""
			for i in range(mesh.get_surface_count()):
				var mat: Material = mesh.surface_get_material(i)
				if mat != null:
					mat = mat.duplicate(true)
					mat.resource_path = ""
					if mat is BaseMaterial3D:
						var mat_name: String = mat.resource_name
						if mat_name=="brick_photo":
							mat.albedo_texture=load("res://wuming_campus/assets/textures/brick_photo_tile.png")
							mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
						mat.cull_mode = BaseMaterial3D.CULL_DISABLED if mat_name.begins_with("leaf") or mat_name.begins_with("flower") or mat_name.begins_with("canna") else BaseMaterial3D.CULL_BACK
					mesh.surface_set_material(i,mat)
			var path: String = "res://wuming_campus/assets/meshes/"+id+"_"+str(native_mesh_count)+".res"
			var err: Error = ResourceSaver.save(mesh,path)
			if err != OK: errors.append({"mesh":path,"error":err})
			mesh.take_over_path(path)
			child.mesh = mesh
			native_mesh_count += 1
		else:
			child = Node3D.new()
		child.name = old.name
		if old is Node3D:child.transform = old.transform
		dst.add_child(child)
		clone_meshes(old,child,id)

func add_collision(node: Node3D, data: Dictionary, index: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision_"+str(index)
	var a: Array = data.center
	body.position = Vector3(float(a[0]),float(a[1]),float(a[2]))
	body.rotation.y = -float(data.get("angle",0.0))
	var c := CollisionShape3D.new()
	if data.type == "box":
		var shape := BoxShape3D.new()
		var b: Array = data.size
		shape.size = Vector3(float(b[0]),float(b[1]),float(b[2]))
		c.shape = shape
	elif data.type == "trimesh":
		var shape := ConcavePolygonShape3D.new()
		var faces := PackedVector3Array()
		for vertex in data.faces:faces.append(Vector3(float(vertex[0]),float(vertex[1]),float(vertex[2])))
		shape.set_faces(faces)
		c.shape = shape
	else:
		var shape := CylinderShape3D.new()
		shape.radius = float(data.radius)
		shape.height = float(data.height)
		c.shape = shape
	body.add_child(c)
	node.add_child(body)

func facade_glyph(node: Node3D, name: String, text: String, at: Vector3, color: Color, pixel_size: float, font_size: int) -> void:
	var label := Label3D.new()
	label.name=name
	label.text=text
	label.font=font
	label.font_size=font_size
	label.pixel_size=pixel_size
	label.position=at
	label.modulate=color
	label.outline_size=0
	label.shaded=false
	label.no_depth_test=false
	node.add_child(label)

func clock_numerals(node: Node3D, anchor: Vector3, height: float, width: float) -> void:
	var numerals := ["XII","I","II","III","IV","V","VI","VII","VIII","IX","X","XI"]
	for face in range(4):
		var angle: float = float(face)*PI/2.0
		var turn := Basis(Vector3.UP,-angle)
		for hour in range(12):
			var a: float = float(hour)*TAU/12.0
			var at := anchor+turn*Vector3(sin(a)*1.13,height-2.5+cos(a)*1.13,width/2.0+.51)
			var name: String = "RomanClock_"+str(face)+"_"+str(hour)
			facade_glyph(node,name,numerals[hour],at,Color(.12,.15,.13),.0068,32)
			node.get_node(name).rotation.y=-angle

func make_asset(info: Dictionary) -> PackedScene:
	var imported: PackedScene = load(info.model)
	if imported == null:
		errors.append({"model":info.model,"error":"load_failed"})
		return null
	var old: Node = imported.instantiate()
	var root := Node3D.new()
	root.name = info.id
	root.set_meta("asset_id",info.id)
	root.set_meta("category",info.category)
	root.set_meta("display_name",info.name)
	root.set_meta("units","metre")
	root.set_meta("evidence",info.get("confidence","map_derived_estimate"))
	clone_meshes(old,root,info.id)
	old.free()
	if info.id=="B1":
		facade_glyph(root,"LibraryNameSign","图书馆",Vector3(0,8.2,float(info.map_size[0])/metric_scale*.5-3.30),Color(.89,.69,.19),.053,64)
	elif info.id in ["A10","A11"]:
		var turn: float = PI/2 if info.id=="A10" else -PI/2
		var rot := Basis(Vector3.UP,-turn)
		var at := rot*Vector3(0,56.3,float(info.map_size[0])/metric_scale*.5+1.06)
		facade_glyph(root,"UniversityNameSign","广西医科大学",at,Color(.68,.22,.15),.055,60)
		root.get_node("UniversityNameSign").rotation.y=-turn
		var english_at := rot*Vector3(0,54.65,float(info.map_size[0])/metric_scale*.5+1.08)
		facade_glyph(root,"UniversityEnglishSign","GUANGXI MEDICAL UNIVERSITY",english_at,Color(.68,.22,.15),.023,34)
		root.get_node("UniversityEnglishSign").rotation.y=-turn
	elif info.id=="motto_gate":
		facade_glyph(root,"MottoLeft","厚\n德\n励\n志",Vector3(-4.4,4.04,1.26),Color(.29,.12,.065),.019,48)
		facade_glyph(root,"MottoRight","博\n学\n弘\n医",Vector3(4.4,4.04,1.26),Color(.29,.12,.065),.019,48)
		var letters := ["广","西","医","科","大","学"]
		for i in range(letters.size()):
			var a: float = deg_to_rad(145.0-float(i)*22.0)
			var name: String = "SealChinese_"+str(i)
			facade_glyph(root,name,letters[i],Vector3(.70*cos(a),14.09+.70*sin(a),1.17),Color(.94,.93,.88),.0067,24)
			root.get_node(name).rotation.z=a-PI/2.0
		facade_glyph(root,"SealLowerLettering","GXMU",Vector3(0,13.58,1.18),Color(.94,.93,.88),.0038,32)
	elif info.id=="clocktower":
		clock_numerals(root,Vector3.ZERO,27.8,7.0)
	for i in range(info.colliders.size()):add_collision(root,info.colliders[i],i)
	owned(root,root)
	var packed := PackedScene.new()
	var err: Error = packed.pack(root)
	if err == OK:err = ResourceSaver.save(packed,info.scene)
	if err != OK:errors.append({"scene":info.scene,"error":err})
	root.free()
	return packed

func find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:return node.mesh
	for child in node.get_children():
		var mesh: Mesh = find_mesh(child)
		if mesh != null:return mesh
	return null

func add_label(node: Node3D, text: String, at: Vector3, size: int = 40) -> void:
	var l := Label3D.new()
	l.name = "NameLabel"
	l.text = text
	l.font = font
	l.font_size = size
	l.pixel_size = .05
	l.position = at
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(.15,.20,.19)
	l.outline_modulate = Color(.95,.96,.91)
	l.outline_size = 8
	l.no_depth_test = false
	l.shaded = false
	l.set_meta("labels",true)
	node.add_child(l)

func bake() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use a graphical Godot session for baking MultiMesh buffers. Headless mode is supported for import and validation.")
		quit(1)
		return
	catalog = read_json("res://wuming_campus/data/asset_catalog.json")
	layout = read_json("res://wuming_campus/data/campus_layout.json")
	metric_scale = float(layout.map.working_pixels_per_metre)
	font = load("res://wuming_campus/assets/fonts/NotoSansSC.ttf")
	for info in catalog:
		var scene: PackedScene = make_asset(info)
		if scene != null:assets[info.id] = scene
	print("ASSETS_BAKED ",assets.size()," NATIVE_MESHES ",native_mesh_count)
	var world := Node3D.new()
	world.name = "WumingCampus"
	world.set_script(load("res://wuming_campus/scripts/campus_controller.gd"))
	world.set_meta("map_reference","https://www.gxmu.edu.cn/x_xxgk/x_dtjt/wmxqxydt/")
	world.set_meta("unit_metres",1.0)
	world.set_meta("scale_basis","100m = 628 original map pixels")
	world.set_meta("precision","manual plan reconstruction; heights and small-prop placements estimated")
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.73,.78,.77)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.85,.87,.82)
	env.ambient_light_energy = .32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	world.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_color = Color(1.0,.93,.81)
	sun.light_energy = .72
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 1100
	sun.shadow_bias = .10
	sun.shadow_normal_bias = 1.2
	world.add_child(sun)
	world.add_child(assets.campus_ground.instantiate())
	var land := StaticBody3D.new()
	land.name = "WalkableGround"
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(1550,.45,2420)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0,-.13,-300)
	land.add_child(floor_shape)
	world.add_child(land)
	var buildings := Node3D.new()
	buildings.name = "Buildings"
	world.add_child(buildings)
	for v in layout.buildings:
		var node: Node3D = assets[v.id].instantiate()
		node.position = wp(v.map_center)
		node.rotation.y = -deg_to_rad(float(v.yaw_degrees))
		node.set_meta("reference_photo",v.get("reference_photo"))
		var info: Dictionary = catalog.filter(func(i):return i.id == v.id)[0]
		add_label(node,v.name,Vector3(0,float(info.bounds_max[1])+3,0),28)
		buildings.add_child(node)
	var sports := Node3D.new()
	sports.name = "SportsSurfaces"
	world.add_child(sports)
	for v in layout.sports:
		var node: Node3D = assets[v.id].instantiate()
		node.position = wp(v.center)
		node.rotation.y = -deg_to_rad(float(v.angle))
		sports.add_child(node)
	var landmarks := Node3D.new()
	landmarks.name = "Landmarks"
	world.add_child(landmarks)
	for v in layout.landmarks:
		var node: Node3D = assets[v.id].instantiate()
		node.position = wp(v.map_center)
		node.rotation.y = -deg_to_rad(float(v.yaw_degrees))
		node.set_meta("placement_basis",v.confidence)
		if v.id == "gxmu_letters":
			var label := Label3D.new()
			label.font = font
			label.text = "I ♥ GXMU"
			label.font_size = 100
			label.pixel_size = .016
			label.position = Vector3(0,1.3,.78)
			label.modulate = Color(.20,.47,.72)
			label.outline_size = 0
			node.add_child(label)
		landmarks.add_child(node)
	var trees := Node3D.new()
	trees.name = "Trees_MultiMesh"
	world.add_child(trees)
	var props := Node3D.new()
	props.name = "StreetFurnitureAndPlanting"
	world.add_child(props)
	var groups: Dictionary = {}
	var tree_collisions := StaticBody3D.new()
	tree_collisions.name = "TreeTrunks"
	world.add_child(tree_collisions)
	for p in layout.placements:
		var asset_id: String = p.asset
		if asset_id.begins_with("tree_"):
			if not groups.has(asset_id):groups[asset_id] = []
			groups[asset_id].append(p)
			if p.get("collision",false):
				var collision := CollisionShape3D.new()
				var shape := CylinderShape3D.new()
				shape.radius = .24*float(p.scale)
				shape.height = 3.0*float(p.scale)
				collision.shape = shape
				collision.position = wp(p.map_position)+Vector3(0,shape.height/2.0,0)
				tree_collisions.add_child(collision)
		else:
			var node: Node3D = assets[asset_id].instantiate()
			node.name = asset_id+"_"+str(props.get_child_count()+1)
			node.position = wp(p.map_position)
			node.rotation.y = -deg_to_rad(float(p.yaw_degrees))
			node.scale = Vector3.ONE*float(p.scale)
			node.set_meta("placement_basis",p.placement_basis)
			props.add_child(node)
	for id in groups:
		var native: Node3D = assets[id].instantiate()
		var mesh: Mesh = find_mesh(native)
		var instance := MultiMeshInstance3D.new()
		instance.name = id
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = groups[id].size()
		for i in range(groups[id].size()):
			var p: Dictionary = groups[id][i]
			var basis := Basis(Vector3.UP,-deg_to_rad(float(p.yaw_degrees))).scaled(Vector3.ONE*float(p.scale))
			mm.set_instance_transform(i,Transform3D(basis,wp(p.map_position)))
		instance.multimesh = mm
		instance.set_meta("placement_data","res://wuming_campus/data/campus_layout.json")
		trees.add_child(instance)
		native.free()
	RenderingServer.force_sync()
	var camera := Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 760
	camera.far = 7000
	camera.near = 1
	world.add_child(camera)
	var player := CharacterBody3D.new()
	player.name = "CampusWalker"
	player.floor_snap_length = .3
	player.set_script(load("res://wuming_campus/scripts/campus_walker.gd"))
	player.position = wp([707,2305])+Vector3(0,.2,0)
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .32
	capsule.height = 1.72
	body_shape.shape = capsule
	body_shape.position = Vector3(0,.88,0)
	player.add_child(body_shape)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = .31
	body_mesh.height = 1.65
	body.mesh = body_mesh
	body.position = Vector3(0,.85,0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.19,.49,.71)
	body.material_override = mat
	player.add_child(body)
	world.add_child(player)
	owned(world,world)
	var packed := PackedScene.new()
	var result: Error = packed.pack(world)
	if result == OK:result = ResourceSaver.save(packed,"res://wuming_campus/scenes/world/campus.tscn")
	if result != OK:errors.append({"campus":result})
	# A separate native scene exposes all 34 reusable small assets for inspection.
	var showroom := Node3D.new()
	showroom.name = "CampusPropsShowroom"
	showroom.add_child(env_node.duplicate())
	showroom.add_child(sun.duplicate())
	var stage := MeshInstance3D.new()
	var stage_mesh := BoxMesh.new()
	stage_mesh.size=Vector3(92,.25,78)
	stage.mesh=stage_mesh
	stage.position=Vector3(36,-.18,27)
	var stage_mat := StandardMaterial3D.new()
	stage_mat.albedo_color=Color(.78,.80,.74)
	stage.material_override=stage_mat
	showroom.add_child(stage)
	var prop_index: int=0
	for info in catalog:
		if not info.has("location_basis"):continue
		var node: Node3D=assets[info.id].instantiate()
		node.position=Vector3((prop_index%7)*12,0,(prop_index/7)*12)
		showroom.add_child(node)
		add_label(node,info.name,Vector3(0,.35,4.8),19)
		prop_index+=1
	var show_camera := Camera3D.new()
	show_camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	show_camera.size=88
	show_camera.position=Vector3(88,105,117)
	show_camera.look_at_from_position(show_camera.position,Vector3(36,1,27))
	show_camera.far=1000
	showroom.add_child(show_camera)
	owned(showroom,showroom)
	var show_packed := PackedScene.new()
	show_packed.pack(showroom)
	ResourceSaver.save(show_packed,"res://wuming_campus/scenes/world/props_showroom.tscn")
	showroom.free()
	var report: Dictionary = {"assets":assets.size(),"native_meshes":native_mesh_count,"buildings":layout.buildings.size(),"sports":layout.sports.size(),"props":props.get_child_count(),"tree_groups":groups.size(),"trees":tree_collisions.get_child_count(),"errors":errors}
	var file := FileAccess.open("res://wuming_campus/data/bake_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	world.free()
	print("BAKE_RESULT ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
