extends RefCounted
## Additional connected street segments and the rooms inside apartment 201.
static func extend_places(places: Dictionary) -> void:
 var extra: Dictionary={
  "east_street":{"name":"海风东街","group":"outside","type":"east_street","subtitle":"花店、便利铺与通往港湾的路","links":["street","florist","market","alley","waterfront"]},
  "waterfront":{"name":"港湾步道","group":"outside","type":"waterfront","subtitle":"沿着水边走一小段，听风经过栏杆","links":["street","east_street"]},
  "alley":{"name":"绿荫小巷","group":"outside","type":"alley","subtitle":"连接街角花园与东街的安静近路","links":["garden","east_street"]},
  "florist":{"name":"青柠花房","group":"outside","type":"room","layout":2,"custom":"florist","subtitle":"挑一盆植物，也留一点光给新叶","links":["east_street"]},
  "market":{"name":"鲸邮便利铺","group":"outside","type":"room","layout":1,"custom":"market","subtitle":"日常补给、包裹与街区消息","links":["east_street"]},
  "suite_entry":{"name":"201 · 玄关","group":"floor2","type":"room","layout":0,"custom":"entry","subtitle":"从走廊回到家，换鞋、放下钥匙","links":["hall_2","home_201","suite_living","suite_bath"]},
  "suite_living":{"name":"201 · 客厅","group":"floor2","type":"room","layout":2,"custom":"living","subtitle":"窗边的沙发与连通厨房的日常空间","links":["suite_entry","suite_kitchen"]},
  "suite_kitchen":{"name":"201 · 厨房","group":"floor2","type":"room","layout":2,"custom":"kitchen","subtitle":"冰箱、灶台和两个人的小餐桌","links":["suite_living"]},
  "suite_bath":{"name":"201 · 卫浴","group":"floor2","type":"room","layout":0,"custom":"bath","subtitle":"蓝白瓷砖、淋浴与温暖的干净毛巾","links":["suite_entry"]},
  "laundry":{"name":"屋顶 · 洗衣房","group":"floor3","type":"room","layout":1,"custom":"laundry","subtitle":"洗衣、整理，再去露台晒晒太阳","links":["roof"]}}
 places.merge(extra,true)
 places.street.links.append("east_street");places.street.links.append("waterfront")
 places.garden.links.append("alley");places.roof.links.append("laundry")
 places.home_201.links[0]="suite_entry";places.home_201.name="201 · 卧室"
 var at: int=places.hall_2.links.find("home_201")
 if at>=0:places.hall_2.links[at]="suite_entry"

static func build_outdoor(game,id: String) -> void:
 match id:
  "east_street":_east_street(game)
  "waterfront":_waterfront(game)
  "alley":_alley(game)

static func _east_street(g) -> void:
 g.floor_mesh.visible=false
 var b=g._builder(g.shell)
 b.box(Vector3(22,.26,12),Vector3(0,-.16,.3),Color("687e8c"))
 b.box(Vector3(21.8,.035,5.1),Vector3(0,.005,3.35),Color("8c9fa8"))
 b.box(Vector3(21.8,.05,5.3),Vector3(0,.015,-1.9),Color("d2dee0"))
 for x in range(-10,11):b.box(Vector3(.015,.008,5.2),Vector3(float(x),.049,-1.85),Color("b7c8cc"))
 for z in [-3.4,-2.2,-1.0,.2]:b.box(Vector3(21.8,.008,.015),Vector3(0,.050,z),Color("b7c8cc"))
 b.box(Vector3(21.8,.12,.18),Vector3(0,.025,.85),Color("edf0e6"))
 g._facade(-5.3,6.2,"青柠花房",Color("cee0d9"),true)
 g._facade(3.0,6.2,"鲸邮便利",Color("d4e2e8"),true)
 g._portal(Vector3(-5.3,0,-1.65),"florist","青柠花房 · 欢迎进来")
 g._portal(Vector3(3.0,0,-1.65),"market","鲸邮便利 · 日常补给")
 g._portal(Vector3(-9.7,0,4.4),"street","← 返回鲸落街","path")
 g._portal(Vector3(9.6,0,4.4),"waterfront","港湾步道 →","path")
 g._portal(Vector3(9.1,0,-.75),"alley","绿荫小巷 · 近路","path")
 for x in [-9.4,-1.5,7.4]:g._asset("tree",Vector3(x,0,.15))
 for x in [-8.1,.6,8.0]:g._asset("streetlamp",Vector3(x,0,.65))
 for x in [-7.0,-3.65]:g._asset("flower_stand",Vector3(x,0,-1.30))
 g._asset("parcel_locker",Vector3(5.15,0,-1.40))
 g._asset("recycling",Vector3(7.25,0,-1.25))
 g._asset("outdoor_table",Vector3(-3.0,0,2.65))
 g._asset("outdoor_table",Vector3(.15,0,2.65))
 g._asset("bike_rack",Vector3(5.8,0,4.7));g._asset("bicycle",Vector3(5.8,0,4.55))
 g._asset("bench",Vector3(-6.0,0,.35))
 g._bounds(Vector2(22,12))

