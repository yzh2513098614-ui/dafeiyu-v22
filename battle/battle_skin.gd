extends RefCounted
## Battle-only palette; world menus keep their own skin.
const INK:=Color("293f52")
const MUTED:=Color("526879")
const BLUE:=Color("75adbd")
const GOLD:=Color("8b6233")
const PaintedUi=preload("res://battle/painted_ui_assets.gd")
static var _body_font: FontFile
static var _numeric_font: FontFile
static func _prepare_font(path:String)->FontFile:
 var font:FontFile=load(path).duplicate()
 font.antialiasing=TextServer.FONT_ANTIALIASING_GRAY
 font.hinting=TextServer.HINTING_NORMAL
 font.force_autohinter=true
 font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED
 font.oversampling=0.0
 return font
static func body_font()->Font:
 if _body_font==null:
  _body_font=_prepare_font("res://assets/fonts/misans/MiSans-Demibold.ttf")
 return _body_font
static func numeric_font() -> Font:
 if _numeric_font == null:
  _numeric_font=_prepare_font("res://assets/fonts/misans/MiSans-Bold.ttf")
 return _numeric_font

## 像素硬边开关。
## 这个皮肤原来是纯矢量语言：面板圆角 22px、按钮/卡片 16px、7px 软模糊阴影。
## 而工程其它 UI（WhaleStyle / PixelFrames / pixel_skin）全是像素硬边 ——
## 两套放在同一屏里就是「像素背景 + 柔圆角面板 + 插画卡图」三种风格打架。
## 设 true：圆角归零、软阴影换成 2px 硬偏移。
## 想回原来的柔和风，把这里改成 false 就行（一处开关，不改结构）。
const PIXEL_EDGES:=false

static func _radius(soft: int) -> int:
 return 0 if PIXEL_EDGES else soft

static func _corner(s: StyleBoxFlat,soft: int) -> void:
 s.set_corner_radius_all(_radius(soft))
 if PIXEL_EDGES:
  s.shadow_size=0;s.shadow_offset=Vector2(2,2)

static func frame(kind: String="panel") -> StyleBoxFlat:
 var s:=StyleBoxFlat.new()
 s.bg_color=Color("faf5e9")
 s.bg_color.a=.97
 s.border_color=Color("bac8c1")
 s.set_border_width_all(2)
 s.border_width_bottom=4
 s.set_corner_radius_all(_radius(22))
 s.content_margin_left=18;s.content_margin_right=18
 s.content_margin_top=8;s.content_margin_bottom=8
 s.shadow_color=Color(.19,.29,.32,.20);s.shadow_size=4;s.shadow_offset=Vector2(0,3)
 match kind:
  "plate":s.bg_color=Color("e8f0eb");s.border_color=Color("afc4bf");_corner(s,16)
  "paper","card":s.bg_color=Color("faf4e7")
  "hand_tray":s.bg_color=Color("e6eeea");s.border_color=Color("8ea8a8");s.border_width_bottom=6;_corner(s,20)
  "status":s.bg_color=Color("f7f1e5");s.border_color=Color("aab9b4");s.border_width_bottom=5
  "sky":s.bg_color=Color("eef7f7")
  "button":s.bg_color=Color("e9f0ee");_corner(s,14);s.shadow_size=0
  "hover","selected":s.bg_color=Color("dbf1f0");s.border_color=BLUE;s.set_border_width_all(2);s.shadow_size=0
  "pressed":s.bg_color=Color("cde5ea");s.border_color=BLUE;s.shadow_size=0
  "disabled":s.bg_color=Color("ecf0f1");s.border_color=Color("dbe3e7");s.shadow_size=0
  "focus":s.bg_color=Color.TRANSPARENT;s.border_color=BLUE;s.set_border_width_all(2);s.shadow_size=0
 return s

static func theme(font: Font) -> Theme:
 var t:=Theme.new();t.default_font=font;t.default_font_size=22
 for type in ["Label","RichTextLabel","Button"]:
  t.set_color("font_color",type,INK);t.set_color("font_hover_color",type,INK)
  t.set_color("font_pressed_color",type,INK);t.set_color("font_focus_color",type,INK)
  t.set_color("font_disabled_color",type,Color("8197aa"))
 t.set_stylebox("panel","Panel",frame())
 for state in ["normal","hover","pressed","disabled","focus"]:
  t.set_stylebox(state,"Button",frame("button" if state=="normal" else state))
 for type in ["VScrollBar","HScrollBar"]:
  var track:=StyleBoxFlat.new();track.bg_color=Color("e7f0f0");track.set_corner_radius_all(4)
  track.content_margin_left=4;track.content_margin_right=4;track.content_margin_top=4;track.content_margin_bottom=4
  var thumb:=track.duplicate() as StyleBoxFlat;thumb.bg_color=Color("a9cbd2")
  t.set_stylebox("scroll",type,track);t.set_stylebox("grabber",type,thumb)
  t.set_stylebox("grabber_highlight",type,thumb);t.set_stylebox("grabber_pressed",type,thumb)
 t.set_constant("separation","VBoxContainer",8)
 return t

static func panel(parent: Node,pos: Vector2,size: Vector2,kind: String="panel") -> Panel:
 var p:=Panel.new();p.position=pos;p.size=size;p.add_theme_stylebox_override("panel",frame(kind));parent.add_child(p);PaintedUi.panel(p,kind);return p

static func label(parent: Node,text: String,pos: Vector2,size: Vector2,font_size: int=22,color: Color=INK) -> Label:
 var l:=Label.new();l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE
 l.add_theme_font_override("font",body_font())
 l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color)
 l.text=text;l.position=pos;l.size=size;parent.add_child(l);return l

static func card_button(b: Button,selected: bool=false) -> void:
 for state in ["normal","hover","pressed","disabled","focus"]:
  b.add_theme_stylebox_override(state,frame(("card" if selected else "button") if state=="normal" else state))
 b.add_theme_color_override("font_color",INK);b.add_theme_color_override("font_hover_color",INK)
 b.add_theme_color_override("font_focus_color",INK);b.add_theme_color_override("font_pressed_color",INK)
 b.add_theme_color_override("font_disabled_color",Color("687e88"))
 PaintedUi.button(b)

static func primary(b: Button) -> void:
 var normal:=frame("button");normal.bg_color=Color("ffe6cd");normal.border_color=Color("edcfb0")
 var hover:=normal.duplicate() as StyleBoxFlat;hover.bg_color=Color("ffedd9")
 b.add_theme_stylebox_override("normal",normal);b.add_theme_stylebox_override("hover",hover)
 for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:b.add_theme_color_override(state,INK)
 PaintedUi.button(b,"primary")

static func action(b: Button,role: String) -> void:
 var color: Color={"attack":Color("ffe6cd"),"intent_cast":Color("ede6fb"),"heal":Color("dff0e7"),"multihit":Color("fff0ce"),"move":Color("e0f1fa"),"target":Color("fbe7ee")}.get(role,Color("edf7fa"))
 var normal:=frame("button");normal.bg_color=color
 b.add_theme_stylebox_override("normal",normal)
 var hover:=frame("hover");hover.bg_color=color.lightened(.13)
 b.add_theme_stylebox_override("hover",hover)
 PaintedUi.button(b,role)



