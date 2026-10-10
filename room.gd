extends Node2D
const Module = preload("res://module.gd")
const SPEED := 190.0
const ROOM := Rect2(144,288,1152,640)
const FLOOR_NAMES := ["oak","pale_oak","walnut","herringbone","ivory_tile","slate_tile","concrete","marble","terrazzo","navy_carpet","tatami","metal_grid"]
const WALL_NAMES := ["plaster_ivory","oak_slats","walnut_slats","slate_panels","concrete_panels","navy_padded","plaster_mint","cream_tile","brushed_metal","beige_wainscot","white_marble","pale_wainscot"]
var catalog: Dictionary
var world: Node2D
var shell: Node2D
var floor_map: TileMapLayer
var player: CharacterBody2D
var avatar: AnimatedSprite2D
var facing := "down"
var frames: SpriteFrames
var items: Array = []
var layout_index := 0
var floor_index := 0
var wall_index := 0
var editing := false
var selected := "plant_broadleaf"
var ui: CanvasLayer
var title: Label
var hint: Label
var panel: Panel
var catalog_page := 0
var catalog_ids: Array = []
var ghost: Sprite2D
var dialog: Panel
var message: Label
var dialog_open := false
var closest: Node2D
var demo := false
var tick := 0
var movement := Vector2.ZERO
var failures := 0

func _ready() -> void:
 catalog = Module.get_catalog()
 catalog_ids = catalog.keys()
 demo = "--demo" in OS.get_cmdline_user_args()
 RenderingServer.set_default_clear_color(Color("111b28"))
 floor_map = TileMapLayer.new()
 floor_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 floor_map.z_index = -10
 add_child(floor_map)
 shell = Node2D.new()
 shell.z_index = -5
 add_child(shell)
 world = Node2D.new()
 world.y_sort_enabled = true
 add_child(world)
 _player()
 _ui()
 _layout(0)
 ghost = Sprite2D.new()
 ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 ghost.modulate = Color(0.7,1,0.8,0.7)
 ghost.z_index = 20
 add_child(ghost)
 if "--test-room" in OS.get_cmdline_user_args():call_deferred("_test")

func _player() -> void:
 player = CharacterBody2D.new()
 player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
 var hit := CollisionShape2D.new()
 var circle := CircleShape2D.new()
 circle.radius=13
 hit.shape=circle
 hit.position.y=-7
 player.add_child(hit)
 var shadow := Polygon2D.new()
 var points := PackedVector2Array()
 for i in 24:points.append(Vector2(cos(TAU*i/24)*32,sin(TAU*i/24)*9-3))
 shadow.polygon=points
 shadow.color=Color(0.05,0.07,0.10,0.24)
 player.add_child(shadow)
 frames=_build_frames()
 avatar=AnimatedSprite2D.new()
 avatar.sprite_frames=frames
 avatar.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 avatar.position=Vector2(0,-78)
 avatar.scale=Vector2(0.78,0.78)
 avatar.animation_finished.connect(func():avatar.play("idle_"+facing))
 player.add_child(avatar)
 world.add_child(player)
 avatar.play("idle_down")

func _floor() -> void:
 floor_map.tile_set=load("res://assets/floors/floor_library.tres")
 floor_map.clear()
 floor_map.position=ROOM.position
 for y in 10:
  for x in 18:floor_map.set_cell(Vector2i(x,y),floor_index,Vector2i.ZERO)

func _shell() -> void:
 for child in shell.get_children():child.free()
 for i in 9:
  _spawn(WALL_NAMES[wall_index],Vector2(208+i*128,288),shell)
  _spawn("cap_oak",Vector2(208+i*128,96),shell)
  _spawn("base_oak",Vector2(208+i*128,297),shell)
 for side in [144,1296]:
  var side_wall := Polygon2D.new()
  side_wall.polygon=PackedVector2Array([Vector2(side-16,96),Vector2(side+16,112),Vector2(side+16,928),Vector2(side-16,946)])
  side_wall.color=Color("4d5255")
  shell.add_child(side_wall)
  for y in range(288,929,160):_spawn("post_oak",Vector2(side,y),shell)
 for box in [Rect2(112,128,32,800),Rect2(1296,128,32,800),Rect2(144,260,1152,28),Rect2(144,928,1152,24)]:
  var b := StaticBody2D.new()
  var c := CollisionShape2D.new()
  var shape := RectangleShape2D.new()
  shape.size=box.size;c.shape=shape;b.position=box.get_center();b.add_child(c);shell.add_child(b)
 var sill := Polygon2D.new()
 sill.polygon=PackedVector2Array([Vector2(128,928),Vector2(1312,928),Vector2(1312,948),Vector2(128,948)])
 sill.color=Color("81705d")
 shell.add_child(sill)

