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
## 世界数值 HUD 的保留区：静默态只画出 slim 小卡，但这块 450x206 一直是 hud 的尺寸，
## 这样 _layout_world_hud() 与验收脚本量到的「HUD 占位」不会随状态跳来跳去。
var hud: Control
var wide: Panel
var slim: Panel
var meters: Dictionary={}
var minis: Dictionary={}
var avatars: Dictionary={}
var bubble: Panel
var bubble_text: Label
var bubble_ring: Panel
var bubble_tail: Control
var bubble_dot: Control
var edge_glow: TextureRect
var glow_warm: GradientTexture2D
var glow_hurt: GradientTexture2D
var level_pill: Label
var hud_sub: Label
var hud_status: Label
var hud_needs: Label
var level_label: Label
var status_subtitle: Label
var hud_form:="slim"
var alert_on:=false
var alert_health:=false
var face_kind:="fine"
var mood_face:="fine"
## 受击后 4 秒内展开数值；触发结束后再留 1.5 秒才收回静默态。
var hit_window:=0.0
var hold_window:=0.0
var mood_window:=0.0
var last_health:=-1.0
var last_mood:=-1.0
var enter_tween: Tween
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
 hud=Control.new();hud.name="WorldVitals";hud.position=Vector2(48,196);hud.size=Vector2(450,206)
 hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.district_canvas.add_child(hud)
 wide=WhaleStyle.panel(hud,Vector2.ZERO,Vector2(450,206));wide.add_theme_stylebox_override("panel",_sticker_frame())
 _sticker_backing(wide,wide.get_theme_stylebox("panel"))
 wide.mouse_filter=Control.MOUSE_FILTER_IGNORE;wide.visible=false
 slim=WhaleStyle.panel(hud,Vector2.ZERO,Vector2(262,50));slim.add_theme_stylebox_override("panel",_sticker_frame())
 _sticker_backing(slim,slim.get_theme_stylebox("panel"))
 slim.mouse_filter=Control.MOUSE_FILTER_STOP;slim.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 slim.gui_input.connect(_slim_pressed)
 avatars={"wide":_avatar(wide,Vector2(12,7)),"slim":_avatar(slim,Vector2(12,7))}
 level_label=WhaleStyle.label(wide,"",Vector2(56,6),Vector2(240,24),17,Color("2857c9"))
 level_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 level_label.add_theme_font_override("font",preload("res://assets/fonts/misans/MiSans-Bold.ttf"))
 hud_sub=WhaleStyle.label(wide,"",Vector2(56,30),Vector2(240,15),12,Color("6f8fd6"))
 preload("res://ui/world_hud_skin.gd").single_line(hud_sub)
 var status_button:=_button(wide,"C · 状态",Vector2(302,0),Vector2(132,44),open)
 status_button.set_script(preload("res://ui/candy_sticker_button.gd"))
 status_button.accent=Color("aad4ff");status_button.compact=true;status_button.add_theme_font_size_override("font_size",17)
 for state in ["normal","hover","pressed","disabled","focus"]:status_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
 for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:status_button.add_theme_color_override(state,Color.TRANSPARENT)
 status_button.add_theme_constant_override("outline_size",0)
 var cap:=Label.new();cap.text="C · 状态";cap.position=Vector2(12,2);cap.mouse_filter=Control.MOUSE_FILTER_IGNORE
 cap.add_theme_font_override("font",preload("res://assets/fonts/misans/MiSans-Bold.ttf"))
 cap.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cap.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 status_button.add_child(cap);status_button.live_label=cap
 _meter(wide,"hud_health","生命",Vector2(16,46),Vector2(418,30),Color("f4407e"),"health")
 _meter(wide,"hud_stamina","体力",Vector2(16,76),Vector2(418,30),Color("23cbd4"),"stamina")
 _meter(wide,"hud_hunger","饱食",Vector2(16,106),Vector2(418,30),Color("feb633"),"hunger")
 _meter(wide,"hud_mood","心情",Vector2(16,136),Vector2(418,30),Color("638eff"),"mood")
 hud_needs=WhaleStyle.label(wide,"",Vector2.ZERO,Vector2.ZERO,17);hud_needs.hide()
 hud_status=WhaleStyle.label(wide,"",Vector2(16,174),Vector2(418,22),12,Color("4a71c4"))
 preload("res://ui/world_hud_skin.gd").single_line(hud_status)
 _build_slim();_build_alert()
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

