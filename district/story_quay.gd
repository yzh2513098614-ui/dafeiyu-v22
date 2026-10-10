extends RefCounted
## Original harbor study based on the supplied screenshot's visual relationships.
const Geo=preload("res://district/story_geometry.gd")
const Shape=preload("res://district/space_shape.gd")
const PAVING=preload("res://assets/modern/shaders/story_paving.gdshader")
const WOOD=Color("b98d53")
const STEEL=Color("52646b")
const CURB=Color("c7cedc")

static func _ground(parent: Node3D,size: Vector2,point: Vector3,base: Color,joint: Color,kind: int=0,unit: Vector2=Vector2(1.15,1.15)) -> void:
 var mesh:=PlaneMesh.new();mesh.size=size
 var material:=ShaderMaterial.new();material.shader=PAVING
 material.set_shader_parameter("base_color",base);material.set_shader_parameter("joint_color",joint)
 material.set_shader_parameter("paving_kind",kind);material.set_shader_parameter("tile_size",unit)
 var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;node.position=point;parent.add_child(node)

static func build(g) -> Dictionary:
 var contour:=PackedVector2Array([Vector2(-7.5,-11),Vector2(12,-11),Vector2(12,11),Vector2(-7.5,11),Vector2(-7.5,5.5),Vector2(-11,5.5),Vector2(-11,3),Vector2(-7.5,3)])
 if Geometry2D.is_polygon_clockwise(contour):contour.reverse()
 g.shell.set_meta("floor_contours",[contour]);g.shell.set_meta("floor_layout","story_quay")
 g.shell.set_meta("layout_revision","story_quay_v1");g.shell.set_meta("story_look",true)
 Shape.slab(g,contour)
 _ground(g.shell,Vector2(19.5,22),Vector3(2.25,.025,0),Color("b59981"),Color("d5bda0"),0,Vector2(1.45,1.15))
 _ground(g.shell,Vector2(4.5,22),Vector3(2.75,.029,0),Color("858ba7"),Color("c5cadd"),1)
 _ground(g.shell,Vector2(6.25,22),Vector3(8.875,.028,0),Color("d7ba7f"),Color("e6d2a4"),2,Vector2(.85,.75))
 for x in [.15,5.35]:
  for z in range(-11,11):Geo.box(g.shell,Vector3(.42,.075,.985),Vector3(x,.035,z+.5),CURB,0,.025)
 for z in [-6.1,-.3,5.3]:
  _drain(g.shell,Vector3(-.4,.06,z));_drain(g.shell,Vector3(5.9,.06,z))
 # Water and a short wooden landing give the close view a foreground and depth.
 Geo.box(g.shell,Vector3(6.5,.14,24),Vector3(-10.6,-.85,0),Color("799dab"),0,.025)
 for i in 12:
  Geo.box(g.shell,Vector3(3.45,.12,.198),Vector3(-9.25,.015,3.12+i*.20),Color("96724f"),1,.018)
 for z in [3.12,5.38]:Geo.box(g.shell,Vector3(3.55,.22,.17),Vector3(-9.25,-.04,z),Color("735a46"),1)
 for z in [-8.6,-4.9,-1.2,7.1,10.4]:
  Geo.box(g.shell,Vector3(.45,.80,2.95),Vector3(-7.35,.36,z),Color("dddcd3"),0,.055)
  Geo.box(g.shell,Vector3(.53,.10,3.0),Vector3(-7.35,.81,z),Color("ece8dd"),0,.028)
 for z in [-6.8,-2.9,1.1,6.8,9.9]:_bollard(g,Vector3(-6.8,0,z))
 _bench(g,Vector3(6.6,0,-1.2),90);_bench(g,Vector3(6.6,0,2.1),90)
 _lamp(g,Vector3(7.1,0,.4))
 _net(g,Vector3(-3.8,0,-2.1),.62)
 _net(g,Vector3(-4.0,0,6.5),.58)
 _net(g,Vector3(-5.35,0,6.75),.47)
 _crate(g,Vector3(1.2,0,5.5),Color("437fba"),true)
 _crate(g,Vector3(1.2,.65,5.5),Color("4c8ac5"),true,false)
 _crate(g,Vector3(2.55,0,5.5),Color("c4b252"),true)
 _crate(g,Vector3(-4.1,0,-5.6),Color("5688aa"),false)
 _cart(g,Vector3(.7,0,6.8))
 _lifebuoy(g.shell,Vector3(-6.8,1.08,7.1))
 for position in [Vector3(-4.7,.13,-1.5),Vector3(-3.0,.13,6.9),Vector3(-5.1,.13,5.9)]:
  Geo.cylinder(g.shell,.105,.30,position,Color("e1bd50")).rotation.z=PI*.5
  Geo.cylinder(g.shell,.112,.035,position+Vector3(.15,0,0),Color("727957")).rotation.z=PI*.5
 g._bounds(Vector2(24,22))
 var zone: Dictionary={"id":"story_quay_walk","name":"海风码头 · 散步与渔获","rect":Rect2(-11,-11,23,22),"polygon":contour,"center":Vector3(-1,0,2),"paths":[],"door_clear":[]}
 return {"bounds":Vector2(24,22),"spawn":Vector3(-1.9,0,2.2),"zones":[zone],"exit":Vector3(-5.4,0,9.1),"camera_size":28.0,"supply":Vector3(-5.8,0,-7.8)}

