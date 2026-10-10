extends Node3D
const CATEGORIES: Array[String]=["safes","storage","living","restaurant","utility","decor","retail","lab","medical","logistics","lounge","architecture"]
const TITLES: Array[String]=["保险盒与保管柜","收纳与储物","现代生活家具","餐厅与厨房","生活设备与科技","灯具与室内装饰","零售与商店","实验室器材","医疗与护理","仓储与维修","公共休闲家具","建筑模块"]
var catalog: Array
var category:=6
var focused:=-1
var objects: Array[Node3D]=[]
var stage: Node3D
var labels: Array[Label]=[]
var camera: Camera3D
var title: Label
var detail: Label
var font: Font
var yaw:=.28
var pitch:=.65
var zoom:=1.0
var spin:=false
var overlay: Control
var tick:=0
var demo:=false
var room_mode:=false
var failure:=0
func _ready() -> void:
 catalog=JSON.parse_string(FileAccess.get_file_as_string("res://interior_pack/catalog.json"))
 var face:=FontVariation.new();face.base_font=load("res://interior_pack/assets/NotoSansSC.ttf");face.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):600.0};font=face
 var env:=WorldEnvironment.new();var settings:=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("16283e");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("d9e8fa");settings.ambient_light_energy=.28;settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.environment=settings;add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-32,0);light.light_color=Color("fff1dc");light.light_energy=.50;light.shadow_enabled=true;light.directional_shadow_max_distance=35;light.shadow_bias=.14;light.shadow_normal_bias=1.3;add_child(light)
 var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-25,145,0);fill.light_color=Color("c8e7ff");fill.light_energy=.12;add_child(fill)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;add_child(camera)
 _ui();_populate()
 var args:=OS.get_cmdline_user_args();demo="--demo" in args
 if "--verify" in args:call_deferred("_verify")
 if "--thumbs" in args:call_deferred("_thumbnails")
func _material(color: String,emission: bool=false) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=.73
 if emission:m.emission_enabled=true;m.emission=Color(color);m.emission_energy_multiplier=.8
 return m
func _box(parent: Node3D,size: Vector3,pos: Vector3,color: String) -> void:
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=size;mesh.mesh=box;mesh.material_override=_material(color,color=="56d5dd");mesh.position=pos;parent.add_child(mesh)
func _ui() -> void:
 var layer:=CanvasLayer.new();layer.layer=20;add_child(layer);overlay=Control.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.size=Vector2(1280,900);layer.add_child(overlay)
 var theme:=Theme.new();theme.default_font=font;theme.default_font_size=18;theme.set_color("font_color","Button",Color("283f68"));theme.set_color("font_hover_color","Button",Color("466a9b"));theme.set_color("font_pressed_color","Button",Color.WHITE)
 for key in ["normal","hover","pressed","disabled"]:
  var b:=StyleBoxFlat.new();b.bg_color=Color("6286b9" if key=="pressed" else ("dceeff" if key=="hover" else "f5f2e9"));b.border_color=Color("7088af");b.set_border_width_all(2);b.set_corner_radius_all(9);b.content_margin_left=12;b.content_margin_right=12;b.content_margin_top=6;b.content_margin_bottom=6;theme.set_stylebox(key,"Button",b)
 overlay.theme=theme
 title=_label("",Vector2(30,22),Vector2(1200,42),30,Color("edf4ff"))
 for i in CATEGORIES.size():_button(TITLES[i],Vector2(30+(i%6)*209,81+(i/6)*52),Vector2(196,44),func():category=i;focused=-1;room_mode=false;zoom=1;_populate())
 detail=_label("",Vector2(31,791),Vector2(1190,63),18,Color("d8e6f5"))
 _label("点物品查看 · 右键拖动镜头 · 滚轮缩放 · E / 空格开合 · A自动旋转 · Esc回分类",Vector2(31,858),Vector2(1128,30),17,Color("9cb6d4"))
 _button("场景搭配",Vector2(1124,855),Vector2(122,32),func():room_mode=not room_mode;focused=-1;_populate())
func _label(text: String,pos: Vector2,size: Vector2,fs: int,color: Color) -> Label:
 var l:=Label.new();l.text=text;l.position=pos;l.size=size;l.add_theme_font_size_override("font_size",fs);l.add_theme_color_override("font_color",color);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(l);return l
func _button(text: String,pos: Vector2,size: Vector2,callback: Callable) -> Button:
 var b:=Button.new();b.text=text;b.position=pos;b.size=size;b.pressed.connect(callback);overlay.add_child(b);return b
