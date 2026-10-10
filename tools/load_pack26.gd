extends SceneTree
## Only check that every imported map and its model dependencies can be loaded.
func _initialize() -> void:call_deferred("load_maps")

func load_maps() -> void:
	var definitions: Array=JSON.parse_string(FileAccess.get_file_as_string("res://world_pack26/interior_pack/levels.json"))
	var loaded:=0
	var joint_meshes:=0
	for spec in definitions:
		var scene=load(spec.scene)
		if scene is PackedScene and scene.can_instantiate():
			var map=scene.instantiate();map.standalone_preview=false;root.add_child(map)
			joint_meshes+=map.get_node("Architecture").find_children("*Joint*","MeshInstance3D",false,false).size()
			loaded+=1;map.free();await process_frame
		else:push_error("Map could not load: "+str(spec.id))
	print("PACK26 RESOURCE LOAD: ",loaded,"/",definitions.size())
	print("REMAINING JOINT MESHES: ",joint_meshes)
	quit(0 if loaded==26 and joint_meshes==0 else 1)
