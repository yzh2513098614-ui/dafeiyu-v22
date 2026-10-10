extends RefCounted
## A single continuous neighborhood. Doorways are open vestibules in real solids.
const FLOOR_HEIGHT:=3.15
const WALL:=Color("d9e2df")
const TRIM:=Color("f1f0e7")
const NAVY:=Color("4b687e")
const GLASS:=Color("90b9c5")
const WALK:=Color("d2dedf")
const Models=preload("res://environment_models.gd")
## 大地图上的货箱复用「室内容器」那套（真实铰链开合 + 各自独立的战利品库存）。
## 只是把 _container() / _wire_loot() 拿来用，不去改 container_rooms.gd 的任何逻辑。
const ContainerRooms=preload("res://district/container_rooms.gd")

static func build(g) -> Dictionary:
 var b=g._builder(g.shell)
 # The extended southern block houses three new walkable public buildings.
 b.box(Vector3(132,.28,116),Vector3(0,-.17,5),Color("80969d"))
 b.box(Vector3(130.8,.04,114.8),Vector3(0,-.009,5),WALK)
 _roads(g,b)
 # 东港仓储带自己的路：一条南北向的带内街道 + 一条从老街区接过来的横路。
 # 带内街道放在两列建筑中间（x=55），两列的门都朝它开。
 _lane(b,Vector2(55,-44),Vector2(55,44),5.0)
 _lane(b,Vector2(41,0),Vector2(55,0),6.0)
 var buildings: Array=[
  {"id":"apt","name":"云湾公寓","center":Vector3(-29,0,-22),"width":16.0,"depth":12.0,"floors":3,"height":3.35,"angle":0.0,"tint":Color("dce4df"),"target":"apt_1","detail":"住户生活 · 1—3F","kind":"apartment"},
  {"id":"community","name":"潮汐社区馆","center":Vector3(-10,0,-22),"width":13.0,"depth":11.0,"floors":2,"height":3.55,"angle":90.0,"tint":Color("c7dcd6"),"target":"community_1","detail":"阅览与共享 · 1—2F","kind":"community"},
  {"id":"inn","name":"海风旅舍","center":Vector3(24,0,-23),"width":15.0,"depth":11.0,"floors":3,"height":3.05,"angle":0.0,"tint":Color("d4e1e9"),"target":"inn_1","detail":"大厅与客房 · 1—3F","kind":"inn"},
  {"id":"bakery","name":"晨光烘焙","center":Vector3(34,0,-7),"width":7.0,"depth":8.0,"floors":1,"height":3.60,"angle":-90.0,"tint":Color("e6dfd0"),"kind":"shop"},
  {"id":"florist","target":"garden","name":"青柠花房","center":Vector3(-35,0,16),"width":6.0,"depth":8.0,"floors":1,"height":3.05,"angle":0.0,"tint":Color("c8dcd3"),"kind":"flower"},
  {"id":"cafe","name":"潮汐咖啡","center":Vector3(-29,0,-3.5),"width":11.0,"depth":10.0,"floors":2,"height":3.05,"angle":90.0,"tint":Color("dbe5e0"),"kind":"cafe"},
  {"id":"market","target":"market","name":"鲸邮便利铺","center":Vector3(13,0,-1.5),"width":8.0,"depth":8.0,"floors":1,"height":3.35,"angle":0.0,"tint":Color("ccdde6"),"kind":"market"},
  {"id":"workshop","target":"music_1","detail":"演出 / 录音 / 试听 · 1—2F","name":"蓝鲸音乐馆","center":Vector3(-10.5,0,22),"width":8.0,"depth":11.0,"floors":2,"height":3.50,"angle":-90.0,"tint":Color("bdcdd9"),"kind":"music"},
  {"id":"gallery","target":"gallery","name":"白帆艺廊","center":Vector3(-32,0,28),"width":12.0,"depth":6.0,"floors":1,"height":4.15,"angle":180.0,"tint":Color("e1e6e4"),"kind":"gallery"},
  {"id":"bookshop","name":"漂流书店","center":Vector3(-24,0,18),"width":8.0,"depth":7.0,"floors":2,"height":3.0,"angle":0.0,"tint":Color("d6dfd5"),"kind":"bookshop"},
  {"id":"office","target":"obs_1","detail":"海洋 / 星空 / 天象 · 1—3F","name":"潮汐观测站","center":Vector3(29,0,23),"width":14.0,"depth":10.0,"floors":3,"height":3.45,"angle":-90.0,"tint":Color("c6d5dd"),"kind":"observatory"},
  {"id":"studio","name":"蓝鲸手作室","center":Vector3(11,0,22),"width":10.0,"depth":10.0,"floors":2,"height":3.20,"angle":180.0,"tint":Color("d7e0dc"),"kind":"studio"},
  {"id":"restaurant","name":"海蓝餐厅","center":Vector3(-33,0,45),"width":15.0,"depth":9.0,"floors":2,"height":3.75,"angle":0.0,"tint":Color("e2dccf"),"target":"restaurant_1","detail":"1F 餐厅 / 2F 包间露台 / B1 后勤暗室","kind":"restaurant"},
  {"id":"school","name":"海湾学校","center":Vector3(-12,0,45),"width":16.0,"depth":10.0,"floors":2,"height":3.40,"angle":0.0,"tint":Color("ccdcd7"),"target":"school_1","detail":"教室 / 图书 / 科学实验 · 1—2F","kind":"school"},
  {"id":"hospital","name":"海湾医院","center":Vector3(20,0,45),"width":17.0,"depth":10.0,"floors":2,"height":3.55,"angle":0.0,"tint":Color("d5e1e5"),"target":"hospital_1","detail":"门诊 / 药房 / 病房 · 1—2F","kind":"hospital"}]
 # ── 东港仓储带（2026-10-03 素材包搭的那批地点，现在是**地图上真实存在的建筑**）──
 # 带内街道在 x=52：西列（x=46）门朝东、东列（x=58）门朝西，两列的门都开向同一条街。
 # angle=90 → 局部 +z（正门）转到世界 +x；angle=-90 → 转到 -x。
 # 每一栋都带 target，所以 _building() 会开出可走的中央门洞并生成传送点 ——
 # 和街区里那三栋可进入的主楼同一套机制，不是"只存在于图鉴里的传送点"。
 var belt: Array=[
  # 西列（x=48，门朝东）
  {"id":"belt_depot","name":"港湾补给仓","center":Vector3(48,0,-37.5),"width":9.0,"depth":8.0,"floors":1,"height":4.20,"angle":90.0,"tint":Color("b8c4c9"),"target":"depot","detail":"货笼 / 信号柜 / 潜水装备箱 · 按 E 开合","kind":"market"},
  {"id":"belt_archive","name":"潮汐档案馆","center":Vector3(48,0,-22.5),"width":9.0,"depth":8.0,"floors":2,"height":3.60,"angle":90.0,"tint":Color("ced6d2"),"target":"archive","detail":"回字形环廊 · 能绕一圈走回原地","kind":"bookshop"},
  {"id":"belt_quarantine","name":"分区检疫所","center":Vector3(48,0,-7.5),"width":9.0,"depth":8.0,"floors":1,"height":3.80,"angle":90.0,"tint":Color("cdd5d8"),"target":"quarantine","detail":"室内四道隔断 · 走到门洞才知道后面","kind":"office"},
  {"id":"belt_hub","name":"中央枢纽站","center":Vector3(48,0,7.5),"width":9.0,"depth":8.0,"floors":2,"height":3.80,"angle":90.0,"tint":Color("c3d2cd"),"target":"hub","detail":"十字形平面 · 中央大厅四个方向","kind":"community"},
  {"id":"belt_vault","name":"港湾保险库","center":Vector3(48,0,22.5),"width":9.0,"depth":8.0,"floors":1,"height":4.60,"angle":90.0,"tint":Color("d3c9b4"),"target":"vault","detail":"L 形平面 · 东翼要绕过拐角","kind":"office"},
  {"id":"belt_spares","name":"备件长库","center":Vector3(48,0,37.5),"width":9.0,"depth":8.0,"floors":1,"height":4.00,"angle":90.0,"tint":Color("b6c0c6"),"target":"spares","detail":"梳形平面 · 24 米长脊 + 四个侧龛","kind":"market"},
  # 东列（x=62，门朝西）
  {"id":"belt_cold","name":"后厨冷藏间","center":Vector3(62,0,-37.5),"width":9.0,"depth":8.0,"floors":1,"height":3.60,"angle":-90.0,"tint":Color("c9d6da"),"target":"coldstore","detail":"双门冷藏柜 / 存货抽屉 / 保险柜","kind":"shop"},
  {"id":"belt_lab","name":"地下实验区","center":Vector3(62,0,-22.5),"width":9.0,"depth":8.0,"floors":2,"height":3.70,"angle":-90.0,"tint":Color("bcc8cd"),"target":"lab","detail":"U 形平面 · 围着中央中庭","kind":"studio"},
  {"id":"belt_customs","name":"港口海关查验厅","center":Vector3(62,0,-7.5),"width":9.0,"depth":8.0,"floors":1,"height":4.40,"angle":-90.0,"tint":Color("c6ced1"),"target":"customs","detail":"T 形平面 · 支廊在正中","kind":"office"},
  {"id":"belt_weather","name":"山地气象站","center":Vector3(62,0,7.5),"width":9.0,"depth":8.0,"floors":2,"height":3.90,"angle":-90.0,"tint":Color("bcd0d8"),"target":"weather","detail":"Z 形平面 · 通道先偏左再偏右","kind":"observatory"},
  # 潮间带是室外露天的，不可能是「一栋楼」。这里放的是**通往滩地的观潮台**（海边咖啡那种），
  # 涨落潮两个状态共用这一个入口，进去之后按 E 换潮位。
  {"id":"belt_tidal","name":"潮间带观潮台","center":Vector3(62,0,22.5),"width":9.0,"depth":8.0,"floors":1,"height":3.40,"angle":-90.0,"tint":Color("d8d2bd"),"target":"tidal_high","detail":"通往潮间滩地 · 进门后按 E 换潮位","kind":"cafe"},
  # 最后一格不空着：放一栋**没有 target 的封闭门脸**（和街区里的晨光烘焙、漂流书店同类）。
  # 一排全是可进入的门洞反而不像街区，混一栋「进不去的」才像。
  {"id":"belt_yard","name":"东港值守站","center":Vector3(62,0,37.5),"width":9.0,"depth":8.0,"floors":1,"height":3.40,"angle":-90.0,"tint":Color("c4c9c6"),"kind":"shop"}]
 for extra in belt:
  buildings.append(extra)
 var entrances: Array=[]
 var zones: Array=[]
 for data in buildings:
  var entrance: Dictionary=_building(g,data)
  if not entrance.is_empty():entrances.append(entrance)
  var c: Vector3=data.center
  zones.append({"id":str(data.id),"name":str(data.name),"rect":_building_footprint(data),"center":c})
 _furnish(g)
 _plaza(g,b)
 _containers(g)
 entrances.append_array(preload("res://district/courtyard_scenes.gd").city_gates(g))
 zones.append({"id":"east_square","name":"海风口袋广场","rect":Rect2(24,-1,14,12),"center":Vector3(31,0,5)})
 zones.append({"id":"flower_court","name":"花房小院","rect":Rect2(-39,20.4,10,4.4),"center":Vector3(-34,0,22.6)})
 zones.append({"id":"main_street","name":"鲸落大道","rect":Rect2(-4.5,-31,9,62),"center":Vector3(0,0,0)})
 zones.append({"id":"north_street","name":"海风支街","rect":Rect2(-41,-15.25,82,5.5),"center":Vector3(0,0,-12.5)})
 zones.append({"id":"south_street","name":"蓝湾弯街","rect":Rect2(-40,3,47,8),"center":Vector3(-16.5,0,7)})
 zones.append({"id":"east_belt","name":"东港仓储带","rect":Rect2(42,-48,24,96),"center":Vector3(54,0,0)})
 zones.append({"id":"south_civic","name":"南港公共街","rect":Rect2(-44,39,83,18),"center":Vector3(-2.5,0,48)})
 g._bounds(Vector2(132,116))
 return {"bounds":Vector2(132,116),"spawn":Vector3(0,0,8),"camera_size":118.0,"entrances":entrances,"zones":zones}

