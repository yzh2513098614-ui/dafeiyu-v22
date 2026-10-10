extends RefCounted
const Geo=preload("res://district/story_geometry.gd")
const Action=preload("res://district/harbor_action.gd")
const FABRIC=preload("res://assets/modern/shaders/harbor_fabric.gdshader")
const STEEL=Color("52646b")
const CREAM=Color("e6e3d5")

static func _label(g,parent: Node3D,text: String,point: Vector3,size: int=36,color: Color=Color("405d71")) -> void:
 var label:=Label3D.new();label.text=text;label.font=g._game_font();label.font_size=size;label.pixel_size=.006
 label.position=point;label.modulate=color;label.outline_size=0;label.shaded=true;parent.add_child(label)
 label.set_meta("harbor_wayfinding",true)

static func _waymark(g,parent: Node3D,point: Vector3,title: String,route: String) -> void:
 var root:=Node3D.new();root.name="HarborDirectionSign";root.position=point;root.rotation_degrees.y=-42;parent.add_child(root)
 Geo.box(root,Vector3(.12,2.10,.12),Vector3(0,1.05,0),STEEL,2,.02)
 Geo.box(root,Vector3(2.62,.90,.10),Vector3(0,1.82,0),Color("69878f"),0,.028)
 Geo.box(root,Vector3(2.50,.79,.02),Vector3(0,1.82,.062),CREAM,0,.012)
 _label(g,root,title,Vector3(0,1.98,.081),56)
 _label(g,root,route,Vector3(0,1.65,.081),34,Color("788a91"))
 Geo.cylinder(root,.24,.075,Vector3(0,.037,0),Color("bdc7cc"))
 g._collision(root,Vector3(.20,2.1,.20),Vector3(0,1.05,0))
 g._collision(root,Vector3(2.62,.90,.10),Vector3(0,1.82,0))

static func _beacon_console(g,upper: Node3D) -> void:
 var tower: Node3D=upper.get_node("LookoutLighthouse")
 var action=Action.new();action.name="HarborBeaconConsole";action.position=Vector3(8.5,3.6,-17.0);g.world.add_child(action)
 action.configure(g,"beacon","灯塔 · 港口信标开关",3.6)
 Geo.box(action,Vector3(.95,.94,.65),Vector3(0,.47,0),Color("8ba4ae"),0,.06)
 Geo.box(action,Vector3(1.01,.12,.72),Vector3(0,1.0,0),CREAM,0,.035)
 Geo.box(action,Vector3(.64,.30,.022),Vector3(0,.69,.34),Color("d8e2de"),0,.023)
 _label(g,action,"H / 02",Vector3(0,.69,.36),20)
 action.lever=Node3D.new();action.lever.position=Vector3(-.16,1.07,0);action.add_child(action.lever)
 Geo.rod(action.lever,Vector3.ZERO,Vector3(0,.24,0),.025,STEEL)
 Geo.cylinder(action.lever,.068,.078,Vector3(0,.23,0),Color("d7b778"))
 var indicator:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.054;sphere.height=.108;sphere.radial_segments=12;sphere.rings=6
 var material:=StandardMaterial3D.new();material.albedo_color=Color("6a7b7e");material.emission_enabled=true;material.emission=Color("afdfb9")
 indicator.mesh=sphere;indicator.material_override=material;indicator.position=Vector3(.25,1.11,.1);action.add_child(indicator);action.indicator=indicator
 action.beacon_pivot=Node3D.new();action.beacon_pivot.name="RotatingBeacon";action.beacon_pivot.position=Vector3(0,4.17,0);tower.add_child(action.beacon_pivot)
 var beacon:=SpotLight3D.new();beacon.light_color=Color("ffe2ad");beacon.light_energy=0;beacon.spot_range=23;beacon.spot_angle=23;beacon.spot_attenuation=.65;beacon.rotation.x=deg_to_rad(-25)
 beacon.set_meta("harbor_lamp",true);beacon.set_meta("harbor_beacon",true);beacon.set_meta("beacon_amount",action.amount);beacon.set_meta("fixture_weight",0.0);beacon.shadow_enabled=false
 action.beacon_pivot.add_child(beacon);action.beacon=beacon
 g._collision(action,Vector3(.95,1.13,.72),Vector3(0,.56,0));Geo.contact(action,Vector3(0,.047,0),Vector2(1.7,1.35),.15)