func _spawn(id: String, pos: Vector2, parent: Node2D = world, base_y: float = -1) -> Node2D:
 var obj = load("res://scenes/modules/"+id+".tscn").instantiate()
 obj.position=pos
 parent.add_child(obj)
 if base_y>=0:
  obj.position.y=base_y
  obj.visual.position.y-=base_y-pos.y
  obj.z_index=0
 return obj

func _layout(index: int) -> void:
 layout_index=index
 for child in world.get_children():
  if child!=player:child.free()
 items.clear()
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://layouts/"+["bedroom","studio","reading_cafe"][index]+".json"))
 floor_index=FLOOR_NAMES.find(data.floor)
 wall_index=WALL_NAMES.find(data.wall)
 _floor();_shell()
 for item in data.items:
  var obj := _spawn(item.id,Vector2(item.x,item.y),world,float(item.get("sort_y",-1)))
  obj.set_meta("placement",item.duplicate())
  items.append(obj)
 player.position=Vector2(data.spawn[0],data.spawn[1])
 player.velocity=Vector2.ZERO
 dialog_open=false;dialog.hide()
 title.text="大肥鱼的房间  /  "+str(data.name)
 _rug(Vector2(740,810),Vector2(480,164),Color("40536a"))
 if ghost:ghost.hide()
 editing=false
 queue_redraw()

func _rug(pos: Vector2,size: Vector2,color: Color) -> void:
 var rug := Polygon2D.new()
 rug.position=pos
 rug.polygon=PackedVector2Array([-size/2,Vector2(size.x/2,-size.y/2),size/2,Vector2(-size.x/2,size.y/2)])
 rug.color=color
 rug.z_index=-4
 world.add_child(rug)
 var edge := Line2D.new()
 edge.points=rug.polygon
 edge.closed=true
 edge.width=6
 edge.default_color=Color("b7a38c")
 rug.add_child(edge)
 for x in [-160,-80,0,80,160]:
  var diamond := Line2D.new()
  diamond.points=PackedVector2Array([Vector2(x,-28),Vector2(x+26,0),Vector2(x,28),Vector2(x-26,0)])
  diamond.closed=true;diamond.width=3;diamond.default_color=Color("788798");rug.add_child(diamond)