static func _roads(g,b) -> void:
 # A wide main spine, a narrower north street and a bent southern lane form unequal blocks.
 _lane(b,Vector2(0,-31),Vector2(0,54),9.0)
 _lane(b,Vector2(-40,-12.5),Vector2(40,-12.5),5.5)
 _lane(b,Vector2(-40,7),Vector2(8,7),8.0)
 _lane(b,Vector2(8,7),Vector2(21,7),7.0)
 _lane(b,Vector2(21,7),Vector2(21,13),6.0)
 _lane(b,Vector2(21,13),Vector2(40,13),6.0)
 _lane(b,Vector2(21,13),Vector2(21,30),6.0)
 _lane(b,Vector2(-19,-12.5),Vector2(-19,7),6.0)
 _lane(b,Vector2(23,-12.5),Vector2(23,7),5.5)
 _lane(b,Vector2(-17,13),Vector2(21,13),5.0)
 _lane(b,Vector2(-17,13),Vector2(-17,29),4.5)
 _lane(b,Vector2(-43,36),Vector2(39,36),5.0)
 _lane(b,Vector2(-43,54),Vector2(39,54),5.2)
 # Small paving patches, with different retreats instead of equal building lots.
 b.box(Vector3(11,.025,4),Vector3(-28,.024,-13.75),Color("c6d6d5"))
 b.box(Vector3(10,.025,3.6),Vector3(24,.023,-15.4),Color("cad8d6"))
 for stripe in range(7):
  b.box(Vector3(.40,.015,2.7),Vector3(-3.2+stripe*1.05,.072,2.4),TRIM)
  b.box(Vector3(2.3,.015,.38),Vector3(7.4,.071,4.1+stripe*.94),TRIM)
 var sign=g._sign("鲸落大道",Vector3(0,.085,-2.0),54,Color("cfe0df"));sign.rotation_degrees.x=-90

