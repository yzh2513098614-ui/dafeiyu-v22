extends RefCounted
## Two levels, two walkable stairways and piers, using the quay's exact art family.
const Geo=preload("res://district/story_geometry.gd")
const Quay=preload("res://district/story_quay.gd")
const Shape=preload("res://district/space_shape.gd")
const Door=preload("res://district/interactive_door.gd")
const WATER=preload("res://assets/modern/shaders/harbor_water.gdshader")
const HEIGHT:=3.6
const STONE=Color("dddcd3")
const BLUE=Color("858ba7")
const STEEL=Color("52646b")
const WOOD=Color("b98d53")

static func _group(parent: Node3D,label: String,height: float=0.0) -> Node3D:
 var node:=Node3D.new();node.name=label;node.set_meta("floor_height",height);parent.add_child(node);return node

static func _slab(level: Node3D,parent: Node3D,rect: Rect2,height: float) -> void:
 var center: Vector2=rect.get_center()
 Geo.box(parent,Vector3(rect.size.x,.28,rect.size.y),Vector3(center.x,height-.14,center.y),Color("7e8e9b"),0,.025)
 var body:=StaticBody3D.new();body.name="WalkableFloor";body.collision_layer=10;body.collision_mask=4
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(rect.size.x,.28,rect.size.y)
 body.position=Vector3(center.x,height-.115,center.y);shape.shape=box;body.add_child(shape);parent.add_child(body);body.set_meta("walkable_top",height+.025)
 var slabs: Array=level.get_meta("walkable_slabs",[]);slabs.append(body);level.set_meta("walkable_slabs",slabs)

static func _paving(parent: Node3D,rect: Rect2,height: float,kind: int=0) -> void:
 var center: Vector2=rect.get_center()
 Quay._ground(parent,rect.size,Vector3(center.x,height+.027,center.y),Color("b59981") if kind==0 else (BLUE if kind==1 else Color("d7ba7f")),Color("d5bda0") if kind==0 else (Color("c5cadd") if kind==1 else Color("e6d2a4")),kind,Vector2(1.45,1.15) if kind==0 else Vector2(.85,.75))

static func _rail(g,parent: Node3D,a: Vector3,b: Vector3,stone: bool=false) -> void:
 var d: Vector3=b-a;var count: int=maxi(1,ceili(d.length()/1.8));var center: Vector3=(a+b)*.5
 var holder:=Node3D.new();holder.position=center;holder.rotation.y=-atan2(d.z,d.x);parent.add_child(holder)
 var length: float=d.length()
 if stone:
  Geo.box(holder,Vector3(length,.70,.35),Vector3(0,.35,0),STONE,0,.045)
  Geo.box(holder,Vector3(length+.05,.09,.43),Vector3(0,.75,0),Color("ece8dd"),0,.025)
 else:
  Geo.box(holder,Vector3(length,.15,.20),Vector3(0,.075,0),Color("bdc8d5"),0,.02)
  for y in [.42,.93]:Geo.box(holder,Vector3(length,.055,.07),Vector3(0,y,0),STEEL,2,.014)
  for i in count+1:
   var x: float=-length*.5+i*length/count
   Geo.box(holder,Vector3(.12,.94,.12),Vector3(x,.47,0),STONE,0,.025)
   Geo.box(holder,Vector3(.18,.05,.18),Vector3(x,.96,0),Color("ece8dd"),0,.016)
 g._collision(holder,Vector3(length,1.05,.18),Vector3(0,.52,0))

static func _prop(g,parent: Node3D,kind: String,point: Vector3,angle: float=0.0,color: Color=Color("437fba"),fish: bool=true) -> void:
 var first: int=g.world.get_child_count()
 match kind:
  "bench":Quay._bench(g,point,angle)
  "lamp":Quay._lamp(g,point)
  "bollard":Quay._bollard(g,point)
  "net":Quay._net(g,point,.61)
  "crate":Quay._crate(g,point,color,fish)
  "cart":Quay._cart(g,point)
 for i in range(first,g.world.get_child_count()):
  var node: Node3D=g.world.get_child(i)
  if kind=="crate":
   for mesh in node.get_children():
    if mesh is MeshInstance3D and mesh.mesh is PlaneMesh:mesh.position.y=.044-(point.y-float(parent.get_meta("floor_height",0.0)))
  node.reparent(parent,true)

