extends RefCounted
## Original coastal salon: a shared letter table links service, reading and rest.
const Geo=preload("res://district/story_geometry.gd")
const Shape=preload("res://district/space_shape.gd")
const Action=preload("res://district/cafe_action.gd")
const Door=preload("res://district/interactive_door.gd")
const FLOOR=preload("res://assets/modern/shaders/cafe_floor.gdshader")
const ART=preload("res://assets/modern/shaders/cafe_art.gdshader")
const INK=Color("36585d")
const WOOD=Color("a77d56")
const CREAM=Color("e6dfc8")
const BRASS=Color("b8a168")
const CORAL=Color("c88775")
const SAGE=Color("a7c6bd")

static func _root(g,label: String,point: Vector3,yaw: float=0.0) -> Node3D:
 var node:=Node3D.new();node.name=label;node.position=point;node.rotation_degrees.y=yaw;g.world.add_child(node);return node

static func _sphere(parent: Node3D,point: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
 var node:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.5;mesh.height=1.;mesh.radial_segments=16;mesh.rings=8
 node.mesh=mesh;node.material_override=Geo.material(color);node.position=point;node.scale=size;parent.add_child(node);return node

static func _floor(parent: Node3D,size: Vector2,point: Vector3,kind: int) -> void:
 var node:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=size;node.mesh=plane;node.position=point
 var material:=ShaderMaterial.new();material.shader=FLOOR;material.set_shader_parameter("zone_kind",kind);node.material_override=material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node)

static func _art(parent: Node3D,size: Vector2,point: Vector3,motif: int=0) -> MeshInstance3D:
 var node:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=size;node.mesh=mesh;node.position=point
 var material:=ShaderMaterial.new();material.shader=ART;material.set_shader_parameter("motif",motif);node.material_override=material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node)
 return node

static func _plant(parent: Node3D,point: Vector3,scale_value: float=1.0) -> void:
 var root:=Node3D.new();root.position=point;root.scale=Vector3.ONE*scale_value;parent.add_child(root)
 Geo.cylinder(root,.25,.43,Vector3(0,.215,0),Color("d7c6a5"),.31)
 Geo.cylinder(root,.29,.045,Vector3(0,.44,0),Color("746a51"))
 for i in 7:
  var angle: float=i*TAU/7.;var top:=Vector3(cos(angle)*.26,.94+float(i%3)*.16,sin(angle)*.26)
  Geo.rod(root,Vector3(0,.4,0),top,.018,Color("657f58"))
  var leaf: MeshInstance3D=_sphere(root,top,Vector3(.27,.44,.12),Color("72946a") if i%2==0 else Color("8ea878"));leaf.rotation=Vector3(.28,angle,-.43)
 Geo.contact(parent,point+Vector3(0,.047,0),Vector2.ONE*.8*scale_value,.12)

static func _cup(parent: Node3D,point: Vector3,color: Color=CREAM) -> void:
 Geo.cylinder(parent,.125,.025,point+Vector3(0,.012,0),color)
 Geo.cylinder(parent,.079,.13,point+Vector3(0,.09,0),color,.09)
 Geo.cylinder(parent,.077,.004,point+Vector3(0,.158,0),Color("6b4936"))
 var node:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.037;torus.outer_radius=.064;torus.rings=12;torus.ring_segments=6
 node.mesh=torus;node.material_override=Geo.material(color);node.position=point+Vector3(.105,.095,0);node.rotation.x=PI*.5;parent.add_child(node)

static func _books(parent: Node3D,point: Vector3,count: int=7) -> void:
 var palette: Array[Color]=[Color("709297"),Color("b48b72"),Color("d6c493"),Color("7d9d86"),Color("58717d")]
 for i in count:
  var height: float=.28+float(i%3)*.05
  Geo.box(parent,Vector3(.11,height,.25),point+Vector3(i*.125,height*.5,0),palette[i%palette.size()],0,.007)
  Geo.box(parent,Vector3(.085,.016,.012),point+Vector3(i*.125,height*.75,.132),CREAM,0,.003)

