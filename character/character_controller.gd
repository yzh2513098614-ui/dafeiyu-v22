extends Node
const LifeState=preload("res://character/life_state.gd")
const WhaleStyle=preload("res://ui/whale_skin.gd")
const Frames=preload("res://dialogue/pixel_skin.gd")
const UiFit=preload("res://ui/ui_fit.gd")
var model=LifeState.new()
var game
var active:=false
var was_ui_visible:=true
var layer: CanvasLayer
var root: Control
var panel: Panel
var hud: Panel
var meters: Dictionary={}
var hud_status: Label
var hud_needs: Label
var level_label: Label
var feedback: Label
var rest_button: Button
var bag_button: Button
var equipment_buttons: Dictionary={}
var last_position:=Vector3.ZERO
## 上一次见到的等级。升级音效靠它判断 —— 模型是纯数据，不该知道音效的存在，
## 所以把「等级涨了」这件事放在界面刷新时检测。
var seen_level:=0
var hud_time:=0.0
var save_time:=0.0
var dirty:=false
var message:="初次探索新的房间，会积累阅历。"
var dash_remaining:=0.0
var dash_cooldown:=0.0
var dash_direction:=Vector3.ZERO
var dash_step_distance:=0.0
var portrait_texture: Texture2D

func configure(owner_game) -> void:
 game=owner_game
 if not game.loot.character_data.is_empty():model.restore(game.loot.character_data)
 else:
  for id in model.balance.starter:
   if game.loot.occupied_slots()>=64 and int(game.loot.inventory.get(id,0))==0:continue
   game.loot.inventory[id]=mini(9999,int(game.loot.inventory.get(id,0))+int(model.balance.starter[id]))
  if not game.loot.save_state():message="初始补给尚未保存，请使用菜单保存。";dirty=true
 game.loot._bag_count();last_position=game.player.position
 portrait_texture=load("res://assets/dialogue/downloaded_20261014/transparent/01_listen.png") as Texture2D
 hud=WhaleStyle.panel(game.district_canvas,Vector2(48,196),Vector2(450,230))
 hud.name="WorldVitals";hud.add_theme_stylebox_override("panel",preload("res://ui/world_hud_skin.gd").frame())
 level_label=WhaleStyle.label(hud,"",Vector2(14,9),Vector2(263,32),22)
 var status_button:=_button(hud,"C · 状态",Vector2(302,10),Vector2(132,34),open);status_button.add_theme_font_size_override("font_size",17)
 var button_style:=preload("res://ui/world_hud_skin.gd").frame();button_style.bg_color=Color("ccd8f6");button_style.set_corner_radius_all(11);button_style.shadow_size=0
 status_button.add_theme_stylebox_override("normal",button_style)
 _meter(hud,"hud_health","生命",Vector2(16,50),Vector2(418,43),Color("ee829d"))
 _meter(hud,"hud_stamina","体力",Vector2(16,99),Vector2(418,43),Color("51beb7"))
 _meter(hud,"hud_hunger","饱食",Vector2(16,148),Vector2(201,40),Color("dfb961"))
 _meter(hud,"hud_mood","心情",Vector2(233,148),Vector2(201,40),Color("a58bda"))
 hud_needs=WhaleStyle.label(hud,"",Vector2.ZERO,Vector2.ZERO,17);hud_needs.hide()
 hud_status=WhaleStyle.label(hud,"",Vector2(16,199),Vector2(418,25),17,Color("596887"))
 preload("res://ui/world_hud_skin.gd").single_line(hud_status)
 layer=CanvasLayer.new();layer.layer=45;add_child(layer)
 root=Control.new();root.size=Vector2(1448,1086);root.mouse_filter=Control.MOUSE_FILTER_STOP;root.theme=WhaleStyle.theme(game._game_font());layer.add_child(root)
 UiFit.fill(root)
 var shade:=ColorRect.new();shade.size=root.size;shade.color=Color(.08,.13,.24,.55);root.add_child(shade)
 panel=WhaleStyle.panel(root,Vector2(202,137),Vector2(1044,810));root.hide();refresh()
 UiFit.pin_center(panel,1044,137,810)
 call_deferred("_layout_world_hud")

