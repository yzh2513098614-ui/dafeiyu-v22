extends SceneTree

func _initialize() -> void:
    var world = load("res://district/continuous_world.tscn").instantiate()
    root.add_child(world)
    var g = world
    world.location_id = "tidal_high"
    world._travel("tidal_high")
    
    # Check container nodes in world
    var placed_boxes = []
    for c in g.get_children():
        if c.has_meta("container_id"):
            placed_boxes.append(str(c.get_meta("container_id")) + " at " + str(c.position))
    for c in g.world.get_children():
        if c.has_meta("container_id"):
            placed_boxes.append(str(c.get_meta("container_id")) + " at " + str(c.position))
    print("Placed containers in tidal_high: ", placed_boxes)
    
    # Check AABB around (-6.5, 0.06, -8.3)
    var test_box = AABB(Vector3(-7.3, 0.0, -8.8), Vector3(1.6, 1.0, 1.0))
    print("Testing overlaps with ", test_box)
    for c in g.world.get_children():
        if c is Node3D:
            # find visual instance or collision
            for sub in c.get_children():
                if sub is VisualInstance3D:
                    var aabb = sub.get_aabb()
                    var global_aabb = c.global_transform * aabb
                    if test_box.intersects(global_aabb):
                        print("INTERSECTS: ", c.name, " aabb=", global_aabb)
    quit(0)
