extends SceneTree
## Godot --headless --path <project> --script res://dioramas/rainy_konbini/scripts/bake_scene.gd
func _initialize() -> void:
	call_deferred("bake")

func set_owners(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner=scene_root
		set_owners(child,scene_root)

func bake() -> void:
	var scene := load("res://dioramas/rainy_konbini/scenes/main.tscn").instantiate()
	scene.optimize_batches=false
	root.add_child(scene)
	scene.set_process(false)
	scene.baked=true
	set_owners(scene,scene)
	var packed := PackedScene.new()
	var code := packed.pack(scene)
	if code==OK: code=ResourceSaver.save(packed,"res://dioramas/rainy_konbini/scenes/rainy_corner_editable.tscn")
	print("BAKE_RESULT ",code," NODES ",scene.find_children("*","",true,false).size())
	quit(code)