func _populate() -> void:
 if stage:remove_child(stage);stage.queue_free()
 for l in labels:l.queue_free()
 labels.clear();objects.clear();stage=Node3D.new();add_child(stage)
 title.text="大肥鱼 · 144件室内3D物品 / "+TITLES[category]
 if focused>=0:
  var data: Dictionary=catalog[focused];_item(data,Vector3.ZERO)
  var sx:=float(data.size[0]);var sz:=float(data.size[2]);var span:=maxf(sx,sz)
  _box(stage,Vector3(maxf(1.6,span*1.25),.045,maxf(1.6,span*1.25)),Vector3(0,-.025,0),"abbac8")
  title.text="大肥鱼 · "+str(data.name)+" / 可旋转真实3D模型"
  detail.text="GLB + 独立 .tscn  ·  "+str(int(data.triangles))+" 三角形 / "+str(int(data.mesh_parts))+" 网格部件  ·  "+str(data.size)+" 米\n"+("E：平滑开合门 / 抽屉" if not data.moving.is_empty() else "这个物品没有活动部件")
 elif room_mode:_room()
 else:
  _box(stage,Vector3(15.7,.06,6.0),Vector3(0,-.06,0),"b7c4cc")
  for col in range(7):_box(stage,Vector3(.012,.005,6.0),Vector3(-7.8+col*2.6,-.026,0),"95a7b6")
  for row in range(3):_box(stage,Vector3(15.7,.005,.012),Vector3(0,-.026,-3+row*3),"95a7b6")
  for i in 12:
   var data: Dictionary=catalog[category*12+i];var pos:=Vector3((i%6-2.5)*2.55,0,(i/6-.5)*2.85)
   _box(stage,Vector3(2.2,.06,2.42),pos+Vector3(0,-.019,0),"cdd7df");_item(data,pos)
   var l:=_label(data.name,Vector2.ZERO,Vector2(200,30),18,Color("e7f2ff"));l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.add_theme_color_override("font_outline_color",Color("18334f"));l.add_theme_constant_override("outline_size",4);labels.append(l)
  detail.text="12 件不同结构的物品 · 所有物品具有顶面 / 侧面、倒角和 PBR 材质。活动部件可用 E 平滑开合。\nGLB 可直接导入 Godot；场景附带碰撞和交互。"
 yaw=.24;pitch=.69;zoom=1;_camera()
func _item(data: Dictionary,pos: Vector3) -> void:
 var object:=load(data.scene).instantiate() as Node3D;object.position=pos;stage.add_child(object);objects.append(object)