static func _lane(b,start: Vector2,finish: Vector2,width: float) -> void:
 var delta: Vector2=finish-start
 var center: Vector2=(start+finish)/2
 var road=b.box(Vector3(delta.length(),.045,width),Vector3(center.x,.022,center.y),Color("738996"))
 road.rotation.y=-atan2(delta.y,delta.x)
 var direction: Vector2=delta.normalized()
 for step in range(1,int(delta.length()/4)):
  var p: Vector2=start+direction*step*4.0
  var mark=b.box(Vector3(1.35,.007,.055),Vector3(p.x,.051,p.y),Color("dce6df"))
  mark.rotation.y=road.rotation.y

static func _building(g,data: Dictionary) -> Dictionary:
 var shell:=Node3D.new();shell.name="Building_"+str(data.id);shell.position=data.center;shell.rotation_degrees.y=float(data.angle);g.shell.add_child(shell)
 var b=g._builder(shell)
 var w: float=data.width;var d: float=data.depth;var floors: int=data.floors
 var level_height: float=data.get("height",FLOOR_HEIGHT)
 var h: float=floors*level_height;var front: float=d/2
 var tint: Color=data.tint;var is_open: bool=data.has("target")
 var opening: float=2.8 if is_open else 1.8
 var vestibule: float=1.65
 var wall_surface=load("res://district/wall_surfaces.gd")
 var wall_axis: Vector3=Basis(Vector3.UP,deg_to_rad(float(data.angle)))*Vector3.RIGHT
 var facade_material: ShaderMaterial=wall_surface.material(wall_surface.BUILDINGS[str(data.kind)],wall_axis,true,tint)
 # The rear core and flanking wings leave a genuinely walkable central doorway.
 b.box(Vector3(w,h,d-vestibule),Vector3(0,h/2,-vestibule/2),tint).material_override=facade_material
 var wing: float=(w-opening)/2
 for side in [-1.0,1.0]:
  b.box(Vector3(wing,h,vestibule),Vector3(side*(opening+wing)/2,h/2,front-vestibule/2),tint).material_override=facade_material
 b.box(Vector3(opening,h-2.65,vestibule),Vector3(0,2.65+(h-2.65)/2,front-vestibule/2),tint).material_override=facade_material
 g._collision(shell,Vector3(w,h,d-vestibule),Vector3(0,h/2,-vestibule/2))
 for side in [-1.0,1.0]:g._collision(shell,Vector3(wing,h,vestibule),Vector3(side*(opening+wing)/2,h/2,front-vestibule/2))
 if not is_open:
  # Street-scene shops are closed facades, distinct from the three explorable buildings.
  b.box(Vector3(opening,2.65,.09),Vector3(0,1.325,front-.14),GLASS.darkened(.12))
  g._collision(shell,Vector3(opening,2.65,.20),Vector3(0,1.325,front-.12))
 else:
  b.box(Vector3(opening-.08,.04,vestibule),Vector3(0,.015,front-vestibule/2),Color("e8e7da"))
  b.box(Vector3(opening-.2,.045,.6),Vector3(0,.055,front-.45),Color("8aa8af"))
  b.led_box(Vector3(opening-.25,.06,.10),Vector3(0,2.49,front-.4),Color("d2e8dc"),.24)
 # Roof, corner pilasters and horizontal floor bands make the floor count visible.
 b.box(Vector3(w+.32,.23,d+.32),Vector3(0,h+.10,0),NAVY)
 b.box(Vector3(w+.05,.10,d+.05),Vector3(0,.10,0),Color("a2b8bf"))
 for level in range(1,floors):b.box(Vector3(w+.10,.16,d+.12),Vector3(0,level*level_height,0),TRIM)
 for side in [-1.0,1.0]:b.box(Vector3(.20,h,.16),Vector3(side*(w/2-.09),h/2,front+.035),TRIM)
 for level in floors:
  var y: float=level*level_height+1.56
  for fraction in [-.35,-.15,.15,.35]:
   var x: float=w*fraction
   if level==0 and absf(x)<opening/2+.7:continue
   _window(b,Vector3(x,y,front+.04),Vector2(1.62,1.76),level)
  for side in [-1.0,1.0]:
   for z in [-d*.30,0,d*.30]:_side_window(b,Vector3(side*(w/2+.035),y,z),Vector2(1.45,1.70),side)
 # Front lintel, door frame, and sign are sized for the normal following camera.
 for side in [-1.0,1.0]:b.box(Vector3(.16,2.67,.20),Vector3(side*(opening/2+.015),1.335,front+.055),NAVY)
 b.box(Vector3(opening+.36,.18,.24),Vector3(0,2.66,front+.07),TRIM)
 b.box(Vector3(minf(w-.8,6.5),.63,.16),Vector3(0,2.98,front+.18),NAVY)
 var title=g._sign(str(data.name),_at(data,Vector3(0,3.00,front+.30)),58,Color("f5f1df"));title.pixel_size=.010;title.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 if is_open:
  var floor_label=g._sign(str(data.get("detail","庭院与小铺 · 欢迎进入")),_at(data,Vector3(0,3.57,front+.20)),33,Color("476673"));floor_label.pixel_size=.007;floor_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 _identity(g,b,data,w,d,h)
 _roof_profile(b,data,w,d,h)
 # Only the north-row civic buildings yield entrance triggers.
 if is_open:
  var outward:=_building_transform(data).basis*Vector3.BACK
  var trigger:=_at(data,Vector3(0,0,front-.42))
  var gate=preload("res://district/interactive_door.gd").new();gate.name="EntranceDoor";gate.position=Vector3(0,0,front-.12);shell.add_child(gate)
  gate.configure(g,opening,"entrance:"+str(data.id),str(data.name)+" · 入口门",2.45)
  return {"target":str(data.target),"name":str(data.name),"pos":trigger,"normal":outward,"spawn":trigger+outward*1.1,"door":gate}
 return {}

