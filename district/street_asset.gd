@tool
extends "res://module_3d.gd"
## Reusable neighborhood modules, using the original room's material library.
@export var asset_kind := "bench"
const Decor = preload("res://district/decor_library.gd")
const DETAILED := {"bench":"curved_bench","noticeboard":"notice_easel","planter":"hydrangea_pot","flower_stand":"restaurant_herb_rack","outdoor_table":"restaurant_bistro_set","mailboxes":"mailbox_bank","parcel_locker":"parcel_station","recycling":"recycling_station","kiosk":"market_kiosk","bus_stop":"bus_shelter"}
const NAMES := {"bench":"街边长椅","planter":"蓝白花箱","tree":"街道小树","streetlamp":"港湾路灯","mailboxes":"住户信箱","bollard":"道路护柱","bus_stop":"鲸落港候车亭","bicycle":"蓝色自行车","kiosk":"街角报刊亭","stairs":"楼层阶梯","elevator":"公寓电梯","awning":"蓝白遮阳篷","noticeboard":"社区公告栏","hydrant":"消防水栓","flower_stand":"花店阶梯花架","parcel_locker":"蓝白包裹柜","recycling":"分类回收箱","outdoor_table":"街边双人桌","bike_rack":"自行车停放架","lifebuoy":"港湾救生圈","dinghy":"蓝湾小船","washer":"蓝白滚筒洗衣机","bathtub":"独立浴缸","vanity":"洗手台与镜子","shower":"玻璃淋浴间","towel_rack":"浴室毛巾架","clothesline":"阳台晾衣架"}
const FOOTPRINTS := {"bench":[150,50],"planter":[120,46],"tree":[54,34],"streetlamp":[22,20],"mailboxes":[174,30],"bollard":[20,18],"bus_stop":[260,72],"bicycle":[124,34],"kiosk":[168,90],"stairs":[160,140],"elevator":[186,28],"awning":[288,82],"noticeboard":[164,28],"hydrant":[40,28],"flower_stand":[130,86],"parcel_locker":[164,56],"recycling":[126,44],"outdoor_table":[226,62],"bike_rack":[184,46],"lifebuoy":[22,20],"dinghy":[114,146],"washer":[88,68],"bathtub":[198,86],"vanity":[118,54],"shower":[116,96],"towel_rack":[76,26],"clothesline":[182,28]}

