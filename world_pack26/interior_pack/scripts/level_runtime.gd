extends Node3D
## Importable map API; no autoload, camera, UI or character is imposed on another game.
signal interaction_requested(kind: String, data: Dictionary)
signal world_exit_requested(destination: String, spawn_id: String)
signal progress_changed(snapshot: Dictionary)
signal zone_entered(region_id: int,display_name: String,risk_tier: int)
@export_flags_3d_physics var player_detection_mask: int = 4
@export var level_id: String = ""
@export var level_title: String = ""
@export var cutaway_walls: bool = true
@export var standalone_preview: bool = true
var progress = {"keys": [], "switches": [], "opened": [], "container_open": [], "checkpoint": "", "visited": []}
var ambient_time = 0.0
var rides: Array = []
var jets: Array = []
var floor_view_enabled = false
var floor_view_height = -100.0
func _ready() -> void:
    preload("res://district/filtered_pack_floors.gd").apply($Architecture)
    set_wall_cutaway(cutaway_walls)
    for area in $Signals.get_children():
        if area is Area3D:
            area.collision_mask=player_detection_mask
            area.body_entered.connect(func(_body):
                var region_id=int(area.get_meta("region_id"))
                var tag=level_id+"_"+str(region_id)
                if tag not in progress.visited:progress.visited.append(tag)
                zone_entered.emit(region_id,str(area.get_meta("region_name")),int(area.get_meta("risk_tier")))
                progress_changed.emit(capture_progress())
            )
    rides = find_children("RideBody", "Node3D", true, false)
    jets = find_children("WaterJets", "Node3D", true, false)
    if standalone_preview and get_parent() == get_tree().root and "--bake-nav" not in OS.get_cmdline_user_args():
        call_deferred("_preview")
func _preview() -> void:
    var controller = Node3D.new()
    controller.set_script(load("res://world_pack26/interior_pack/scripts/level_playtest.gd"))
    controller.set("embedded_level", self)
    add_child(controller)
func _process(delta: float) -> void:
    ambient_time += delta
    for node in rides:
        node.rotation.x = sin(ambient_time * 1.7) * .055
    for node in jets:
        node.position.y = .40 + sin(ambient_time * 2.5) * .025
func set_wall_cutaway(value: bool) -> void:
    cutaway_walls = value
    for node in $Architecture.find_children("Visual", "Node3D", true, false):
        if node.has_meta("cutaway_wall"):
            node.scale.y = .32 if value else 1.0
func set_floor_view(height: float, enabled: bool) -> void:
    if floor_view_enabled == enabled and absf(floor_view_height-height)<.1:return
    floor_view_enabled=enabled
    floor_view_height=height
    # Visibility only: full collision and navigation remain active on all floors.
    for group in ["Architecture","Furnishings","Gates","Signals"]:
        for node in get_node(group).get_children():
            if node is Node3D:
                var storey=float(node.get_meta("floor_height",floor((node.position.y+.15)/3.6)*3.6))
                node.visible=not enabled or storey<=height+.2
    for node in get_children():
        if node is Label3D and node.has_meta("floor_height"):
            node.visible=not enabled or float(node.get_meta("floor_height"))<=height+.2
func apply_progress(snapshot: Dictionary) -> void:
    progress = snapshot.duplicate(true)
    if not progress.has("visited"):progress.visited=[]
    if not progress.has("container_open"):progress.container_open=[]
    for gate in $Gates.get_children():
        var available = (gate.required_key == "" or gate.required_key in progress.keys) and (gate.required_switch == "" or gate.required_switch in progress.switches)
        gate.apply_state(available, true)
    for marker in $Interactions.get_children():
        if str(marker.get_meta("kind"))!="chest":continue
        var item=marker.get_node_or_null(marker.get_meta("model_path"))
        var id=str(marker.get_meta("interaction_id"))
        var opened=id in progress.container_open or id in progress.opened
        if item and item.has_method("set_open_state"):
            item.set_open_state(opened,false)
        elif item and item.has_method("set_open"):
            item.set_open(opened)
func capture_progress() -> Dictionary:
    return progress.duplicate(true)
func nearest_interaction(origin: Vector3, radius: float = 1.8) -> Node3D:
    var nearest: Node3D = null
    var best = radius
    for marker in $Interactions.get_children():
        if absf(marker.global_position.y-origin.y) > 1.0:
            continue
        if marker.get_meta("kind") == "key" and marker.get_meta("key_id") in progress.keys:
            continue
        var distance = Vector2(marker.global_position.x-origin.x, marker.global_position.z-origin.z).length()
        if distance < best:
            var sight=PhysicsRayQueryParameters3D.create(origin+Vector3(0,.75,0),marker.global_position+Vector3(0,.75,0),1)
            if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():continue
            nearest = marker
            best = distance
    return nearest
func activate(marker: Node3D) -> void:
    var kind = str(marker.get_meta("kind"))
    var data = {"id": str(marker.get_meta("interaction_id")), "title": str(marker.get_meta("title")), "position": marker.global_position, "marker": marker}
    match kind:
        "key":
            var key = str(marker.get_meta("key_id"))
            if key not in progress.keys:
                progress.keys.append(key)
            data["key"] = key
            _refresh_gates()
        "switch":
            var switch = str(marker.get_meta("switch_id"))
            if switch not in progress.switches:
                progress.switches.append(switch)
            data["switch"] = switch
            _refresh_gates()
        "chest":
            data["loot"] = JSON.parse_string(marker.get_meta("loot_json"))
            data["already_opened"] = data.id in progress.opened
            if not progress.has("container_open"):progress.container_open=[]
            if data.id not in progress.container_open:progress.container_open.append(data.id)
            var item = marker.get_node_or_null(marker.get_meta("model_path"))
            if item and item.has_method("set_open"):
                item.set_open(true)
        "checkpoint":
            progress.checkpoint = data.id
        "portal":
            world_exit_requested.emit(str(marker.get_meta("destination")), "Entrance")
        "extract":
            pass
    interaction_requested.emit(kind, data)
    progress_changed.emit(capture_progress())
func mark_chest_empty(id: String) -> void:
    if id not in progress.opened:
        progress.opened.append(id)
    progress_changed.emit(capture_progress())
func _refresh_gates() -> void:
    for gate in $Gates.get_children():
        var available = (gate.required_key == "" or gate.required_key in progress.keys) and (gate.required_switch == "" or gate.required_switch in progress.switches)
        if available and not gate.opened:
            gate.apply_state(true)