static func _at(data: Dictionary,p: Vector3) -> Vector3:
 return _building_transform(data)*p

static func _roof_profile(b,data: Dictionary,w: float,d: float,h: float) -> void:
 var m=Models.new();m.b=b
 match str(data.kind):
  "restaurant":
   m.box(Vector3(w*.74,.16,d*.48),Vector3(0,h+.34,-d*.17),Models.BLUE)
   for x in [-w*.33,w*.33]:m.plant(Vector3(x,h+.22,d*.25),.75,true)
   m.box(Vector3(.78,.92,.78),Vector3(-w*.29,h+.68,-d*.19),Models.CREAM)
   m.box(Vector3(.87,.07,.87),Vector3(-w*.29,h+1.15,-d*.19),Models.NAVY)
  "school":
   m.box(Vector3(w*.77,.25,d*.60),Vector3(0,h+.34,-d*.05),Models.CREAM)
   for x in [-w*.29,0,w*.29]:m.box(Vector3(.14,.74,.14),Vector3(x,h+.79,d*.22),Models.BLUE)
   m.box(Vector3(w*.67,.12,.22),Vector3(0,h+1.16,d*.22),Models.BLUE)
   m.cyl(.55,.15,Vector3(0,h+.52,d*.30),Models.GOLD)
  "hospital":
   m.box(Vector3(w*.75,.42,d*.58),Vector3(0,h+.40,-d*.12),Models.CREAM)
   for x in [-w*.26,w*.26]:m.box(Vector3(.13,.65,.13),Vector3(x,h+.92,d*.18),Models.BLUE)
   m.box(Vector3(w*.64,.11,.17),Vector3(0,h+1.26,d*.18),Models.BLUE)
   m.box(Vector3(.82,.18,.15),Vector3(0,h+1.39,d*.29),Models.WHITE)
   m.box(Vector3(.18,.82,.15),Vector3(0,h+1.39,d*.29),Models.WHITE)
  "shop","flower","bookshop":
   var rise=1.35 if str(data.kind)=="shop" else 1.0
   var run=w/2+.24;var angle=atan2(rise,run)
   for side in [-1,1]:
    m.box(Vector3(sqrt(run*run+rise*rise),.13,d+.50),Vector3(side*run/2,h+.22+rise/2,0),Models.BLUE).rotation.z=-side*angle
   m.rod(Vector3(0,h+.23+rise,-d/2-.27),Vector3(0,h+.23+rise,d/2+.27),.055,Models.CREAM)
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
   for side in [-1,1]:
    var a=Vector3(-w/2,h+.20,side*d/2);var z=Vector3(0,h+.20+rise,side*d/2);var c=Vector3(w/2,h+.20,side*d/2)
    Models.triangle(tool,a,z,c) if side>0 else Models.triangle(tool,c,z,a)
   var cap=MeshInstance3D.new();cap.mesh=tool.commit();cap.material_override=Models.M.surface(Models.CREAM,false,false);b.add_child(cap)
   if str(data.kind)=="shop":
    m.box(Vector3(.62,1.15,.72),Vector3(-w*.27,h+.64,-d*.2),Models.CREAM)
    m.box(Vector3(.75,.11,.86),Vector3(-w*.27,h+1.24,-d*.2),Models.NAVY)
   elif str(data.kind)=="bookshop":
    m.box(Vector3(1.4,.75,1.0),Vector3(w*.24,h+.56,.16),Models.CREAM)
    m.glass(Vector3(.87,.48,.035),Vector3(w*.24,h+.64,.68));m.box(Vector3(1.53,.07,1.11),Vector3(w*.24,h+.99,.16),Models.BLUE)
  "cafe":
   # Open timber pergola and planted terrace, instead of another gable roof.
   for x in [-w*.30,w*.30]:
    for z in [-d*.28,d*.28]:m.box(Vector3(.14,1.65,.14),Vector3(x,h+.96,z),Models.CREAM)
   for i in 9:m.box(Vector3(w*.69,.08,.09),Vector3(0,h+1.80,-d*.32+i*d*.08),Models.CREAM)
   for x in [-w*.24,w*.24]:m.plant(Vector3(x,h+.24,d*.26),1.1,true)
   m.box(Vector3(w*.73,.065,.13),Vector3(0,h+.35,d*.30),Models.NAVY)
  "gallery":
   # A sawtooth skylight makes the low art gallery legible from the overview.
   for i in 3:
    var x=(i-1)*w*.30
    m.box(Vector3(w*.29,.11,d*.72),Vector3(x,h+.55,0),Models.BLUE).rotation.z=-.20
    m.glass(Vector3(w*.23,.025,d*.50),Vector3(x,h+.64,0))
    m.rod(Vector3(x-w*.15,h+.30,d*.36),Vector3(x+w*.15,h+.8,d*.36),.04,Models.CREAM)
  "studio":
   for i in 3:
    m.box(Vector3(1.1,.075,2.0),Vector3(-w*.28+i*w*.28,h+.45,-d*.18),Models.BLUE).rotation.x=-.19
   m.plant(Vector3(w*.32,h+.24,d*.30),1.0)
 # Fine gutter and downspout geometry gives the tall blank sides a scale cue.
 if str(data.kind) not in ["observatory","music"]:
  for side in [-1,1]:
   m.rod(Vector3(side*(w/2+.13),h+.22,-d/2),Vector3(side*(w/2+.13),h+.22,d/2),.047,Models.NAVY)
   m.rod(Vector3(side*(w/2+.13),h+.22,-d/2+.25),Vector3(side*(w/2+.13),.2,-d/2+.25),.04,Models.NAVY)