static func _stairs(g,level: Node3D,parent: Node3D,x: float,front: float,back: float,label: String) -> void:
 var width:=3.6;var run: float=front-back
 var node:=Node3D.new();node.name=label;node.position=Vector3(x,0,(front+back)*.5);parent.add_child(node)
 for i in 24:
  var rise: float=HEIGHT*(i+1)/24.0
  Geo.box(node,Vector3(width,rise+.08,run/24.0+.006),Vector3(0,rise*.5-.015,run*.5-(i+.5)*run/24.0),Color("c7cedc"),0,.018)
  Geo.box(node,Vector3(width-.12,.013,.055),Vector3(0,rise+.029,run*.5-(i+.03)*run/24.0),Color("e9e5d8"),0,.003)
 # Smooth concrete cheek faces cover the joints between stacked step blocks.
 for side in [-1.0,1.0]:
  var side_tool:=SurfaceTool.new();side_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  var side_points: Array[Vector3]=[Vector3(side*(width*.5+.002),-.04,run*.5),Vector3(side*(width*.5+.002),-.04,-run*.5),Vector3(side*(width*.5+.002),HEIGHT-.10,-run*.5)]
  Geo._face(side_tool,side_points,Vector3.RIGHT*side)
  var cheek:=MeshInstance3D.new();cheek.mesh=side_tool.commit();cheek.material_override=Geo.material(Color("c7cedc"));node.add_child(cheek)
 var body:=StaticBody3D.new();body.name="StairSupport";body.collision_layer=10;body.collision_mask=4
 var hit:=CollisionShape3D.new();hit.name="Shape";var ramp:=ConvexPolygonShape3D.new();var points:=PackedVector3Array()
 for side in [-width*.5,width*.5]:
  points.append(Vector3(side,.025,run*.5));points.append(Vector3(side,HEIGHT+.025,-run*.5))
  points.append(Vector3(side,-.24,run*.5));points.append(Vector3(side,-.24,-run*.5))
 ramp.points=points;hit.shape=ramp;body.add_child(hit);node.add_child(body)
 body.set_meta("walkable_top",HEIGHT+.025);body.set_meta("walkable_stair",hit)
 var slabs: Array=level.get_meta("walkable_slabs",[]);slabs.append(body);level.set_meta("walkable_slabs",slabs)
 for side in [-1.0,1.0]:
  var first:=Vector3(side*2.0,.94,run*.5);var last:=Vector3(side*2.0,HEIGHT+.94,-run*.5)
  Geo.rod(node,first,last,.042,STEEL)
  for i in range(0,25,4):
   var t: float=i/24.0;var point: Vector3=first.lerp(last,t)
   Geo.rod(node,point-Vector3.UP*.91,point,.035,STEEL)
  var guard:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
  box.size=Vector3(.12,1.2,sqrt(run*run+HEIGHT*HEIGHT));shape.shape=box;guard.position=Vector3(side*2.0,HEIGHT*.5+.63,0);guard.rotation.x=atan2(HEIGHT,run);guard.add_child(shape);node.add_child(guard)
 # A landing sign is aligned to the route, leaving the whole stair width clear.
 var sign: Label3D=g._sign("海景步道  ↑",Vector3(x+2.4,.9,front-.2),24,Color("476177"));sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED

static func _pier(g,level: Node3D,parent: Node3D,z: float) -> void:
 var rect:=Rect2(-29,z-2,11,4);_slab(level,parent,rect,0.0)
 for i in 42:Geo.box(parent,Vector3(10.96,.06,.091),Vector3(-23.5,.04,z-1.94+i*.093),Color("a27d56"),1,.008)
 _rail(g,parent,Vector3(-29,0,z-2),Vector3(-18,0,z-2));_rail(g,parent,Vector3(-29,0,z+2),Vector3(-18,0,z+2));_rail(g,parent,Vector3(-29,0,z-2),Vector3(-29,0,z+2))
 for x in [-27.5,-22.0]:_prop(g,parent,"bollard",Vector3(x,0,z+1.3))
 _prop(g,parent,"net",Vector3(-24,0,z-1.13));Quay._lifebuoy(parent,Vector3(-27.5,.93,z+1.92))