func _physics_process(delta: float) -> void:
 var direction := movement
 if demo:
  tick+=1
  if tick==660:_layout(1)
  if tick==1260:_layout(2)
  if tick==1800:_catalog(true)
  if tick in [1920,2040,2160,2280,2400]:catalog_page=(tick-1800)/120;_catalog(true)
  if tick==2640:panel.hide();_layout(0)
  if tick==2700:_place("plant_fiddle",Vector2(548,808))
  if tick==2820:_place("whale_plush",Vector2(716,865))
  if tick==2940:floor_index=1;_floor()
  var local_tick := tick%600
  if tick<1800:
   direction=Vector2.RIGHT if local_tick<120 else (Vector2.UP if local_tick<240 else (Vector2.LEFT if local_tick<360 else (Vector2.DOWN if local_tick<480 else Vector2.ZERO)))
 else:
  direction+=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
 if dialog_open or panel.visible or editing:direction=Vector2.ZERO
 player.velocity=direction.limit_length()*SPEED
 player.move_and_slide()
 if direction.length_squared()>0.01:facing=_direction_name(direction)
 if not avatar.animation.begins_with("interact_") or not avatar.is_playing():
  var walking := player.get_real_velocity().length()>5
  var desired := ("walk_" if walking else "idle_")+facing
  if avatar.animation!=desired:avatar.play(desired)
 closest=null
 var distance := 125.0
 for item in items:
  if item.metadata.layer=="surface":continue
  var d: float = player.position.distance_to(item.position)
  if d<distance:distance=d;closest=item
 if editing:
  ghost.show();ghost.texture=load(catalog[selected].texture)
  var p := get_global_mouse_position().snapped(Vector2(16,16))
  ghost.position=p-Vector2(0,catalog[selected].size[1]/2.0)
  hint.text="摆放："+str(catalog[selected].name)+" · 左键放置 / 右键删除 · Tab换部件 · B结束 · F5保存"
 else:
  ghost.hide()
  if not dialog_open:hint.text="WASD 移动  ·  E 交互"+("："+str(closest.metadata.name) if closest else "")+"  ·  Tab 素材库  ·  B 摆放  ·  F2 地板 / F3 墙面"

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  match event.physical_keycode:
   KEY_1:_layout(0)
   KEY_2:_layout(1)
   KEY_3:_layout(2)
   KEY_TAB:_catalog(not panel.visible)
   KEY_B:editing=not editing;panel.hide();dialog.hide();dialog_open=false
   KEY_F2:floor_index=(floor_index+1)%12;_floor()
   KEY_F3:wall_index=(wall_index+1)%12;_shell()
   KEY_F5:_save()
   KEY_F9:_restore()
   KEY_E,KEY_ENTER,KEY_SPACE:_interact()
   KEY_ESCAPE:panel.hide();dialog.hide();dialog_open=false;editing=false
 if event is InputEventMouseButton and event.pressed and editing and not panel.visible:
  var p := get_global_mouse_position().snapped(Vector2(16,16))
  if event.button_index==MOUSE_BUTTON_LEFT:_place(selected,p)
  elif event.button_index==MOUSE_BUTTON_RIGHT:
   var nearest: Node2D
   var distance := 80.0
   for item in items:
    var d: float = item.position.distance_to(p)
    if d<distance:distance=d;nearest=item
   if nearest:items.erase(nearest);nearest.free()

func _place(id: String,p: Vector2) -> bool:
 if not catalog.has(id) or catalog[id].category=="floor":return false
 if not Rect2(160,160,1120,752).has_point(p):return false
 var data: Dictionary=catalog[id]
 if data.solid:
  var bounds := Rect2(p-Vector2(data.footprint[0]/2.0,data.footprint[1]-2),Vector2(data.footprint[0],data.footprint[1]))
  if bounds.grow(14).has_point(player.position):return false
 var object := _spawn(id,p)
 object.set_meta("placement",{"id":id,"x":p.x,"y":p.y})
 items.append(object)
 return true

func _interact() -> void:
 if dialog_open:dialog.hide();dialog_open=false;return
 if panel.visible or editing or closest==null:return
 if str(closest.module_id).begins_with("door_"):
  _layout((layout_index+1)%3)
  return
 facing=_direction_name(closest.position-player.position)
 avatar.play("interact_"+facing)
 var prose := "阳光落在这里。每件小物，都有自己的位置。"
 var id: String=closest.module_id
 if id.begins_with("bed_"):prose="被子晒得很暖。今天也从一个安静的早晨开始吧。"
 elif id.begins_with("desk_"):prose="昨天的笔记还放在桌上。先泡一杯茶，再继续写下去。"
 elif id.contains("chair") or id.contains("sofa") or id.contains("loveseat"):prose="坐在这里，可以听见窗外的风。休息一下，也是一种前进。"
 elif id.contains("plant") or id=="fern":prose="新叶子又长出来了。给它留一点光，也留一点水。"
 elif id=="bookcase":prose="书页里夹着一枚蓝色书签。故事还没有读完。"
 elif id.contains("window"):prose="城市正在慢慢醒来。远处的列车已经驶过第一座桥。"
 message.text="【"+str(closest.metadata.name)+"】\n"+prose+"\nE / Enter 继续"
 dialog.show();dialog_open=true

func _save() -> bool:
 var placements := []
 for item in items:placements.append(item.get_meta("placement"))
 var file := FileAccess.open("user://modular_room.json",FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify({"layout":layout_index,"floor":floor_index,"wall":wall_index,"items":placements,"player":[player.position.x,player.position.y]}))
 hint.text="已保存自定义布局 · F9恢复"
 return true