static func _waterfront(g) -> void:
 g.floor_mesh.visible=false;var b=g._builder(g.shell)
 b.box(Vector3(16,.25,7.8),Vector3(0,-.20,.5),Color("536f80"))
 b.box(Vector3(15.7,.09,3.0),Vector3(0,.002,-2.0),Color("c6d5d7"))
 for x in range(-7,8):b.box(Vector3(.020,.005,2.9),Vector3(float(x),.052,-2.0),Color("a8bec6"))
 var water:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(15.7,4.9);water.mesh=plane;water.position=Vector3(0,-.025,1.90)
 var shader:=Shader.new();shader.code="shader_type spatial;render_mode cull_disabled;void fragment(){float a=sin(UV.x*93.+TIME*.8+sin(UV.y*28.+TIME*.3));float b=sin(UV.y*105.-TIME*.5);float ripple=smoothstep(.90,1.,a*b);ALBEDO=mix(vec3(.27,.53,.63),vec3(.61,.80,.82),ripple*.38);ROUGHNESS=.35;SPECULAR=.3;}"
 var mat:=ShaderMaterial.new();mat.shader=shader;water.material_override=mat;g.shell.add_child(water)
 for x in range(-7,8):
  b.cylinder(.025,.72,Vector3(float(x),.40,-.45),Color("718d99"))
 b.box(Vector3(15.5,.055,.055),Vector3(0,.76,-.45),Color("ecede4"))
 b.box(Vector3(15.5,.035,.035),Vector3(0,.43,-.45),Color("b8c9ca"))
 for x in [-5.4,0,5.4]:g._asset("bench",Vector3(x,0,-2.25))
 for x in [-6.5,-2.8,2.8,6.5]:g._asset("streetlamp",Vector3(x,0,-3.05))
 g._asset("lifebuoy",Vector3(-1.8,0,-.5))
 g._asset("dinghy",Vector3(4.0,-.13,1.45),-17)
 for x in [-5,-4.5,-4,-3.5,-3]:b.box(Vector3(.43,.12,2.7),Vector3(float(x),.04,.9),Color("b6c7c5"))
 g._portal(Vector3(-6.9,0,-1.45),"street","← 鲸落街","path")
 g._portal(Vector3(6.9,0,-1.45),"east_street","海风东街 →","path")
 g._collision(g.shell,Vector3(16,1,.15),Vector3(0,.5,-.42))
 g._bounds(Vector2(16,7.7))

static func _alley(g) -> void:
 g.floor_mesh.visible=false;var b=g._builder(g.shell)
 b.box(Vector3(12.4,.22,7),Vector3(0,-.15,0),Color("728e98"))
 b.box(Vector3(12,.035,6.7),Vector3(0,.0,0),Color("d0ddda"))
 b.box(Vector3(12,1.65,.18),Vector3(0,.825,-3.2),Color("d7e1d8"))
 for x in range(-5,6):b.box(Vector3(.014,.008,6.4),Vector3(float(x),.025,0),Color("aebfba"))
 for z in [-2,-1,0,1,2]:b.box(Vector3(11.8,.008,.014),Vector3(0,.025,float(z)),Color("aebfba"))
 for x in [-4.5,-1.2,2.6]:g._asset("tree",Vector3(x,0,-2.4))
 for x in [-3.1,.1,4.5]:g._asset("planter",Vector3(x,0,-2.5))
 g._asset("bench",Vector3(-1.8,0,-1.2));g._asset("bicycle",Vector3(3.7,0,-1.5),12)
 g._asset("streetlamp",Vector3(-4.7,0,.8));g._asset("recycling",Vector3(4.9,0,-2.2))
 g._portal(Vector3(-4.85,0,2.0),"garden","← 街角小花园","path")
 g._portal(Vector3(4.85,0,2.0),"east_street","海风东街 →","path")
 g._bounds(Vector2(12,6.7))