static func _asset_at(g,data: Dictionary,kind: String,p: Vector3,angle: float=0.0) -> void:
 g._asset(kind,_at(data,p),float(data.angle)+angle)

static func _window(b,p: Vector3,size: Vector2,level: int) -> void:
 b.box(Vector3(size.x+.15,size.y+.16,.13),p,TRIM)
 b.box(Vector3(size.x,size.y,.04),p+Vector3(0,0,.091),GLASS.lightened(.035*level))
 b.box(Vector3(.055,size.y,.065),p+Vector3(0,0,.12),TRIM)
 b.box(Vector3(size.x,.055,.065),p+Vector3(0,-.03,.12),TRIM)
 b.box(Vector3(size.x+.20,.09,.28),p+Vector3(0,-size.y/2-.08,.13),NAVY.lightened(.20))

static func _side_window(b,p: Vector3,size: Vector2,side: float) -> void:
 b.box(Vector3(.12,size.y+.16,size.x+.15),p,TRIM)
 b.box(Vector3(.045,size.y,size.x),p+Vector3(side*.09,0,0),GLASS)
 b.box(Vector3(.06,size.y,.055),p+Vector3(side*.12,0,0),TRIM)
 b.box(Vector3(.06,.055,size.x),p+Vector3(side*.12,0,0),TRIM)