static func _boat(parent: Node3D,point: Vector3,yaw: float=90.0) -> void:
 var root:=Node3D.new();root.name="FishingBoat";root.position=point;root.rotation_degrees.y=yaw;parent.add_child(root)
 var outline: Array[Vector2]=[Vector2(-2.65,-.58),Vector2(-1.65,-.96),Vector2(1.55,-.96),Vector2(2.6,-.5),Vector2(3.0,0),Vector2(2.6,.5),Vector2(1.55,.96),Vector2(-1.65,.96),Vector2(-2.65,.58)]
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in outline.size():
  var a: Vector2=outline[i];var b: Vector2=outline[(i+1)%outline.size()]
  var p:=Vector3(a.x,.14,a.y);var q:=Vector3(b.x,.14,b.y);var r:=Vector3(b.x*.80,-.42,b.y*.54);var s:=Vector3(a.x*.80,-.42,a.y*.54)
  var normal: Vector3=(q-p).cross(r-p).normalized()
  if normal.dot(Vector3(a.x+b.x,0,a.y+b.y))<0:normal=-normal
  Geo._face(tool,[p,q,r,s],normal)
  Geo.rod(root,p+Vector3.UP*.04,q+Vector3.UP*.04,.055,Color("e6e3d3"))
 var hull:=MeshInstance3D.new();hull.mesh=tool.commit();hull.material_override=Geo.material(Color("4d7e9b"));root.add_child(hull)
 Geo.box(root,Vector3(3.75,.10,1.35),Vector3(-.12,.08,0),Color("927554"),1,.03)
 Geo.box(root,Vector3(1.39,.72,1.24),Vector3(-.65,.50,0),Color("e6e3d5"),0,.07)
 Geo.box(root,Vector3(1.48,.12,1.36),Vector3(-.65,.92,0),Color("9aaebc"),0,.035)
 for side in [-1.0,1.0]:Geo.box(root,Vector3(.62,.29,.022),Vector3(-.68,.66,side*.64),Color("9bbcca"),0,.018)
 Geo.box(root,Vector3(.028,.30,.79),Vector3(.066,.65,0),Color("9bbcca"),0,.015)
 Geo.rod(root,Vector3(-.7,.94,0),Vector3(-.7,2.6,0),.035,STEEL)
 Geo.rod(root,Vector3(-1.18,2.13,0),Vector3(-.22,2.13,0),.035,STEEL)
 Geo.cylinder(root,.25,.44,Vector3(1.13,.39,-.22),Color("738d87"))
 for x in [-2.0,-1.35,.65,1.35]:
  for side in [-1.0,1.0]:
   var tire:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.11;ring.outer_radius=.20;ring.rings=16;ring.ring_segments=8
   tire.mesh=ring;tire.position=Vector3(x,-.02,side*.94);tire.rotation.x=PI*.5;tire.material_override=Geo.material(Color("505e6b"));root.add_child(tire)
 root.set_meta("boat_origin",point)

