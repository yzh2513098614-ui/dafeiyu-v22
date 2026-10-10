extends Control
var definition: Dictionary = {}
var level: Node3D
var player: Node3D
func _process(_delta: float) -> void:
    queue_redraw()
func project(pos: Vector3) -> Vector2:
    var bounds=definition.get("size",[36,30])
    var origin=definition.get("origin",[-18,-15])
    return Vector2((pos.x-float(origin[0]))/float(bounds[0])*size.x,(pos.z-float(origin[1]))/float(bounds[1])*size.y)
func _draw() -> void:
    if definition.is_empty():
        return
    draw_style_box(_panel(),Rect2(Vector2.ZERO,size))
    var floor_height=0.0
    var heights=definition.get("floor_heights",[0,3.6] if not definition.get("stairs",[]).is_empty() else [0])
    for height in heights:
        if player and player.position.y>float(height)-.65:floor_height=float(height)
    for room in definition.rooms:
        if absf(float(room.get("height",0))-floor_height)>.5:continue
        var rect=room.get("rect",[room.center[0]-5.9,room.center[1]-4.9,room.center[0]+5.9,room.center[1]+4.9])
        var p = project(Vector3(rect[0]+.14,0,rect[1]+.14))
        var end = project(Vector3(rect[2]-.14,0,rect[3]-.14))
        var found=level and str(definition.id)+"_"+str(int(room.id)) in level.progress.visited
        draw_rect(Rect2(p,end-p),Color("c1d9e9") if found else Color("dbe7ef"))
        draw_string(get_theme_default_font(),p+Vector2(5,15),str(int(room.id)+1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("45618b"))
    for edge in definition.gates:
        var color = Color("58ae9a")
        var gate = level.get_node_or_null("Gates/"+edge.id) if level else null
        if not gate:
            continue
        if absf(gate.position.y-floor_height)>.5:continue
        if gate and not gate.opened:
            color = Color("bd8a68")
        # Door marks follow physical boundaries; diagonal graph edges hid the
        # room layout and suggested passages through solid walls.
        var p = project(gate.position)
        var axis = Vector2(0,1) if absf(gate.rotation.y) > 0.5 else Vector2(1,0)
        draw_line(p-axis*5,p+axis*5,color,4,true)
    if level:
        for marker in level.get_node("Interactions").get_children():
            if absf(marker.position.y-floor_height)>.7:continue
            var kind = str(marker.get_meta("kind"))
            if kind=="chest":
                draw_rect(Rect2(project(marker.position)-Vector2(3,3),Vector2(6,6)),Color("e7b968"))
            elif kind in ["key","switch"]:
                draw_circle(project(marker.position),3,Color("6984c7"))
            elif kind in ["portal","extract"]:
                draw_circle(project(marker.position),4,Color("5ba895"))
    if player:
        draw_circle(project(player.position),6,Color("314d81"))
        draw_circle(project(player.position),2,Color.WHITE)
    if not definition.get("stairs",[]).is_empty():
        for stair in definition.stairs:
            for endpoint in [stair.start,stair.end]:
                if absf(float(endpoint[1])-floor_height)<.5:draw_circle(project(Vector3(endpoint[0],floor_height,endpoint[2])),4,Color("649bab"))
        draw_string(get_theme_default_font(),Vector2(6,size.y-6),str(definition.get("floor_labels",{}).get(str(floor_height),"B1" if floor_height<0 else str(int(floor_height/3.6)+1)+"F"))+" · 青点楼梯",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("45618b"))
func _panel() -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = Color("eaf5fc")
    style.border_color = Color("8caccc")
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    return style