func _meter(parent: Node,id: String,title: String,pos: Vector2,dimensions: Vector2,color: Color,kind: String="") -> void:
 var big:=dimensions.y>34
 var icon_s:=24 if big else 22
 var track_h:=20 if big else 18
 var lab_w:=32 if big else 30
 var reading_font:=preload("res://assets/fonts/misans/MiSans-Bold.ttf")
 var largest_reading: String="%d / %d !"%[ceili(model.maximum(kind)),ceili(model.maximum(kind))]
 var val_w:=maxf(70 if big else 66,ceilf(reading_font.get_string_size(largest_reading,HORIZONTAL_ALIGNMENT_LEFT,-1,13 if big else 12).x))
 var row:=Control.new();row.position=pos;row.size=dimensions;row.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(row)
 var icon:=Panel.new();icon.position=Vector2(0,(dimensions.y-icon_s)*.5);icon.size=Vector2(icon_s,icon_s);icon.pivot_offset=Vector2(icon_s,icon_s)*.5;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(icon)
 var icon_faces: Dictionary={"normal":_icon_box(_icon_tint(kind),color,icon_s),"zero":_icon_box(Color("eef1f6"),Color("b1bed9"),icon_s),"alert":_icon_box(Color("ffd7e4") if kind=="health" else Color("ffe9c2"),Color("f4407e") if kind=="health" else Color("feb633"),icon_s)}
 icon.add_theme_stylebox_override("panel",icon_faces.normal)
 var icon_backing:=_sticker_backing(icon,icon_faces.normal)
 var icon_art:=MeterIcon.new();icon_art.kind=kind if kind!="" else "health";icon_art.tint=color;icon_art.set_anchors_preset(Control.PRESET_FULL_RECT);icon.add_child(icon_art)
 var caption:=WhaleStyle.label(row,title,Vector2(icon_s+6,0),Vector2(lab_w,dimensions.y),14 if big else 12,Color("2857c9"))
 caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;caption.add_theme_font_override("font",preload("res://assets/fonts/misans/MiSans-Bold.ttf"))
 caption.autowrap_mode=TextServer.AUTOWRAP_OFF
 var text:=WhaleStyle.label(row,"",Vector2(dimensions.x-val_w,0),Vector2(val_w,dimensions.y),13 if big else 12,Color("2857c9"))
 text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;text.add_theme_font_override("font",preload("res://assets/fonts/misans/MiSans-Bold.ttf"))
 text.autowrap_mode=TextServer.AUTOWRAP_OFF
 var track:=ProgressBar.new();track.position=Vector2(icon_s+lab_w+12,(dimensions.y-track_h)*.5);track.size=Vector2(dimensions.x-icon_s-lab_w-val_w-18,track_h);track.show_percentage=false;track.mouse_filter=Control.MOUSE_FILTER_IGNORE;track.step=0.01;row.add_child(track)
 # The hidden percentage font still contributes to ProgressBar's minimum height.
 track.add_theme_font_size_override("font_size",1)
 var faces: Dictionary={"normal":_meter_box(Color("eaf2ff"),Color.WHITE,Color("638eff"),track_h),"zero":_meter_box(Color("eef1f6"),Color.WHITE,Color("b1bed9"),track_h),"alert":_meter_box(Color("eaf2ff"),Color("ffd7e4") if kind=="health" else Color("ffe9c2"),Color("f4407e") if kind=="health" else Color("feb633"),track_h)}
 var fill:=StyleBoxFlat.new();fill.bg_color=color;fill.set_corner_radius_all(maxi(int(track_h*.5)-3,2))
 # Draw the fill inside the white rim; ProgressBar's native fill covers its full height.
 track.add_theme_stylebox_override("background",faces.normal);track.add_theme_stylebox_override("fill",StyleBoxEmpty.new())
 var track_backing:=_sticker_backing(track,faces.normal)
 var overlay:=MeterOverlay.new();overlay.position=track.position;overlay.size=track.size;overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(overlay)
 meters[id]={"fill":track,"fill_skin":fill,"text":text,"title":title,"kind":kind,"color":color,"ghost":-1.0,"ghost_start":0.0,"ghost_time":0.0,"flash":0.0,"gain":0,"reading":"","reading_color":Color("2857c9"),"low":false,"zero":false,"overlay":overlay,"icon":icon,"icon_art":icon_art,"faces":faces,"icon_faces":icon_faces,"icon_backing":icon_backing,"track_backing":track_backing}
 overlay.st=meters[id]

func _sticker_backing(target: Control,face: StyleBoxFlat) -> StickerBacking:
 var backing:=StickerBacking.new();backing.face=face;backing.show_behind_parent=true
 backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;target.add_child(backing)
 backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 return backing

class StickerBacking extends Control:
 ## shadow_size=0 disables native shadows, so draw the solid offset layer explicitly.
 var face: StyleBoxFlat
 var ink:=StyleBoxFlat.new()
 func _ready() -> void:
  resized.connect(queue_redraw)
 func _draw() -> void:
  ink.bg_color=face.shadow_color
  for corner in 4:ink.set_corner_radius(corner,face.get_corner_radius(corner))
  draw_style_box(ink,Rect2(face.shadow_offset,size))

func _icon_tint(kind: String) -> Color:
 return {"health":Color("ffe3ec"),"stamina":Color("dcf8f9"),"hunger":Color("fff2dc"),"mood":Color("e4ecff")}.get(kind,Color.WHITE)

func _icon_box(bg: Color,shadow: Color,h: int) -> StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=bg;box.border_color=Color.WHITE;box.set_border_width_all(2)
 box.set_corner_radius_all(int(h*.5));box.shadow_color=shadow;box.shadow_size=0;box.shadow_offset=Vector2(1.5,2.5);box.anti_aliasing=true
 box.content_margin_left=0;box.content_margin_right=0;box.content_margin_top=0;box.content_margin_bottom=0
 return box

func _sticker_frame() -> StyleBoxFlat:
 var card:=StyleBoxFlat.new();card.bg_color=Color("fcfdff");card.border_color=Color.WHITE;card.set_border_width_all(4)
 card.set_corner_radius_all(16);card.shadow_color=Color("638eff");card.shadow_size=0;card.shadow_offset=Vector2(3,4);card.anti_aliasing=true
 card.content_margin_left=0;card.content_margin_right=0;card.content_margin_top=0;card.content_margin_bottom=0
 return card

func _meter_box(bg: Color,ring: Color,shadow: Color,h: int) -> StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=bg;box.border_color=ring;box.set_border_width_all(3)
 box.set_corner_radius_all(int(h*.5));box.shadow_color=shadow;box.shadow_size=0;box.shadow_offset=Vector2(2,3);box.anti_aliasing=true
 box.content_margin_left=0;box.content_margin_right=0;box.content_margin_top=0;box.content_margin_bottom=0
 return box

