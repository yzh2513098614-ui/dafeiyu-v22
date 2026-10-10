@tool
extends SceneTree

func _init():
    var g = load("res://district/continuous_world.tscn").instantiate()
    root.add_child(g)
    var total = g.locations.size()
    var depot_count = 0
    var floor_count = 0
    for id in g.locations:
        var loc = g.locations[id]
        var type = str(loc.get("type", ""))
        if type == "depot":
            depot_count += 1
        elif type == "floor":
            floor_count += 1
    print("TOTAL_LOCATIONS: ", total, " DEPOT: ", depot_count, " FLOOR: ", floor_count)
    quit()