static func _root(g,title: String,position: Vector3) -> Node3D:
 var node:=Node3D.new();node.name=title;node.position=position;g.world.add_child(node);return node

static func _drain(parent: Node3D,point: Vector3) -> void:
 Geo.box(parent,Vector3(.44,.027,.7),point,Color("6d7986"),2,.008)
 for z in range(7):Geo.box(parent,Vector3(.39,.014,.035),point+Vector3(0,.023,-.27+z*.09),Color("b0b8c1"),2,.006)

static func _bench(g,position: Vector3,angle: float) -> void:
 var node: Node3D=_root(g,"StoryBench",position);node.rotation_degrees.y=angle
 for x in [-1.12,1.12]:
  Geo.box(node,Vector3(.105,.46,.54),Vector3(x,.23,.02),STEEL,2)
  Geo.rod(node,Vector3(x,.45,-.29),Vector3(x,1.04,-.40),.065,STEEL)
  Geo.rod(node,Vector3(x,.65,.24),Vector3(x,.78,-.36),.05,STEEL)
  Geo.rod(node,Vector3(x,.40,.21),Vector3(x,.65,.24),.05,STEEL)
 for z in [-.21,-.055,.10,.255]:Geo.box(node,Vector3(2.65,.075,.14),Vector3(0,.48,z),WOOD,1,.022)
 for y in [.67,.85,1.03]:
  var plank: MeshInstance3D=Geo.box(node,Vector3(2.65,.155,.075),Vector3(0,y,-.33-(y-.67)*.13),WOOD,1,.022);plank.rotation.x=-.13
 Geo.contact(node,Vector3(0,.044,.01),Vector2(3.0,1.3),.19)
 g._collision(node,Vector3(2.76,1.1,.75),Vector3(0,.55,0))

static func _bollard(g,position: Vector3) -> void:
 var node: Node3D=_root(g,"StoryBollard",position)
 Geo.cylinder(node,.24,.11,Vector3(0,.055,0),Color("666a79"),.22)
 Geo.cylinder(node,.16,.50,Vector3(0,.34,0),Color("636a78"),.20)
 Geo.cylinder(node,.265,.10,Vector3(0,.63,0),Color("858a99"),.28)
 Geo.contact(node,Vector3(0,.043,0),Vector2(.92,.92),.17)
 g._collision(node,Vector3(.56,.73,.56),Vector3(0,.365,0))

static func _lamp(g,position: Vector3) -> void:
 var node: Node3D=_root(g,"StoryStreetLamp",position)
 Geo.cylinder(node,.22,.12,Vector3(0,.06,0),STEEL)
 Geo.cylinder(node,.064,3.8,Vector3(0,1.96,0),STEEL)
 Geo.rod(node,Vector3(0,3.78,0),Vector3(.6,3.78,0),.047,STEEL)
 Geo.box(node,Vector3(.55,.13,.32),Vector3(.63,3.76,0),Color("899298"),2)
 Geo.box(node,Vector3(.43,.025,.25),Vector3(.63,3.677,0),Color("ece4c5"))
 Geo.contact(node,Vector3(0,.044,0),Vector2(.8,.8),.15)
 g._collision(node,Vector3(.26,3.9,.26),Vector3(0,1.95,0))
 var lamp:=OmniLight3D.new();lamp.position=Vector3(.63,3.57,0);lamp.omni_range=5;lamp.light_color=Color("ffdea3");lamp.light_energy=.42;node.add_child(lamp)

static func _net(g,position: Vector3,radius: float) -> void:
 var node: Node3D=_root(g,"StoryFishingNet",position)
 var rim:=TorusMesh.new();rim.inner_radius=radius-.025;rim.outer_radius=radius+.025;rim.rings=24;rim.ring_segments=6
 for y in [.08,.42]:
  var ring:=MeshInstance3D.new();ring.mesh=rim;ring.position.y=y;ring.material_override=Geo.material(Color("447b94"));node.add_child(ring)
 for i in 22:
  var a: float=i*TAU/22;var b: float=(i+4)*TAU/22
  Geo.rod(node,Vector3(cos(a)*radius,.08,sin(a)*radius),Vector3(cos(b)*radius,.42,sin(b)*radius),.013,Color("426a83"))
  Geo.rod(node,Vector3(cos(a)*radius,.42,sin(a)*radius),Vector3(cos(b)*radius,.08,sin(b)*radius),.013,Color("426a83"))
 Geo.contact(node,Vector3(0,.044,0),Vector2.ONE*radius*2.8,.21)
 g._collision(node,Vector3(radius*2,.48,radius*2),Vector3(0,.24,0))