static func _winch(g,sea: Node3D) -> void:
 var action=Action.new();action.name="SouthPierMooringWinch";action.position=Vector3(-23,0,10.35);g.world.add_child(action)
 action.configure(g,"winch","南栈桥 · 停泊绞盘",0.0)
 for child in sea.get_children():
  if child.has_meta("boat_origin") and child.position.z>10:action.boat=child
 action.moor_direction=Vector3(.12,0,-1).normalized()
 Geo.box(action,Vector3(.90,.10,.70),Vector3(0,.10,0),Color("b7c6cb"),0,.035)
 for side in [-1.0,1.0]:Geo.box(action,Vector3(.10,.74,.51),Vector3(side*.34,.50,0),Color("6b8d98"),2,.025)
 action.drum=Node3D.new();action.drum.position=Vector3(0,.71,0);action.add_child(action.drum)
 Geo.rod(action.drum,Vector3(-.38,0,0),Vector3(.38,0,0),.083,STEEL)
 var reel: MeshInstance3D=Geo.cylinder(action.drum,.22,.48,Vector3.ZERO,Color("b6a77c"));reel.rotation.z=PI*.5
 for side in [-1.0,1.0]:
  var flange: MeshInstance3D=Geo.cylinder(action.drum,.28,.045,Vector3(side*.26,0,0),STEEL);flange.rotation.z=PI*.5
 for i in 14:
  var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.193;torus.outer_radius=.217;torus.rings=16;torus.ring_segments=6
  ring.mesh=torus;ring.position=Vector3(-.23+i*.035,0,0);ring.rotation.z=PI*.5;ring.material_override=Geo.material(Color("c5b990"));action.drum.add_child(ring)
 Geo.rod(action.drum,Vector3(.43,0,0),Vector3(.43,.25,0),.034,STEEL)
 Geo.rod(action.drum,Vector3(.43,.25,0),Vector3(.59,.25,0),.050,Color("b89564"))
 for i in 12:
  var mesh:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=.022;cylinder.bottom_radius=.022;cylinder.height=1.0;cylinder.radial_segments=8
  mesh.mesh=cylinder;mesh.material_override=Geo.material(Color("d1c7a4"));action.add_child(mesh);action.rope_segments.append(mesh)
 g._collision(action,Vector3(.97,.96,.73),Vector3(0,.51,0));Geo.contact(action,Vector3(0,.08,0),Vector2(1.4,1.3),.17)

static func _pennants(g,ground: Node3D) -> void:
 for x in [-14.4,-4.5]:
  Geo.rod(ground,Vector3(x,0,12.4),Vector3(x,3.08,12.4),.035,STEEL)
  g._collision(ground,Vector3(.08,3.1,.08),Vector3(x,1.55,12.4))
 Geo.rod(ground,Vector3(-14.4,3.08,12.4),Vector3(-4.5,3.08,12.4),.018,Color("bcc7c7"))
 var palette: Array[Color]=[Color("9cbbb2"),Color("e5c994"),Color("c7907f"),Color("8da8b7")]
 for i in 17:
  var root:=MeshInstance3D.new();var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  for pair in [[Vector3(-.17,0,0),Vector2(0,0)],[Vector3(.17,0,0),Vector2(1,0)],[Vector3(0,-.40,0),Vector2(.5,1)]]:
   tool.set_normal(Vector3.BACK);tool.set_uv(pair[1]);tool.add_vertex(pair[0])
  root.mesh=tool.commit();root.position=Vector3(-14.08+i*.575,3.07-sin(float(i)/16.0*PI)*.15,12.4)
  var material:=ShaderMaterial.new();material.shader=FABRIC;material.set_shader_parameter("cloth_color",palette[i%palette.size()]);root.material_override=material
  root.set_meta("harbor_wind",true);root.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;ground.add_child(root)

static func _gulls(sea: Node3D) -> void:
 for i in 3:
  var root:=Node3D.new();root.name="HarborGull";root.set_meta("harbor_gull",true);root.set_meta("phase",float(i)*TAU/3.0);sea.add_child(root)
  Geo.box(root,Vector3(.11,.09,.24),Vector3.ZERO,Color("ede9dc"),0,.028).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  Geo.box(root,Vector3(.045,.042,.11),Vector3(0,.015,-.15),Color("c9af70"),0,.01).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for side in [-1.0,1.0]:
   var wing:=Node3D.new();wing.name="LeftWing" if side<0 else "RightWing";wing.position.x=side*.04;root.add_child(wing)
   Geo.box(wing,Vector3(.37,.026,.14),Vector3(side*.18,0,.018),CREAM,0,.008).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   Geo.box(wing,Vector3(.13,.024,.09),Vector3(side*.40,0,.039),Color("9cabb1"),0,.007).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func build(g,level: Node3D) -> void:
 var ground: Node3D=level.get_node("Ground");var upper: Node3D=level.get_node("Upper");var sea: Node3D=level.get_node("Sea")
 _beacon_console(g,upper);_winch(g,sea);_pennants(g,ground);_gulls(sea)
 _waymark(g,ground,Vector3(-13.0,0,-4.15),"↑ 灯塔步道","西侧楼梯 · 2F")
 _waymark(g,ground,Vector3(15.8,0,14.7),"↑ 海风长廊","东侧楼梯 · 2F")
 _waymark(g,ground,Vector3(-15.2,0,6.4),"← 南栈桥","绞盘 · 停泊区")
 _waymark(g,upper,Vector3(-14.3,3.6,-19.0),"海风码头 · 2F","灯塔 → 东梯 ↓")
