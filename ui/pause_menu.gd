extends Node
## A quiet pause menu, using the same original art as the title screen.
const UiStyle=preload("res://ui/whale_skin.gd")
const PixelFrames=preload("res://dialogue/pixel_skin.gd")
const UiFit=preload("res://ui/ui_fit.gd")
var game
var layer: CanvasLayer
var root: Control
var panel: Panel
var buttons: Dictionary={}
var active:=false
var page:="main"
var returning_from_settings:=false
var was_ui_visible:=true
var feedback:="随时停一停，鲸落港会等你。"
var feedback_label: Label
var portrait_texture: Texture2D

func configure(owner_game) -> void:
 game=owner_game
 portrait_texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/dialogue/listen_original.png"))
 layer=CanvasLayer.new();layer.layer=60;add_child(layer)
 root=Control.new();root.size=Vector2(1448,1086);root.mouse_filter=Control.MOUSE_FILTER_STOP;root.theme=UiStyle.theme(game._game_font());root.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;layer.add_child(root)
 UiFit.fill(root)
 var shade:=ColorRect.new();shade.size=root.size;shade.color=Color(.08,.13,.24,.53);root.add_child(shade)
 UiFit.fill(shade)
 panel=UiStyle.panel(root,Vector2(220,160),Vector2(1008,760));root.hide()
 UiFit.pin_center(panel,1008,160,760)

func open() -> void:
 var pack: Variant=game.get("pack26_controller")
 if pack!=null and pack.blocked():return
 var expedition: Variant=game.get("expedition_controller")
 if expedition!=null and (expedition.is_active() or expedition.blocked()):return
 if game.combat_controller and game.combat_controller.in_battle():return
 if active:return
 if game.dialog_open or game.loot.blocked() or game.settings_panel.visible or game.map_panel.visible or game.panel.visible:return
 if game.character_controller and game.character_controller.active:return
 game.editing=false;game.ghost.hide();game.player.velocity=Vector3.ZERO
 was_ui_visible=game.ui.visible;game.ui.hide();active=true;page="main";root.show();_render()

func close() -> void:
 active=false;root.hide();game.ui.visible=was_ui_visible

func _render() -> void:
 for child in panel.get_children():
  panel.remove_child(child);child.queue_free()
 buttons.clear()
 var heading:=UiStyle.panel(panel,Vector2(24,22),Vector2(960,108))
 heading.add_theme_stylebox_override("panel",PixelFrames.frame("nameplate"))
 UiStyle.mascot(heading,Vector2(13,13),Vector2(86,80))
 UiStyle.label(heading,"鲸落港 · 暂停" if page=="main" else "港口漫步手册",Vector2(116,17),Vector2(639,45),34,Color("fff8e7"))
 UiStyle.label(heading,"慢慢来，今天也不必赶路。" if page=="main" else "把常用的几步，记在这里。",Vector2(118,68),Vector2(590,29),19,Color("d9e5ed"))
 var dismiss:=_button("dismiss","Esc 继续" if page=="main" else "返回菜单",Vector2(785,48),Vector2(178,52),func():
  if page=="main":close()
  else:page="main";_render())
 if page=="help":_help();dismiss.grab_focus();return
 _button("resume","继续漫步   ▸",Vector2(32,157),Vector2(568,64),close,true)
 _button("settings","画面设置",Vector2(32,238),Vector2(568,64),_settings)
 _button("help","操作说明",Vector2(32,319),Vector2(568,64),func():page="help";_render())
 _button("save","保存这一段旅程",Vector2(32,400),Vector2(568,64),save_session)
 _button("title","保存并返回标题",Vector2(32,481),Vector2(568,64),return_to_title)
 _button("quit","保存并离开",Vector2(32,562),Vector2(568,64),quit_game)
 var portrait:=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.texture=portrait_texture;portrait.position=Vector2(624,136);portrait.size=Vector2(352,500);portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(portrait)
 var place:=UiStyle.panel(panel,Vector2(626,642),Vector2(350,87),"sky")
 UiStyle.label(place,"你停在这里",Vector2(16,10),Vector2(318,26),18,UiStyle.MUTED)
 UiStyle.label(place,str(game.title.text),Vector2(16,40),Vector2(318,36),22)
 feedback_label=UiStyle.label(panel,feedback,Vector2(35,666),Vector2(563,57),20,UiStyle.MUTED)
 buttons.resume.grab_focus()