static func _wall(g,a: Vector2,b: Vector2,window: bool=false,curtains: Action=null) -> void:
 var delta: Vector2=b-a;var length: float=delta.length()
 var root: Node3D=_root(g,"WindowBay" if window else "PaneledWall",Vector3((a.x+b.x)*.5,0,(a.y+b.y)*.5),-rad_to_deg(atan2(delta.y,delta.x)))
 if not window:Geo.box(root,Vector3(length,.2+2.10,.18),Vector3(0,2.18,0),SAGE,0,.025)
 Geo.box(root,Vector3(length,.88,.21),Vector3(0,.44,0),INK,0,.02)
 Geo.box(root,Vector3(length,.075,.28),Vector3(0,.93,.035),BRASS,2,.016)
 Geo.box(root,Vector3(length,.10,.26),Vector3(0,.06,.035),Color("2b464b"),0,.016)
 var panels: int=maxi(1,roundi(length/.9))
 for i in panels:
  var x: float=-length*.5+(i+.5)*length/panels
  Geo.box(root,Vector3(length/panels-.10,.55,.035),Vector3(x,.47,.125),Color("527777"),0,.018)
  Geo.box(root,Vector3(length/panels-.19,.45,.015),Vector3(x,.47,.15),Color("41676a"),0,.01)
 if window:
  var pane: MeshInstance3D=_art(root,Vector2(length-.10,2.24),Vector3(0,2.13,-.012),1 if length>3.5 else 2)
  var windows: Array=g.shell.get_meta("cafe_windows",[]);windows.append(pane.material_override);g.shell.set_meta("cafe_windows",windows)
  for x in [-length*.5,length*.5,0]:Geo.box(root,Vector3(.065,2.31,.14),Vector3(x,2.12,.04),CREAM,0,.013)
  for y in [1.03,2.20,3.24]:Geo.box(root,Vector3(length,.065,.17),Vector3(0,y,.04),CREAM,0,.013)
  # Curtains are separate from the painted sea pane and have no invisible collider.
  if curtains:
   var holder:=Node3D.new();curtains.add_child(holder);holder.global_transform=root.global_transform;holder.position.y=3.21
   for side in [-1.0,1.0]:
    var fabric:=Node3D.new();fabric.position.x=side*(length*.5-.24);holder.add_child(fabric);curtains.parts.append(fabric)
    for fold in 4:
     Geo.box(fabric,Vector3(.10,2.02,.10),Vector3((fold-1.5)*.098,-1.02,.17+sin(fold*1.2)*.035),Color("cfbba0") if fold%2 else CREAM,0,.025)
   Geo.box(root,Vector3(length+.09,.09,.10),Vector3(0,3.29,.16),BRASS,2,.018)
 else:
  Geo.box(root,Vector3(length,.12,.26),Vector3(0,3.27,.025),CREAM,0,.024)
 g._collision(root,Vector3(length,3.3,.20),Vector3(0,1.65,0))

static func _sofa(g,point: Vector3,width: float,color: Color,yaw: float=0.0) -> Node3D:
 var node: Node3D=_root(g,"UpholsteredSeat",point,yaw)
 for x in [-width*.38,width*.38]:
  for z in [-.30,.30]:Geo.cylinder(node,.055,.21,Vector3(x,.105,z),BRASS)
 Geo.box(node,Vector3(width,.28,.94),Vector3(0,.32,0),INK,0,.095)
 Geo.box(node,Vector3(width-.22,.21,.74),Vector3(0,.51,.065),color,0,.075)
 Geo.box(node,Vector3(width,.65,.22),Vector3(0,.77,-.37),color,0,.082)
 for x in [-width*.5+.08,width*.5-.08]:Geo.box(node,Vector3(.20,.42,.96),Vector3(x,.55,0),INK,0,.075)
 for x in [-width*.23,width*.23]:
  Geo.box(node,Vector3(.48,.45,.15),Vector3(x,.81,-.22),CREAM,0,.07).rotation.z=x*.12
 Geo.contact(g.shell,point+Vector3(0,.047,0),Vector2(width+1,1.8),.17)
 g._collision(node,Vector3(width,.95,.93),Vector3(0,.48,0));return node

