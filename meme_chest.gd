@tool
extends Node3D
## Reusable crate: front anchor at z=0, solid box extends toward -Z.
@export var container_id := "bedroom_supply"
@export var display_name := "大肥鱼的补给箱"
@export var note := ""
@export var tint := Color("95a9bb")
var hinge: Node3D
var lid_tween: Tween
var opened := false
var lid_fraction:=0.0
var lid_clearance=preload("res://character/moving_clearance.gd").new()

func _ready() -> void:
 var builder=load("res://module_3d.gd").new()
 builder.module_id="";add_child(builder)
 builder.box(Vector3(1.24,.12,.90),Vector3(0,.08,-.45),Color("425b70"))
 # Four walls leave an actual dark interior visible when the lid opens.
 builder.box(Vector3(1.24,.56,.10),Vector3(0,.38,-.05),tint)
 builder.box(Vector3(1.24,.56,.10),Vector3(0,.38,-.85),tint.darkened(.12))
 for x in [-.57,.57]:builder.box(Vector3(.10,.56,.76),Vector3(x,.38,-.45),tint.darkened(.08))
 builder.box(Vector3(1.02,.04,.68),Vector3(0,.17,-.45),Color("223445"))
 # Flush satin panels, protective corner strips and a cyan status seam.
 for x in [-.54,.54]:
  builder.box(Vector3(.042,.57,.015),Vector3(x,.38,.013),Color("d2dce3"))
 builder.led_box(Vector3(1.08,.018,.014),Vector3(0,.632,.014),Color("83d9e5"),.35)
 builder.box(Vector3(.19,.14,.035),Vector3(.32,.41,.026),Color("30475a"))
 builder.led_box(Vector3(.105,.034,.012),Vector3(.32,.43,.05),Color("8ce3ec"),.35)
 builder.box(Vector3(.14,.035,.021),Vector3(.32,.376,.05),Color("bdcdd8"))
 # Original whale badge, built from simple geometry rather than a brand logo.
 builder.pillow(Vector3(.26,.13,.035),Vector3(-.25,.40,.033),Color("709dda"))
 var tail=builder.box(Vector3(.075,.075,.032),Vector3(-.40,.43,.034),Color("709dda"));tail.rotation.z=PI/4
 builder.pillow(Vector3(.025,.025,.012),Vector3(-.17,.43,.055),Color("18334b"))
 hinge=Node3D.new();hinge.position=Vector3(0,.69,-.86);add_child(hinge)
 var top=load("res://module_3d.gd").new();top.module_id="";hinge.add_child(top)
 top.box(Vector3(1.30,.10,.96),Vector3(0,.03,.43),tint.lightened(.12))
 top.box(Vector3(1.16,.012,.81),Vector3(0,.087,.43),tint.lightened(.055))
 top.led_box(Vector3(.42,.010,.014),Vector3(0,.10,.19),Color("8ad7e5"),.20)
 for x in [-.54,.54]:top.box(Vector3(.04,.012,.82),Vector3(x,.101,.43),Color("d2dce3"))
 var body:=StaticBody3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.24,.76,.90)
 var hit:=CollisionShape3D.new();hit.shape=shape;hit.position=Vector3(0,.38,-.45);body.add_child(hit);add_child(body)
 if not Engine.is_editor_hint():lid_clearance.add_meshes(hinge,false)

func set_open(value: bool) -> void:
 opened=value
 if lid_tween:lid_tween.kill()
 if not is_inside_tree() or not hinge:return

func _physics_process(delta: float) -> void:
 if Engine.is_editor_hint() or not is_instance_valid(hinge):return
 var destination:=1.0 if opened else 0.0
 if is_equal_approx(destination,lid_fraction):return
 var remaining:=minf(delta/.38,absf(destination-lid_fraction))
 while remaining>0:
  var step:=minf(.015,remaining)
  var next:=move_toward(lid_fraction,destination,step)
  hinge.rotation.x=deg_to_rad(-105)*smoothstep(0.0,1.0,next)
  if lid_clearance.blocked():hinge.rotation.x=deg_to_rad(-105)*smoothstep(0.0,1.0,lid_fraction);return
  lid_fraction=next;remaining-=step