func _layout_world_hud() -> void:
 var next_y:=hud.position.y+hud.size.y+16
 var combat: Variant=game.get("combat_controller")
 if combat!=null and combat.entry_button!=null:
  combat.entry_button.position.y=next_y;next_y+=combat.entry_button.size.y+16
 var expedition: Variant=game.get("expedition_controller")
 if expedition!=null and expedition.entry!=null:expedition.entry.position.y=next_y

func _button(parent: Node,text: String,pos: Vector2,dimensions: Vector2,action: Callable) -> Button:
 var button:=Button.new();button.text=text;button.position=pos;button.size=dimensions;button.pressed.connect(action);parent.add_child(button);return button

func _meter(parent: Node,id: String,title: String,pos: Vector2,dimensions: Vector2,color: Color) -> void:
 var container:=Control.new();container.position=pos;container.size=dimensions;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(container)
 var caption:=WhaleStyle.label(container,title,Vector2.ZERO,Vector2(dimensions.x*.4,25),18,Color("394364"))
 caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var text:=WhaleStyle.label(container,"",Vector2(dimensions.x*.4,0),Vector2(dimensions.x*.6,25),18,Color("394364"))
 text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var track:=ProgressBar.new();track.position=Vector2(0,29);track.size=Vector2(dimensions.x,dimensions.y-29);track.show_percentage=false;track.mouse_filter=Control.MOUSE_FILTER_IGNORE;track.step=0.01;container.add_child(track)
 # The hidden percentage font still contributes to ProgressBar's minimum height.
 track.add_theme_font_size_override("font_size",1)
 var background:=StyleBoxFlat.new();background.bg_color=Color("d1d9ee");background.border_color=Color("a6b2d0");background.set_border_width_all(1);background.set_corner_radius_all(7)
 var fill:=StyleBoxFlat.new();fill.bg_color=color;fill.border_color=color.darkened(.16);fill.set_border_width_all(1);fill.set_corner_radius_all(8)
 track.add_theme_stylebox_override("background",background);track.add_theme_stylebox_override("fill",fill)
 track.size=Vector2(dimensions.x,dimensions.y-29)
 meters[id]={"fill":track,"text":text,"title":title}

func _update_meter(id: String,vital: String) -> void:
 if not meters.has(id):return
 var meter: Dictionary=meters[id]
 meter.fill.max_value=model.maximum(vital);meter.fill.value=model.value(vital)
 var low: bool=model.value(vital)/model.maximum(vital)<=.2
 meter.text.text="%d / %d%s"%[ceili(model.value(vital)),int(model.maximum(vital)),"  !" if low else ""]
 meter.text.add_theme_color_override("font_color",Color("974154") if low else Color("394364"))

func free_world() -> bool:
 var pack: Variant=game.get("pack26_controller")
 if pack!=null and pack.blocked():return false
 var expedition: Variant=game.get("expedition_controller")
 if expedition!=null and (expedition.is_active() or expedition.blocked()):return false
 # 战斗中也要冻结：否则玩家能一边打一边走动
 var battle: Variant = game.get("combat_controller")
 return not active and not game.pause_menu.active and not game.dialog_open and not game.loot.blocked() and not game.settings_panel.visible and not game.map_panel.visible and not game.panel.visible and not game.editing and not game.transitioning and not (battle != null and battle.in_battle())

func cancel_dash() -> void:
 dash_remaining=0.0;dash_step_distance=0.0