static func _chair(g,point: Vector3,yaw: float=0.0,color: Color=SAGE) -> void:
 var node: Node3D=_root(g,"CafeChair",point,yaw)
 for x in [-.25,.25]:
  for z in [-.24,.24]:Geo.rod(node,Vector3(x,.05,z),Vector3(x*.85,.49,z*.8),.025,INK)
 Geo.box(node,Vector3(.63,.13,.60),Vector3(0,.52,0),color,0,.055)
 Geo.box(node,Vector3(.61,.40,.095),Vector3(0,.84,-.26),color,0,.032)
 for x in [-.26,.26]:Geo.rod(node,Vector3(x,.46,-.25),Vector3(x,1.02,-.29),.025,INK)
 Geo.contact(g.shell,point+Vector3(0,.046,0),Vector2(.9,.9),.12);g._collision(node,Vector3(.66,1.0,.64),Vector3(0,.5,0))

static func _round_table(g,point: Vector3,radius: float=.60,height: float=.56) -> Node3D:
 var node: Node3D=_root(g,"RoundTable",point)
 var top: MeshInstance3D=Geo.cylinder(node,radius,.085,Vector3(0,height,0),CREAM);top.mesh.radial_segments=48
 var band: MeshInstance3D=Geo.cylinder(node,radius*.96,.038,Vector3(0,height-.05,0),BRASS);band.mesh.radial_segments=48
 Geo.cylinder(node,.055,height-.10,Vector3(0,(height-.10)*.5,0),INK)
 Geo.cylinder(node,radius*.53,.065,Vector3(0,.045,0),INK)
 g._collision(node,Vector3(radius*1.8,height,radius*1.8),Vector3(0,height*.5,0));Geo.contact(g.shell,point+Vector3(0,.046,0),Vector2.ONE*radius*2.7,.14);return node

static func _shared_table(g) -> void:
 var node: Node3D=_root(g,"LetterIsland",Vector3(1.0,0,-.5))
 for x in [-1.15,1.15]:
  Geo.cylinder(node,.12,.71,Vector3(x,.36,0),INK)
  Geo.box(node,Vector3(.9,.09,.80),Vector3(x,.06,0),INK,0,.03)
 var top: MeshInstance3D=Geo.cylinder(node,1.0,.105,Vector3(0,.81,0),CREAM);top.scale.x=2.12;top.mesh.radial_segments=64
 var band: MeshInstance3D=Geo.cylinder(node,.985,.035,Vector3(0,.744,0),BRASS);band.scale.x=2.12;band.mesh.radial_segments=64
 for i in 4:
  var mat: MeshInstance3D=Geo.box(node,Vector3(.67,.012,.43),Vector3(-1.36+i*.9,.871,.08),Color("709a96"),0,.025);mat.rotation.y=(i-1.5)*.07
  _cup(node,Vector3(-1.43+i*.9,.885,.04),CREAM)
  Geo.box(node,Vector3(.27,.01,.19),Vector3(-1.18+i*.9,.89,-.25),Color("eeddb4"),0,.002).rotation.y=.18
 _plant(node,Vector3(.04,.87,-.37),.36)
 # A small lighthouse lamp gives the shared table its own silhouette.
 Geo.cylinder(node,.17,.045,Vector3(.02,.90,-.02),BRASS)
 Geo.cylinder(node,.10,.23,Vector3(.02,1.04,-.02),INK,.09)
 var lantern: MeshInstance3D=Geo.cylinder(node,.15,.20,Vector3(.02,1.25,-.02),Color("ead5a0"))
 var lamp_material:=StandardMaterial3D.new();lamp_material.albedo_color=Color("ead5a0");lamp_material.emission_enabled=true;lamp_material.emission=Color("c3a471");lamp_material.emission_energy_multiplier=.20;lantern.material_override=lamp_material
 for i in 4:
  var a: float=i*PI*.5;Geo.rod(node,Vector3(cos(a)*.14,1.14,sin(a)*.14-.02),Vector3(cos(a)*.14,1.36,sin(a)*.14-.02),.012,BRASS)
 Geo.cylinder(node,.19,.12,Vector3(.02,1.41,-.02),INK,.04)
 var glow:=OmniLight3D.new();glow.position=Vector3(.02,1.25,-.02);glow.omni_range=3.8;glow.light_color=Color("ffe6ba");glow.light_energy=.48;glow.set_meta("cafe_lamp",true);glow.set_meta("fixture_weight",.70);node.add_child(glow)
 g._collision(node,Vector3(4.10,.91,1.80),Vector3(0,.45,0));Geo.contact(g.shell,Vector3(1,.046,-.5),Vector2(5.2,2.8),.18)
 _chair(g,Vector3(-.3,0,1.0),0,CORAL);_chair(g,Vector3(2.05,0,1.0),0,SAGE)
 _chair(g,Vector3(-.3,0,-2.0),180,SAGE);_chair(g,Vector3(2.05,0,-2.0),180,CORAL)