static func _stall(g,parent: Node3D,point: Vector3,yaw: float=0.0) -> void:
 var root:=Node3D.new();root.name="FishMarketStall";root.position=point;root.rotation_degrees.y=yaw;parent.add_child(root)
 Geo.box(root,Vector3(3.30,.16,1.05),Vector3(0,.90,0),Color("dfd7bf"),0,.035)
 for x in [-1.35,1.35]:
  Geo.box(root,Vector3(.12,.82,.78),Vector3(x,.43,0),WOOD,1,.025)
  Geo.rod(root,Vector3(x*.99,.08,-.48),Vector3(x*.99,2.72,-.48),.045,STEEL)
 for i in 13:
  var color: Color=Color("a1bdb7") if i%2==0 else Color("e8dfc8")
  var strip: MeshInstance3D=Geo.box(root,Vector3(.259,.07,1.68),Vector3(-1.56+i*.26,2.68,-.13),color,0,.017);strip.rotation.x=-.09
  Geo.box(root,Vector3(.259,.22,.06),Vector3(-1.56+i*.26,2.55,.70),color,0,.018)
 Geo.box(root,Vector3(3.20,.34,.12),Vector3(0,.59,-.47),Color("94acac"),0,.035)
 g._collision(root,Vector3(3.38,1.06,1.10),Vector3(0,.53,0))
 Geo.contact(root,Vector3(0,.047,0),Vector2(4.4,2.3),.18)
 # Reuse the same recognizable blue / yellow fish crates on a raised stall.
 for i in 2:
  var first: int=g.world.get_child_count();Quay._crate(g,root.to_global(Vector3(-.69+i*1.4,.99,0)),Color("437fba") if i==0 else Color("c4b252"),true,false)
  var crate: Node3D=g.world.get_child(first);crate.rotation_degrees.y=yaw;crate.reparent(root,true)
  for mesh in crate.get_children():
   if mesh is MeshInstance3D and mesh.mesh is PlaneMesh:mesh.hide()

static func _lighthouse(g,parent: Node3D) -> void:
 var root:=Node3D.new();root.name="LookoutLighthouse";root.position=Vector3(12,HEIGHT,-17.1);parent.add_child(root)
 Geo.cylinder(root,1.40,.20,Vector3(0,.10,0),Color("bdc6d0"),1.30)
 Geo.cylinder(root,1.02,3.40,Vector3(0,1.90,0),Color("e8e3d7"),.78)
 Geo.cylinder(root,1.00,.38,Vector3(0,1.67,0),Color("7295af"),.94)
 Geo.cylinder(root,.87,.12,Vector3(0,3.65,0),Color("e3dec9"))
 var glass: MeshInstance3D=Geo.cylinder(root,.61,.91,Vector3(0,4.17,0),Color("a7c1c7"));glass.name="LanternGlass"
 var glow:=StandardMaterial3D.new();glow.albedo_color=Color("a7c1c7");glow.roughness=.64;glow.emission_enabled=true;glow.emission=Color("ffd99a");glow.emission_energy_multiplier=.03;glass.material_override=glow
 for i in 8:
  var angle: float=i*TAU/8.0;Geo.rod(root,Vector3(cos(angle)*.61,3.71,sin(angle)*.61),Vector3(cos(angle)*.61,4.63,sin(angle)*.61),.039,STEEL)
 Geo.cylinder(root,.92,.36,Vector3(0,4.70,0),Color("75889a"),.28)
 Geo.cylinder(root,.047,.48,Vector3(0,5.09,0),STEEL)
 Geo.box(root,Vector3(.66,.12,.04),Vector3(.25,5.16,0),Color("c4b15a"),0,.018)
 Geo.box(root,Vector3(.57,.98,.035),Vector3(0,.67,1.05),Color("597d92"),0,.03)
 g._collision(root,Vector3(2.5,4.6,2.5),Vector3(0,2.3,0));Geo.contact(root,Vector3(0,.047,0),Vector2(3.9,3.9),.21)
 var lamp:=OmniLight3D.new();lamp.position=Vector3(0,4.17,0);lamp.omni_range=7;lamp.light_color=Color("ffe1a6");lamp.light_energy=.62;lamp.set_meta("harbor_lamp",true);lamp.set_meta("fixture_weight",.75);root.add_child(lamp)