func _room() -> void:
 title.text="大肥鱼 · 现代餐厅 / 真实模块搭配"
 _box(stage,Vector3(10,.10,6.8),Vector3(0,-.06,0),"c4cfd5")
 _box(stage,Vector3(10,2.6,.10),Vector3(0,1.3,-3.4),"e0e5e6")
 _box(stage,Vector3(.10,2.6,6.8),Vector3(-5,1.3,0),"d3dee4")
 for i in range(11):_box(stage,Vector3(.012,.004,6.8),Vector3(-5+i,-.005,0),"a3b4c0")
 for i in range(8):_box(stage,Vector3(10,.004,.012),Vector3(0,-.005,-3.4+i*.97),"a3b4c0")
 _box(stage,Vector3(8.8,.022,.022),Vector3(0,.20,-3.33),"56d5dd")
 var arrangement: Array=[ ["restaurant_05",Vector3(1.8,0,-2.55)],["restaurant_02",Vector3(1.8,1.10,-2.55)],["restaurant_07",Vector3(3.70,0,-2.53)],["restaurant_04",Vector3(.5,0,-1.50)],["restaurant_06",Vector3(-4.5,0,-2.89)],["decor_02",Vector3(-1.7,0,-2.85)],["decor_06",Vector3(0,1.45,-3.31)],["restaurant_08",Vector3(-2.9,0,.05)],["restaurant_08",Vector3(-2.9,0,1.90)],["restaurant_11",Vector3(-4.4,0,.10)],["restaurant_11",Vector3(-4.4,0,1.95)],["living_08",Vector3(-1.9,0,.12)],["living_08",Vector3(-1.9,0,1.90)],["living_08",Vector3(-2.9,0,.98)],["living_08",Vector3(-2.9,0,2.85)],["decor_01",Vector3(4.20,0,2.3)],["safes_08",Vector3(3.5,0,.35)],["decor_12",Vector3(.70,0,2.70)]]
 if category==7 or category==8:
  title.text="大肥鱼 · 现代实验室 / 可复用建筑内景"
  arrangement=[["lab_01",Vector3(-3.8,0,-2.85)],["lab_06",Vector3(3.9,0,-2.95)],["lab_10",Vector3(1.3,0,-2.8)],["lounge_01",Vector3(1.3,0,-1.85)],["lab_12",Vector3(-2.0,0,-1.5)],["lab_07",Vector3(3.8,0,-.5)],["living_07",Vector3(-2.9,0,.65)],["lab_02",Vector3(-3.1,1.05,.65)],["lab_03",Vector3(-2.5,1.05,.65)],["living_07",Vector3(.2,0,.65)],["lab_04",Vector3(-.05,1.05,.65)],["lab_11",Vector3(.65,1.05,.65)],["medical_12",Vector3(3.6,0,1.6)],["lab_05",Vector3(1.4,.805,-2.7)],["architecture_10",Vector3(-4.7,0,2.6)],["decor_01",Vector3(4.3,0,2.5)]]
 elif category==6:
  title.text="大肥鱼 · 现代便利店 / 可复用建筑内景"
  arrangement=[["retail_01",Vector3(3.5,0,-1.5)],["retail_02",Vector3(-4.3,0,-2.8)],["retail_10",Vector3(4.3,0,-2.9)],["retail_03",Vector3(-1.6,0,-.7)],["retail_03",Vector3(.65,0,-.7)],["retail_07",Vector3(-1.6,0,1.9)],["retail_04",Vector3(2.5,0,1.9)],["decor_12",Vector3(-4.2,0,2.6)],["retail_11",Vector3(-2.7,0,-3.1)],["decor_01",Vector3(4.3,0,2.4)]]
 for entry in arrangement:
  for data in catalog:
   if data.id==entry[0]:_item(data,entry[1]);break
 detail.text="示范：切换“零售 / 实验室 / 其他分类”再打开场景搭配，可查看三种内景。物品均来自144件素材库。\n点击“场景搭配”回到分类；右键拖动可以查看另一侧。"
func _camera() -> void:
 var target:=Vector3(0,.7,0);var radius:=18.0;camera.size=12.0*zoom
 if focused>=0:
  var data: Dictionary=catalog[focused];target=Vector3(0,float(data.size[1])*.48,0);camera.size=maxf(1.0,maxf(float(data.size[1]),maxf(float(data.size[0]),float(data.size[2])))*2.3)*zoom;radius=6
 elif room_mode:camera.size=12.0*zoom;target=Vector3(0,.80,-.1)
 camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*radius;camera.look_at(target)
func _process(delta: float) -> void:
 if spin:yaw+=delta*(.22 if demo else .35);_camera()
 for i in labels.size():
  if i>=objects.size():break
  var point:=camera.unproject_position(objects[i].position+Vector3(0,0,1.25));labels[i].position=point-Vector2(100,0)
 if demo:
  tick+=1
  if tick==1:category=11;focused=132;_populate();spin=true
  if tick==60:_action()
  if tick==170:_action()
  if tick==240:category=7;focused=85;_populate()
  if tick==270:_action()
  if tick==355:category=6;focused=-1;_populate();spin=false
  if tick==435:category=8;_populate()
  if tick==515:category=9;_populate()
  if tick==595:category=10;_populate()
  if tick==675:category=11;_populate()
  if tick==755:category=7;room_mode=true;_populate();spin=true
func _action() -> void:
 for object in objects:
  if object.has_action():object.interact()
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT:yaw-=event.relative.x*.007;pitch=clampf(pitch+event.relative.y*.005,-1.15,1.30);_camera()
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=clampf(zoom*.90,.5,1.6);_camera()
  if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=clampf(zoom*1.10,.5,1.6);_camera()
  if event.button_index==MOUSE_BUTTON_LEFT and focused<0 and not room_mode:
   var best:=80.0;var index:=-1
   for i in objects.size():
    var object:=objects[i];var point:=camera.unproject_position(object.position+Vector3(0,.5,0));var dist:=point.distance_to(event.position)
    if dist<best:best=dist;index=i
   if index>=0:focused=category*12+index;_populate()
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode in [KEY_E,KEY_SPACE]:_action()
  if event.keycode==KEY_A:spin=not spin
  if event.keycode==KEY_ESCAPE:focused=-1;room_mode=false;spin=false;_populate()
  if event.keycode==KEY_LEFT:category=posmod(category-1,CATEGORIES.size());focused=-1;_populate()
  if event.keycode==KEY_RIGHT:category=(category+1)%CATEGORIES.size();focused=-1;_populate()