## 静默态小卡：头像贴 + 4 根 34x8 迷你条 + 等级胶囊；点它直接开状态页。
func _build_slim() -> void:
 var order: Array=["health","stamina","hunger","mood"]
 var tint: Dictionary={"health":Color("f4407e"),"stamina":Color("23cbd4"),"hunger":Color("feb633"),"mood":Color("638eff")}
 for i in order.size():
  var bar:=MiniBar.new();bar.position=Vector2(54+i*39,21);bar.size=Vector2(34,8)
  bar.color=tint[order[i]];slim.add_child(bar);minis[order[i]]=bar
 var pill:=Panel.new();pill.position=Vector2(214,15);pill.size=Vector2(34,20);pill.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var pill_box:=StyleBoxFlat.new();pill_box.bg_color=Color("007ff7");pill_box.set_corner_radius_all(10)
 pill_box.content_margin_left=0;pill_box.content_margin_right=0;pill_box.content_margin_top=0;pill_box.content_margin_bottom=0
 pill.add_theme_stylebox_override("panel",pill_box);slim.add_child(pill)
 level_pill=WhaleStyle.label(pill,"",Vector2.ZERO,Vector2(34,20),13,Color.WHITE)
 level_pill.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;level_pill.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 level_pill.add_theme_font_override("font",preload("res://assets/fonts/misans/MiSans-Bold.ttf"))

## 告警层：就近气泡（只在静默态挂出来）+ 左下角边缘脉冲，都不遮画面中心。
func _build_alert() -> void:
 glow_warm=_glow(Color("ffd66e"),.5);glow_hurt=_glow(Color("f4407e"),.42)
 bubble=Panel.new();bubble.position=Vector2(16,58);bubble.size=Vector2(330,44)
 bubble.mouse_filter=Control.MOUSE_FILTER_IGNORE;bubble.visible=false
 bubble.add_theme_stylebox_override("panel",_bubble_box(false));hud.add_child(bubble)
 _sticker_backing(bubble,bubble.get_theme_stylebox("panel"))
 bubble_ring=Panel.new();bubble_ring.position=Vector2(3,3);bubble_ring.size=Vector2(324,38)
 bubble_ring.mouse_filter=Control.MOUSE_FILTER_IGNORE;bubble_ring.add_theme_stylebox_override("panel",_ring_box(Color("ffd98a")))
 bubble.add_child(bubble_ring)
 bubble_tail=BubbleTail.new();bubble_tail.position=Vector2(-8,10);bubble_tail.size=Vector2(16,16)
 bubble_tail.mouse_filter=Control.MOUSE_FILTER_IGNORE;bubble.add_child(bubble_tail)
 bubble_dot=PulseDot.new();bubble_dot.position=Vector2(13,17);bubble_dot.size=Vector2(10,10)
 bubble_dot.mouse_filter=Control.MOUSE_FILTER_IGNORE;bubble.add_child(bubble_dot)
 bubble_text=WhaleStyle.label(bubble,"",Vector2(32,0),Vector2(286,44),13,Color("a05a00"))
 bubble_text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 bubble_text.add_theme_font_override("font",preload("res://assets/fonts/misans/MiSans-Bold.ttf"))
 preload("res://ui/world_hud_skin.gd").single_line(bubble_text)
 edge_glow=TextureRect.new();edge_glow.texture=glow_warm
 edge_glow.anchor_left=0.0;edge_glow.anchor_top=.6;edge_glow.anchor_right=.46;edge_glow.anchor_bottom=1.0
 edge_glow.offset_left=0;edge_glow.offset_top=0;edge_glow.offset_right=0;edge_glow.offset_bottom=0
 edge_glow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;edge_glow.stretch_mode=TextureRect.STRETCH_SCALE
 edge_glow.mouse_filter=Control.MOUSE_FILTER_IGNORE;edge_glow.visible=false
 game.district_canvas.add_child(edge_glow)

## 头像贴：30px 圆脸 + 3px 白包边 + 底影，告警时白环换成案 2 的警报环。
func _avatar(parent: Node,pos: Vector2) -> Dictionary:
 var box:=Panel.new();box.position=pos;box.size=Vector2(36,36);box.pivot_offset=Vector2(18,18)
 box.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(box)
 var skins: Dictionary={"normal":_avatar_box(Color.WHITE,Color("638eff")),"health":_avatar_box(Color("ffd7e4"),Color("f4407e")),"other":_avatar_box(Color("ffe9c2"),Color("feb633"))}
 box.add_theme_stylebox_override("panel",skins.normal)
 var backing:=_sticker_backing(box,skins.normal)
 var art:=FaceIcon.new();art.position=Vector2(8,8);art.size=Vector2(20,20);art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 box.add_child(art)
 return {"box":box,"art":art,"skins":skins,"tween":null,"backing":backing}

func _avatar_box(ring: Color,shadow: Color) -> StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=Color("e4ecff");box.border_color=ring;box.set_border_width_all(3)
 box.set_corner_radius_all(18);box.shadow_color=shadow;box.shadow_size=0;box.shadow_offset=Vector2(2,3);box.anti_aliasing=true
 box.content_margin_left=0;box.content_margin_right=0;box.content_margin_top=0;box.content_margin_bottom=0
 return box

func _bubble_box(health: bool) -> StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=Color("fff0f5") if health else Color("fff6dd")
 box.border_color=Color.WHITE;box.set_border_width_all(3);box.set_corner_radius_all(13)
 box.shadow_color=Color("f4407e") if health else Color("feb633");box.shadow_size=0;box.shadow_offset=Vector2(3,4);box.anti_aliasing=true
 box.content_margin_left=0;box.content_margin_right=0;box.content_margin_top=0;box.content_margin_bottom=0
 return box

