extends "res://room_3d.gd"
const StreetAsset=preload("res://district/street_asset.gd")
const Expansion=preload("res://district/expanded_places.gd")
const GuideView=preload("res://district/guide_view.gd")
var district_ready:=false
var location_id:="home_201"
var locations: Dictionary={}
var portals: Array[Dictionary]=[]
var nearest_portal: Dictionary={}
var map_panel: Panel
var map_shade: ColorRect
var district_canvas: Control
var breadcrumb: Label
var destination_hint: Button
var map_tab:="outside"
var visited: Dictionary={}
var room_edits: Dictionary={}
var changing:=false
var arrival_note: Label
var favorites: Dictionary={}
var route_destination:=""
var route_steps: Array=[]
var route_marker: MeshInstance3D
var route_card: Panel
var route_title: Label
var route_detail: Label
var transitioning:=false

func _ready() -> void:
 get_window().title="大肥鱼 · 鲸落港生活街区 v12"
 _define_locations()
 super._ready()
 district_ready=true
 _district_ui()
 _travel("home_201")

func _define_locations() -> void:
 locations={
  "street":{"name":"鲸落街","group":"outside","type":"street","subtitle":"蓝白店面、树影和慢行街道","links":["lobby","cafe","workshop","garden"]},
  "lobby":{"name":"云湾公寓 · 大厅","group":"outside","type":"lobby","subtitle":"信箱、等候区与上楼的阶梯","links":["street","hall_1","hall_2","hall_3"]},
  "cafe":{"name":"潮汐咖啡馆","group":"outside","type":"room","layout":2,"subtitle":"临街咖啡与阅读角","links":["street"]},
  "workshop":{"name":"深潜工作室","group":"outside","type":"room","layout":1,"subtitle":"街区创作与工作空间","links":["street"]},
  "garden":{"name":"街角小花园","group":"outside","type":"garden","subtitle":"花箱、长椅与小树下的休息处","links":["street"]},
  "roof":{"name":"屋顶露台","group":"floor3","type":"roof","subtitle":"晾晒、种植和远处的城市","links":["hall_3"]}}
 var room_names: Array=["共享客厅","生活厨房","漂流书房","大肥鱼的家","个人工作间","朋友的客房","植物房","手作室","观景茶室"]
 var descriptions: Array=["柔软沙发和一张可以聊天的茶几","收好餐具，准备今天的热饭","旧书、便签与安静的阅读角","蓝色床铺、窗边书桌与生活小物","连接卧室的安静创作房间","为来做客的朋友准备的房间","给新叶子留一点阳光","收纳、展示和慢慢完成的小作品","三楼的窗景与午后茶点"]
 for floor_number in range(1,4):
  var hall_id:="hall_"+str(floor_number)
  var room_links: Array=[]
  for number in range(1,4):
   var room_id:="home_"+str(floor_number*100+number)
   var i: int=(floor_number-1)*3+number-1
   var layout: int=[2,2,2,0,1,0,2,1,2][i]
   var links: Array=[hall_id]
   if room_id=="home_201":links.append("home_202")
   if room_id=="home_202":links.append("home_201")
   locations[room_id]={"name":str(floor_number*100+number)+" · "+room_names[i],"group":"floor"+str(floor_number),"type":"room","layout":layout,"subtitle":descriptions[i],"links":links,"floor":floor_number,"theme":i}
   room_links.append(room_id)
  room_links.append("lobby")
  if floor_number>1:room_links.append("hall_"+str(floor_number-1))
  room_links.append("hall_"+str(floor_number+1) if floor_number<3 else "roof")
  locations[hall_id]={"name":str(floor_number)+"F · 云湾走廊","group":"floor"+str(floor_number),"type":"hall","floor":floor_number,"subtitle":"三个房间，一条连通的生活走廊","links":room_links}
 Expansion.extend_places(locations)

func _layout(index: int) -> void:
 if not district_ready:super._layout(index);return
 request_travel(["home_201","street","cafe"][clampi(index,0,2)])