static func _identity(g,b,data: Dictionary,w: float,d: float,h: float) -> void:
 var front: float=d/2
 var level_height: float=data.get("height",FLOOR_HEIGHT)
 match str(data.kind):
  "restaurant":
   _asset_at(g,data,"awning",Vector3(0,2.78,front+.66))
   for x in [-w*.33,w*.33]:_asset_at(g,data,"outdoor_table",Vector3(x,0,front+1.00))
   b.box(Vector3(w*.78,.07,.08),Vector3(0,2.34,front+.15),Color("b79c72"))
  "school":
   _asset_at(g,data,"noticeboard",Vector3(-w*.37,0,front+.85))
   _asset_at(g,data,"bench",Vector3(w*.34,0,front+1.0))
   for x in [-w*.41,w*.41]:_asset_at(g,data,"planter",Vector3(x,0,front+.9))
   b.box(Vector3(w*.82,.12,.12),Vector3(0,2.43,front+.15),Color("8caea7"))
  "hospital":
   for x in [-w*.40,w*.40]:_asset_at(g,data,"planter",Vector3(x,0,front+.92))
   b.led_box(Vector3(.70,.16,.08),Vector3(-w*.32,2.43,front+.24),Color("92c8dc"),.18)
   b.led_box(Vector3(.16,.70,.08),Vector3(-w*.32,2.43,front+.24),Color("92c8dc"),.18)
   _asset_at(g,data,"bench",Vector3(w*.36,0,front+1.0))
  "apartment":
   for level in [1,2]:
    for side in [-1.0,1.0]:
     var x: float=side*w*.29
     b.box(Vector3(3.9,.14,.75),Vector3(x,level*level_height-.1,front+.35),Color("a9bcc1"))
     b.box(Vector3(3.9,.08,.055),Vector3(x,level*level_height+.77,front+.68),TRIM)
     for post in range(8):b.cylinder(.022,.85,Vector3(x-1.75+post*.5,level*level_height+.35,front+.68),NAVY)
   _asset_at(g,data,"mailboxes",Vector3(-w*.36,0,front+.65));_asset_at(g,data,"planter",Vector3(w*.37,0,front+.72))
  "community":
   # A low garden crown distinguishes the civic roof from the apartment balconies.
   b.box(Vector3(w-.45,.40,d-.45),Vector3(0,h+.43,0),Color("afc6be"))
   for x in [-4.5,0,4.5]:
    b.box(Vector3(1.5,.42,1.0),Vector3(x,h+.73,-1.2),TRIM)
    b.pillow(Vector3(1.45,.8,.95),Vector3(x,h+1.2,-1.2),Color("8cb2a1"))
   _asset_at(g,data,"noticeboard",Vector3(-w*.36,0,front+.78));_asset_at(g,data,"bench",Vector3(w*.30,0,front+.80))
  "inn":
   b.box(Vector3(w-.4,.66,d-.4),Vector3(0,h+.57,0),Color("638097"))
   for x in [-4.0,0,4.0]:
    b.box(Vector3(1.9,.72,1.35),Vector3(x,h+.77,1.75),TRIM)
    _window(b,Vector3(x,h+.83,2.45),Vector2(1.35,.46),2)
   _asset_at(g,data,"planter",Vector3(-w*.34,0,front+.8));_asset_at(g,data,"bicycle",Vector3(w*.34,0,front+.8),-15)
  "flower":
   _asset_at(g,data,"awning",Vector3(0,2.75,front+.64))
   for x in [-w*.30,w*.30]:_asset_at(g,data,"flower_stand",Vector3(x,0,front+.8))
  "cafe":
   _asset_at(g,data,"awning",Vector3(0,2.75,front+.64))
   for x in [-w*.34,w*.34]:_asset_at(g,data,"outdoor_table",Vector3(x,0,front+.80))
  "market":
   b.box(Vector3(w-.3,.23,.22),Vector3(0,2.48,front+.27),Color("8da9b4"))
   _asset_at(g,data,"parcel_locker",Vector3(-w*.32,0,front+.72));_asset_at(g,data,"recycling",Vector3(w*.31,0,front+.75))
  "workshop","studio":
   b.box(Vector3(w*.66,.13,.35),Vector3(0,2.40,front+.20),Color("96b4bf"))
   _asset_at(g,data,"noticeboard",Vector3(-w*.33,0,front+.7));_asset_at(g,data,"planter",Vector3(w*.33,0,front+.75))
  "shop","bookshop":_asset_at(g,data,"awning",Vector3(0,2.75,front+.64))
  "observatory":
   b.cylinder(3.2,.4,Vector3(2,h+.38,-1),Color("829cac"))
   b.pillow(Vector3(6.3,3.7,6.3),Vector3(2,h+1.55,-1),Color("577b94"))
   b.box(Vector3(.38,3.3,5.9),Vector3(2,h+1.55,-1),Color("bed0d1"))
   b.cylinder(.075,4.0,Vector3(-w*.3,h+2.0,-d*.3),NAVY)
   b.box(Vector3(1.8,.1,.12),Vector3(-w*.3,h+3.4,-d*.3),TRIM)
  "music":
   b.pillow(Vector3(w*.85,1.8,d*.55),Vector3(0,h+.8,-d*.18),Color("667f94"))
   for x in [-w*.3,w*.3]:
    b.cylinder(.34,.1,Vector3(x,2.7,front+.23),Color("e2dec7"))
   b.box(Vector3(w*.7,.35,.7),Vector3(0,h+.30,front-.9),Color("c1d5cd"))
   _asset_at(g,data,"bench",Vector3(w*.29,0,front+.8))
  "office":
   for x in [-3.4,3.4]:b.box(Vector3(.15,h,.16),Vector3(x,h/2,front+.14),NAVY.lightened(.15))
  "gallery":
   for x in [-w*.32,w*.32]:_asset_at(g,data,"planter",Vector3(x,0,front+.7))

