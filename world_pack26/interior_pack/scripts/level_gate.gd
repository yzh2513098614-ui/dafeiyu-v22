extends Node3D
signal state_changed(gate_id: String,opened: bool)
const Clearance=preload("res://character/moving_clearance.gd")
@export var gate_id: String=""
@export var required_key: String=""
@export var required_switch: String=""
@export var initial_open: bool=false
var opened:=false
var target_open:=false
var openness:=0.0
var clearance=Clearance.new()

func _ready() -> void:
	clearance.add_meshes($LeftPanel,false);clearance.add_meshes($RightPanel,false)
	if "--bake-nav" not in OS.get_cmdline_user_args():apply_state(initial_open,true)

func _pose(value: float) -> void:
	var eased:=smoothstep(0.0,1.0,value)
	$LeftPanel.position.x=lerpf(-.65,-1.94,eased)
	$RightPanel.position.x=lerpf(.65,1.94,eased)

func _sync() -> void:
	opened=is_equal_approx(openness,1.0)
	$Blocker/Shape.set_deferred("disabled",opened or (not target_open and openness>0))
	$NavigationLink.enabled=opened

func apply_state(value: bool,instant: bool=false) -> void:
	target_open=value
	if instant:
		if not value and Clearance.players_overlap($Blocker/Shape):return
		var previous:=openness
		_pose(1.0 if value else 0.0)
		if clearance.blocked():_pose(previous);return
		openness=1.0 if value else 0.0;_sync()

func _physics_process(delta: float) -> void:
	var destination:=1.0 if target_open else 0.0
	if is_equal_approx(openness,destination):return
	if not target_open and Clearance.players_overlap($Blocker/Shape):return
	var remaining:=minf(delta/.65,absf(destination-openness))
	while remaining>0:
		var step:=minf(.015,remaining)
		var next:=move_toward(openness,destination,step)
		_pose(next)
		if clearance.blocked():_pose(openness);return
		openness=next;remaining-=step
	_sync()
	if is_equal_approx(openness,destination):state_changed.emit(gate_id,opened)