func _travel(target: String,route: String="",staged: bool=false) -> void:
 if changing or not locations.has(target):return
 changing=true
 if staged:await preload("res://ui/loading_transition.gd").instance(get_tree()).checkpoint(.16,"记住当前位置")
 if district_ready and locations.has(location_id) and not items.is_empty():_remember_room()
 var previous:=location_id;location_id=target;visited[target]=true
 nearest_portal={};portals.clear();closest=null
 if loot:loot.close()
 panel.hide();dialog.hide();dialog_open=false;settings_panel.hide();editing=false
 if map_panel:map_panel.hide();map_shade.hide()
 var data: Dictionary=locations[target]
 floor_mesh.visible=true
 if data.type=="room":
  super._layout(int(data.layout))
  _room_theme(int(data.get("theme",-1)))
  if data.has("custom"):Expansion.build_room(self,str(data.custom))
  for item in items.duplicate():
   if str(item.module_id).begins_with("door_"):
    items.erase(item);item.free()
  _portal(Vector3(4.78,0,-3.05),data.links[0],"出门 · "+str(locations[data.links[0]].name))
  var extra_doors: Array=[Vector3(-5.05,0,-3.05),Vector3(1.55,0,-3.05),Vector3(-1.75,0,-3.05)]
  for i in range(1,data.links.size()):_portal(extra_doors[i-1],data.links[i],"通往 · "+str(locations[data.links[i]].name))
  _restore_room_edits()
 else:
  _clear_world()
  match str(data.type):
   "street":_street()
   "lobby":_lobby()
   "hall":_hall(int(data.floor))
   "garden":_garden(false)
   "roof":_garden(true)
   _:Expansion.build_outdoor(self,location_id)
  if atmosphere:atmosphere.rebuild()
 if staged:await preload("res://ui/loading_transition.gd").instance(get_tree()).checkpoint(.78,"准备人物与镜头")
 camera.size=18.6 if data.type in ["street","east_street"] else (13.6 if data.type=="waterfront" else 11.7)
 camera_angle=28;_camera()
 player.position=Vector3(4.2,0,2.4) if data.type=="room" else Vector3(1.3,0,1.5)
 if data.type in ["street","east_street"]:player.position=Vector3(0,0,2.5)
 if data.type=="waterfront":player.position=Vector3(1.5,0,-1.4)
 if data.type in ["garden","roof"]:player.position=Vector3(.3,0,2.3)
 var found_entry:=false
 for portal in portals:
  if portal.target!=previous:continue
  if not found_entry:player.position=portal.spawn;found_entry=true
  if route=="" or portal.route==route:player.position=portal.spawn;break
 player.velocity=Vector3.ZERO;facing_accum=Vector2.ZERO;facing_timer=0;facing="down";avatar.speed_scale=1;avatar.play("idle_down")
 title.text=str(data.name)
 for i in nav_buttons.size():nav_buttons[i].set_pressed_no_signal(target==["home_201","street","cafe"][i])
 if breadcrumb:breadcrumb.text="鲸落港  /  "+_group_name(str(data.group))+"  /  "+str(data.name)
 if arrival_note:arrival_note.text=str(data.subtitle)
 changing=false
 _refresh_route()

func _clear_world() -> void:
 for child in world.get_children():
  if child!=player:child.free()
 items.clear()
 for child in shell.get_children():child.free()
 loot.chests.clear();loot.nearby=null;loot.current_chest=null
 floor_index=2;wall_index=0;_floor();floor_mesh.visible=true

func _builder(parent: Node) -> Node3D:
 var b:=SolidModule.new();b.module_id="";parent.add_child(b);return b

func _bounds(size: Vector2) -> void:
 for spec in [[Vector3(size.x+.5,2,.2),Vector3(0,1,-size.y/2)],[Vector3(size.x+.5,2,.2),Vector3(0,1,size.y/2)],[Vector3(.2,2,size.y),Vector3(-size.x/2,1,0)],[Vector3(.2,2,size.y),Vector3(size.x/2,1,0)]]:
  _collision(shell,spec[0],spec[1])

func _collision(parent: Node,size: Vector3,pos: Vector3) -> void:
 var body:=StaticBody3D.new();var hit:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;hit.shape=shape;body.position=pos;body.add_child(hit);parent.add_child(body)

func _asset(kind: String,pos: Vector3,angle: float=0) -> Node3D:
 var n:=StreetAsset.new();n.asset_kind=kind;n.position=pos;n.rotation_degrees.y=angle;world.add_child(n);return n