static func _warehouse(g,parent: Node3D) -> void:
 var root:=Node3D.new();root.name="QuaysideWorkshop";root.position=Vector3(13,0,-4.0);parent.add_child(root)
 for spec in [[Vector3(7.3,2.55,.18),Vector3(0,1.275,-3.0)],[Vector3(.18,2.55,6.1),Vector3(3.57,1.275,0)],[Vector3(2.30,2.55,.18),Vector3(-2.52,1.275,3.0)],[Vector3(2.30,2.55,.18),Vector3(2.52,1.275,3.0)]]:
  Geo.box(root,spec[0],spec[1],Color("b8cacf"),0,.025);g._collision(root,spec[0],spec[1])
 Geo.box(root,Vector3(7.5,.15,.26),Vector3(0,2.60,-3),Color("e7e6d9"),0,.025)
 for x in [-2.1,2.1]:
  Geo.box(root,Vector3(1.64,.92,.06),Vector3(x,1.65,3.12),Color("e8e4d4"),0,.035)
  Geo.box(root,Vector3(1.40,.68,.045),Vector3(x,1.65,3.16),Color("8daebb"),0,.023)
  Geo.box(root,Vector3(.035,.71,.05),Vector3(x,1.65,3.2),Color("e9e5d7"),0,.004)
 var door:=Door.new();door.position=Vector3(13,0,-1.0);g.world.add_child(door);door.configure(g,2.64,"harbor_workshop","渔具工坊 · 双开门",2.18)
 for x in [11.60,14.40]:Geo.box(parent,Vector3(.16,2.45,.22),Vector3(x,1.225,-1.0),Color("567488"),0,.025)
 Geo.box(parent,Vector3(2.96,.19,.23),Vector3(13,2.42,-1.0),Color("567488"),0,.023)
 _prop(g,parent,"crate",Vector3(10.6,0,-5.3));_prop(g,parent,"crate",Vector3(10.6,.65,-5.3))
 _prop(g,parent,"net",Vector3(14.7,0,-5.8));_prop(g,parent,"net",Vector3(15.4,0,-4.4));_prop(g,parent,"cart",Vector3(12.6,0,-5.0))
 var lamp:=OmniLight3D.new();lamp.position=Vector3(13,2.8,-4);lamp.omni_range=6;lamp.light_color=Color("ffe4bc");lamp.light_energy=.42;lamp.set_meta("harbor_lamp",true);lamp.set_meta("fixture_weight",.8);root.add_child(lamp)

