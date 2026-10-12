extends SceneTree

func _initialize() -> void:
	call_deferred("make_scene")

func own(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner=scene
		# Keep packed model instances live instead of saving stale mesh overrides.
		if child.scene_file_path.is_empty():own(child,scene)

func make_scene() -> void:
	var scene:=Node3D.new()
	scene.name="PhotoRoofDetails"
	scene.set_script(load("res://wuming_campus/scripts/roof_detail_controller.gd"))
	scene.set_meta("dimensions_basis","Roof shapes follow visible photo proportions; dimensions and thicknesses are estimated")
	var environment_node:=WorldEnvironment.new()
	environment_node.name="WorldEnvironment"
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(.71,.78,.80)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(.88,.93,.97)
	env.ambient_light_energy=.46
	environment_node.environment=env
	scene.add_child(environment_node)
	var sun:=DirectionalLight3D.new()
	sun.name="RoofStudySun"
	sun.rotation_degrees=Vector3(-48,-42,0)
	sun.light_color=Color(1,.985,.96)
	sun.light_energy=.68
	sun.shadow_enabled=true
	sun.shadow_bias=.06
	sun.shadow_normal_bias=.5
	sun.directional_shadow_max_distance=400
	scene.add_child(sun)
	var ids: Array[String]=["photo_teaching_wing","clocktower","A10","B1"]
	var names: Array[String]=["TeachingRoofStudy","IndependentClockRoofStudy","TowerCrownStudy","LibraryRoofStudy"]
	for index in range(4):
		var folder: String="props" if index==1 else "buildings"
		var model: Node3D=load("res://wuming_campus/scenes/"+folder+"/"+ids[index]+".tscn").instantiate()
		model.name=names[index]
		if model.has_node("NameLabel"):model.get_node("NameLabel").visible=false
		model.visible=index==0
		scene.add_child(model)
	var camera:=Camera3D.new()
	camera.name="RoofCamera"
	camera.current=true
	scene.add_child(camera)
	own(scene,scene)
	var packed:=PackedScene.new()
	var result: Error=packed.pack(scene)
	if result==OK:result=ResourceSaver.save(packed,"res://wuming_campus/scenes/world/photo_roof_detail.tscn")
	print("ROOF_DETAIL_SCENE ",result)
	scene.free()
	quit(0 if result==OK else 1)