func _prop(id: String,pos: Vector3,angle: float=0) -> Node3D:
 return _spawn({"id":id,"pos":[pos.x,pos.y,pos.z],"angle":angle})

func _sign(text: String,pos: Vector3,size: int=42,color: Color=Color("334d67")) -> Label3D:
 var label:=Label3D.new();label.text=text;label.font=_game_font();label.font_size=size;label.pixel_size=.006;label.position=pos;label.modulate=color;label.outline_size=0;label.shaded=false;world.add_child(label);return label

func _portal(pos: Vector3,target: String,label_text: String,kind: String="door") -> void:
 if kind=="door":_prop("door_glass" if target in ["street","cafe","workshop"] else "door_ivory",pos)
 elif kind=="elevator":_asset("elevator",pos)
 elif kind=="stairs":_asset("stairs",pos)
 var approach:=pos+Vector3(0,0,.85)
 var trigger:=pos+Vector3(0,0,.40)
 if kind=="path":approach=pos;trigger=pos
 var route: String="stairs" if kind=="path" and (target.begins_with("hall_") or target=="lobby" or target=="roof") else kind
 portals.append({"pos":trigger,"spawn":approach,"target":target,"label":label_text,"route":route})
 var sign_y:=2.55 if kind=="door" else (2.83 if kind=="elevator" else 1.75)
 var short_label: String=str(locations[target].name)
 if target=="suite_entry" and location_id=="hall_2":short_label="201 · 大肥鱼的家"
 var label:=_sign(short_label,pos+Vector3(0,sign_y,.10),28)
 if kind in ["stairs","path"]:label.billboard=BaseMaterial3D.BILLBOARD_ENABLED

func _street() -> void:
 floor_mesh.visible=false
 var b:=_builder(shell)
 b.box(Vector3(22,.26,12),Vector3(0,-.16,.3),Color("687e8c"))
 b.box(Vector3(21.8,.04,5.2),Vector3(0,-.005,3.35),Color("748998"))
 b.box(Vector3(21.8,.05,5.3),Vector3(0,.015,-1.9),Color("d2dee0"))
 for x in range(-10,11):
  b.box(Vector3(.016,.006,5.0),Vector3(float(x),.045,-1.8),Color("b1c3cc"))
 for z in [-3.4,-2.2,-1.0,.2]:b.box(Vector3(21.8,.008,.016),Vector3(0,.046,z),Color("b1c3cc"))
 b.box(Vector3(21.8,.12,.16),Vector3(0,.02,.8),Color("e6ebdf"))
 for x in range(-9,11,2):b.box(Vector3(1.0,.008,.045),Vector3(float(x),.023,3.9),Color("cfdddf"))
 for z in range(6):b.box(Vector3(2.1,.012,.30),Vector3(-.7,.025,1.25+z*.52),Color("e3e9df"))
 _facade(-6.7,5.8,"云湾公寓",Color("e1e5df"),false)
 _facade(.2,5.0,"潮汐咖啡",Color("dce8e5"),true)
 _facade(6.0,4.5,"深潜工作室",Color("b2ccd6"),true)
 _portal(Vector3(-6.7,0,-1.65),"lobby","云湾公寓 · 入口")
 _portal(Vector3(.2,0,-1.65),"cafe","潮汐咖啡 · 进店")
 _portal(Vector3(6.0,0,-1.65),"workshop","深潜工作室 · 进门")
 _portal(Vector3(9.45,0,3.5),"garden","街角小花园 →","path")
 _portal(Vector3(9.7,0,5.2),"east_street","海风东街 →","path")
 _portal(Vector3(-9.8,0,3.0),"waterfront","← 港湾步道","path")
 for x in [-10.0,-3.45,3.55,9.2]:_asset("tree",Vector3(x,0,.05))
 for x in [-8.7,-2.8,4.0,8.2]:_asset("streetlamp",Vector3(x,0,.60))
 _asset("bench",Vector3(-4.15,0,-.4));_asset("bicycle",Vector3(3.5,0,-.7),-20)
 _asset("bus_stop",Vector3(-6.8,0,5.0));_sign("鲸落港  ·  慢行线",Vector3(-6.8,2.48,5.03),34,Color("f2f5ef"))
 _asset("kiosk",Vector3(8.4,0,-1.5));_asset("hydrant",Vector3(7.4,0,.50))
 for x in [-9.7,-9.0,1.1,1.8,2.5]:_asset("bollard",Vector3(x,0,.75))
 for x in [-8.45,-4.95,1.6,7.75]:_asset("planter",Vector3(x,0,-1.4))
 _bounds(Vector2(22,12))