static func build(g) -> Dictionary:
 var level:=Node3D.new();level.name="SeaBreezeHarbor";level.set_meta("walkable_slabs",[]);g.world.add_child(level)
 var ground: Node3D=_group(level,"Ground");var upper: Node3D=_group(level,"Upper",HEIGHT);var water_group: Node3D=_group(level,"Sea")
 g.shell.set_meta("layout_revision","story_harbor_terraces_v1");g.shell.set_meta("story_look",true)
 g.shell.set_meta("guide_anchor",Vector3(-15,.04,16))
 _slab(level,ground,Rect2(-18,-20,36,40),0)
 _paving(ground,Rect2(-18,-20,36,40),0);_paving(ground,Rect2(.5,-20,4.5,40),.004,1);_paving(ground,Rect2(5.75,-20,12.25,40),.003,2)
 for x in [.15,5.35]:
  for z in range(-20,20):Geo.box(ground,Vector3(.42,.075,.985),Vector3(x,.035,z+.5),Color("c7cedc"),0,.025)
 for z in [-15.1,-8.1,-.3,5.3,12.3,18.3]:
  Quay._drain(ground,Vector3(-.4,.06,z));Quay._drain(ground,Vector3(5.9,.06,z))
 var sea:=MeshInstance3D.new();var ocean:=PlaneMesh.new();ocean.size=Vector2(24,54);sea.mesh=ocean;sea.position=Vector3(-29,-.77,0)
 var material:=ShaderMaterial.new();material.shader=WATER;material.set_shader_parameter("water_color",Color("799dab"));sea.material_override=material;water_group.add_child(sea);sea.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 g.shell.set_meta("harbor_water",material)
 _pier(g,level,ground,-6.0);_pier(g,level,ground,9.0)
 _boat(water_group,Vector3(-25.5,-.65,.9));_boat(water_group,Vector3(-24.6,-.65,15.0),85)
 # Lower seawall has genuine openings onto both piers.
 for span in [Vector2(-20,-8),Vector2(-4,7),Vector2(11,20)]:_rail(g,ground,Vector3(-18,0,span.x),Vector3(-18,0,span.y),true)
 _rail(g,ground,Vector3(-18,0,-20),Vector3(18,0,-20),true)
 _rail(g,ground,Vector3(18,0,-20),Vector3(18,0,20),true)
 _rail(g,ground,Vector3(-18,0,20),Vector3(18,0,20),true)
 # An L-shaped upper route leaves a broad open harbour plaza in front.
 _slab(level,upper,Rect2(-16,-20,34,7),HEIGHT);_paving(upper,Rect2(-16,-20,34,7),HEIGHT,2);_paving(upper,Rect2(-16,-18.25,34,4.5),HEIGHT+.004,1)
 _slab(level,upper,Rect2(9,-13,9,21),HEIGHT);_paving(upper,Rect2(9,-13,9,21),HEIGHT,2);_paving(upper,Rect2(10.5,-13,4.5,21),HEIGHT+.004,1)
 for x in [-15,-7,1,8]:Geo.box(ground,Vector3(.45,3.35,.45),Vector3(x,1.675,-13.4),STONE,0,.035);g._collision(ground,Vector3(.45,3.35,.45),Vector3(x,1.675,-13.4))
 for z in [-10,-3,4]:
  for x in [9.4,17.6]:Geo.box(ground,Vector3(.45,3.35,.45),Vector3(x,1.675,z),STONE,0,.035);g._collision(ground,Vector3(.45,3.35,.45),Vector3(x,1.675,z))
 _stairs(g,level,ground,-10,-5,-13,"WestPromenadeStairs")
 _stairs(g,level,ground,12,16,8,"EastReturnStairs")
 for span in [Vector2(-16,-12.02),Vector2(-7.98,9)]:_rail(g,upper,Vector3(span.x,HEIGHT,-13),Vector3(span.y,HEIGHT,-13))
 _rail(g,upper,Vector3(-16,HEIGHT,-20),Vector3(18,HEIGHT,-20));_rail(g,upper,Vector3(-16,HEIGHT,-20),Vector3(-16,HEIGHT,-13))
 _rail(g,upper,Vector3(18,HEIGHT,-20),Vector3(18,HEIGHT,8));_rail(g,upper,Vector3(9,HEIGHT,-13),Vector3(9,HEIGHT,8))
 for span in [Vector2(9,9.98),Vector2(14.02,18)]:_rail(g,upper,Vector3(span.x,HEIGHT,8),Vector3(span.y,HEIGHT,8))
 # The original scene's close view remains the texture and prop reference.
 for z in [-1.2,2.1,11.6]:_prop(g,ground,"bench",Vector3(6.6,0,z),90)
 _prop(g,ground,"lamp",Vector3(7.1,0,.4));_prop(g,ground,"lamp",Vector3(7.1,0,11.6))
 for z in [-16,-9,-.8,5.8,14.2]:_prop(g,ground,"bollard",Vector3(-16.8,0,z))
 for point in [Vector3(-3.8,0,-2.1),Vector3(-4,0,6.5),Vector3(-5.35,0,6.75),Vector3(-13.3,0,14.8)]:_prop(g,ground,"net",point)
 _prop(g,ground,"crate",Vector3(1.2,0,5.5));_prop(g,ground,"crate",Vector3(1.2,.65,5.5));_prop(g,ground,"crate",Vector3(2.55,0,5.5),0,Color("c4b252"))
 _prop(g,ground,"cart",Vector3(.7,0,6.8));_prop(g,ground,"crate",Vector3(-4.1,0,-5.6),0,Color("5688aa"),false)
 for point in [Vector3(-12,0,1.8),Vector3(-7,0,11.4),Vector3(-12,0,11.4)]:_stall(g,ground,point)
 for x in [-12,-3,4]:_prop(g,upper,"bench",Vector3(x,HEIGHT,-18.9))
 for z in [-7.0,-.5,5.0]:_prop(g,upper,"bench",Vector3(16.9,HEIGHT,z),-90)
 for point in [Vector3(-5.5,HEIGHT,-19.0),Vector3(7.6,HEIGHT,-19),Vector3(16.8,HEIGHT,-4),Vector3(16.8,HEIGHT,3.1)]:_prop(g,upper,"lamp",point)
 _lighthouse(g,upper);_warehouse(g,ground)
 for point in [Vector3(-4.7,.13,-1.5),Vector3(-3.0,.13,6.9),Vector3(-5.1,.13,5.9),Vector3(-14.0,.13,15.7)]:
  Geo.cylinder(ground,.105,.30,point,Color("e1bd50")).rotation.z=PI*.5
 _batch(ground);_batch(upper)
 var zones: Array=[]
 for spec in [["lower_quay","1F · 渔获码头",Rect2(-18,-20,27,40),0.0],["workshop","1F · 渔具工坊与桥下作业区",Rect2(9,-13,9,21),0.0],["east_plaza","1F · 东侧回港广场",Rect2(9,8,9,12),0.0],["north_pier","1F · 北栈桥",Rect2(-29,-8,11,4),0.0],["south_pier","1F · 南栈桥",Rect2(-29,7,11,4),0.0],["upper_back","2F · 灯塔海景步道",Rect2(-16,-20,34,7),HEIGHT],["upper_east","2F · 海风休息长廊",Rect2(9,-13,9,21),HEIGHT]]:
  var rect: Rect2=spec[2];zones.append({"id":spec[0],"name":spec[1],"rect":rect,"polygon":Shape.rectangle(rect),"height":spec[3],"center":Vector3(rect.get_center().x,spec[3],rect.get_center().y),"paths":[],"door_clear":[]})
 return {"level":level,"bounds":Vector2(60,44),"spawn":Vector3(-2.4,.04,2.0),"zones":zones,"exit":Vector3(12,0,18),"sample_exit":Vector3(16,0,18),"camera_size":40.0}

