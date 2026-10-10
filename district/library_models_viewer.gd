extends Node3D
## Inspect the actual GLB geometry; this scene does not replace the game's menu.
const Library=preload("res://district/library_models.gd")
const IDS=["safe_floor","safe_tall","safe_compact","token_atm","bench","street_lamp","supply_crate","water_barrel","whale_fountain","whale_statue","recycling_bin","whale_sign","tree_oak","tree_pine","tree_birch","tree_cherry","tree_palm","tree_autumn","tree_snow_pine","tree_dead","bush_berry","shrub","stump","fallen_log"]
var entries: Array=[]
var selected:=0
var model: Node3D
var camera: Camera3D
var selector: OptionButton
var details: Label
var ui: CanvasLayer
var target:=Vector3.ZERO
var yaw:=.55
var pitch:=.54
var framing:=4.0
var zoom:=1.0
var dragging:=false
var rotating:=false

func _ready() -> void:
 var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://models/library_props/library_catalog.json"))
 for id in IDS:
  for entry in catalog:
   if entry.id=="library_"+id:entries.append(entry);break
 var environment:=WorldEnvironment.new();var env:=Environment.new()
 env.background_mode=Environment.BG_COLOR;env.background_color=Color("192b3b")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d1d9df");env.ambient_light_energy=.35
 environment.environment=env;add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_color=Color("fff4dc");sun.light_energy=.55;sun.shadow_enabled=true;add_child(sun)
 var floor_mesh:=PlaneMesh.new();floor_mesh.size=Vector2(200,200)
 var ground:=MeshInstance3D.new();ground.mesh=floor_mesh
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("7a9093");mat.roughness=.9;ground.material_override=mat;add_child(ground)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;add_child(camera)
 _interface();show_model(0)

func _interface() -> void:
 ui=CanvasLayer.new();add_child(ui)
 var panel:=PanelContainer.new();panel.position=Vector2(22,22);panel.custom_minimum_size=Vector2(380,0);ui.add_child(panel)
 var style:=StyleBoxFlat.new();style.bg_color=Color("192b3bef");style.border_color=Color("bca46d");style.set_border_width_all(1);style.set_corner_radius_all(12);style.set_content_margin_all(18);panel.add_theme_stylebox_override("panel",style)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",12);panel.add_child(box)
 var title:=Label.new();title.text="蓝鲸港 · 24 件三维模型";title.add_theme_font_size_override("font_size",26);box.add_child(title)
 selector=OptionButton.new();selector.custom_minimum_size=Vector2(350,42)
 for n in entries.size():selector.add_item(str(n+1)+" / "+str(entries[n].name).replace("资料库 · ",""))
 selector.item_selected.connect(show_model);box.add_child(selector)
 var row:=HBoxContainer.new();box.add_child(row)
 for pair in [["上一件",-1],["下一件",1]]:
  var button:=Button.new();button.text=pair[0];button.custom_minimum_size=Vector2(170,40)
  button.pressed.connect(func():show_model(posmod(selected+int(pair[1]),entries.size())));row.add_child(button)
 var angles:=HBoxContainer.new();box.add_child(angles)
 for pair in [["正面",.55],["背面",PI+.55],["侧面",PI/2]]:
  var button:=Button.new();button.text=pair[0];button.custom_minimum_size=Vector2(110,38)
  button.pressed.connect(func():yaw=float(pair[1]);pitch=.54;zoom=1;_camera());angles.add_child(button)
 var spin:=CheckButton.new();spin.text="自动旋转";spin.toggled.connect(func(value: bool):rotating=value);box.add_child(spin)
 details=Label.new();details.add_theme_color_override("font_color",Color("cadbdc"));box.add_child(details)
 var help:=Label.new();help.text="拖动：旋转视角  ·  滚轮：缩放\n方向键：切换物件  ·  F：复位视角\n全部为三维几何，材质与 v22 共用";help.add_theme_font_size_override("font_size",16);box.add_child(help)

func show_model(index: int) -> void:
 selected=index;selector.select(index)
 if is_instance_valid(model):remove_child(model);model.queue_free()
 var entry: Dictionary=entries[index]
 model=Library.instance(entry.id);add_child(model)
 var size:=Vector3(entry.size[0],entry.size[1],entry.size[2])
 target=Vector3(entry.center[0],size.y*.50,entry.center[2])
 framing=maxf(size.y*1.5,maxf(size.x,size.z)*1.55)+.4
 yaw=.55;pitch=.54;zoom=1;_camera()
 details.text="城镇物品" if index<12 else "树木与自然物件"
 details.text+="  ·  "+str(entry.surfaces)+" 种材质\n碰撞："+("树干可阻挡，树冠可穿行" if entry.collision=="trunk" else "与物件外形范围对齐")

func _camera() -> void:
 camera.size=framing*zoom
 camera.h_offset=-camera.size*.23 if ui.visible else 0.0
 camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*20
 camera.look_at(target)

func _process(delta: float) -> void:
 if rotating:yaw+=delta*.35;_camera()

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
  if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   zoom=clampf(zoom*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),.45,2);_camera()
 if event is InputEventMouseMotion and dragging:
  yaw-=event.relative.x*.008;pitch=clampf(pitch+event.relative.y*.005,.12,1.35);_camera()
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_LEFT:show_model(posmod(selected-1,entries.size()))
  if event.keycode==KEY_RIGHT:show_model(posmod(selected+1,entries.size()))
  if event.keycode==KEY_F:yaw=.55;pitch=.54;zoom=1;_camera()