func _facade(x: float,width: float,shop_name: String,tint: Color,awning: bool) -> void:
 var b:=_builder(shell)
 b.box(Vector3(width,5.1,2.0),Vector3(x,2.55,-2.8),tint)
 b.box(Vector3(width+.14,.18,2.13),Vector3(x,5.14,-2.8),Color("4f6d85"))
 b.box(Vector3(width+.06,.12,.12),Vector3(x,2.8,-1.73),Color("f0eee4"))
 for side in [-1,1]:
  for y in [1.32,3.82]:
   var p:=Vector3(x+side*width*.29,y,-1.755)
   b.box(Vector3(width*.24,1.42,.08),p,Color("edf0e9"))
   b.box(Vector3(width*.24-.13,1.26,.045),p+Vector3(0,0,.056),Color("84adbf"))
   b.box(Vector3(.035,1.32,.045),p+Vector3(0,0,.09),Color("e6eddf"))
 b.box(Vector3(2.35,.47,.08),Vector3(x,2.77,-1.64),Color("304b6b"))
 _sign(shop_name,Vector3(x,2.8,-1.57),48,Color("f5f1df"))
 if awning:_asset("awning",Vector3(x,2.55,-1.1))
 _collision(shell,Vector3(width,4,1.8),Vector3(x,2,-2.8))

func _lobby() -> void:
 floor_index=2;wall_index=0;_floor();_shell()
 _portal(Vector3(4.8,0,-3.06),"street","出门 · 鲸落街")
 _portal(Vector3(-4.7,0,.5),"hall_1","上楼 · 1F 走廊","stairs")
 _portal(Vector3(1.6,0,-3.02),"hall_2","电梯 · 2F 住户层","elevator")
 _portal(Vector3(-1.0,0,-3.02),"hall_3","电梯 · 3F 生活层","elevator")
 _asset("mailboxes",Vector3(-4.2,0,-2.85));_asset("noticeboard",Vector3(4.7,0,.6),-15)
 _asset("bench",Vector3(.25,0,1.7));_asset("planter",Vector3(2.3,0,1.8))
 _prop("plant_fiddle",Vector3(5.4,0,-1.6));_prop("lamp_floor",Vector3(-2.8,0,1.75))
 _sign("云湾公寓  /  WELCOME HOME",Vector3(-2.5,2.53,-3.02),32)

func _hall(floor_number: int) -> void:
 floor_index=7;wall_index=2;_floor();_shell()
 var b:=_builder(world);b.box(Vector3(10.5,.02,1.35),Vector3(0,.025,.65),Color("839dac"))
 for n in range(1,4):
  var target:="home_"+str(floor_number*100+n)
  if floor_number==2 and n==1:target="suite_entry"
  _portal(Vector3(-3.8+(n-1)*3.0,0,-3.02),target,str(locations[target].name))
  _prop("lamp_wall",Vector3(-3.8+(n-1)*3.0,2.35,-3.00))
 _portal(Vector3(4.7,0,-3.04),"lobby","电梯 · 一楼大厅","elevator")
 _portal(Vector3(-4.9,0,1.85),"hall_"+str(floor_number+1) if floor_number<3 else "roof","上行 · "+(str(floor_number+1)+"F" if floor_number<3 else "屋顶"),"stairs")
 _portal(Vector3(4.85,0,2.0),"hall_"+str(floor_number-1) if floor_number>1 else "lobby","下行 · "+(str(floor_number-1)+"F" if floor_number>1 else "大厅"),"path")
 _asset("planter",Vector3(0,0,2.35));_prop("painting_whale",Vector3(-5.93,1.7,-.4),90)
 _sign(str(floor_number)+"F",Vector3(-5.85,2.3,.4),82)

