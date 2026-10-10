@tool
extends Node3D
## Shared reversible GLB door/drawer motion with collision on the moving meshes.
const Clearance=preload("res://character/moving_clearance.gd")
@export var asset_id: String=""
@export var passage: bool=false
var opened:=false
var active_tween: Tween
var moving: Array=[]
var origins: Dictionary={}
var progress:=0.0
var animating:=false
var clearance=Clearance.new()

func _catalog_path() -> String:return ""

func _ready() -> void:
	var entries: Array=JSON.parse_string(FileAccess.get_file_as_string(_catalog_path()))
	for entry in entries:
		if entry.id==asset_id:set_meta("asset_definition",entry);moving=entry.moving;break
	for move in moving:
		var node:=find_child(move.node,true,false) as Node3D
		if node:
			origins[move.node]=node.transform
			if not Engine.is_editor_hint():clearance.add_meshes(node,false)
	for node in find_children("*","AnimationPlayer",true,false):node.active=false

func has_action() -> bool:return not moving.is_empty()
func interact() -> void:set_open(not opened)

func set_open(value: bool) -> void:
	if Engine.is_editor_hint():return
	opened=value;animating=true

func _pose(value: float) -> void:
	var fraction:=smoothstep(0.0,1.0,value)
	for move in moving:
		var node:=find_child(move.node,true,false) as Node3D
		if not node or not origins.has(move.node):continue
		var original: Transform3D=origins[move.node]
		var axis: Vector3={"x":Vector3.RIGHT,"y":Vector3.UP,"z":Vector3.BACK}[move.axis]
		var next:=original
		if move.has("distance"):next.origin+=axis*float(move.distance)*fraction
		else:next.basis=original.basis*Basis(axis,deg_to_rad(float(move.angle))*fraction)
		node.transform=next

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not animating:return
	var blocker:=get_node_or_null("DoorBlocker/Shape") as CollisionShape3D
	if passage and not opened and blocker and Clearance.players_overlap(blocker):return
	var destination:=1.0 if opened else 0.0
	var remaining:=minf(delta/.75,absf(destination-progress))
	while remaining>0:
		var step:=minf(.015,remaining)
		var next:=move_toward(progress,destination,step)
		_pose(next)
		if clearance.blocked():_pose(progress);return
		progress=next;remaining-=step
	if blocker:blocker.set_deferred("disabled",progress>=.999 or (not opened and progress>0))
	if is_equal_approx(progress,destination):animating=false