static func build_room(g,kind: String) -> void:
 for item in g.items:item.free()
 g.items.clear()
 for chest in g.loot.chests:
  if is_instance_valid(chest):chest.free()
 g.loot.chests.clear();g.loot.nearby=null;g.loot.current_chest=null
 # Remove the base layout's untracked rug before dressing a different room.
 for child in g.world.get_children():
  if child!=g.player:child.free()
 g.floor_index=2 if kind in ["bath","laundry","market"] else 0
 g.wall_index=2 if kind in ["bath","laundry"] else 0
 g._floor();g._shell()
 g._prop("window_frost" if kind=="bath" else "window_oak",Vector3(-5.91,1.12,-.9),90)
 match kind:
  "entry":
   g._prop("shoe_cabinet",Vector3(-4.8,0,.4),90);g._prop("coat_rack",Vector3(-4.7,0,2.2));g._prop("entry_bench",Vector3(-2.1,0,-1.0))
   g._prop("mirror",Vector3(-3.4,1.5,-3.1));g._prop("slippers",Vector3(-1.5,0,.2));g._prop("plant_snake",Vector3(4.9,0,2.4))
   var b=g._builder(g.world);b.box(Vector3(3.1,.016,1.6),Vector3(.8,.024,1.6),Color("9db9bf"))
  "living":
   g._prop("sofa_cream",Vector3(-2.7,0,-1.2));g._prop("coffee_table",Vector3(-1.5,0,.9));g._prop("tea_tray",Vector3(-1.5,.55,.40))
   g._prop("armchair_sage",Vector3(1.5,0,.4));g._prop("tv_cabinet",Vector3(1.5,0,-2.65));g._prop("lamp_floor",Vector3(-4.3,0,-1.2));g._prop("plant_fiddle",Vector3(5.0,0,1.4))
   g._prop("bookcase",Vector3(-3.35,0,-2.65));g._prop("whale_plush",Vector3(-2.4,.7,-1.55))
  "kitchen":
   for spec in [["fridge",Vector3(-4.8,0,-2.55)],["sink_counter",Vector3(-3.1,0,-2.55)],["counter_blank",Vector3(-1.5,0,-2.55)],["stove_counter",Vector3(.1,0,-2.55)]]:g._prop(spec[0],spec[1])
   g._prop("upper_cabinet",Vector3(-2.3,1.6,-3.06));g._prop("microwave",Vector3(-1.5,.98,-2.90));g._prop("dining_round",Vector3(.5,0,1.25))
   g._prop("chair_white",Vector3(-.8,0,.41),90);g._prop("chair_white",Vector3(1.8,0,.41),-90);g._prop("tea_tray",Vector3(.5,.90,.41));g._prop("waste_bin",Vector3(4.8,0,.1))
  "bath":
   g._prop("district_bathtub",Vector3(-3.6,0,-1.75));g._prop("district_vanity",Vector3(.1,0,-2.6));g._prop("district_shower",Vector3(2.2,0,-2.1))
   g._prop("district_towel_rack",Vector3(-4.5,0,1.6));g._prop("basket",Vector3(.5,0,.2));g._prop("plant_snake",Vector3(3.8,0,1.3))
  "laundry":
   for x in [-4.0,-2.5,-1.0]:g._prop("district_washer",Vector3(x,0,-2.4))
   g._prop("counter_blank",Vector3(1.3,0,-2.4));g._prop("folded_blanket",Vector3(1.3,.98,-2.84));g._prop("district_clothesline",Vector3(-2.8,0,.8))
   g._prop("basket",Vector3(.3,0,.7));g._prop("storage_box",Vector3(3.2,0,.5))
  "florist":
   for i in 4:g._asset("flower_stand",Vector3(-4.8+i*1.55,0,-2.25))
   g._prop("counter_blank",Vector3(3,0,.15));g._prop("flowers",Vector3(3,.98,-.29));g._prop("plant_fiddle",Vector3(-4.7,0,.5));g._prop("plant_broadleaf",Vector3(-2.9,0,1.2))
   g._asset("planter",Vector3(.1,0,1.65));g._prop("basket",Vector3(4.5,0,.5))
  "market":
   for x in [-4.5,-2.6,-.7]:g._prop("bookcase",Vector3(x,0,-2.65))
   g._prop("fridge",Vector3(2.1,0,-2.55));g._prop("counter_blank",Vector3(2.5,0,.7));g._prop("keyboard",Vector3(2.5,.98,.26))
   g._asset("parcel_locker",Vector3(-4.8,0,.6),90);g._prop("storage_box",Vector3(-1,0,1.1));g._asset("kiosk",Vector3(.3,0,-.7))
 if g.atmosphere:g.atmosphere.rebuild()
