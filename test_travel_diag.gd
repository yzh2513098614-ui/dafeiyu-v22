@tool
extends SceneTree

func _init():
    var g = load("res://district/continuous_world.tscn").instantiate()
    root.add_child(g)
    print("District ready: ", g.district_ready)
    print("Locations count: ", g.locations.size())
    print("Testing travel to all locations...")
    var failed = []
    for loc_id in g.locations.keys():
        print("-> Testing: ", loc_id)
        g.changing = false
        g.transitioning = false
        g._travel(loc_id)
        if g.location_id != loc_id:
            failed.append(loc_id + " (actual: " + g.location_id + ")")
        else:
            print("   OK: ", loc_id, " zones: ", g.room_zones.size(), " portals: ", g.portals.size())
    print("RESULTS:")
    print("Failed: ", failed)
    quit()