static func _shelf(g,point: Vector3,width: float=3.2,height: float=1.08,yaw: float=0.0) -> Node3D:
 var node: Node3D=_root(g,"OpenBookPartition",point,yaw)
 for x in [-width*.5,0,width*.5]:Geo.box(node,Vector3(.065,height,.48),Vector3(x,height*.5,0),WOOD,1,.014)
 for y in [.12,height*.52,height]:Geo.box(node,Vector3(width+.10,.075,.52),Vector3(0,y,0),WOOD,1,.013)
 _books(node,Vector3(-width*.5+.12,.16,.06),8);_books(node,Vector3(.17,height*.56,.06),8)
 _plant(node,Vector3(-width*.3,height+.035,0),.48)
 Geo.box(node,Vector3(.58,.04,.30),Vector3(width*.26,height+.068,0),CREAM,0,.009)
 g._collision(node,Vector3(width,height,.52),Vector3(0,height*.5,0));Geo.contact(g.shell,point+Vector3(0,.046,0),Vector2(width+.9,1.3),.16);return node

static func _pendant(parent: Node3D,point: Vector3) -> void:
 Geo.rod(parent,point+Vector3(0,.10,0),point+Vector3(0,.73,0),.012,BRASS)
 Geo.cylinder(parent,.34,.27,point,INK,.13)
 var glow: MeshInstance3D=Geo.cylinder(parent,.27,.022,point-Vector3(0,.144,0),Color("f3df9b"))
 var material:=StandardMaterial3D.new();material.albedo_color=Color("f3df9b");material.emission_enabled=true;material.emission=Color("ead39d");material.emission_energy_multiplier=.35;glow.material_override=material
 var light:=OmniLight3D.new();light.position=point-Vector3(0,.16,0);light.omni_range=4.0;light.light_color=Color("ffe0a6");light.light_energy=.55;light.set_meta("cafe_lamp",true);light.set_meta("fixture_weight",.55);parent.add_child(light)