func start_dash() -> bool:
 if not free_world() or dash_remaining>0 or dash_cooldown>0:return false
 var cost: float=model.balance.rules.dash_stamina_cost
 if not model.can_sprint() or model.value("stamina")<cost:refresh();return false
 var direction: Vector2=game.movement+Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
 if direction.length_squared()<.0001:
  var facing_vectors: Dictionary={"up":Vector2.UP,"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT,"up_left":Vector2(-1,-1),"up_right":Vector2(1,-1),"down_left":Vector2(-1,1),"down_right":Vector2(1,1)}
  direction=facing_vectors.get(game.facing,Vector2.DOWN)
 dash_direction=game._screen_direction_to_world(direction)
 dash_remaining=float(model.balance.rules.dash_duration);dash_cooldown=float(model.balance.rules.dash_cooldown)
 model.state.vitals.stamina=model.value("stamina")-cost;dirty=true;refresh();return true

func movement_velocity(direction: Vector2,delta: float) -> Vector3:
 dash_step_distance=0.0
 if not free_world():cancel_dash();return Vector3.ZERO
 if dash_remaining>0:
  var step: float=minf(delta,dash_remaining)
  dash_remaining=maxf(0.0,dash_remaining-step)
  dash_step_distance=float(model.balance.rules.dash_distance)*step/float(model.balance.rules.dash_duration)
  return dash_direction*dash_step_distance/delta
 return game._screen_direction_to_world(direction)*game.SPEED*model.speed_multiplier()

func _process(delta: float) -> void:
 if not game:return
 dash_cooldown=maxf(0.0,dash_cooldown-delta)
 if not free_world():cancel_dash();hud.hide();return
 hud.show()
 hud_time+=delta;save_time+=delta
 if hud_time>=.15:hud_time=0;refresh()
 if save_time>=20.0:
  save_time=0
  if dirty and game.loot.save_state():dirty=false

func advance(delta: float,before: Vector3) -> void:
 if not free_world():return
 var distance: float=game.player.position.distance_to(before)
 # Tick once per physics step. Rendering frames must not grant idle recovery.
 if distance>2.0:distance=0.0
 if dash_step_distance>0 and (game.player.position-before).dot(dash_direction)<dash_step_distance*.8:cancel_dash()
 dash_step_distance=0.0
 model.tick(delta,distance,false);dirty=true
 if game.zone_id!="" and model.discover(game.location_id+":"+game.zone_id):message="发现了新的地方，阅历增加。"

func refresh() -> void:
 if not hud:return
 # refresh() 每 0.15 秒也会被调一次，所以用「等级比上次高」判断，而不是在 gain_xp 里播音效。
 # 第一次只记录等级（seen_level==0），载入存档时不会误响。
 if int(model.state.level)>seen_level:
  if seen_level>0:SfxDirector.play("level_up",-1.0)
  seen_level=int(model.state.level)
 level_label.text="大肥鱼  ·  Lv.%d"%int(model.state.level)
 for vital in ["health","stamina","hunger","mood"]:_update_meter("hud_"+vital,vital)
 hud_needs.text="饱食 %d / 100     心情 %d / 100"%[ceili(model.value("hunger")),ceili(model.value("mood"))]
 if dash_remaining>0:hud_status.text="突进中 · 向前冲出一段距离"
 elif dash_cooldown>0:hud_status.text="突进冷却 %.1f 秒"%dash_cooldown
 elif not model.can_sprint() or model.value("stamina")<float(model.balance.rules.dash_stamina_cost):hud_status.text="体力不足 · 停下恢复后突进"
 else:hud_status.text=model.status_text()+" · Shift 突进"
 hud_status.add_theme_color_override("font_color",Color("974154") if model.value("hunger")<=20 else Color("596887"))
 if active:_render()

func open() -> void:
 if active:close();return
 if not free_world():return
 game.player.velocity=Vector3.ZERO;was_ui_visible=game.ui.visible;game.ui.hide();active=true;root.show();_render()

func close() -> void:
 active=false;root.hide();game.ui.visible=was_ui_visible;last_position=game.player.position

func _render() -> void:
 for child in panel.get_children():panel.remove_child(child);child.queue_free()
 for id in meters.keys():
  if not id.begins_with("hud_"):meters.erase(id)
 equipment_buttons.clear()
 var heading:=WhaleStyle.panel(panel,Vector2(22,20),Vector2(1000,94));heading.add_theme_stylebox_override("panel",Frames.frame("nameplate"))
 WhaleStyle.mascot(heading,Vector2(12,9),Vector2(76,72))
 WhaleStyle.label(heading,"大肥鱼 · 人物状态",Vector2(103,12),Vector2(730,39),30,Color("fff8e7"))
 WhaleStyle.label(heading,"Lv.%d  港口蓝鲸信使  ·  %s"%[int(model.state.level),model.status_text()],Vector2(105,56),Vector2(720,27),18,Color("dbe5ed"))
 _button(heading,"Esc 关闭",Vector2(837,22),Vector2(145,50),close)
 var portrait:=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.texture=portrait_texture;portrait.position=Vector2(32,129);portrait.size=Vector2(322,464);portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(portrait)
 var vitality: Array=[["health","生命",Color("ef829c")],["stamina","体力",Color("51c6bb")],["hunger","饱食",Color("e7b85a")],["mood","心情",Color("ac93e5")]]
 for i in vitality.size():
  var entry: Array=vitality[i]
  var pos:=Vector2(380+(i%2)*318,143+(i/2)*98)
  var card:=WhaleStyle.panel(panel,pos,Vector2(303,85),"card")
  _meter(card,entry[0],entry[1],Vector2(12,12),Vector2(279,58),entry[2]);_update_meter(entry[0],entry[0])
 WhaleStyle.label(panel,"基础属性 / 随身加成",Vector2(382,346),Vector2(620,34),24)
 var attributes: Array=model.balance.initial.keys()
 for i in attributes.size():
  var id: String=attributes[i];var card:=WhaleStyle.panel(panel,Vector2(380+(i%3)*213,393+(i/3)*73),Vector2(198,62),"sky")
  var bonus:=model.attribute(id)-int(model.state.base[id])
  WhaleStyle.label(card,str(model.balance.labels[id])+"  "+str(model.attribute(id))+(" (+%d)"%bonus if bonus else ""),Vector2(12,14),Vector2(175,37),21)
 var derived:=WhaleStyle.panel(panel,Vector2(380,551),Vector2(621,81),"card")
 WhaleStyle.label(derived,"漫步速度 ×%.2f  ·  休息恢复体力 +35"%model.speed_multiplier(),Vector2(12,9),Vector2(598,30),19)
 WhaleStyle.label(derived,"攻击 %d · 防御 %d  ·  潮汐试炼：靠近怪物后选择战斗"%[model.attack(),model.defense()],Vector2(12,44),Vector2(598,28),18,WhaleStyle.MUTED)
 var equipment:=WhaleStyle.panel(panel,Vector2(29,602),Vector2(323,158),"sky")
 WhaleStyle.label(equipment,"随身装备",Vector2(12,8),Vector2(294,30),23)
 var slot_labels: Dictionary={"tool":"工具","charm":"随身物"}
 var slot_index:=0
 for slot in slot_labels:
  var item: String=model.state.equipment[slot]
  var caption:=str(slot_labels[slot])+"："+(str(game.loot.definitions[item].name) if item!="" else "未装备")
  var button:=_button(equipment,caption,Vector2(11,47+slot_index*47),Vector2(301,41),func():unequip(slot));button.add_theme_font_size_override("font_size",17);button.disabled=item=="";equipment_buttons[slot]=button;slot_index+=1
 var xp:=WhaleStyle.panel(panel,Vector2(380,649),Vector2(621,46),"sky")
 WhaleStyle.label(xp,"阅历  %d / %d  ·  新地点只奖励一次"%[int(model.state.xp),model.xp_needed()],Vector2(12,9),Vector2(598,31),19)
 rest_button=_button(panel,"休息一下",Vector2(380,711),Vector2(292,52),rest)
 bag_button=_button(panel,"去背包补给 / 装备",Vector2(691,711),Vector2(310,52),func():close();game.loot.open_bag())
 feedback=WhaleStyle.label(panel,message,Vector2(29,772),Vector2(978,28),17,WhaleStyle.MUTED)

func rest() -> bool:
 var before: Dictionary=model.snapshot()
 if not model.rest():message=model.last_message;refresh();return false
 if not game.loot.save_state():model.restore(before);message="保存失败，休息没有改变状态。";refresh();return false
 message=model.last_message;refresh();return true
func unequip(slot: String) -> bool:
 var id: String=model.state.equipment.get(slot,"")
 if id=="":return false
 var before: Dictionary=model.snapshot();model.apply_item(id)
 if not game.loot.save_state():model.restore(before);message="保存失败，装备保持原样。";refresh();return false
 message="已卸下 "+str(game.loot.definitions[id].name);refresh();return true

func _input(event: InputEvent) -> void:
 if not game:return
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_SHIFT and free_world():
  start_dash();get_viewport().set_input_as_handled();return
 if active:
  if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE,KEY_C]:
   close();get_viewport().set_input_as_handled()
  return
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_C and free_world():
  open();get_viewport().set_input_as_handled()

func _unhandled_input(_event: InputEvent) -> void:
 if active:get_viewport().set_input_as_handled()
