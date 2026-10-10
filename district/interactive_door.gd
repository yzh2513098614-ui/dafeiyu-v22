extends Node3D
## Reusable double door: real hinges, reversible motion and guarded collision.
const Clearance=preload("res://character/moving_clearance.gd")
var game
var display_name:="房间门"
var opened:=false
var animating:=false
var obstructed:=false
var fraction:=0.0
var swing:=1.0
var door_width:=2.4
var state_key:=""
var pivots: Array[Node3D]=[]
var bodies: Array[StaticBody3D]=[]
var blocker: CollisionShape3D
var clearance=Clearance.new()

func configure(owner_game,width: float,key: String,title: String="房间门",height: float=2.03) -> void:
 game=owner_game;door_width=width;state_key=str(game.location_id)+":door:"+key;display_name=title
 add_to_group("map_interactive_doors")
 set_meta("map_interactive_door",true)
 var trim:=StandardMaterial3D.new();trim.albedo_color=Color("476274");trim.roughness=.52
 var panel:=StandardMaterial3D.new();panel.albedo_color=Color("d5dfd9");panel.roughness=.69
 var glazing:=StandardMaterial3D.new();glazing.albedo_color=Color("93b9c2");glazing.roughness=.28
 var steel:=StandardMaterial3D.new();steel.albedo_color=Color("d4ddd9");steel.metallic=.55;steel.roughness=.32
 var span: float=(width-.12)*.5
 for side in [-1.0,1.0]:
  var hinge:=Node3D.new();hinge.name="LeftHinge" if side<0 else "RightHinge"
  hinge.position.x=side*(width*.5-.035);add_child(hinge);pivots.append(hinge)
  var center_x: float=-side*span*.5
  _box(hinge,Vector3(span,height*.43,.075),Vector3(center_x,height*.215+.035,0),panel)
  _box(hinge,Vector3(span-.13,height*.50,.035),Vector3(center_x,height*.715,0),glazing)
  for x in [center_x-span*.5+.033,center_x+span*.5-.033]:
   _box(hinge,Vector3(.066,height,.10),Vector3(x,height*.5,0),trim)
  for y in [.06,height*.45,height-.035]:
   _box(hinge,Vector3(span,.07,.10),Vector3(center_x,y,0),trim)
  var handle_x: float=-side*(span-.16)
  for face in [-1.0,1.0]:
   _box(hinge,Vector3(.045,.27,.06),Vector3(handle_x,.98,face*.065),steel)
  var body:=StaticBody3D.new();body.name="DoorLeafSolid";hinge.add_child(body);bodies.append(body)
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(span,height,.105)
  shape.shape=box;shape.position=Vector3(center_x,height*.5,0);body.add_child(shape);clearance.shapes.append(shape)
 var fixed:=StaticBody3D.new();fixed.name="ClosedDoorBlocker";add_child(fixed);bodies.append(fixed)
 blocker=CollisionShape3D.new();var barrier:=BoxShape3D.new();barrier.size=Vector3(width-.09,height,.14)
 blocker.shape=barrier;blocker.position.y=height*.5;fixed.add_child(blocker)
 opened=bool(game.visited.get(state_key,false));fraction=1.0 if opened else 0.0
 swing=-1.0 if bool(game.visited.get(state_key+":reverse",false)) else 1.0
 _pose(fraction);blocker.disabled=opened

func _box(parent: Node3D,size: Vector3,point: Vector3,material: Material) -> void:
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=size
 mesh.mesh=box;mesh.position=point;mesh.material_override=material;parent.add_child(mesh)

func interaction_position() -> Vector3:
 var local: Vector3=to_local(game.player.global_position)
 return to_global(Vector3(clampf(local.x,-door_width*.5+.08,door_width*.5-.08),0,0))

func toggle_open() -> void:
 set_open(not opened)

func set_open(value: bool) -> void:
 if not value and Clearance.players_overlap(blocker):
  obstructed=true;game.hint.text="先离开门口，再关门。";return
 if value and fraction<=.001:
  # Open away from the player; moving leaves still pause if somebody steps in.
  swing=1.0 if to_local(game.player.global_position).z>=0 else -1.0
 opened=value;animating=true;obstructed=false
 game.visited[state_key]=opened;game.visited[state_key+":reverse"]=swing<0
 SfxDirector.play("door",-5.0)
 if game.life_booted:game._save()

func is_passable() -> bool:
 return fraction>=.999

func _pose(value: float) -> void:
 var angle: float=smoothstep(0.0,1.0,value)*deg_to_rad(88.0)*swing
 pivots[0].rotation.y=angle;pivots[1].rotation.y=-angle

func _physics_process(delta: float) -> void:
 for body in bodies:body.collision_layer=1 if is_visible_in_tree() else 0
 if not animating or not is_visible_in_tree():return
 if not opened and Clearance.players_overlap(blocker):obstructed=true;return
 var destination: float=1.0 if opened else 0.0
 var remaining: float=minf(delta/.65,absf(destination-fraction))
 obstructed=false
 while remaining>0:
  var step: float=minf(.012,remaining)
  var next: float=move_toward(fraction,destination,step)
  _pose(next)
  if clearance.blocked():_pose(fraction);obstructed=true;return
  fraction=next;remaining-=step
 # The leaves guard a moving doorway. A closed door also seals the centre seam.
 blocker.set_deferred("disabled",fraction>.001)
 if is_equal_approx(fraction,destination):animating=false