static func _bar(g) -> Action:
 var node: Node3D=_root(g,"FlutedCoffeeBar",Vector3(-5.7,0,-4.25))
 Geo.box(node,Vector3(5.1,.93,1.12),Vector3(0,.47,0),Color("739895"),0,.07)
 Geo.box(node,Vector3(5.3,.115,1.26),Vector3(0,1.01,0),CREAM,0,.045)
 for i in 29:Geo.box(node,Vector3(.065,.77,.048),Vector3(-2.44+i*.174,.47,.586),WOOD,1,.015)
 Geo.box(node,Vector3(5.05,.06,.06),Vector3(0,.14,.619),BRASS,2,.016)
 Geo.box(node,Vector3(1.16,.94,2.12),Vector3(-2.01,.47,1.45),Color("739895"),0,.07)
 Geo.box(node,Vector3(1.28,.115,2.15),Vector3(-2.01,1.01,1.45),CREAM,0,.035)
 for i in 12:Geo.box(node,Vector3(.04,.77,.065),Vector3(-1.408,.47,.43+i*.175),WOOD,1,.013)
 g._collision(node,Vector3(5.25,1.12,1.2),Vector3(0,.56,0));g._collision(node,Vector3(1.25,1.12,2.12),Vector3(-2.0,.56,1.44))
 Geo.contact(g.shell,Vector3(-5.7,.045,-4.25),Vector2(6.3,2.1),.16)
 # Equipment origin sits on the accessible side; model body rests on the bar.
 var coffee: Action=Action.new();coffee.position=Vector3(-4.65,0,-3.05);g.world.add_child(coffee);coffee.configure(g,"coffee","海盐拿铁 · 咖啡机")
 Geo.box(coffee,Vector3(1.05,.49,.58),Vector3(0,1.36,-1.12),INK,0,.06)
 Geo.box(coffee,Vector3(.92,.11,.45),Vector3(0,1.075,-.92),BRASS,2,.028)
 Geo.box(coffee,Vector3(.68,.12,.33),Vector3(0,1.60,-1.11),CREAM,0,.03)
 Geo.cylinder(coffee,.08,.23,Vector3(-.26,1.30,-.77),BRASS)
 coffee.lever=Node3D.new();coffee.lever.position=Vector3(.28,1.49,-.85);coffee.add_child(coffee.lever)
 Geo.rod(coffee.lever,Vector3.ZERO,Vector3(.29,0,.04),.025,BRASS)
 Geo.cylinder(coffee.lever,.041,.18,Vector3(.29,-.06,.04),WOOD)
 _cup(coffee,Vector3(.25,1.10,-.68),CREAM)
 coffee.cup=Geo.cylinder(coffee,.071,.012,Vector3(.25,1.259,-.68),Color("dfc7a2"));coffee.cup.scale.y=.1
 # Steam uses local coordinates relative to a marker immediately above the cup.
 var steam_holder:=Node3D.new();steam_holder.position=Vector3(0,.45,-1.10);coffee.add_child(steam_holder)
 for i in 5:
  var particle: MeshInstance3D=_sphere(steam_holder,Vector3(.25,.92,.42),Vector3(.105,.17,.105),CREAM)
  var material:=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(1,.97,.91,.12);particle.material_override=material
  particle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;coffee.steam.append(particle);particle.hide()
 for x in [-1.60,-1.14,-.68]:_cup(node,Vector3(x,1.08,.15),CREAM)
 _plant(node,Vector3(-2.07,1.07,2.06),.48)
 # Back counter, grinder, cakes and a menu card keep the work area readable.
 var back: Node3D=_root(g,"BackService",Vector3(-5.55,0,-6.25))
 Geo.box(back,Vector3(5.8,.87,.62),Vector3(0,.44,0),INK,0,.025);Geo.box(back,Vector3(5.91,.09,.73),Vector3(0,.92,0),WOOD,1,.024)
 for x in [-2.4,-1.6,-.8,0,.8,1.6,2.4]:Geo.box(back,Vector3(.55,.022,.035),Vector3(x,.74,.34),BRASS,2,.004)
 Geo.box(back,Vector3(.49,.53,.37),Vector3(-1.9,1.23,0),CREAM,0,.027)
 Geo.cylinder(back,.17,.20,Vector3(-1.9,1.59,0),Color("9a785a"))
 for i in 4:
  Geo.cylinder(back,.13,.06,Vector3(-.7+i*.32,1.04,.03),CREAM)
  _sphere(back,Vector3(-.7+i*.32,1.13,.03),Vector3(.17,.13,.14),CORAL)
 _books(back,Vector3(1.1,.98,0),8)
 _pendant(g.shell,Vector3(-6.5,2.62,-3.8));_pendant(g.shell,Vector3(-3.7,2.62,-3.8))
 for x in [-6.4,-4.9]:
  var stool: Node3D=_root(g,"BarStool",Vector3(x,0,-2.6));Geo.cylinder(stool,.29,.12,Vector3(0,.76,0),CORAL)
  for angle in [0.,PI*.5,PI,PI*1.5]:Geo.rod(stool,Vector3(cos(angle)*.26,.03,sin(angle)*.26),Vector3(cos(angle)*.19,.71,sin(angle)*.19),.024,INK)
  g._collision(stool,Vector3(.55,.86,.55),Vector3(0,.43,0))
 return coffee