static func _furnish(g) -> void:
 # Individually placed clusters follow the irregular corners and courtyards.
 for p in [Vector2(-39,-29),Vector2(-39,-10),Vector2(-39,2),Vector2(-40,23),Vector2(39,-28),Vector2(40,-1),Vector2(39,29),Vector2(-19,-26),Vector2(-19,-19),Vector2(7,-26),Vector2(13,-15),Vector2(-17,11),Vector2(18,30)]:g._asset("tree",Vector3(p.x,0,p.y))
 for p in [Vector2(-37,-15.5),Vector2(-20,-15.7),Vector2(5,-29),Vector2(5,-17),Vector2(15,-16),Vector2(35,-16),Vector2(-22,1.8),Vector2(-37,11.4),Vector2(-18,11.7),Vector2(5,1.8),Vector2(18,3),Vector2(26,11.9),Vector2(37,11.8),Vector2(17.5,22),Vector2(-4.8,29)]:g._asset("streetlamp",Vector3(p.x,0,p.y))
 for p in [Vector2(-36,-15.5),Vector2(-26,-15.5),Vector2(19,-16),Vector2(29,-16),Vector2(-37,11.4),Vector2(-29,11.4)]:g._asset("planter",Vector3(p.x,0,p.y))
 g._asset("bus_stop",Vector3(-8,0,2.0));g._asset("bus_stop",Vector3(37,0,17.0),-90)
 g._asset("kiosk",Vector3(36,0,4.5))
 g._asset("bike_rack",Vector3(-8,0,12));g._asset("bicycle",Vector3(-8,0,11.9),-10)
 for p in [Vector2(-23,25.0),Vector2(27,1.0),Vector2(34,8.8),Vector2(7.5,-12.0)]:g._asset("bench",Vector3(p.x,0,p.y))
 for z in [-8.0,-1.0,16.0]:
  for x in [-4.8,4.8]:g._asset("bollard",Vector3(x,0,z))
 for p in [Vector3(-24,0,-15.4),Vector3(31,0,-15.5),Vector3(-29,0,11.5)]:g._prop("v18_street_flower_trough",p)
 g._prop("v18_street_bicycle",Vector3(-11,0,11.4))
 g._prop("v18_street_postbox",Vector3(6.7,0,-16.5))
 g._prop("v18_street_parcel_locker",Vector3(18,0,-4))
 g._prop("v18_street_parasol_table",Vector3(33,0,8.5))
 g._prop("v18_street_info_board",Vector3(24.5,0,9.1))
 # South civic street: deliberately asymmetric planting while keeping each door clear.
 for x in [-47,-25,-2,7,34]:g._asset("streetlamp",Vector3(x,0,53.8))
 for x in [-45,-23,5,36]:g._asset("tree",Vector3(x,0,56.2))
 for x in [-43,-22,4,32]:g._asset("planter",Vector3(x,0,51.4))
 g._asset("bench",Vector3(-24,0,55.0),180)
 g._asset("bench",Vector3(5,0,55.0),180)
 g._prop("v18_pastry_cart",Vector3(30,0,-.4))
 g._prop("v18_whale_planter",Vector3(-37,0,22.2))

static func _plaza(g,b) -> void:
 b.box(Vector3(14,.03,12),Vector3(31,.025,5),Color("cbdcd7"))
 for x in [25.0,28.0,31.0,34.0,37.0]:b.box(Vector3(.018,.009,11.5),Vector3(x,.047,5),Color("b1c7c3"))
 for z in [0.0,3.0,6.0,9.0]:b.box(Vector3(13.5,.009,.018),Vector3(31,.047,z),Color("b1c7c3"))
 b.cylinder(1.65,.30,Vector3(29,.19,5),TRIM)
 b.cylinder(1.43,.035,Vector3(29,.36,5),Color("8ab9c5"))
 b.cylinder(.24,.68,Vector3(29,.67,5),Color("adbfc0"))
 b.pillow(Vector3(.66,.66,.66),Vector3(29,1.09,5),Color("92b6c7"))
 g._collision(g.shell,Vector3(3.3,.65,3.3),Vector3(29,.325,5))
 for p in [Vector2(25,1),Vector2(37,9)]:g._asset("planter",Vector3(p.x,0,p.y))
 b.box(Vector3(10,.03,4.4),Vector3(-34,.025,22.6),Color("bfcec2"))
 g._asset("outdoor_table",Vector3(-36,0,22.5));g._asset("bench",Vector3(-31,0,22.8))
 var sign=g._sign("海风小广场",Vector3(31,.083,10.0),42,Color("839d9e"));sign.rotation_degrees.x=-90