func _garden(roof: bool) -> void:
 floor_mesh.visible=false;var b:=_builder(shell)
 b.box(Vector3(12.4,.25,7.1),Vector3(0,-.14,0),Color("69838e"))
 b.box(Vector3(12,.04,6.7),Vector3(0,.005,0),Color("c5d4d6") if roof else Color("a4bcb3"))
 for x in [-5.9,5.9]:b.box(Vector3(.12,.8,6.8),Vector3(x,.4,0),Color("e2e7de"))
 b.box(Vector3(12,.8,.12),Vector3(0,.4,-3.3),Color("e2e7de"))
 _portal(Vector3(4.6,0,-2.8),"hall_3" if roof else "street","回到 · "+("三楼走廊" if roof else "鲸落街"))
 for x in [-4.4,0,3.4]:_asset("planter",Vector3(x,0,-2.3))
 for x in [-3.9,2.9]:_asset("bench",Vector3(x,0,1.1))
 _prop("dining_round",Vector3(-.7,0,-.4));_prop("tea_tray",Vector3(-.7,.9,-.4))
 _prop("chair_white",Vector3(-.7,0,.65));_prop("chair_white",Vector3(-.7,0,-1.45),180)
 if roof:
  _portal(Vector3(-4.8,0,-2.8),"laundry","去洗衣房")
  _prop("plant_broadleaf",Vector3(-5.0,0,-2.3));_prop("plant_snake",Vector3(1.4,0,-2.4))
  for x in [-6,-3,0,3,6]:
   b.box(Vector3(1.9,2.5+absf(x)*.13,1.3),Vector3(float(x),-.5,-5),Color("829dac"))
 else:
  _portal(Vector3(-4.8,0,1.3),"alley","穿过绿荫小巷","path")
  for p in [Vector3(-4.6,0,-1.0),Vector3(3.8,0,-1.3)]:_asset("tree",p)
  _asset("streetlamp",Vector3(4.0,0,2.4));_asset("noticeboard",Vector3(-4.8,0,2.2),20)
 _bounds(Vector2(12,6.7))

func _room_theme(theme: int) -> void:
 if theme<0:return
 floor_index=[7,2,0,2,7,0,9,0,3][theme];wall_index=[0,2,0,0,1,2,2,0,0][theme];_floor();_shell()
 if theme in [0,1,2,6,7,8]:
  for item in items.duplicate():
   if not (str(item.module_id).begins_with("window_") or str(item.module_id).begins_with("curtains_") or str(item.module_id).begins_with("door_") or str(item.module_id).begins_with("painting_")):
    items.erase(item);item.free()
 match theme:
  0:
   _prop("sofa_cream",Vector3(-2.2,0,.20));_prop("coffee_table",Vector3(-1.5,0,1.9));_prop("tv_cabinet",Vector3(1.4,0,-2.5))
   _prop("armchair_sage",Vector3(1.5,0,1.1));_prop("plant_fiddle",Vector3(-5.1,0,-2.4));_prop("lamp_floor",Vector3(-3.8,0,.4));_prop("tea_tray",Vector3(-1.5,.55,1.9))
  1:
   for spec in [["fridge",Vector3(-4.5,0,-2.7)],["sink_counter",Vector3(-2.8,0,-2.7)],["stove_counter",Vector3(-1.2,0,-2.7)],["dining_white",Vector3(0,0,1.7)]]:_prop(spec[0],spec[1])
   _prop("counter_blank",Vector3(.5,0,-2.7));_prop("upper_cabinet",Vector3(-2.8,1.6,-3));_prop("chair_white",Vector3(-1.35,0,1.7),90);_prop("chair_white",Vector3(1.35,0,1.7),-90);_prop("plate_rack",Vector3(.5,.97,-2.7))
  2:
   _prop("bookcase",Vector3(-4.5,0,-2.6));_prop("bookcase",Vector3(-2.8,0,-2.6));_prop("armchair_sage",Vector3(2.7,0,1.2));_prop("lamp_floor",Vector3(3.8,0,.9))
   _prop("desk_oak",Vector3(.3,0,-2.5));_prop("chair_oak",Vector3(.3,0,-1.4));_prop("open_book",Vector3(.3,.98,-2.5));_prop("side_table",Vector3(1.4,0,1.3))
  5:
   _prop("flowers",Vector3(1.5,.98,-2.5));_prop("basket",Vector3(4.3,0,1.8))
  6:
   for i in 5:_prop(["plant_fiddle","plant_broadleaf","plant_snake","fern","bonsai"][i],Vector3(-4.5+i*1.7,0,-1.8))
   _asset("planter",Vector3(2.7,0,1.85))
   _asset("bench",Vector3(-1.8,0,1.3));_prop("tea_trolley",Vector3(.6,0,.6))
  7:
   _prop("desk_white",Vector3(2.4,0,-2.4));_prop("chair_white",Vector3(2.4,0,-1.3));_prop("storage_box",Vector3(-3.7,0,.2));_prop("shelf_books",Vector3(-3.5,1.4,-3));_prop("whale_plush",Vector3(2.4,.98,-2.3));_prop("cubby",Vector3(-3.5,0,-2.6));_prop("dining_white",Vector3(0,0,1.1))
  8:
   _prop("dining_round",Vector3(1.5,0,.6));_prop("tea_trolley",Vector3(-3.8,0,-.8));_prop("tea_tray",Vector3(1.5,.9,.6));_prop("chair_white",Vector3(1.5,0,1.7));_prop("chair_white",Vector3(1.5,0,-.6),180);_prop("loveseat_navy",Vector3(-2,0,-1.6));_prop("side_table",Vector3(-1.3,0,.4));_prop("flowers",Vector3(-1.3,.75,.4))