func _button(id: String,text: String,pos: Vector2,dimensions: Vector2,action: Callable,primary: bool=false) -> Button:
 var button:=Button.new();button.text=text;button.position=pos;button.size=dimensions;button.add_theme_font_size_override("font_size",25);button.pressed.connect(action);panel.add_child(button);buttons[id]=button
 var focus:=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=UiStyle.BLUE;focus.set_border_width_all(2);focus.set_corner_radius_all(9);focus.set_expand_margin_all(2);button.add_theme_stylebox_override("focus",focus)
 if primary:
  PixelFrames.SkyStyle.primary(button)
 if id=="settings":UiStyle.button_icon(button,"settings")
 elif id=="help":UiStyle.button_icon(button,"tasks")
 elif id=="save":UiStyle.button_icon(button,"mail")
 return button

func _help() -> void:
 var entries: Array=[
  ["漫步与互动","WASD / 方向键 · 移动   按住 Shift · 冲刺（消耗体力）\nE · 进出建筑、楼层或互动"],
  ["镜头与导览","滚轮 · 放大缩小   Z · 总览 / 跟随\nM · 找地方、标记路线"],
  ["和大肥鱼说话","Q · 聊聊   Enter / Space · 下一句\n1—3 · 选回应   H · 回看   A · 自动"],
  ["收好小惊喜","C · 人物状态 / 休息   I · 背包\nE · 补给箱   背包内可使用 / 装备"],
  ["把房间布置好","B / Tab · 打开家居箱，选择家具\n点击放置 · R 旋转 · 右键移除\n布置时 B · 结束装饰"],
  ["潮汐试炼与存档","J · 攻击   K · 闪避   L · 急救\n红圈是蓄力提示，走出范围再反击\nEsc · 菜单   F5 · 保存旅程"]]
 for i in entries.size():
  var card:=UiStyle.panel(panel,Vector2(32+(i%2)*480,147+(i/2)*167),Vector2(464,151),"card")
  UiStyle.label(card,entries[i][0],Vector2(17,13),Vector2(430,35),25)
  UiStyle.label(card,entries[i][1],Vector2(18,57),Vector2(428,85),19,UiStyle.MUTED)
 _button("back","知道了，返回菜单",Vector2(32,665),Vector2(944,61),func():page="main";_render(),true)

func _settings() -> void:
 returning_from_settings=true;close();game._settings(true)

func settings_closed() -> void:
 if returning_from_settings:
  returning_from_settings=false;open()

func save_session() -> bool:
 if not game.loot.save_state() or not game.dialogue_controller._save_state() or not game._save():
  feedback="这一段尚未保存，请再试一次。"
  if is_instance_valid(feedback_label):feedback_label.text=feedback
  return false
 feedback="已经记住你的位置、房间和背包。"
 if is_instance_valid(feedback_label):feedback_label.text=feedback
 return true

func return_to_title() -> void:
 if not save_session():return
 HarborPrefs.continue_game=false
 preload("res://ui/loading_transition.gd").instance(get_tree()).change_scene("res://ui/start_menu.tscn","标题界面")

func quit_game() -> void:
 if save_session():get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
 var pack=game.get("pack26_controller")
 if pack!=null and pack.blocked():return
 var expedition: Variant=game.get("expedition_controller")
 if expedition!=null and (expedition.is_active() or expedition.blocked()):return
 if active:
  if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("ui_cancel"):
   if page=="help":page="main";_render()
   else:close()
  get_viewport().set_input_as_handled();return
 if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("ui_cancel") and not game.editing and not game.panel.visible and not game.dialog_open and not game.loot.blocked() and not game.settings_panel.visible and not game.map_panel.visible:
  open();get_viewport().set_input_as_handled()