func _ring_box(ring: Color) -> StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=Color.TRANSPARENT;box.border_color=ring;box.set_border_width_all(2)
 box.set_corner_radius_all(10);box.content_margin_left=0;box.content_margin_right=0;box.content_margin_top=0;box.content_margin_bottom=0
 return box

func _glow(c: Color,peak: float) -> GradientTexture2D:
 var gradient:=Gradient.new();gradient.remove_point(0);gradient.set_color(0,Color(c,0.0))
 gradient.add_point(0.0,Color(c,peak));gradient.add_point(.38,Color(c,peak*.32));gradient.add_point(.68,Color(c,0.0))
 var texture:=GradientTexture2D.new();texture.gradient=gradient;texture.fill=GradientTexture2D.FILL_RADIAL
 texture.fill_from=Vector2(0,1);texture.fill_to=Vector2(1,0);texture.width=128;texture.height=128
 return texture

func _slim_pressed(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:open()

## 三态判定。阈值取自 v2 设计稿的显示条件表：受击后 4 秒内展开、体力 <30% 展开、
## 触发结束后再留 1.5 秒收回；饱食 ≤20% 或生命 ≤35% 点亮告警层。
func _apply_hud_state() -> void:
 var health: float=model.value("health")
 var hunger: float=model.value("hunger")
 var mood: float=model.value("mood")
 var health_frac: float=health/maxf(model.maximum("health"),.0001)
 var stamina_frac: float=model.value("stamina")/maxf(model.maximum("stamina"),.0001)
 if last_health>=0.0 and health<last_health-.01:hit_window=4.0
 if last_mood>=0.0 and absf(mood-last_mood)>.5:mood_face="fine" if mood>last_mood else "low";mood_window=2.0
 last_health=health;last_mood=mood
 alert_health=health_frac<=.35
 var want_alert: bool=alert_health or hunger<=20.0
 var trigger: bool=hit_window>0.0 or dash_remaining>0.0 or dash_cooldown>0.0 or stamina_frac<.30
 if trigger:hold_window=1.5
 var want_form: String="wide" if (trigger or hold_window>0.0) else "slim"
 if want_form!=hud_form:
  hud_form=want_form;wide.visible=hud_form=="wide";slim.visible=hud_form=="slim"
  _enter(wide if hud_form=="wide" else slim)
 if want_alert!=alert_on:alert_on=want_alert;_style_alert()
 bubble.visible=alert_on and hud_form=="slim"
 edge_glow.visible=alert_on and hud.visible
 var kind: String=_face_kind(health_frac,stamina_frac,hunger,mood)
 if kind!=face_kind:
  face_kind=kind
  for id in avatars:
   var entry: Dictionary=avatars[id]
   entry.art.kind=kind;_squash(entry)
 level_pill.text=str(int(model.state.level))
 hud_sub.text=_place_name()
 bubble_text.text=_alert_copy(hunger)
 for vital in minis:
  var maxv: float=maxf(model.maximum(vital),.0001)
  var value: float=model.value(vital)
  var bar: MiniBar=minis[vital]
  bar.update(value/maxv,value<=0.0,value/maxv<=.2,vital=="health")

## 表情优先级：疼 > 饿了 / 累了 > 蔫了 > 安好；心情变化只在这 2 秒内盖过最末两档。
func _face_kind(health_frac: float,stamina_frac: float,hunger: float,mood: float) -> String:
 if mood_window>0.0 and health_frac>=.35 and hunger>=20.0 and stamina_frac>=.30:return mood_face
 if health_frac<.35:return "hurt"
 if hunger<20.0:return "hungry"
 if stamina_frac<.30:return "tired"
 if mood<40.0:return "low"
 return "fine"

## 告警文案只做「状态 + 去处 + 按键」；距离与方位要等导航票券那轮接上真实 POI 再补，
## 现在报数字会是编的。
func _alert_copy(hunger: float) -> String:
 if alert_health:return "伤得不轻 —— 按 C 打开状态，休息一下再走"
 if hunger<=0.0:return "饱食见底了 —— 去小吃摊或咖啡馆，按 E 吃一份"
 return "肚子有点空了 —— 找处小吃摊，按 E 补一口"

## 抬头第二行只报「所在地点」；区域名由世界上方那张地点卡负责，这里不重复一遍。
func _place_name() -> String:
 var places: Variant=game.get("locations")
 if places is Dictionary:
  var entry: Variant=(places as Dictionary).get(game.location_id,{})
  if entry is Dictionary and not (entry as Dictionary).is_empty():return str((entry as Dictionary).get("name",""))
 return model.status_text()

func _style_alert() -> void:
 var key: String="normal"
 if alert_on:key="health" if alert_health else "other"
 for id in avatars:
  var entry: Dictionary=avatars[id]
  entry.box.add_theme_stylebox_override("panel",entry.skins[key])
  entry.backing.face=entry.skins[key];entry.backing.queue_redraw()
 var bubble_face:=_bubble_box(alert_health)
 bubble.add_theme_stylebox_override("panel",bubble_face)
 var bubble_backing: StickerBacking=bubble.get_child(0)
 bubble_backing.face=bubble_face;bubble_backing.queue_redraw()
 bubble_ring.add_theme_stylebox_override("panel",_ring_box(Color("ffd7e4") if alert_health else Color("ffd98a")))
 bubble_tail.face=Color("fff0f5") if alert_health else Color("fff6dd");bubble_tail.queue_redraw()
 bubble_dot.tint=Color("f4407e") if alert_health else Color("feb633");bubble_dot.queue_redraw()
 bubble_text.add_theme_color_override("font_color",Color("974154") if alert_health else Color("a05a00"))
 edge_glow.texture=glow_hurt if alert_health else glow_warm

## L2 入场：卡片 0.94 → 1 生长 + 淡入，140ms ease-out。关掉特效时直接落位。
func _enter(card: Control) -> void:
 if enter_tween!=null and enter_tween.is_valid():enter_tween.kill()
 if not bool(HarborPrefs.values.effects):card.scale=Vector2.ONE;card.modulate.a=1.0;return
 card.pivot_offset=card.size*.5;card.scale=Vector2(.94,.94);card.modulate.a=0.0
 enter_tween=card.create_tween();enter_tween.set_parallel(true)
 enter_tween.tween_property(card,"scale",Vector2.ONE,.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 enter_tween.tween_property(card,"modulate:a",1.0,.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## L6 吉祥物：换表情时 Q 弹一下，(1.08,0.92) → (1,1) 共 160ms。
func _squash(entry: Dictionary) -> void:
 if not bool(HarborPrefs.values.effects):return
 var box: Control=entry.box
 var running: Tween=entry.tween
 if running!=null and running.is_valid():running.kill()
 box.pivot_offset=box.size*.5
 var tween:=box.create_tween();entry.tween=tween
 tween.tween_property(box,"scale",Vector2(1.08,.92),.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 tween.tween_property(box,"scale",Vector2.ONE,.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## L4 图标高亮：告警时只让最要紧的那一枚图标 1↔1.06 呼吸，1.2s 一圈。
func _pulse_icons() -> void:
 if not bool(HarborPrefs.values.effects):return
 var beat: float=0.5+0.5*sin(Time.get_ticks_msec()/1000.0*TAU/1.2)
 var top: String=""
 if alert_on:
  for vital in ["health","hunger","stamina","mood"]:
   var candidate: String="hud_"+vital
   if meters.has(candidate) and (meters[candidate].low or meters[candidate].zero):top=candidate;break
 for id in meters:
  if not str(id).begins_with("hud_"):continue
  var meter: Dictionary=meters[id]
  var k: float=0.06*beat if str(id)==top else 0.0
  meter.icon.scale=Vector2(1.0+k,1.0+k)

func _update_meter(id: String,vital: String) -> void:
 if not meters.has(id):return
 var meter: Dictionary=meters[id]
 var maxv: float=maxf(model.maximum(vital),0.0001)
 var value: float=model.value(vital)
 var prev: float=meter.fill.value
 meter.fill.max_value=maxv;meter.fill.value=value
 if meter.ghost<0:meter.ghost=value
 elif value<prev-0.01:
  meter.ghost_start=maxf(meter.ghost,prev);meter.ghost=meter.ghost_start;meter.ghost_time=0.6
  meter.flash=0.0;meter.gain=0
 elif value>prev+0.01:
  meter.flash=0.4;meter.gain=roundi(value-prev) if value-prev>=1.0 else 0
  meter.ghost=value;meter.ghost_time=0.0
 var frac: float=value/maxv
 var low: bool=frac<=.2
 var zero: bool=value<=0
 var alert_text:=Color("974154") if meter.kind=="health" else Color("8a5a17")
 meter.reading_color=Color("2857c9")
 if zero:meter.reading="0 !";meter.reading_color=alert_text
 elif low:meter.reading="%d / %d !"%[ceili(value),int(maxv)];meter.reading_color=alert_text
 elif frac>=1.0:meter.reading="满";meter.reading_color=Color("93a6c4")
 else:meter.reading="%d / %d"%[ceili(value),int(maxv)]
 var show_gain: bool=meter.gain>0 and meter.flash>0.0
 meter.text.text="+%d"%meter.gain if show_gain else meter.reading
 meter.text.add_theme_color_override("font_color",Color("1d9e63") if show_gain else meter.reading_color)
 var faces: Dictionary=meter.faces
 var face: StyleBoxFlat=faces.zero if zero else (faces.alert if low else faces.normal)
 meter.fill.add_theme_stylebox_override("background",face)
 meter.track_backing.face=face;meter.track_backing.queue_redraw()
 meter.icon_art.tint=Color("b1bed9") if zero else meter.color
 var icon_face: StyleBoxFlat=meter.icon_faces.zero if zero else (meter.icon_faces.alert if low else meter.icon_faces.normal)
 meter.icon.add_theme_stylebox_override("panel",icon_face)
 meter.icon_backing.face=icon_face;meter.icon_backing.queue_redraw()
 meter.icon.rotation=-0.17 if low and not zero else 0.0
 meter.low=low and not zero;meter.zero=zero
 meter.overlay.queue_redraw();meter.icon_art.queue_redraw()

class MeterIcon extends Control:
 var kind:="health"
 var tint:=Color.WHITE
 func _poly(pts: Array,k: float) -> PackedVector2Array:
  var out:=PackedVector2Array()
  for p in pts:out.append(Vector2(p[0],p[1])*k)
  return out
 func _draw() -> void:
  var k:=size.x/24.0
  if kind=="stamina":
   draw_colored_polygon(_poly([[13.4,2],[4.6,13.6],[10.1,13.6],[9,22],[18.4,9.8],[12.8,9.8]],k),tint)
  elif kind=="hunger":
   draw_circle(Vector2(10.8,12)*k,6.2*k,tint)
   draw_colored_polygon(_poly([[16.5,12],[22,8.2],[22,15.8]],k),tint)
   draw_circle(Vector2(7.6,10.6)*k,1.2*k,Color.WHITE)
  elif kind=="mood":
   draw_circle(Vector2(12,12)*k,9.4*k,tint)
   draw_circle(Vector2(8.8,10)*k,1.35*k,Color.WHITE)
   draw_circle(Vector2(15.2,10)*k,1.35*k,Color.WHITE)
   draw_arc(Vector2(12,11.6)*k,4.6*k,deg_to_rad(25),deg_to_rad(155),12,Color.WHITE,1.7*k,true)
  else:
   draw_colored_polygon(_poly([[12,20.5],[4.8,13.6],[2.8,9.6],[4.2,6.2],[7.2,5.2],[9.8,6.4],[12,8.6],[14.2,6.4],[16.8,5.2],[19.8,6.2],[21.2,9.6],[19.2,13.6]],k),tint)

class MeterOverlay extends Control:
 var st: Dictionary={}
 var ghost_skin:=StyleBoxFlat.new()
 func _process(delta: float) -> void:
  if st.is_empty():return
  var active: bool=st.low
  if st.flash>0:
   st.flash=maxf(0.0,st.flash-delta);active=true
   if st.flash<=0.0:
    st.gain=0;st.text.text=st.reading;st.text.add_theme_color_override("font_color",st.reading_color)
  var target: float=st.fill.value
  if st.ghost_time>0:
   st.ghost_time=maxf(0.0,st.ghost_time-delta)
   st.ghost=lerpf(target,st.ghost_start,st.ghost_time/0.6);active=true
  if active:queue_redraw()
 func _draw() -> void:
  if st.is_empty():return
  var track: ProgressBar=st.fill
  var w:=size.x;var h:=size.y
  var maxv: float=maxf(track.max_value,0.0001)
  var t:=3.0
  var rr:=(h-t*2)*.5
  var inner_w:=w-t*2
  var fill_w: float=clampf(track.value/maxv,0.0,1.0)*inner_w
  var ghost_w: float=clampf(st.ghost/maxv,0.0,1.0)*inner_w
  var fill_x: float=t+fill_w
  var ghost_x: float=t+ghost_w
  var color: Color=st.color
  var light: Color=color.lightened(.55)
  if st.zero:
   var gray:=Color("b1bed9")
   draw_dashed_line(Vector2(t+rr,t+.75),Vector2(w-t-rr,t+.75),gray,1.5,4.0,true)
   draw_dashed_line(Vector2(t+rr,h-t-.75),Vector2(w-t-rr,h-t-.75),gray,1.5,4.0,true)
   draw_arc(Vector2(w-t-rr,h*.5),rr-.75,deg_to_rad(-90),deg_to_rad(90),10,gray,1.5,true)
   draw_arc(Vector2(t+rr,h*.5),rr-.75,deg_to_rad(90),deg_to_rad(270),10,gray,1.5,true)
   return
  if ghost_w>fill_w+.01:
   ghost_skin.bg_color=Color(color,.35);ghost_skin.set_corner_radius_all(int(rr))
   draw_style_box(ghost_skin,Rect2(Vector2(t,t),Vector2(ghost_w,h-t*2)))
  if fill_w>0:
   draw_style_box(st.fill_skin,Rect2(Vector2(t,t),Vector2(fill_w,h-t*2)))
  var ring_x: float=minf(maxf(ghost_x,t+rr),w-t-rr)
  if ring_x<w-t-rr-1:
   var ring:=light
   if st.low:
    ring=(Color("f4407e") if st.kind=="health" else Color("feb633")).lightened(.55)
    if bool(HarborPrefs.values.effects):ring.a=0.35+0.65*abs(sin(Time.get_ticks_msec()/312.5))
   draw_line(Vector2(ring_x,t+.75),Vector2(w-t-rr,t+.75),ring,1.5,true)
   draw_line(Vector2(ring_x,h-t-.75),Vector2(w-t-rr,h-t-.75),ring,1.5,true)
   draw_arc(Vector2(w-t-rr,h*.5),rr-.75,deg_to_rad(-90),deg_to_rad(90),10,ring,1.5,true)
  if fill_w>rr*2+4:
   draw_line(Vector2(t+rr,t+1),Vector2(fill_x-rr,t+1),Color(1,1,1,.35),1,true)
   draw_line(Vector2(t+rr,h-t-1),Vector2(fill_x-rr,h-t-1),Color(0,0,0,.10),1,true)
  if st.flash>0 and bool(HarborPrefs.values.effects):
   var f: float=st.flash/0.4
   draw_circle(Vector2(maxf(fill_x-3,t+2),h*.5),2.5,Color(1,1,1,.95*f))
   var halo:=Color(light);halo.a=.7*f
   draw_line(Vector2(h*.5,-2.5),Vector2(w-h*.5,-2.5),halo,2,true)
   draw_line(Vector2(h*.5,h+2.5),Vector2(w-h*.5,h+2.5),halo,2,true)
   draw_arc(Vector2(w-h*.5,h*.5),h*.5+2.5,deg_to_rad(-90),deg_to_rad(90),10,halo,2,true)
   draw_arc(Vector2(h*.5,h*.5),h*.5+2.5,deg_to_rad(90),deg_to_rad(270),10,halo,2,true)

class MiniBar extends Control:
 ## 静默态迷你条：白环 2px 画在 34x8 之外，底影 (1.5,2)，异常时换成案 2 的警报环。
 var color:=Color("638eff")
 var frac:=1.0
 var zero:=false
 var alert:=false
 var alert_health:=false
 var backing: StyleBoxFlat
 var ring: StyleBoxFlat
 var face: StyleBoxFlat
 var fill: StyleBoxFlat
 func _ready() -> void:
  mouse_filter=Control.MOUSE_FILTER_IGNORE
  backing=_box(Color("638eff"),6);ring=_box(Color.WHITE,6);face=_box(Color("eaf2ff"),4);fill=_box(color,4)
 func _box(c: Color,r: int) -> StyleBoxFlat:
  var box:=StyleBoxFlat.new();box.bg_color=c;box.set_corner_radius_all(r)
  box.content_margin_left=0;box.content_margin_right=0;box.content_margin_top=0;box.content_margin_bottom=0
  return box
 func update(next_frac: float,next_zero: bool,next_alert: bool,next_health: bool) -> void:
  var changed: bool=not is_equal_approx(frac,next_frac) or zero!=next_zero or alert!=next_alert or alert_health!=next_health
  frac=next_frac;zero=next_zero;alert=next_alert;alert_health=next_health
  if not changed:return
  ring.bg_color=(Color("ffd7e4") if alert_health else Color("ffe9c2")) if alert else Color.WHITE
  backing.bg_color=(Color("f4407e") if alert_health else Color("feb633")) if alert else Color("638eff")
  face.bg_color=Color("eef1f6") if zero else Color("eaf2ff")
  queue_redraw()
 func _draw() -> void:
  if ring==null:return
  var outer:=size+Vector2(4,4)
  backing.draw(get_canvas_item(),Rect2(Vector2(-.5,0),outer))
  ring.draw(get_canvas_item(),Rect2(Vector2(-2,-2),outer))
  face.draw(get_canvas_item(),Rect2(Vector2.ZERO,size))
  if frac<=0.0:return
  fill.bg_color=Color("b1bed9") if zero else color
  fill.draw(get_canvas_item(),Rect2(Vector2.ZERO,Vector2(size.x*clampf(frac,0.0,1.0),size.y)))

class FaceIcon extends Control:
 ## 代码绘制的鲸鱼头像，5 种表情。造型按 v2 设计稿 44x40 的 viewBox 等比映射到控件尺寸，
 ## 不新增贴图；改表情只要换 kind 再 queue_redraw()。
 const DARK:=Color("20242c")
 const WET:=Color("7ed5e4")
 const BLUSH:=Color("ff86b2")
 var kind:="fine"
 var tint:=Color("1794f9")
 var k:=1.0
 var oy:=0.0
 func _p(x: float,y: float) -> Vector2:
  return Vector2(x*k,y*k+oy)
 func _bez(a: Vector2,b: Vector2,c: Vector2,d: Vector2,out: PackedVector2Array) -> void:
  for i in 5:
   var t:=float(i)/4.0
   var u:=1.0-t
   out.append(a*u*u*u+b*(3.0*u*u*t)+c*(3.0*u*t*t)+d*(t*t*t))
 func _ell(cx: float,cy: float,rx: float,ry: float) -> PackedVector2Array:
  var pts:=PackedVector2Array()
  for i in 26:
   var a:=TAU*float(i)/26.0
   pts.append(_p(cx+cos(a)*rx,cy+sin(a)*ry))
  return pts
 func _stroke(pts: Array,c: Color,width: float) -> void:
  var out:=PackedVector2Array()
  for p in pts:out.append(_p(float(p[0]),float(p[1])))
  draw_polyline(out,c,width*k,true)
 func _curve(a: Array,b: Array,c: Array,d: Array,col: Color,width: float) -> void:
  var out:=PackedVector2Array()
  _bez(_p(float(a[0]),float(a[1])),_p(float(b[0]),float(b[1])),_p(float(c[0]),float(c[1])),_p(float(d[0]),float(d[1])),out)
  draw_polyline(out,col,width*k,true)
 func _drop(cx: float,cy: float,r: float) -> void:
  draw_colored_polygon(PackedVector2Array([_p(cx,cy-r*2.0),_p(cx+r,cy),_p(cx-r,cy)]),WET)
  draw_circle(_p(cx,cy),r*k,WET)
 func _draw() -> void:
  k=size.x/44.0;oy=(size.y-40.0*k)*.5
  draw_colored_polygon(_ell(20,21,15,12.6),tint)
  var tail:=PackedVector2Array([_p(33.4,21.6)])
  _bez(_p(33.4,21.6),_p(36.0,22.0),_p(38.4,20.9),_p(40.4,18.9),tail)
  _bez(_p(40.4,18.9),_p(40.0,22.5),_p(38.4,25.1),_p(35.8,26.6),tail)
  _bez(_p(35.8,26.6),_p(34.3,25.1),_p(33.4,23.4),_p(33.4,21.6),tail)
  draw_colored_polygon(tail,tint)
  draw_colored_polygon(_ell(19,25,10,6.4),Color(1,1,1,.45))
  _curve([17.6,8.4],[17.6,6.4],[18.9,5.0],[18.9,5.0],tint,1.7)
  _curve([18.9,5.0],[18.9,5.0],[20.2,6.4],[20.2,8.4],tint,1.7)
  if kind=="hungry":
   _curve([11.8,19.4],[13.0,17.0],[15.0,17.0],[16.2,19.4],DARK,1.8)
   _curve([20.8,19.4],[22.0,17.0],[24.0,17.0],[25.2,19.4],DARK,1.8)
   draw_colored_polygon(_ell(18.6,26.2,3.3,2.7),DARK)
   draw_colored_polygon(_ell(18.6,27.5,1.9,1.2),BLUSH)
   _drop(25.2,27.7,1.7)
  elif kind=="tired":
   _curve([11.9,18.4],[13.1,20.1],[15.0,20.1],[16.2,18.4],DARK,1.8)
   _curve([21.0,18.4],[22.2,20.1],[24.1,20.1],[25.3,18.4],DARK,1.8)
   _curve([15.8,26.0],[16.9,25.1],[18.0,26.9],[19.1,26.0],DARK,1.5)
   _curve([19.1,26.0],[20.2,25.1],[21.3,26.9],[22.4,26.0],DARK,1.5)
   _drop(8.2,15.8,1.6)
   _stroke([[29.6,8.4],[33.0,8.4],[29.6,12.2],[33.0,12.2]],DARK,1.3)
   _stroke([[34.8,5.6],[37.4,5.6],[34.8,8.5],[37.4,8.5]],DARK,1.3)
  elif kind=="hurt":
   _stroke([[11.6,16.6],[15.0,19.0],[11.6,21.4]],DARK,1.9)
   _stroke([[25.6,16.6],[22.2,19.0],[25.6,21.4]],DARK,1.9)
   _curve([15.4,28.0],[17.3,25.5],[20.1,25.5],[22.0,28.0],DARK,1.7)
   _stroke([[27.6,9.4],[32.0,13.8]],Color("f4407e"),2.2)
   _stroke([[32.0,9.4],[27.6,13.8]],Color("f4407e"),2.2)
  elif kind=="low":
   draw_circle(_p(14.2,19.2),1.9*k,DARK);draw_circle(_p(23.0,19.2),1.9*k,DARK)
   _curve([11.6,15.8],[13.0,14.8],[14.6,14.8],[16.0,15.6],DARK,1.6)
   _curve([21.2,15.6],[22.6,14.8],[24.2,14.8],[25.6,15.8],DARK,1.6)
   _curve([15.8,27.6],[17.5,25.7],[19.9,25.7],[21.6,27.6],DARK,1.6)
   _drop(14.2,24.8,1.6)
  else:
   draw_circle(_p(14.0,18.6),2.1*k,DARK);draw_circle(_p(14.8,17.8),.7*k,Color.WHITE)
   draw_circle(_p(23.2,18.6),2.1*k,DARK);draw_circle(_p(24.0,17.8),.7*k,Color.WHITE)
   _curve([15.2,24.8],[16.8,26.9],[20.6,26.9],[22.2,24.8],DARK,1.7)
   draw_colored_polygon(_ell(10.4,23.0,2.4,1.5),Color(BLUSH,.5))
   draw_colored_polygon(_ell(27.0,23.0,2.4,1.5),Color(BLUSH,.5))

class BubbleTail extends Control:
 ## 气泡左侧的尖角：白包边菱形 + 承面内芯，和气泡同一套贴纸语言。
 var face:=Color("fff6dd")
 func _draw() -> void:
  var c:=size*.5
  var outer:=PackedVector2Array([Vector2(c.x,0),Vector2(size.x,c.y),Vector2(c.x,size.y),Vector2(0,c.y)])
  draw_colored_polygon(outer,Color.WHITE)
  var inner:=PackedVector2Array()
  for p in outer:inner.append(c+(p-c)*.47)
  draw_colored_polygon(inner,face)

class PulseDot extends Control:
 ## 告警气泡前的呼吸圆点，1.2s 一圈；特效关掉或气泡隐藏时不空转。
 var tint:=Color("f4407e")
 var phase:=0.0
 func _process(delta: float) -> void:
  if not is_visible_in_tree() or not bool(HarborPrefs.values.effects):return
  phase+=delta;queue_redraw()
 func _draw() -> void:
  var c:=size*.5
  var beat: float=0.5+0.5*sin(phase*TAU/1.2)
  draw_circle(c,3.4+1.6*beat,Color(tint,.22))
  draw_circle(c,3.0,Color(tint,.75))
  draw_circle(c,2.1,tint)

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
 if not free_world():cancel_dash();hud.hide();edge_glow.hide();return
 hud.show()
 hit_window=maxf(0.0,hit_window-delta);hold_window=maxf(0.0,hold_window-delta);mood_window=maxf(0.0,mood_window-delta)
 if edge_glow.visible:
  edge_glow.modulate.a=(.72+.28*sin(Time.get_ticks_msec()/1000.0*TAU/1.2)) if bool(HarborPrefs.values.effects) else 1.0
 _pulse_icons()
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
 elif model.value("hunger")<=0:hud_status.text="饱食见底 · 去咖啡馆吃点东西"
 elif not model.can_sprint() or model.value("stamina")<float(model.balance.rules.dash_stamina_cost):hud_status.text="体力不足 · 停下恢复后突进"
 else:hud_status.text=model.status_text()+" · Shift 突进"
 hud_status.add_theme_color_override("font_color",Color("8a5a17") if model.value("hunger")<=20 else Color("4a71c4"))
 _apply_hud_state()
 if active:
  for vital in ["health","stamina","hunger","mood"]:_update_meter(vital,vital)
  status_subtitle.text="Lv.%d  港口蓝鲸信使  ·  %s"%[int(model.state.level),model.status_text()]
  feedback.text=message

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
 status_subtitle=WhaleStyle.label(heading,"Lv.%d  港口蓝鲸信使  ·  %s"%[int(model.state.level),model.status_text()],Vector2(105,56),Vector2(720,27),18,Color("dbe5ed"))
 _button(heading,"Esc 关闭",Vector2(837,22),Vector2(145,50),close)
 var portrait:=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.texture=portrait_texture;portrait.position=Vector2(32,129);portrait.size=Vector2(322,464);portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(portrait)
 var vitality: Array=[["health","生命",Color("f4407e")],["stamina","体力",Color("23cbd4")],["hunger","饱食",Color("feb633")],["mood","心情",Color("638eff")]]
 for i in vitality.size():
  var entry: Array=vitality[i]
  var pos:=Vector2(380+(i%2)*318,143+(i/2)*78)
  var card:=WhaleStyle.panel(panel,pos,Vector2(303,66),"card")
  card.add_theme_stylebox_override("panel",_sticker_frame())
  _sticker_backing(card,card.get_theme_stylebox("panel"))
  _meter(card,entry[0],entry[1],Vector2(12,12),Vector2(279,42),entry[2],entry[0]);_update_meter(entry[0],entry[0])
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
 message="已卸下 "+str(game.loot.definitions[id].name);_render();refresh();return true

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
