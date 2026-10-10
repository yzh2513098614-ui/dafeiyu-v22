@tool
extends Node3D
## Reusable container model with a real pivot or drawer translation.
## A loot system can listen for opened_changed; this script only handles the model.

const Clearance=preload("res://character/moving_clearance.gd")
var moving_clearance=Clearance.new()
var animation_obstructed:=false
var blocked_progress:=0.0
var collision_visibility:=true

signal opened_changed(opened: bool)

@export var container_id := "reinforced_flight_case"
@export_range(0.4, 6.0, 0.1) var opening_seconds := 2.4
@export var create_body_collision := true
@export var editor_open_preview := false:
	set(value):
		editor_open_preview = value
		if Engine.is_editor_hint() and is_instance_valid(model_root):
			set_open_state(value, false)

var target_open := false
var spec: Dictionary = {}
var model_root: Node3D
var opening_pivot: Node3D
var opening_tween: Tween
var pivot_origin := Vector3.ZERO
var axis := Vector3.ZERO
var translation := Vector3.ZERO
var angle := 0.0
var unlock_fraction := 0.0
var bolt_retract := 0.0
var bolt_parts: Array[MeshInstance3D] = []
var bolt_origins: Array[Vector3] = []
var grouped_pivots: Array[Dictionary] = []
var progress := 0.0:
	set(value):
		var destination:=clampf(value,0.0,1.0)
		var start:=progress
		var steps:=maxi(1,ceili(absf(destination-start)/.015))
		animation_obstructed=false
		for i in range(1,steps+1):
			var previous:=progress
			progress=lerpf(start,destination,float(i)/steps)
			_apply_pose()
			if not Engine.is_editor_hint() and moving_clearance.blocked():
				progress=previous;_apply_pose()
				blocked_progress=destination;animation_obstructed=true
				if is_instance_valid(opening_tween):opening_tween.pause()
				return

func _ready() -> void:
	# Editor instances show the same geometry and can preview a door or lid pose.
	# Generated children stay unowned so saving a map keeps a reusable scene instance.
	if is_instance_valid(model_root):
		return
	var file := FileAccess.open("res://world_pack26/interior_pack/library_173/container_specs.json", FileAccess.READ)
	if file == null:
		push_error("Container: container_specs.json is missing")
		return
	var designs: Variant = JSON.parse_string(file.get_as_text())
	if not designs is Array:
		push_error("Container: invalid design catalog")
		return
	for design in designs:
		if design["id"] == container_id:
			spec = design
			break
	if spec.is_empty():
		push_error("Container: unknown ID " + container_id)
		return
	var packed := load("res://world_pack26/interior_pack/library_173/" + str(spec["closed_path"])) as PackedScene
	if packed == null:
		push_error("Container: missing model " + container_id)
		return
	model_root = packed.instantiate() as Node3D
	add_child(model_root)
	var mechanism: Dictionary = spec["mechanism"]
	if mechanism.has("groups"):
		var all_moving: Array[MeshInstance3D] = []
		_collect_moving(model_root, all_moving)
		for group in mechanism["groups"]:
			var hinge := Node3D.new()
			hinge.name = str(group["prefix"]) + "Pivot"
			model_root.add_child(hinge)
			var origin := _vector_from_array(group["pivot"])
			hinge.position = origin
			for part in all_moving:
				if str(part.name).begins_with(str(group["prefix"])):
					part.reparent(hinge, true)
			grouped_pivots.append({"node": hinge, "origin": origin, "axis": Vector3.UP, "angle": deg_to_rad(float(group["angle_degrees"]))})
		opening_pivot = Node3D.new()
		model_root.add_child(opening_pivot)
		if create_body_collision:
			_add_body_collision()
		_apply_pose()
		if Engine.is_editor_hint():
			set_open_state(editor_open_preview, false)
		return
	unlock_fraction = float(mechanism.get("unlock_fraction", 0.0))
	bolt_retract = float(mechanism.get("bolt_retract", 0.0))
	if mechanism["kind"] == "drawer":
		translation = _vector_from_array(mechanism["translation"])
	else:
		pivot_origin = _vector_from_array(mechanism["pivot"])
		axis = Vector3.RIGHT if mechanism["axis"] == "x" else Vector3.UP
		angle = deg_to_rad(float(mechanism["angle_degrees"]))
	opening_pivot = Node3D.new()
	opening_pivot.name = "OpeningPivot"
	model_root.add_child(opening_pivot)
	opening_pivot.position = pivot_origin
	var moving: Array[MeshInstance3D] = []
	_collect_moving(model_root, moving)
	for part in moving:
		part.reparent(opening_pivot, true)
		if str(part.name).begins_with("moving_lock_bolt"):
			bolt_parts.append(part)
			bolt_origins.append(part.position)
	if moving.is_empty():
		push_error("Container: no movable mesh parts found")
	if create_body_collision:
		_add_body_collision()
	_apply_pose()
	if Engine.is_editor_hint():
		set_open_state(editor_open_preview, false)

func _add_body_collision() -> void:
	moving_clearance.add_meshes(model_root)
	var body := StaticBody3D.new()
	body.name = "ContainerBody"
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = _vector_from_array(spec["size"])
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.size.y * 0.5
	body.add_child(collider)

func _vector_from_array(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

func _collect_moving(node: Node, moving: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and str(node.name).begins_with("moving_"):
		moving.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_moving(child, moving)

func _apply_pose() -> void:
	if not is_instance_valid(opening_pivot):
		return
	if not grouped_pivots.is_empty():
		for group in grouped_pivots:
			var hinge := group["node"] as Node3D
			hinge.position = group["origin"]
			hinge.basis = Basis(group["axis"], float(group["angle"]) * progress)
		return
	opening_pivot.position = pivot_origin + translation * progress
	var turn_progress := clampf((progress - unlock_fraction) / maxf(1.0 - unlock_fraction, 0.001), 0.0, 1.0)
	opening_pivot.basis = Basis.IDENTITY if axis == Vector3.ZERO else Basis(axis, angle * turn_progress)
	var retraction := bolt_retract * clampf(progress / maxf(unlock_fraction, 0.001), 0.0, 1.0)
	for i in range(bolt_parts.size()):
		bolt_parts[i].position = bolt_origins[i] - Vector3(retraction, 0.0, 0.0)

func set_open_state(opened: bool, animated := true) -> void:
	if not is_instance_valid(opening_pivot):
		return
	if is_instance_valid(opening_tween):
		opening_tween.kill()
	target_open = opened
	var destination := 1.0 if opened else 0.0
	if not animated:
		progress = destination
		if not animation_obstructed:opened_changed.emit(opened)
		return
	var duration := maxf(0.15, opening_seconds * absf(destination - progress))
	opening_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	opening_tween.set_trans(Tween.TRANS_SINE)
	opening_tween.set_ease(Tween.EASE_IN_OUT)
	opening_tween.tween_property(self, "progress", destination, duration)
	opening_tween.finished.connect(_finish_opening.bind(opened))

func _finish_opening(opened: bool) -> void:
	opened_changed.emit(opened)

func toggle_open() -> void:
	set_open_state(not target_open)

func set_open(value: bool) -> void:
	set_open_state(value, true)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():return
	var visible:=is_visible_in_tree()
	if visible!=collision_visibility:
		collision_visibility=visible;moving_clearance.update_visibility(visible)
	if animation_obstructed:
		progress=blocked_progress
		if not animation_obstructed:
			if is_instance_valid(opening_tween):opening_tween.play()
			else:opened_changed.emit(target_open)