func _restore() -> bool:
 if not FileAccess.file_exists("user://modular_room.json"):return false
 var data = JSON.parse_string(FileAccess.get_file_as_string("user://modular_room.json"))
 if not data is Dictionary:return false
 for entry in data.items:
  if not catalog.has(entry.id):return false
 _layout(int(data.layout))
 for item in items:item.free()
 items.clear()
 floor_index=int(data.floor)%12;wall_index=int(data.wall)%12;_floor();_shell()
 for entry in data.items:
  var object := _spawn(entry.id,Vector2(entry.x,entry.y),world,float(entry.get("sort_y",-1)))
  object.set_meta("placement",entry);items.append(object)
 player.position=Vector2(data.player[0],data.player[1])
 return true

func _style() -> StyleBoxFlat:
 var box := StyleBoxFlat.new()
 box.bg_color=Color("1d2c40")
 box.border_color=Color("658393")
 box.set_border_width_all(2);box.set_corner_radius_all(8)
 return box

func _button(text: String,pos: Vector2,size: Vector2,parent: Node,action: Callable) -> Button:
 var button := Button.new()
 button.text=text;button.position=pos;button.size=size;button.focus_mode=Control.FOCUS_NONE
 button.add_theme_stylebox_override("normal",_style());button.add_theme_font_size_override("font_size",20)
 button.pressed.connect(action);parent.add_child(button)
 return button

func _ui() -> void:
 ui=CanvasLayer.new();add_child(ui)
 var theme := Theme.new();theme.default_font=load("res://assets/NotoSansSC.ttf")
 theme.default_font_size=22
 var canvas := Control.new();canvas.theme=theme;ui.add_child(canvas)
 title=Label.new();title.position=Vector2(140,28);title.add_theme_font_size_override("font_size",28);canvas.add_child(title)
 _button("1 卧室",Vector2(680,26),Vector2(148,46),canvas,func():_layout(0))
 _button("2 工作室",Vector2(840,26),Vector2(148,46),canvas,func():_layout(1))
 _button("3 阅读室",Vector2(1000,26),Vector2(148,46),canvas,func():_layout(2))
 _button("素材库",Vector2(1160,26),Vector2(146,46),canvas,func():_catalog(not panel.visible))
 hint=Label.new();hint.position=Vector2(144,977);hint.add_theme_font_size_override("font_size",20);canvas.add_child(hint)
 var subtitle := Label.new();subtitle.position=Vector2(144,1016);subtitle.text="独立墙面 / 连续地板 / 家具 / 小物    ·    124个部件    ·    56帧四向角色";subtitle.modulate=Color("8a9fad");subtitle.add_theme_font_size_override("font_size",18);canvas.add_child(subtitle)
 panel=Panel.new();panel.position=Vector2(112,110);panel.size=Vector2(1224,850);panel.add_theme_stylebox_override("panel",_style());canvas.add_child(panel);panel.hide()
 dialog=Panel.new();dialog.position=Vector2(228,788);dialog.size=Vector2(992,166);dialog.add_theme_stylebox_override("panel",_style());canvas.add_child(dialog);dialog.hide()
 message=Label.new();message.position=Vector2(28,20);message.size=Vector2(936,130);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;dialog.add_child(message)

func _catalog(show: bool) -> void:
 panel.visible=show
 if not show:return
 for child in panel.get_children():child.free()
 var label := Label.new();label.position=Vector2(28,18);label.text="模块素材库 · "+str(catalog.size())+"个部件  /  "+str(catalog_page+1)+"页 · 点击选择，回到房间摆放";panel.add_child(label)
 _button("上一页",Vector2(820,14),Vector2(120,44),panel,func():catalog_page=(catalog_page+5)%6;_catalog(true))
 _button("下一页",Vector2(954,14),Vector2(120,44),panel,func():catalog_page=(catalog_page+1)%6;_catalog(true))
 _button("关闭",Vector2(1084,14),Vector2(112,44),panel,func():panel.hide())
 for i in 24:
  var index := catalog_page*24+i
  if index>=catalog_ids.size():break
  var id: String=catalog_ids[index]
  var m: Dictionary=catalog[id]
  var b := _button("",Vector2(28+(i%6)*196,80+(i/6)*180),Vector2(184,168),panel,func():
   if m.category=="floor":floor_index=FLOOR_NAMES.find(id.trim_prefix("floor_"));_floor()
   else:selected=id;editing=true
   panel.hide())
  var icon := TextureRect.new();icon.texture=load(m.texture);icon.position=Vector2(16,8);icon.size=Vector2(152,118);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(icon)
  var caption := Label.new();caption.text=m.name;caption.position=Vector2(8,132);caption.size=Vector2(168,28);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.add_theme_font_size_override("font_size",18);b.add_child(caption)

