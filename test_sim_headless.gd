@tool
extends SceneTree

func _init():
    var f = FileAccess.open("res://project.godot", FileAccess.READ)
    var txt = f.get_as_text()
    f.close()
    var lines = txt.split("\n")
    var autoloads = {}
    var in_auto = false
    for l in lines:
        l = l.strip_edges()
        if l == "[autoload]":
            in_auto = true
            continue
        if in_auto:
            if l.begins_with("["):
                break
            if "=" in l:
                var parts = l.split("=")
                var k = parts[0].strip_edges()
                var v = parts[1].strip_edges().replace('"', '').replace('*', '')
                autoloads[k] = v
    for k in autoloads:
        var path = autoloads[k]
        var res = load(path)
        if res != null:
            var inst = res.new()
            inst.name = k
            root.add_child(inst)
            print("Loaded autoload: ", k)
        else:
            print("Failed autoload: ", k)

    var cw = load("res://district/continuous_world.tscn").instantiate()
    root.add_child(cw)
    print("Continuous world instantiated successfully!")
    print("Testing travel to all targets:")
    for loc_id in cw.locations.keys():
        cw.transitioning = false
        cw.changing = false
        cw._travel(loc_id)
        if cw.location_id != loc_id:
            print("  FAIL: ", loc_id, " -> actual: ", cw.location_id)
        else:
            print("  OK: ", loc_id, " portals: ", cw.portals.size(), " bounds: ", cw.space_bounds)
    quit()