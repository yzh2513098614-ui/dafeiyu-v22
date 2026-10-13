extends SceneTree
## Generate the editable components used by whale_home_map.gd.
const Props=preload("res://assets/whale_home/pastel_props.gd")
const Geo=preload("res://district/story_geometry.gd")
const OUTPUT="res://models/whale_home/"

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("bake")

func own_children(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner=scene_root
		own_children(child,scene_root)

func save_resource(resource: Resource, path: String) -> void:
	var error:=ResourceSaver.save(resource,OUTPUT+path,ResourceSaver.FLAG_CHANGE_PATH)
	assert(error==OK,"Cannot save "+path+": "+error_string(error))
	resource.take_over_path(OUTPUT+path)

func bake() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+"materials"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+"meshes"))
	var stage:=Node3D.new();root.add_child(stage)
	var models: Dictionary={
		"porch_arch":Props.porch(stage),
		"round_window":Props.round_window(stage),
		"curved_roof_tile":Props.roof_tile(stage,1.10,.56,Vector3.ZERO),
		"tree_tall_green":Props.tree(stage,Vector3.ZERO),
		"tree_low_green":Props.tree(stage,Vector3.ZERO,1.,false,true),
		"tree_sakura":Props.tree(stage,Vector3.ZERO,1.,true),
		"garden_bench":Props.bench(stage,Vector3.ZERO),
		"picket_panel":Props.picket_fence(stage,Vector3(-2,0,0),Vector3(2,0,0)),
		"garden_pergola":Props.pergola(stage),
		"flower_bed":Props.flower_bed(stage),
		"flower_planter":Props.planter(stage,Vector3.ZERO),
		"dock_post":Props.dock_post(stage),
		"whale_rowboat":Props.rowboat(stage)}
	# Paths are set before packing, so every scene references the same resources.
	for key: String in Geo.material_cache:
		var paint: ShaderMaterial=Geo.material_cache[key]
		var color: Color=paint.get_shader_parameter("base_color")
		var kind: int=paint.get_shader_parameter("finish_kind")
		save_resource(paint,"materials/"+color.to_html()+"_"+str(kind)+".tres")
	var palette:=Resource.new();palette.set_meta("materials",Geo.material_cache.duplicate())
	save_resource(palette,"shared_palette.tres")
	save_resource(Props.leaf_mesh,"meshes/leaf_clump.tres")
	save_resource(Props.mesh_cache["picket"],"meshes/picket_board.tres")
	save_resource(Props.mesh_cache["leaf"],"meshes/ridged_leaf.tres")
	save_resource(Props.curved_tile_mesh(1.10,.56),"meshes/curved_roof_tile.tres")
	for label: String in models:
		var model: Node3D=models[label]
		own_children(model,model)
		var scene:=PackedScene.new()
		assert(scene.pack(model)==OK,"Cannot pack "+label)
		save_resource(scene,label+".tscn")
		var saved: PackedScene=ResourceLoader.load(OUTPUT+label+".tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		var instance: Node3D=saved.instantiate()
		assert(instance.get_child_count()>0 or instance is MeshInstance3D,"Empty component "+label)
		instance.free()
		print("MODEL SAVED: ",label)
	stage.queue_free()
	for i in 3:await process_frame
	print("WHALE HOME MODELS: ",models.size()," components saved and loaded")
	quit(0)