func _check(ok: bool,text: String) -> void:
 if ok:print("PASS: ",text)
 else:failure+=1;push_error("FAIL: "+text)
func _verify() -> void:
 _check(catalog.size()==144,"144 independent asset definitions")
 var animated:=0
 for data in catalog:
  var object:=load(data.scene).instantiate() as Node3D;add_child(object)
  var meshes:=object.find_children("*","MeshInstance3D",true,false)
  _check(meshes.size()==int(data.mesh_parts),str(data.id)+" actual 3D mesh parts imported")
  var tris:=0
  for mesh in meshes:
   for surface in mesh.mesh.get_surface_count():tris+=mesh.mesh.surface_get_array_len(surface)/3
  _check(tris==int(data.triangles),str(data.id)+" triangle count matches actual imported mesh")
  var aabb:=AABB()
  for mesh in meshes:
   var bounds: AABB=mesh.global_transform*mesh.get_aabb();aabb=aabb.merge(bounds)
  _check(aabb.size.x>.1 and aabb.size.y>.1 and aabb.size.z>.035,str(data.id)+" has volumetric geometry")
  var bodies:=object.find_children("*","StaticBody3D",true,false)
  if not bodies.is_empty():_check(bodies[0].get_child(0).shape is BoxShape3D,str(data.id)+" native collision shape available")
  if object.has_action():
   animated+=1;object.set_open(true);await get_tree().create_timer(.8).timeout
   for move in data.moving:
    var part:=object.find_child(move.node,true,false) as Node3D;var original: Transform3D=object.origins[move.node]
    _check(part.transform!=original,str(data.id)+" / "+str(move.node)+" moves smoothly")
   if object.passage:
    await get_tree().physics_frame
    _check(object.get_node("DoorBlocker/Shape").disabled,str(data.id)+" open doorway permits passage")
    var query:=PhysicsRayQueryParameters3D.create(Vector3(0,float(data.size[1])*.45,1),Vector3(0,float(data.size[1])*.45,-1),1)
    _check(get_world_3d().direct_space_state.intersect_ray(query).is_empty(),str(data.id)+" open doorway physics ray is clear")
   object.set_open(false);await get_tree().create_timer(.8).timeout
   for move in data.moving:
    var part:=object.find_child(move.node,true,false) as Node3D;var original: Transform3D=object.origins[move.node]
    _check(part.transform.is_equal_approx(original),str(data.id)+" / "+str(move.node)+" closes correctly")
   if object.passage:
    await get_tree().physics_frame
    _check(not object.get_node("DoorBlocker/Shape").disabled,str(data.id)+" closed doorway blocks passage")
    var query:=PhysicsRayQueryParameters3D.create(Vector3(0,float(data.size[1])*.45,1),Vector3(0,float(data.size[1])*.45,-1),1)
    _check(not get_world_3d().direct_space_state.intersect_ray(query).is_empty(),str(data.id)+" closed doorway physics ray hits collider")
   var player:=object.find_child("AnimationPlayer",true,false) as AnimationPlayer
   _check(player!=null and player.get_animation_list().size()>=2,str(data.id)+" GLB contains reusable native animation clips")
  if data.id=="architecture_03":
   await get_tree().physics_frame
   for step in 10:
    var z:=float(data.size[2])/2.0-(step+.5)*float(data.size[2])/10.0
    var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,4,z),Vector3(0,-.1,z),1))
    _check(not hit.is_empty() and absf(float(hit.position.y)-(step+1)*.165)<.002,"stair step "+str(step+1)+" has correct physical height")
  remove_child(object);object.queue_free()
 _check(animated>=40,"at least 40 assets include native open/close parts")
 print("ALL ASSET CHECKS PASSED" if failure==0 else "FAILURES: "+str(failure));get_tree().quit(0 if failure==0 else 1)
func _thumbnails() -> void:
 overlay.hide();get_viewport().transparent_bg=true
 var env: WorldEnvironment=find_children("*","WorldEnvironment",true,false)[0];env.environment.background_color=Color(0,0,0,0)
 for i in catalog.size():
  focused=i;room_mode=false;_populate();yaw=.50;pitch=.56;_camera()
  # Export mesh-only view, excluding the display plinth.
  for child in stage.get_children():
   if child is MeshInstance3D:child.hide()
  for n in 3:await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://interior_pack/assets/thumbnails/"+str(catalog[i].id)+".png")
 print("144 actual Godot thumbnail renders saved");get_tree().quit()