static func apply_lighting(atmosphere: Node3D,night: float) -> void:
 if atmosphere.game.location_id!="story_harbor":return
 var material: ShaderMaterial=atmosphere.game.shell.get_meta("harbor_water",null)
 if material:material.set_shader_parameter("night_weight",night)
 for lamp in atmosphere.lamps:
  if lamp.has_meta("harbor_lamp"):
   lamp.light_energy=lerpf(.08,.80,night)*float(lamp.get_meta("fixture_weight",1.0));lamp.shadow_enabled=false
   var glass: MeshInstance3D=lamp.get_parent().get_node_or_null("LanternGlass")
   if glass:glass.material_override.emission_energy_multiplier=lerpf(.03,1.6,night)

static func _batch(parent: Node3D) -> void:
 var groups: Dictionary={};var count:=0
 for node: MeshInstance3D in parent.find_children("*","MeshInstance3D",true,false):
  if not node.visible or not node.mesh or not node.material_override:continue
  var mesh: Mesh=node.mesh;var signature: String=str(mesh.get_instance_id())
  if mesh is CylinderMesh:signature="cylinder:"+str(snappedf(mesh.bottom_radius,.0001))+":"+str(snappedf(mesh.top_radius,.0001))+":"+str(snappedf(mesh.height,.0001))+":"+str(mesh.radial_segments)
  elif mesh is SphereMesh:signature="sphere:"+str(mesh.radius)+":"+str(mesh.height)+":"+str(mesh.radial_segments)+":"+str(mesh.rings)
  elif mesh is TorusMesh:signature="torus:"+str(mesh.inner_radius)+":"+str(mesh.outer_radius)+":"+str(mesh.rings)+":"+str(mesh.ring_segments)
  var key: String=signature+":"+str(node.material_override.get_instance_id())+":"+str(node.cast_shadow)
  if not groups.has(key):groups[key]=[]
  groups[key].append(node)
 for key in groups:
  var originals: Array=groups[key]
  if originals.size()<4:continue
  var first: MeshInstance3D=originals[0];var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.mesh=first.mesh;multimesh.instance_count=originals.size()
  var bounds:=AABB()
  for i in originals.size():
   var transform: Transform3D=parent.global_transform.affine_inverse()*originals[i].global_transform
   multimesh.set_instance_transform(i,transform);var box: AABB=transform*originals[i].get_aabb();bounds=box if i==0 else bounds.merge(box);originals[i].hide()
  multimesh.custom_aabb=bounds
  var instance:=MultiMeshInstance3D.new();instance.name="HarborStaticBatch_"+str(count);instance.multimesh=multimesh;instance.material_override=first.material_override;instance.cast_shadow=first.cast_shadow;parent.add_child(instance);count+=1
 parent.set_meta("static_batches",count)