static func _letter_box(g) -> Action:
 var action: Action=Action.new();action.position=Vector3(5.65,0,3.75);g.world.add_child(action);action.configure(g,"letter","漂流信笺 · 留言盒")
 Geo.box(action,Vector3(2.45,.73,.84),Vector3(0,.40,0),INK,0,.06)
 Geo.box(action,Vector3(2.54,.08,.94),Vector3(0,.82,0),WOOD,1,.025)
 for i in 6:
  var x: float=-.96+i*.384
  Geo.box(action,Vector3(.33,.22,.03),Vector3(x,.58,.44),Color("709895"),0,.013)
  Geo.box(action,Vector3(.19,.025,.015),Vector3(x,.58,.461),BRASS,2,.005)
 Geo.box(action,Vector3(.91,.24,.55),Vector3(0,.98,0),Color("a3835e"),1,.04)
 action.lid=Node3D.new();action.lid.position=Vector3(0,1.105,-.25);action.add_child(action.lid)
 Geo.box(action.lid,Vector3(.97,.055,.59),Vector3(0,0,.26),WOOD,1,.025)
 Geo.box(action.lid,Vector3(.30,.011,.03),Vector3(0,.033,.26),BRASS,2,.006)
 action.letter=Node3D.new();action.letter.position=Vector3(0,.59,0);action.add_child(action.letter)
 _art(action.letter,Vector2(.67,.46),Vector3.ZERO)
 for i in 3:Geo.box(action,Vector3(.28,.017,.19),Vector3(-.84, .90+i*.019,.10),CREAM,0,.004).rotation.y=-.12+i*.1
 _plant(action,Vector3(.90,.87,-.04),.40)
 Geo.cylinder(action,.10,.025,Vector3(-.83,.89,-.22),BRASS)
 Geo.rod(action,Vector3(-.83,.91,-.22),Vector3(-.83,1.22,-.22),.018,BRASS)
 Geo.cylinder(action,.15,.12,Vector3(-.83,1.27,-.22),INK,.055)
 var task:=OmniLight3D.new();task.position=Vector3(-.83,1.19,-.22);task.omni_range=3.1;task.light_color=Color("ffe6bc");task.light_energy=.42;task.set_meta("cafe_lamp",true);task.set_meta("fixture_weight",.52);action.add_child(task)
 g._collision(action,Vector3(2.5,.9,.87),Vector3(0,.45,0));Geo.contact(g.shell,Vector3(5.65,.046,3.75),Vector2(3.25,1.6),.17)
 action.restore_pose();return action

static func _clock(parent: Node3D) -> void:
 var root:=Node3D.new();root.position=Vector3(8.43,2.13,4.2);root.rotation.y=-PI*.5;parent.add_child(root)
 var rim: MeshInstance3D=Geo.cylinder(root,.48,.08,Vector3.ZERO,BRASS);rim.rotation.x=PI*.5;rim.mesh.radial_segments=48
 var face: MeshInstance3D=Geo.cylinder(root,.431,.02,Vector3(0,0,.051),CREAM);face.rotation.x=PI*.5;face.mesh.radial_segments=48
 for i in 12:
  var a: float=i*TAU/12.;Geo.box(root,Vector3(.018,.065,.014),Vector3(sin(a)*.35,cos(a)*.35,.07),INK,0,.003).rotation.z=-a
 Geo.rod(root,Vector3(0,0,.084),Vector3(.12,.18,.084),.014,INK)
 Geo.rod(root,Vector3(0,0,.085),Vector3(-.26,.06,.085),.010,INK)
 _sphere(root,Vector3(0,0,.09),Vector3(.06,.06,.025),CORAL)