func _ready() -> void:
 var nature=Models.new();nature.b=self
 module_id="district_"+asset_kind
 metadata={"name":NAMES.get(asset_kind,asset_kind),"layer":"object","category":"street","solid":asset_kind!="awning","footprint":FOOTPRINTS.get(asset_kind,[80,50])}
 if DETAILED.has(asset_kind):
  var detailed: Node3D=Decor.instance(DETAILED[asset_kind])
  if detailed != null:
   add_child(detailed)
   var hit: CollisionShape3D=detailed.get_node("Body/Collision")
   metadata["footprint"]=[hit.shape.size.x*96.0,hit.shape.size.z*96.0]
   return
 match asset_kind:
  "bench":
   for x in [-.63,.63]:
    box(Vector3(.08,.46,.52),Vector3(x,.23,0),EDGE)
    box(Vector3(.07,.72,.07),Vector3(x,.58,-.24),EDGE)
   for z in [-.20,-.067,.067,.20]:box(Vector3(1.55,.055,.115),Vector3(0,.49,z),WOOD)
   for y in [.69,.83,.97]:box(Vector3(1.55,.105,.055),Vector3(0,y,-.25),WOOD)
   _hit(Vector3(1.6,.65,.60),Vector3(0,.325,0))
  "planter":
   box(Vector3(1.2,.40,.48),Vector3(0,.20,0),IVORY)
   box(Vector3(1.27,.06,.54),Vector3(0,.40,0),SAGE)
   box(Vector3(1.1,.025,.38),Vector3(0,.44,0),Color("56655f"))
   for i in 7:
    var p:=Vector3(-.48+i*.16,.52+sin(i)*.035,0)
    cylinder(.014,.20,p,Color("739686"))
    nature.leaf(p+Vector3(-.055,.12,0),i*.73,.26,Color("81a99a"))
    nature.leaf(p+Vector3(.055,.14,0),i*.73+PI,.23,Color("6e927b"))
    pillow(Vector3(.065,.066,.064),p+Vector3(.02,.20,.07),Color("e9d3c2") if i%2==0 else Color("adc8db"))
   _hit(Vector3(1.2,.55,.48),Vector3(0,.275,0))
  "tree":
   cylinder(.49,.11,Vector3(0,.055,0),Color("b6c6c6"))
   cylinder(.11,1.5,Vector3(0,.8,0),Color("7c8c88"))
   for spec in [[Vector3(0,2.1,0),Vector3(1.5,1.35,1.4)],[Vector3(-.38,1.78,.15),Vector3(1.05,1.1,1.0)],[Vector3(.43,1.84,-.13),Vector3(1.0,1.14,1.0)]]:
    pillow(spec[1],spec[0],Color("7caa99"))
   _hit(Vector3(.55,1.6,.55),Vector3(0,.8,0))
  "streetlamp":
   cylinder(.14,.10,Vector3(0,.05,0),EDGE);cylinder(.046,2.65,Vector3(0,1.35,0),EDGE)
   box(Vector3(.66,.05,.055),Vector3(.27,2.63,0),EDGE)
   box(Vector3(.38,.12,.33),Vector3(.53,2.57,0),IVORY)
   led_box(Vector3(.30,.025,.26),Vector3(.53,2.5,0),Color("fff0cf"),.28)
   var light:=OmniLight3D.new();light.position=Vector3(.5,2.35,0);light.omni_range=4;light.light_energy=.4;light.light_color=Color("ffe5c0");add_child(light)
   _hit(Vector3(.20,1,.20),Vector3(0,.5,0))
  "mailboxes":
   box(Vector3(1.8,1.40,.25),Vector3(0,.95,0),EDGE)
   for row in 3:
    for col in 3:
     var p:=Vector3(-.59+col*.59,.49+row*.45,.15)
     box(Vector3(.55,.40,.055),p,IVORY if row%2==0 else SAGE)
     box(Vector3(.33,.018,.02),p+Vector3(0,.05,.041),EDGE)
     box(Vector3(.09,.065,.025),p+Vector3(.15,-.1,.04),BLUE)
   _hit(Vector3(1.85,1.5,.4),Vector3(0,.75,0))
  "bollard":
   cylinder(.08,.65,Vector3(0,.325,0),EDGE);cylinder(.085,.045,Vector3(0,.51,0),IVORY)
   _hit(Vector3(.19,.7,.19),Vector3(0,.35,0))
  "bus_stop":
   for x in [-1.25,1.25]:box(Vector3(.075,2.3,.075),Vector3(x,1.15,-.28),EDGE)
   box(Vector3(2.8,.14,1.05),Vector3(0,2.34,.08),BLUE)
   box(Vector3(2.55,1.8,.045),Vector3(0,1.36,-.30),Color("b6d3da"))
   box(Vector3(2.15,.065,.39),Vector3(0,.52,.12),IVORY)
   for x in [-.8,.8]:box(Vector3(.06,.52,.3),Vector3(x,.26,.10),EDGE)
   _hit(Vector3(2.6,.55,.7),Vector3(0,.275,0))
  "bicycle":
   for x in [-.52,.52]:
    var wheel:=TorusMesh.new();wheel.inner_radius=.24;wheel.outer_radius=.29;wheel.rings=24;wheel.ring_segments=8
    var n:=MeshInstance3D.new();n.mesh=wheel;n.material_override=material(EDGE);n.rotation.x=PI/2;n.position=Vector3(x,.31,0);add_child(n)
    for angle in [0,PI/3,PI*2/3]:box(Vector3(.50,.012,.012),n.position,IVORY).rotation.z=angle
   for ends in [[Vector3(-.52,.31,0),Vector3(0,.34,0)],[Vector3(0,.34,0),Vector3(-.17,.84,0)],[Vector3(-.17,.84,0),Vector3(-.52,.31,0)],[Vector3(-.17,.84,0),Vector3(.39,.80,0)],[Vector3(.39,.80,0),Vector3(0,.34,0)],[Vector3(.39,.8,0),Vector3(.52,.31,0)]]:_bar(ends[0],ends[1],.031,BLUE)
   box(Vector3(.25,.05,.16),Vector3(-.17,.88,0),EDGE);box(Vector3(.055,.04,.40),Vector3(.4,1.0,0),EDGE)
   _hit(Vector3(1.25,.8,.38),Vector3(0,.4,0))
  "kiosk":
   box(Vector3(1.5,1.45,.7),Vector3(0,.725,0),IVORY);box(Vector3(1.66,.14,.85),Vector3(0,1.48,0),BLUE)
   for row in 3:
    box(Vector3(1.42,.055,.28),Vector3(0,.45+row*.32,.49),EDGE)
    for col in 5:box(Vector3(.21,.27,.036),Vector3(-.55+col*.275,.61+row*.32,.42),Color("b4cddd") if col%2==0 else Color("eee1c4"))
   _hit(Vector3(1.7,1.6,1.0),Vector3(0,.8,.1))
  "stairs":
   for i in 7:box(Vector3(1.65,.14*(i+1),.28),Vector3(0,.07*(i+1),-.28*i),IVORY)
   for x in [-.86,.86]:
    for i in 4:cylinder(.025,1.05,Vector3(x,.65+i*.28,-i*.56),EDGE)
    _bar(Vector3(x,1.18,.08),Vector3(x,2.05,-1.8),.032,EDGE)
  "elevator":
   box(Vector3(1.9,2.55,.18),Vector3(0,1.275,0),EDGE)
   for side in [-1,1]:box(Vector3(.80,2.22,.055),Vector3(side*.415,1.17,.13),Color("b3c8d2"))
   box(Vector3(.15,.32,.07),Vector3(1.07,1.2,.04),IVORY);led_box(Vector3(.06,.065,.035),Vector3(1.07,1.24,.088),Color("75c9d7"),.35)
   _hit(Vector3(1.9,2.4,.23),Vector3(0,1.2,0))
  "awning":
   for i in 10:
    var roof:=box(Vector3(.3,.05,1.0),Vector3(-1.35+i*.30,0,0),IVORY if i%2==0 else BLUE);roof.rotation.x=.15
    box(Vector3(.30,.20,.045),Vector3(-1.35+i*.3,-.15,.49),IVORY if i%2==0 else BLUE)
  "noticeboard":
   box(Vector3(1.7,1.2,.08),Vector3(0,1.35,0),EDGE);box(Vector3(1.54,1.05,.04),Vector3(0,1.35,.062),Color("cbd5d0"))
   for i in 4:box(Vector3(.32,.40,.016),Vector3(-.56+i*.37,1.39,.094),IVORY if i%2==0 else Color("b8d6e2"))
   for x in [-.65,.65]:box(Vector3(.055,.8,.055),Vector3(x,.4,0),EDGE)
   _hit(Vector3(1.75,1.4,.23),Vector3(0,.7,0))
  "flower_stand":
   for level in 3:
    var z: float=-.30*level;var y: float=.23+.32*level
    box(Vector3(1.30,.055,.34),Vector3(0,y,z),WOOD)
    for x in [-.56,.56]:box(Vector3(.045,y,.045),Vector3(x,y/2,z),EDGE)
    for i in 4:
     var pos:=Vector3(-.45+i*.30,y+.12,z)
     cylinder(.10,.18,pos,IVORY if i%2==0 else SAGE)
     for n in 3:
      var a:=TAU*n/3
      nature.leaf(pos+Vector3(cos(a)*.065,.18,sin(a)*.065),a,.21,Color("80ac99"))
     pillow(Vector3(.095,.08,.10),pos+Vector3(0,.29,0),Color("e7c9b5") if (i+level)%2==0 else Color("b0cbdc"))
   _hit(Vector3(1.35,1.2,1.0),Vector3(0,.6,-.30))
  "parcel_locker":
   box(Vector3(1.65,1.90,.55),Vector3(0,.95,0),EDGE)
   for row in 4:
    for col in 3:
     var pos:=Vector3(-.52+col*.52,.25+row*.46,.3)
     box(Vector3(.48,.42,.035),pos,IVORY if col!=1 else SAGE)
     box(Vector3(.055,.075,.022),pos+Vector3(.14,0,.032),EDGE)
   led_box(Vector3(.26,.26,.035),Vector3(0,1.45,.344),Color("82baca"),.12)
   _hit(Vector3(1.65,1.9,.62),Vector3(0,.95,0))
  "recycling":
   for i in 3:
    var x: float=(i-1)*.43
    box(Vector3(.40,.69,.41),Vector3(x,.345,0),IVORY)
    box(Vector3(.43,.055,.45),Vector3(x,.73,0),[SAGE,BLUE,EDGE][i])
    box(Vector3(.20,.12,.025),Vector3(x,.58,.224),[SAGE,BLUE,EDGE][i])
   _hit(Vector3(1.3,.8,.45),Vector3(0,.4,0))
  "outdoor_table":
   cylinder(.045,.72,Vector3(0,.36,0),EDGE);cylinder(.28,.04,Vector3(0,.025,0),EDGE);cylinder(.50,.055,Vector3(0,.76,0),IVORY)
   for x in [-.9,.9]:
    cylinder(.23,.045,Vector3(x,.42,0),SAGE)
    for z in [-.13,.13]:
     for dx in [-.13,.13]:cylinder(.015,.42,Vector3(x+dx,.21,z),EDGE)
    box(Vector3(.41,.30,.045),Vector3(x,.68,-.17),SAGE)
   cylinder(.045,.12,Vector3(0,.84,0),BLUE)
   _hit(Vector3(2.3,.8,.65),Vector3(0,.4,0))
  "bike_rack":
   box(Vector3(1.9,.035,.45),Vector3(0,.025,0),EDGE)
   for x in [-.72,0,.72]:
    for z in [-.19,.19]:cylinder(.024,.55,Vector3(x,.3,z),SAGE)
    box(Vector3(.048,.048,.42),Vector3(x,.59,0),SAGE)
   _hit(Vector3(1.9,.6,.45),Vector3(0,.3,0))
  "lifebuoy":
   box(Vector3(.06,1.12,.06),Vector3(0,.56,0),EDGE)
   var ring:=TorusMesh.new();ring.inner_radius=.17;ring.outer_radius=.25;ring.rings=32;ring.ring_segments=10
   var n:=MeshInstance3D.new();n.mesh=ring;n.material_override=material(Color("dca780"));n.rotation.x=PI/2;n.position=Vector3(0,.79,.07);add_child(n)
   for p in [Vector3(0,1.0,.084),Vector3(0,.58,.084),Vector3(-.21,.79,.084),Vector3(.21,.79,.084)]:box(Vector3(.07,.07,.042),p,IVORY)
   _hit(Vector3(.20,1,.2),Vector3(0,.5,0))
  "dinghy":
   pillow(Vector3(1.16,.45,2.6),Vector3(0,.25,0),IVORY)
   pillow(Vector3(.91,.16,2.22),Vector3(0,.455,0),BLUE)
   for z in [-.60,.10,.72]:box(Vector3(.88,.075,.20),Vector3(0,.50,z),WOOD)
   for x in [-.60,.60]:pillow(Vector3(.16,.28,.17),Vector3(x,.22,0),SAGE)
   _bar(Vector3(-.6,.60,-.75),Vector3(.7,.52,.7),.020,EDGE)
   _hit(Vector3(1.1,.5,2.5),Vector3(0,.25,0))
  "washer":
   box(Vector3(.89,1.02,.76),Vector3(0,.51,0),IVORY)
   box(Vector3(.87,.20,.055),Vector3(0,.86,.403),Color("c7dce1"))
   var rim:=TorusMesh.new();rim.inner_radius=.21;rim.outer_radius=.27;rim.rings=32;rim.ring_segments=10
   var door:=MeshInstance3D.new();door.mesh=rim;door.material_override=material(EDGE);door.rotation.x=PI/2;door.position=Vector3(0,.46,.410);add_child(door)
   pillow(Vector3(.43,.43,.036),Vector3(0,.46,.43),Color("81afc1"))
   var knob:=cylinder(.045,.03,Vector3(.28,.86,.45),BLUE);knob.rotation.x=PI/2
   box(Vector3(.28,.057,.021),Vector3(-.2,.86,.447),EDGE)
   _hit(Vector3(.9,1.03,.79),Vector3(0,.515,0))
  "bathtub":
   box(Vector3(2.05,.12,.94),Vector3(0,.16,0),IVORY)
   for x in [-.96,.96]:box(Vector3(.14,.43,.94),Vector3(x,.40,0),IVORY)
   for z in [-.40,.40]:box(Vector3(2.05,.43,.14),Vector3(0,.40,z),IVORY)
   box(Vector3(1.78,.025,.65),Vector3(0,.37,0),Color("a4cbd7"))
   for x in [-.72,.72]:
    for z in [-.28,.28]:cylinder(.045,.10,Vector3(x,.05,z),EDGE)
   cylinder(.022,.26,Vector3(-.77,.70,-.32),EDGE);box(Vector3(.26,.035,.04),Vector3(-.66,.82,-.32),EDGE)
   _hit(Vector3(2.05,.63,.95),Vector3(0,.315,0))
  "vanity":
   box(Vector3(1.12,.8,.54),Vector3(0,.40,0),IVORY)
   box(Vector3(1.2,.065,.62),Vector3(0,.84,0),SAGE)
   pillow(Vector3(.73,.12,.40),Vector3(0,.9,0),IVORY);pillow(Vector3(.56,.025,.26),Vector3(0,.949,.015),Color("c4dbe0"))
   cylinder(.018,.18,Vector3(0,1.0,-.23),EDGE);box(Vector3(.025,.025,.14),Vector3(0,1.09,-.16),EDGE)
   box(Vector3(.02,.62,.025),Vector3(0,.4,.29),SAGE)
   box(Vector3(.84,.80,.035),Vector3(0,1.56,-.30),EDGE);box(Vector3(.75,.71,.020),Vector3(0,1.56,-.272),Color("aecdd7"))
   _hit(Vector3(1.2,.95,.66),Vector3(0,.475,0))
  "shower":
   box(Vector3(1.18,.09,1.12),Vector3(0,.055,0),IVORY)
   for x in [-.57,.57]:box(Vector3(.035,2.10,.035),Vector3(x,1.1,-.50),EDGE)
   box(Vector3(1.17,.035,.035),Vector3(0,2.16,-.5),EDGE)
   var glass:=StandardMaterial3D.new();glass.albedo_color=Color(.62,.81,.86,.27);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.roughness=.3;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
   box(Vector3(1.12,2.02,.018),Vector3(0,1.13,-.50),IVORY).material_override=glass
   box(Vector3(.018,2.02,1.04),Vector3(-.57,1.13,0),IVORY).material_override=glass
   cylinder(.017,1.34,Vector3(.40,1.18,-.45),EDGE);box(Vector3(.28,.025,.03),Vector3(.28,1.85,-.45),EDGE)
   cylinder(.1,.018,Vector3(.15,1.82,-.44),EDGE)
   _hit(Vector3(1.2,2.1,1.14),Vector3(0,1.05,0))
  "towel_rack":
   for x in [-.35,.35]:cylinder(.025,1.15,Vector3(x,.58,0),EDGE)
   for y in [.68,1.10]:box(Vector3(.74,.035,.035),Vector3(0,y,0),EDGE)
   for x in [-.18,.18]:box(Vector3(.29,.57,.025),Vector3(x,.79,.035),IVORY if x<0 else SAGE)
   _hit(Vector3(.78,1.15,.28),Vector3(0,.575,0))
  "clothesline":
   for x in [-.9,.9]:
    cylinder(.025,1.95,Vector3(x,.98,0),EDGE);box(Vector3(.40,.035,.035),Vector3(x,.05,0),EDGE)
   box(Vector3(1.84,.024,.025),Vector3(0,1.97,0),EDGE)
   for i in 4:
    var x: float=-.65+i*.43
    box(Vector3(.34,.70,.022),Vector3(x,1.51,.02),IVORY if i%2==0 else SAGE)
    for dx in [-.1,.1]:box(Vector3(.02,.05,.035),Vector3(x+dx,1.94,.026),BLUE)
   _hit(Vector3(1.9,1.95,.3),Vector3(0,.975,0))
  "hydrant":
   cylinder(.12,.57,Vector3(0,.285,0),Color("799baa"));cylinder(.16,.07,Vector3(0,.61,0),IVORY)
   box(Vector3(.4,.12,.14),Vector3(0,.4,0),BLUE)
   _hit(Vector3(.4,.65,.3),Vector3(0,.325,0))

func _hit(size: Vector3,pos: Vector3) -> void:
 var b:=StaticBody3D.new();var h:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=size;h.shape=s;h.position=pos;b.add_child(h);add_child(b)

func _bar(a: Vector3,b: Vector3,r: float,color: Color) -> void:
 var n:=cylinder(r,a.distance_to(b),(a+b)*.5,color)
 var axis: Vector3=(b-a).normalized();var x:=Vector3.FORWARD.cross(axis).normalized();var z:=x.cross(axis).normalized();n.basis=Basis(x,axis,z)