## ── 大地图上的可搜刮容器 ──
##
## 之前 30 种容器只在 11 个室内新地点里出现过，而这张**每天都要穿过**的大地图
## 一个可开的箱子都没有。现在按建筑各自的主题把货堆到门口：
## 补给仓门口是货笼和带轮运输箱，检疫所门口是医疗箱与样本箱，保险库门口是保险柜，
## 潮间带观潮台门口是救生箱与潜水装备箱 —— 沿街走一遍，看门口堆的东西
## 就知道这栋楼是干什么的。
##
## 两条**量出来的**硬约束（都不是估计值）：
##
## 1. **离门洞传送点 ≥1.3 米。** nearest_portal 的抢占半径是 1.25 米，
##    箱子压到门口就会变成「想进楼却开了箱子」。室内那批已经踩过这个坑
##    （见 continuous_world.gd 的 _interact 注释）。两列的传送点算出来是
##    西列 (51.58, 0, zc)、东列 (58.42, 0, zc)（front=d/2=4，trigger 在 front-0.42），
##    所以箱子摆在 zc±2.6 处，斜距 3.1 米，安全。
## 2. **两列各贴自己那侧的建筑面，中间留出通道。** 容器自带 StaticBody3D 碰撞
##    （container_runtime.gd 的 create_body_collision 默认 true），摆到街心会把人堵死。
##    西列贴 x≈53.3（面在 52.5），东列贴 x≈56.7（面在 57.5），中间还剩约 2 米。
##
## 每条是 [容器类型, x, z, 朝向]。朝向按「门朝街」给：西列 90°、东列 -90°。
static func _containers(g) -> void:
 var WB := 53.3   # 西列：建筑面 x=52.5，外沿 0.8 米
 var EB := 56.7   # 东列：建筑面 x=57.5，外沿 0.8 米
 var rows: Array = [
  # ── 西列（门朝东，angle=90）──
  ["harbor_cargo_cage", WB, -37.5 - 2.7, 90],        # 港湾补给仓：货笼
  ["harbor_cargo_cage", WB, -37.5 + 2.7, 90],        # 港湾补给仓：货笼
  ["rolling_logistics_case", WB, -37.5 + 4.4, 90],   # 港湾补给仓：带轮运输箱
  ["searchable_file_cabinet", WB, -22.5 - 2.6, 90],  # 潮汐档案馆：档案柜
  ["port_manifest_drawer", WB, -22.5 + 2.6, 90],     # 潮汐档案馆：单据检索柜
  ["field_medical_chest", WB, -7.5 - 2.6, 90],       # 分区检疫所：医疗补给箱
  ["sample_transport_case", WB, -7.5 + 2.6, 90],     # 分区检疫所：样本运输箱
  ["field_supply_crate", WB, 7.5 - 2.6, 90],         # 中央枢纽站：失物招领
  ["searchable_file_cabinet", WB, 7.5 + 2.6, 90],    # 中央枢纽站：档案柜
  ["office_armored_safe", WB, 22.5 - 2.6, 90],       # 港湾保险库：重型保险柜
  ["currency_transport_case", WB, 22.5 + 2.6, 90],   # 港湾保险库：纸币运输箱
  ["restaurant_cash_drop_safe", WB, 22.5 + 4.3, 90], # 港湾保险库：投币保险柜
  ["industrial_tool_chest", WB, 37.5 - 2.6, 90],     # 备件长库：维修工具箱
  ["battery_module_crate", WB, 37.5 + 2.6, 90],      # 备件长库：电源模块箱
  # ── 东列（门朝西，angle=-90）──
  ["insulated_seafood_chest", EB, -37.5 - 2.6, -90], # 后厨冷藏间：海鲜保温箱
  ["pantry_ingredient_bin", EB, -37.5 + 2.6, -90],   # 后厨冷藏间：配料储藏箱
  ["laboratory_specimen_freezer", EB, -22.5 - 2.6, -90], # 地下实验区：样本低温柜
  ["encrypted_electronics_case", EB, -22.5 + 2.6, -90],  # 地下实验区：加密设备箱
  ["port_manifest_drawer", EB, -7.5 - 2.6, -90],     # 海关查验厅：单据检索柜
  ["harbor_cargo_cage", EB, -7.5 + 2.6, -90],        # 海关查验厅：待查货笼
  ["maritime_signal_locker", EB, 7.5 - 2.6, -90],    # 山地气象站：信号装备柜
  ["server_service_cabinet", EB, 7.5 + 2.6, -90],    # 山地气象站：服务器检修柜
  ["lifesaving_deck_box", EB, 22.5 - 2.6, -90],      # 潮间带观潮台：救生甲板箱
  ["diver_equipment_case", EB, 22.5 + 2.6, -90],     # 潮间带观潮台：潜水装备箱
  ["field_supply_crate", EB, 37.5 - 2.6, -90],       # 东港值守站（进不去，货堆在门口）
  ["long_equipment_case", EB, 37.5 + 2.6, -90],      # 东港值守站：长型装备箱
  # ── 南港公共街：三栋新建公共楼的门口交货（z 卡在楼面 50 与街道 51.4 之间）──
  ["insulated_seafood_chest", -35.5, 50.9, 0],       # 海蓝餐厅：后门交货
  ["pantry_ingredient_bin", -29.5, 50.9, 0],         # 海蓝餐厅：配料
  ["field_supply_crate", -16.0, 50.9, 0],            # 海湾学校：教具补给
  ["reinforced_flight_case", -8.0, 50.9, 0],         # 海湾学校：实验器材
  ["cold_chain_medical_cabinet", 16.0, 50.9, 0],     # 海湾医院：冷链箱
  ["wall_emergency_supply_cabinet", 24.0, 50.9, 0],  # 海湾医院：应急救护柜
  # ── 核心街区 ──
  ["maritime_signal_locker", 22.6, 25.8, 90],        # 潮汐观测站：信号装备
  ["reinforced_flight_case", -17.6, 24.6, 0],        # 蓝鲸音乐馆：乐器航空箱
  ["reinforced_flight_case", -34.4, 24.0, 0],        # 白帆艺廊：画作运输箱
  ["long_equipment_case", -37.0, 24.2, 0],           # 花房小院：园艺工具
  # ── 海风口袋广场：集市摊位的存货 ──
  ["field_supply_crate", 35.5, 2.0, 180],
  ["rolling_logistics_case", 35.5, -0.2, 180],
 ]
 for row in rows:
  ContainerRooms._container(g, str(row[0]), Vector3(float(row[1]), 0, float(row[2])), float(row[3]))
 # 全部摆完之后统一登记进战利品系统（容器 id 是 city__类型__序号，进出地图不会刷新）
 ContainerRooms._wire_loot(g)

static func _building_transform(data: Dictionary) -> Transform3D:
 return Transform3D(Basis(Vector3.UP,deg_to_rad(float(data.angle))),Vector3(data.center))


static func _building_footprint(data: Dictionary) -> Rect2:
 var building_axes:=_building_transform(data)
 var half_width: float=float(data.width)*.5
 var half_depth: float=float(data.depth)*.5
 var first: Vector3=building_axes*Vector3(-half_width,0,-half_depth)
 var bounds:=Rect2(Vector2(first.x,first.z),Vector2.ZERO)
 for x in [-half_width,half_width]:
  for z in [-half_depth,half_depth]:
   var corner: Vector3=building_axes*Vector3(x,0,z)
   bounds=bounds.expand(Vector2(corner.x,corner.z))
 return bounds

