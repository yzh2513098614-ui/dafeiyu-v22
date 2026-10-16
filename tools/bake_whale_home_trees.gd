extends SceneTree
## Regenerate only the three editable tree scenes used by the home garden.
const Props = preload("res://assets/whale_home/pastel_props.gd")
const OUTPUT = "res://models/whale_home/"

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("bake")

func own_children(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		own_children(child, scene_root)

func bake() -> void:
	Props.use_shared_materials()
	var stage := Node3D.new()
	root.add_child(stage)
	var models := {
		"tree_tall_green":Props.tree(stage,Vector3.ZERO),
		"tree_low_green":Props.tree(stage,Vector3.ZERO,1.0,false,true),
		"tree_sakura":Props.tree(stage,Vector3.ZERO,1.0,true)}
	for label: String in models:
		var tree: Node3D = models[label]
		own_children(tree, tree)
		var scene := PackedScene.new()
		assert(scene.pack(tree) == OK)
		assert(ResourceSaver.save(scene, OUTPUT + label + ".tscn") == OK)
		print("TREE SAVED: ", label)
	stage.queue_free()
	for i in 3: await process_frame
	quit()