func _physics_process(delta: float) -> void:
 if transitioning:
  player.velocity=Vector3.ZERO;return
 if map_panel and map_panel.visible:
  player.velocity=Vector3.ZERO;_set_character_pose(false);return
 super._physics_process(delta)
 if not district_ready:return
 nearest_portal={};var best:=1.25
 for portal in portals:
  var d: float=Vector2(player.position.x,player.position.z).distance_to(Vector2(portal.pos.x,portal.pos.z))
  if d<best:nearest_portal=portal;best=d
 var free_ui: bool=not panel.visible and not dialog_open and not settings_panel.visible and not loot.blocked() and not editing
 if destination_hint:
  destination_hint.visible=free_ui and not nearest_portal.is_empty() and get("map_interactions")==null
  if not nearest_portal.is_empty():
   destination_hint.text="E 通行";destination_hint.tooltip_text=str(nearest_portal.label)
   preload("res://ui/map_action_button.gd").place(destination_hint,camera,nearest_portal.pos+Vector3(0,1.25,0))
 if breadcrumb:breadcrumb.visible=free_ui and not has_method("_refresh_zone")
 if arrival_note:arrival_note.visible=free_ui and not has_method("_refresh_zone")
 _route_frame(free_ui)
 if free_ui and not nearest_portal.is_empty():hint.text="WASD 漫步 · 滚轮缩放 · Z 切换总览 · F5 保存进度"
 elif free_ui and not is_instance_valid(loot.nearby):hint.text="漫步鲸落港 · 找到门牌后按 E 进出 · M 查看街道与楼层"

func _interact() -> void:
 if map_panel and map_panel.visible:return
 if not nearest_portal.is_empty() and not loot.blocked() and not panel.visible and not dialog_open and not editing:
  request_travel(str(nearest_portal.target),str(nearest_portal.route));return
 if closest and str(closest.module_id).begins_with("door_"):return
 super._interact()

func _unhandled_input(event: InputEvent) -> void:
 if transitioning:
  get_viewport().set_input_as_handled();return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_M:
   _show_map(not map_panel.visible);get_viewport().set_input_as_handled();return
  if map_panel and map_panel.visible:
   if event.physical_keycode==KEY_ESCAPE:_show_map(false)
   get_viewport().set_input_as_handled();return
  if event.physical_keycode in [KEY_F2,KEY_F3,KEY_B,KEY_TAB] and locations[location_id].type!="room":
   hint.text="先进入房间，再布置自己的空间。";return
 super._unhandled_input(event)

