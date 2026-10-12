extends SceneTree

func _initialize() -> void:
	call_deferred("make_scene")

func own(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner=root_node
		if child.scene_file_path.is_empty():own(child,root_node)

func make_scene() -> void:
	var stage:=Node3D.new()
	stage.name="TeachingAndIndependentClocktower"
	stage.set_script(load("res://wuming_campus/scripts/photo_detail_controller.gd"))
	stage.set_meta("relationship","Clock tower and teaching block are separate, as confirmed by the user")
	stage.set_meta("placement_basis","photo composition estimate; not a surveyed site plan")
	var environment_node:=WorldEnvironment.new()
	environment_node.name="WorldEnvironment"
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(.73,.78,.77)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(.86,.88,.84)
	env.ambient_light_energy=.38
	environment_node.environment=env
	stage.add_child(environment_node)
	var sun:=DirectionalLight3D.new()
	sun.name="DetailSun"
	sun.rotation_degrees=Vector3(-42,-35,0)
	sun.light_color=Color(1,.96,.90)
	sun.light_energy=.68
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=300
	sun.shadow_bias=.1
	sun.shadow_normal_bias=1.2
	stage.add_child(sun)
	var ground:=MeshInstance3D.new()
	ground.name="PavedPhotoStudyGround"
	var slab:=BoxMesh.new()
	slab.size=Vector3(81,.20,71)
	ground.mesh=slab
	ground.position=Vector3(0,-.1,3)
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(.74,.74,.67)
	ground.material_override=material
	stage.add_child(ground)
	var school: Node3D=load("res://wuming_campus/scenes/buildings/photo_teaching_wing.tscn").instantiate()
	school.name="IndependentTeachingBuilding"
	school.position=Vector3(0,0,-9.0)
	stage.add_child(school)
	var clock: Node3D=load("res://wuming_campus/scenes/props/clocktower.tscn").instantiate()
	clock.name="IndependentClocktower"
	clock.position=Vector3(29.0,0,15.0)
	stage.add_child(clock)
	var planting:=Node3D.new()
	planting.name="FrontGardenPlanting"
	stage.add_child(planting)
	for i in range(12):
		var bed: Node3D=load("res://wuming_campus/scenes/props/canna_border_3m.tscn").instantiate()
		bed.position=Vector3(-18+i*3.15,0,22)
		planting.add_child(bed)
	for at in [Vector3(-21,0,7),Vector3(-25,0,-3),Vector3(31,0,18)]:
		var tree: Node3D=load("res://wuming_campus/scenes/props/tree_feathered_supported.tscn").instantiate()
		tree.position=at
		planting.add_child(tree)
	var camera:=Camera3D.new()
	camera.name="DetailCamera"
	camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.position=Vector3(67,56,115)
	camera.look_at_from_position(camera.position,Vector3(3,16,0))
	camera.size=61
	stage.add_child(camera)
	own(stage,stage)
	var packed:=PackedScene.new()
	var result: Error=packed.pack(stage)
	if result==OK:result=ResourceSaver.save(packed,"res://wuming_campus/scenes/world/photo_teaching_detail.tscn")
	print("PHOTO_DETAIL_SCENE ",result)
	stage.free()
	quit(0 if result==OK else 1)