func _build_frames() -> SpriteFrames:
 var library := SpriteFrames.new();library.remove_animation("default")
 for state in ["idle","walk","interact"]:
  var atlas: Texture2D=load("res://assets/animations/"+state+"_atlas.png")
  var count := 6 if state=="walk" else 4
  for row in 4:
   var name: String=state+"_"+["down","left","up","right"][row]
   library.add_animation(name);library.set_animation_loop(name,state!="interact")
   library.set_animation_speed(name,10 if state=="walk" else (6 if state=="interact" else 1))
   for col in count:
    var texture := AtlasTexture.new();texture.atlas=atlas;texture.region=Rect2(col*256,row*224,256,224)
    library.add_frame(name,texture,[0.75,0.65,0.09,0.75][col] if state=="idle" else 1.0)
 return library

func _direction_name(v: Vector2) -> String:
 if v.length_squared()<0.01:return facing
 if absf(v.x)>absf(v.y):return "right" if v.x>0 else "left"
 return "down" if v.y>0 else "up"

func _check(condition: bool,text: String) -> void:
 if condition:print("PASS: ",text)
 else:failures+=1;push_error("FAIL: "+text)

func _test() -> void:
 _check(catalog.size()>=124,"124 distinct reusable assets")
 _check(floor_map.tile_set.get_source_count()==12,"reusable TileSet contains 12 materials")
 for id in catalog:
  _check(ResourceLoader.exists(catalog[id].texture),"texture "+id)
 for id in FLOOR_NAMES:
  var im := Image.load_from_file("res://assets/floors/"+id+".png")
  var seamless := true
  for n in 64:
   if im.get_pixel(0,n)!=im.get_pixel(63,n) or im.get_pixel(n,0)!=im.get_pixel(n,63):seamless=false
  _check(seamless,"seamless edges "+id)
 var start := player.position;movement=Vector2.RIGHT
 for n in 20:await get_tree().physics_frame
 movement=Vector2.ZERO
 _check(player.position.x>start.x+30,"actual player movement")
 player.position=Vector2(220,640);movement=Vector2.LEFT
 for n in 90:await get_tree().physics_frame
 movement=Vector2.ZERO
 _check(player.position.x>=157,"wall blocks feet")
 player.position=Vector2(360,680);movement=Vector2.UP
 for n in 60:await get_tree().physics_frame
 movement=Vector2.ZERO
 _check(player.position.y>=620,"bed footprint blocks movement")
 for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
  player.position=Vector2(710,705);movement=direction
  var visited := {}
  for n in 30:
   await get_tree().physics_frame
   visited[avatar.frame]=true
  _check(avatar.animation=="walk_"+_direction_name(direction) and visited.size()>=3,"directional walk advances "+_direction_name(direction))
  movement=Vector2.ZERO
  for n in 3:await get_tree().physics_frame
  _check(avatar.animation=="idle_"+_direction_name(direction),"stop keeps facing "+_direction_name(direction))
 player.position=Vector2(1160,320)
 for n in 3:await get_tree().physics_frame
 _interact()
 _check(layout_index==1,"door interaction changes actual layout")
 _layout(0)
 player.position=Vector2(620,740)
 for state in ["idle","walk","interact"]:
  for dir in ["down","left","up","right"]:_check(frames.get_frame_count(state+"_"+dir)==(6 if state=="walk" else 4),"frames "+state+"_"+dir)
 _check(_place("whale_plush",Vector2(940,860)),"editor places independent module")
 var count := items.size()
 _check(_save(),"custom layout saves")
 _layout(1)
 _check(_restore() and items.size()==count,"restore keeps edited props")
 for i in 3:
  _layout(i);await get_tree().physics_frame
  _check(items.size()>18 and floor_map.get_used_cells().size()==180,"layout "+str(i)+" independent objects and tiles")
 _catalog(true)
 _check(panel.get_children().size()>20,"catalog contains clickable live assets")
 panel.get_child(4).pressed.emit()
 _check(editing and not panel.visible and selected==catalog_ids[catalog_page*24],"catalog click selects placement asset")
 print("ALL MODULAR CHECKS PASSED" if failures==0 else "FAILURES: "+str(failures))
 get_tree().quit(0 if failures==0 else 1)