static func build(g) -> Dictionary:
 var contour:=PackedVector2Array([Vector2(-9,-7),Vector2(5.6,-7),Vector2(8.6,-5.8),Vector2(10,-3.2),Vector2(10,.8),Vector2(8.6,2.4),Vector2(8.6,7),Vector2(-7.8,7),Vector2(-9,5.8)])
 if Geometry2D.is_polygon_clockwise(contour):contour.reverse()
 g.shell.set_meta("floor_contours",[contour]);g.shell.set_meta("floor_layout","tidal_cafe");g.shell.set_meta("layout_revision","tidal_cafe_v1");g.shell.set_meta("cafe_look",true);g.shell.set_meta("cafe_windows",[])
 Shape.slab(g,contour)
 var floor_node: MeshInstance3D=Shape.floor_mesh(contour,.026,"slate_tile");var floor_material:=ShaderMaterial.new();floor_material.shader=FLOOR;floor_node.material_override=floor_material;g.shell.add_child(floor_node)
 _floor(g.shell,Vector2(6.0,6.0),Vector3(-5.6,.032,-3.6),1)
 _floor(g.shell,Vector2(3.0,5.8),Vector3(7.6,.033,-1.1),1)
 _floor(g.shell,Vector2(5.4,4.4),Vector3(1.0,.037,-.5),2)
 _floor(g.shell,Vector2(4.5,3.7),Vector3(-4.6,.037,3.6),2)
 var curtains: Action=Action.new();curtains.position=Vector3(5.5,0,-.3);g.world.add_child(curtains);curtains.configure(g,"curtain","海景窗湾 · 遮阳帘")
 _wall(g,Vector2(-9,-7),Vector2(5.6,-7))
 var bay: Array[Vector2]=[Vector2(5.6,-7),Vector2(8.6,-5.8),Vector2(10,-3.2),Vector2(10,.8),Vector2(8.6,2.4)]
 for i in bay.size()-1:_wall(g,bay[i],bay[i+1],true,curtains)
 curtains.restore_pose()
 # Front walls are cut away, but the slab edge and physical boundary stay intact.
 for spec in [[Vector3(.18,.34,12.8),Vector3(-8.9,.12,-.6)],[Vector3(6.7,.34,.18),Vector3(-4.45,.12,6.88)],[Vector3(5.4,.34,.18),Vector3(5.8,.12,6.88)]]:
  Geo.box(g.shell,spec[0],spec[1],INK,0,.025)
 _wall(g,Vector2(8.6,2.4),Vector2(8.6,7),false)
 # Two small framed artworks and a distinct wall sign replace a wall of adverts.
 for x in [-.8,2.0]:
  Geo.box(g.shell,Vector3(2.15,1.24,.09),Vector3(x,2.17,-6.84),BRASS,2,.018)
  _art(g.shell,Vector2(2.01,1.1),Vector3(x,2.17,-6.781),0 if x<0 else 3)
 var sign: Label3D=g._sign("潮汐信笺\nCOFFEE & LETTERS",Vector3(-5.65,2.45,-6.77),38,CREAM);sign.pixel_size=.009;sign.outline_size=0
 var bar: Action=_bar(g);_shared_table(g)
 _sofa(g,Vector3(-5.9,0,4.10),2.75,Color("70928c"),0)
 _sofa(g,Vector3(-2.6,0,3.7),1.30,CORAL,90)
 var low: Node3D=_round_table(g,Vector3(-4.8,0,2.62),.69,.50);_cup(low,Vector3(-.19,.55,0));_books(low,Vector3(.0,.55,.12),3)
 _shelf(g,Vector3(-4.4,0,.38),3.3,1.12)
 _plant(g.shell,Vector3(-7.7,0,4.45),1.18)
 # Bay seating follows the faceted wall rather than filling the room centre.
 _sofa(g,Vector3(8.8,0,-1.4),2.75,Color("d0b68e"),-90)
 _sofa(g,Vector3(6.95,0,-5.22),2.12,Color("b8c8b2"),-23)
 var side: Node3D=_round_table(g,Vector3(6.95,0,-2.0),.66,.58);_cup(side,Vector3(.12,.63,.03));_plant(side,Vector3(-.22,.64,-.04),.30)
 _plant(g.shell,Vector3(8.85,0,1.43),1.18)
 _plant(g.shell,Vector3(4.40,0,-5.72),.96)
 _letter_box(g);_shelf(g,Vector3(8.15,0,4.15),2.2,1.45,-90)
 _clock(g.shell)
 var lamp: Node3D=_root(g,"BayReadingLamp",Vector3(8.08,0,.93))
 Geo.cylinder(lamp,.20,.06,Vector3(0,.04,0),INK)
 Geo.rod(lamp,Vector3(0,.05,0),Vector3(0,1.77,0),.025,BRASS)
 Geo.cylinder(lamp,.31,.34,Vector3(0,1.81,0),CREAM,.19)
 var warm:=OmniLight3D.new();warm.position=Vector3(0,1.66,0);warm.omni_range=4.3;warm.light_color=Color("ffdfb1");warm.light_energy=.60;warm.set_meta("cafe_lamp",true);warm.set_meta("fixture_weight",.75);lamp.add_child(warm)
 g._collision(lamp,Vector3(.36,1.65,.36),Vector3(0,.825,0));Geo.contact(g.shell,Vector3(8.08,.046,.93),Vector2(.7,.7),.12)
 # A small gold line gives the arrival area an intentional threshold.
 for x in [-.65,4.05]:Geo.box(g.shell,Vector3(.035,.015,2.3),Vector3(x,.048,5.6),BRASS,2,.003)
 var door:=Door.new();door.position=Vector3(1.70,0,6.68);g.world.add_child(door);door.configure(g,2.55,"salon_exit","潮汐信笺 · 玻璃门",2.35)
 for x in [.38,3.02]:Geo.box(g.shell,Vector3(.15,2.45,.20),Vector3(x,1.22,6.68),INK,0,.025)
 Geo.box(g.shell,Vector3(2.78,.16,.24),Vector3(1.70,2.47,6.68),INK,0,.025)
 # Leaf material is lighter than the old corridor doors and belongs to this room.
 g._bounds(Vector2(20.4,14.4))
 var zones: Array=[]
 for info in [["cafe_bar","海盐拿铁 · 咖啡吧",Rect2(-9,-7,6.4,6.3)],["cafe_island","潮汐信笺 · 分享桌",Rect2(-2.5,-3.4,7.9,5.4)],["cafe_lounge","慢读角 · 沙发书架",Rect2(-9,.1,6.5,6.9)],["cafe_bay","海景窗湾 · 阅读席",Rect2(5.4,-7,4.6,9.5)],["cafe_letters","漂流信 · 来客留言",Rect2(4.4,2.5,4.2,4.5)]]:
  var rect: Rect2=info[2];zones.append({"id":info[0],"name":info[1],"rect":rect,"center":Vector3(rect.get_center().x,0,rect.get_center().y),"paths":[],"door_clear":[]})
 return {"bounds":Vector2(20.4,14.4),"spawn":Vector3(1.7,0,4.6),"zones":zones,"exit":Vector3(1.7,0,6.0),"exit_door":door,"camera_size":19.8}