func _district_ui() -> void:
 for i in 3:nav_buttons[i].text=["1 回家","2 街道","3 咖啡馆"][i]
 district_canvas=Control.new();district_canvas.theme=WhaleSkin.theme(_game_font());district_canvas.size=Vector2(1448,1086);district_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(district_canvas)
 # 画布宽度随窗口比例变化：根画布与遮罩铺满，居中类模态居中锚定，贴右元素钉右边缘
 UiFit.fill(district_canvas)
 var b_map:=_button("M 导览",Vector2(529,979),Vector2(168,55),district_canvas,func():_show_map(true))
 UiFit.pin_design(b_map,529,979,168,55)
 breadcrumb=WhaleSkin.label(district_canvas,"",Vector2(88,132),Vector2(1130,36),19,Color("edf2ed"))
 var crumb_style:=_flat(Color(.09,.17,.23,.88),8);crumb_style.content_margin_left=12;crumb_style.content_margin_right=12;breadcrumb.add_theme_stylebox_override("normal",crumb_style);breadcrumb.size.x=850
 arrival_note=WhaleSkin.label(district_canvas,"",Vector2(89,175),Vector2(1020,33),18,Color("bfced4"))
 arrival_note.add_theme_stylebox_override("normal",crumb_style);arrival_note.size.x=850
 destination_hint=preload("res://ui/map_action_button.gd").create(self,district_canvas,"E 通行",func():
  if not nearest_portal.is_empty() and not transitioning and not loot.blocked():_interact())
 destination_hint.name="NearbyPortalButton";destination_hint.hide()
 map_shade=ColorRect.new();map_shade.color=Color(.04,.10,.16,.65);map_shade.size=Vector2(1448,1086);district_canvas.add_child(map_shade);map_shade.hide()
 UiFit.fill(map_shade)
 map_panel=Panel.new();map_panel.position=Vector2(85,135);map_panel.size=Vector2(1278,805);map_panel.add_theme_stylebox_override("panel",WhaleSkin.frame());district_canvas.add_child(map_panel);map_panel.hide()
 UiFit.pin_center(map_panel,1278,135,805)
 _navigation_ui()

func _flat(color: Color,radius: int,border: Color=Color.TRANSPARENT) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(radius)
 if border.a>0:style.set_border_width_all(2);style.border_color=border
 return style

func _group_name(group: String) -> String:
 return {"outside":"街道与公共区域","floor1":"1F · 共享生活层","floor2":"2F · 住户层","floor3":"3F · 兴趣与屋顶"}.get(group,group)

func _show_map(show: bool) -> void:
 if not show:map_panel.hide();map_shade.hide();return
 if route_card:route_card.hide()
 if route_marker:route_marker.hide()
 panel.hide();settings_panel.hide();dialog.hide();dialog_open=false;loot.close();editing=false
 map_tab=str(locations[location_id].group);_render_map();map_panel.show();map_shade.show()

func _render_map() -> void:
 for child in map_panel.get_children():
  map_panel.remove_child(child);child.queue_free()
 var view:=GuideView.new();map_panel.add_child(view);view.configure(self)

func _remember_room() -> void:
 if locations[location_id].type!="room":return
 var records: Array=[]
 for item in items:
  if item.has_meta("placement") and not str(item.module_id).begins_with("door_"):records.append(item.get_meta("placement"))
 room_edits[location_id]={"items":records,"floor":floor_index,"wall":wall_index}

func _restore_room_edits() -> void:
 if not room_edits.has(location_id):return
 for item in items.duplicate():
  if not str(item.module_id).begins_with("door_"):items.erase(item);item.free()
 var data: Dictionary=room_edits[location_id]
 floor_index=int(data.floor);wall_index=int(data.wall);_floor();_shell()
 for entry in data.items:
  if catalog.has(entry.id):_spawn(entry)

func _save() -> bool:
 if not district_ready:return super._save()
 _remember_room()
 var file:=FileAccess.open("user://whale_neighborhood_v11.json",FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify({"version":2,"location":location_id,"visited":visited,"rooms":room_edits,"player":[player.position.x,player.position.z],"favorites":favorites,"route":route_destination}))
 hint.text="已经记住你在街区里的位置和各个房间的布置。";return true