static func _crate(g,position: Vector3,color: Color,fish: bool,solid: bool=true) -> void:
 var node: Node3D=_root(g,"StoryFishCrate",position)
 Geo.box(node,Vector3(1.13,.08,.79),Vector3(0,.065,0),color,0,.022)
 for z in [-.38,.38]:
  Geo.box(node,Vector3(1.14,.10,.065),Vector3(0,.52,z),color.lightened(.08),0,.018)
  Geo.box(node,Vector3(1.14,.07,.065),Vector3(0,.16,z),color)
  for x in range(8):Geo.box(node,Vector3(.075,.30,.06),Vector3(-.48+x*.137,.33,z),color)
 for x in [-.54,.54]:
  Geo.box(node,Vector3(.075,.50,.80),Vector3(x,.30,0),color,0,.022)
  Geo.box(node,Vector3(.025,.07,.26),Vector3(x*1.04,.44,0),color.darkened(.28),0,.008)
 if fish:
  for i in 6:
   var point:=Vector3(-.35+(i%3)*.32,.34+(i%2)*.045,-.16+floori(i/3.0)*.28)
   var body:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.17;sphere.height=.34;sphere.radial_segments=12;sphere.rings=6
   var fish_root:=Node3D.new();fish_root.position=point;fish_root.rotation.y=(i%3)*.43;node.add_child(fish_root)
   body.mesh=sphere;body.scale=Vector3(1.5,.45,.60)
   body.material_override=Geo.material(Color("cfdecd") if i%2==0 else Color("e6ae9d"));fish_root.add_child(body)
   Geo.box(fish_root,Vector3(.13,.035,.16),Vector3(.23,.015,0),Color("9db9c3"),0,.018).rotation.y=.6
   Geo.box(fish_root,Vector3(.23,.01,.042),Vector3(0,.077,0),Color("91b7c8") if i%2==0 else Color("d68779"),0,.006)
   for side in [-1.0,1.0]:Geo.cylinder(fish_root,.018,.018,Vector3(-.14,.045,side*.081),Color("3f5364"))
 Geo.contact(node,Vector3(0,.044-position.y,0),Vector2(1.7,1.25),.20)
 if solid:g._collision(node,Vector3(1.15,.61,.85),Vector3(0,.305,0))

static func _cart(g,position: Vector3) -> void:
 var node: Node3D=_root(g,"StoryHarborCart",position)
 Geo.box(node,Vector3(1.72,.10,1.12),Vector3(0,.29,0),Color("94a0aa"),2,.025)
 for x in [-.68,.68]:
  for z in [-.39,.39]:Geo.cylinder(node,.14,.09,Vector3(x,.16,z),Color("566175")).rotation.z=PI*.5
 for x in [-.76,.76]:Geo.rod(node,Vector3(x,.33,-.47),Vector3(x,1.07,-.58),.04,Color("8b98a3"))
 Geo.rod(node,Vector3(-.76,1.07,-.58),Vector3(.76,1.07,-.58),.045,Color("8b98a3"))
 Geo.contact(node,Vector3(0,.044,0),Vector2(2.1,1.6),.17)
 g._collision(node,Vector3(1.75,.8,1.2),Vector3(0,.40,0))

static func _lifebuoy(parent: Node3D,position: Vector3) -> void:
 var mesh:=TorusMesh.new();mesh.inner_radius=.24;mesh.outer_radius=.38;mesh.rings=32;mesh.ring_segments=8
 var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=Geo.material(Color("e8dfc4"));node.position=position;node.rotation.z=PI*.5;parent.add_child(node)
 for z in [-.29,.29]:Geo.box(parent,Vector3(.15,.13,.14),position+Vector3(0,0,z),Color("c97860"),0,.018)

static func apply_lighting(atmosphere: Node3D,night: float) -> void:
 if str(atmosphere.game.location_id) not in ["story_quay","story_harbor"]:return
 if not bool(atmosphere.game.shell.get_meta("story_look",true)):return
 var environment: Environment=atmosphere.environment
 atmosphere.sun.light_energy=lerpf(.46,.10,night)
 atmosphere.sun.light_color=Color("fff0da").lerp(Color("a9b8e1"),night)
 atmosphere.sun.rotation_degrees=Vector3(-54,-38,0);atmosphere.sun.shadow_opacity=.88
 atmosphere.sun.shadow_bias=.12;atmosphere.sun.shadow_normal_bias=1.8;atmosphere.sun.shadow_blur=1.1
 environment.ambient_light_energy=lerpf(.32,.25,night)
 environment.ambient_light_color=Color("c4c9e8").lerp(Color("93a7d1"),night)
 environment.ambient_light_sky_contribution=.15
 environment.adjustment_enabled=atmosphere.effects
 environment.adjustment_brightness=1.008;environment.adjustment_contrast=1.0;environment.adjustment_saturation=1.025
 environment.background_color=Color("c8d9df").lerp(Color("233346"),night)
 # Painted ground contact supplies local softness without outlining every edge.
 atmosphere.contact_shading.visible=false