static func apply_lighting(atmosphere: Node3D,night: float) -> void:
 if str(atmosphere.game.location_id)!="tidal_cafe":return
 if not bool(atmosphere.game.shell.get_meta("cafe_look",true)):return
 var env: Environment=atmosphere.environment
 atmosphere.sun.light_energy=lerpf(.42,.12,night);atmosphere.sun.light_color=Color("fff0d4").lerp(Color("b9c8de"),night)
 var open_curtains: bool=bool(atmosphere.game.visited.get("tidal_cafe:curtain",false))
 atmosphere.sun.light_energy*=lerpf(1.04 if open_curtains else .94,1.0,night)
 atmosphere.sun.rotation_degrees=Vector3(-64,-30,0);atmosphere.sun.shadow_opacity=.68
 atmosphere.sun.shadow_bias=.12;atmosphere.sun.shadow_normal_bias=1.8;atmosphere.sun.shadow_blur=1.15
 env.ambient_light_energy=lerpf(.37,.30,night);env.ambient_light_color=Color("c3d3d1").lerp(Color("abbecb"),night);env.ambient_light_sky_contribution=.13
 env.background_color=Color("d4dfdd").lerp(Color("344958"),night)
 env.adjustment_enabled=atmosphere.effects;env.adjustment_brightness=1.0;env.adjustment_contrast=1.015;env.adjustment_saturation=1.015
 atmosphere.contact_shading.visible=false
 for pane: ShaderMaterial in atmosphere.game.shell.get_meta("cafe_windows",[]):pane.set_shader_parameter("night_weight",night)
 for light in atmosphere.lamps:
  if light.has_meta("cafe_lamp"):
   light.light_energy=lerpf(.10,.64,night)*float(light.get_meta("fixture_weight",.55));light.shadow_enabled=false