func _restore() -> bool:
 if not district_ready:return super._restore()
 if not FileAccess.file_exists("user://whale_neighborhood_v11.json"):return false
 var data=JSON.parse_string(FileAccess.get_file_as_string("user://whale_neighborhood_v11.json"))
 if not data is Dictionary or not locations.has(data.get("location","")):return false
 room_edits=data.get("rooms",{});visited=data.get("visited",{})
 favorites=data.get("favorites",{});route_destination=str(data.get("route",""))
 items.clear();_travel(str(data.location))
 if data.get("player") is Array and data.player.size()==2:player.position=Vector3(float(data.player[0]),0,float(data.player[1]))
 return true

func _navigation_ui() -> void:
 route_card=Panel.new();route_card.position=Vector2(1034,140);route_card.size=Vector2(366,164);route_card.add_theme_stylebox_override("panel",WhaleSkin.frame());district_canvas.add_child(route_card);route_card.hide()
 UiFit.pin_right(route_card,366,48,140,164)
 route_title=WhaleSkin.label(route_card,"",Vector2(18,14),Vector2(289,32),20,Color("2d5262"))
 route_detail=WhaleSkin.label(route_card,"",Vector2(18,57),Vector2(330,73),17,Color("64838d"))
 var cancel:=_button("×",Vector2(313,11),Vector2(36,34),route_card,func():set_route(""));cancel.add_theme_stylebox_override("normal",_flat(Color("e1ebea"),8))
 route_marker=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.28;ring.outer_radius=.36;ring.rings=32;ring.ring_segments=8;route_marker.mesh=ring
 var material:=StandardMaterial3D.new();material.albedo_color=Color("86d5d3");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;route_marker.material_override=material;route_marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(route_marker);route_marker.hide()

func find_route(start: String,destination: String) -> Array:
 if not locations.has(start) or not locations.has(destination):return []
 var queue: Array=[start];var previous: Dictionary={};previous[start]=""
 while not queue.is_empty():
  var current: String=str(queue.pop_front())
  if current==destination:break
  for neighbor in locations[current].links:
   if locations.has(neighbor) and not previous.has(neighbor):previous[neighbor]=current;queue.append(neighbor)
 if not previous.has(destination):return []
 var result: Array=[];var cursor:=destination
 while cursor!="":result.push_front(cursor);cursor=str(previous[cursor])
 return result

func set_route(destination: String) -> void:
 route_destination=destination;_refresh_route();_show_map(false)

func _refresh_route() -> void:
 if not route_marker:return
 if route_destination==location_id:
  route_destination=""
  if arrival_note:arrival_note.text="已到达目的地 · "+str(locations[location_id].name)
 route_steps=find_route(location_id,route_destination) if route_destination!="" else []
 if route_steps.size()<2:route_marker.hide();route_card.hide();return
 var has_exit:=false
 for portal in portals:
  if portal.target==route_steps[1]:
   route_marker.position=portal.pos+Vector3(0,.064,0);has_exit=true;break
 if not has_exit:route_steps=[];route_marker.hide();route_card.hide()

func _route_frame(free_ui: bool) -> void:
 if not route_card:return
 var show_route: bool=free_ui and route_steps.size()>1
 route_card.visible=show_route;route_marker.visible=show_route
 if not show_route:return
 route_title.text="去 "+str(locations[route_destination].name)
 var distance: float=Vector2(player.position.x,player.position.z).distance_to(Vector2(route_marker.position.x,route_marker.position.z))
 route_detail.text="下一步："+str(locations[route_steps[1]].name)+"\n入口约 %.1f m  ·  还需经过 %d 处\n靠近浅蓝圆环后按 E"%[distance,route_steps.size()-1]
 route_marker.scale=Vector3.ONE*(.97+.03*sin(Time.get_ticks_msec()*.005))

func request_travel(target: String,route: String="") -> void:
 if transitioning or not locations.has(target):return
 if combat_controller and combat_controller.in_battle():return
 var expedition=get("expedition_controller")
 if expedition and expedition.is_active() and target!="research":return
 var loading=preload("res://ui/loading_transition.gd").instance(get_tree())
 if not loading.begin(str(locations[target].name)):return
 transitioning=true;player.velocity=Vector3.ZERO;avatar.play("idle_"+facing)
 SfxDirector.play("door",-4.0)
 await loading.reveal()
 await _travel(target,route,true)
 await loading.checkpoint(.95,"准备场景交互")
 await loading.finish()
 transitioning=false
