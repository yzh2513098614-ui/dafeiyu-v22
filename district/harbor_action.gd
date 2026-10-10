extends Node3D
## Small harbour facilities use the shared E / proximity card.
const Geo=preload("res://district/story_geometry.gd")
var game
var kind:=""
var opened:=false
var state_key:=""
var busy:=false
var amount:=0.0
var clock:=0.0
var motion: Tween
var lever: Node3D
var drum: Node3D
var indicator: MeshInstance3D
var beacon: SpotLight3D
var beacon_pivot: Node3D
var boat: Node3D
var rope_segments: Array[MeshInstance3D]=[]
var moor_direction:=Vector3.ZERO

func configure(owner_game,action: String,label: String,floor_height: float) -> void:
 game=owner_game;kind=action;state_key="story_harbor:facility:"+kind
 opened=bool(game.visited.get(state_key,false));amount=1.0 if opened else 0.0
 set_meta("interaction_title",label);set_meta("interaction_height",1.65)
 set_meta("harbor_facility",true);set_meta("floor_height",floor_height)
 add_to_group("harbor_facilities")

func has_action() -> bool:return true

func map_action() -> String:
 if busy:return "信标切换中…" if kind=="beacon" else "绞盘转动中…"
 if kind=="beacon":return "关闭旋转信标" if opened else "开启旋转信标"
 return "放松停泊缆绳" if opened else "收紧停泊缆绳"

func map_detail() -> String:
 if kind=="beacon":return "信标已开启 · 夜间缓慢旋转" if opened else "夜间光束沿海景步道缓慢扫过"
 if opened and not busy:return "缆绳已收紧 · 可再次放松"
 return "转动绞盘与缆绳 · 不消耗背包物品"

func interact() -> void:
 if busy:return
 opened=not opened;busy=true;set_meta("map_busy",true)
 game.visited[state_key]=opened
 if motion and motion.is_valid():motion.kill()
 motion=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
 motion.tween_property(self,"amount",1.0 if opened else 0.0,.60 if kind=="beacon" else 2.6)
 if kind=="winch":motion.tween_property(drum,"rotation:x",drum.rotation.x+(TAU*2.0 if opened else -TAU*2.0),2.6)
 game.get_node("/root/SfxDirector").play("chest_open",-17.0)
 motion.finished.connect(func():
  busy=false;set_meta("map_busy",false)
  if game.life_booted:game._save())

func _pose_beacon() -> void:
 lever.rotation.x=lerpf(.26,-.38,amount)
 var material: StandardMaterial3D=indicator.material_override
 material.albedo_color=Color("bad7be") if amount>.5 else Color("6a7b7e")
 material.emission_energy_multiplier=amount*.65
 var hour: float=game.atmosphere.hour
 var night: float=maxf(1.0-smoothstep(5.5,8.0,hour),smoothstep(17.0,20.0,hour))
 beacon.light_energy=amount*night*6.0
 beacon.set_meta("beacon_amount",amount)
 beacon_pivot.rotation.y=clock*.32

func _pose_rope() -> void:
 if not is_instance_valid(boat):return
 boat.set_meta("moor_offset",moor_direction*amount*.22)
 var a: Vector3=to_global(Vector3(0,.72,0));var b: Vector3=boat.to_global(Vector3(2.40,.22,-.55))
 var slack: float=lerpf(.47,.07,amount)
 for i in rope_segments.size():
  var t: float=float(i)/rope_segments.size();var u: float=float(i+1)/rope_segments.size()
  var p: Vector3=a.lerp(b,t)-Vector3.UP*sin(t*PI)*slack
  var q: Vector3=a.lerp(b,u)-Vector3.UP*sin(u*PI)*slack
  var segment: MeshInstance3D=rope_segments[i]
  var axis: Vector3=(q-p).normalized();var tangent: Vector3=Vector3.RIGHT if absf(axis.x)<.9 else Vector3.FORWARD
  var right: Vector3=axis.cross(tangent).normalized()
  segment.global_transform=Transform3D(Basis(right,axis*p.distance_to(q),right.cross(axis).normalized()),(p+q)*.5)

func _process(delta: float) -> void:
 if not game or (game.pause_menu and game.pause_menu.active):return
 clock+=delta
 if kind=="beacon":_pose_beacon()
 elif kind=="winch":_pose_rope()
