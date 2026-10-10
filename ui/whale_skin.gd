extends RefCounted
## Shared native sky UI; existing icons and mascot remain unchanged.
const SkyStyle=preload("res://ui/sky_skin.gd")
const INK := SkyStyle.INK
const MUTED := SkyStyle.MUTED
const BLUE := SkyStyle.BLUE
const GOLD := SkyStyle.BLUE
static var boxes: Dictionary = {}

static func frame(kind: String = "panel") -> StyleBox:
 if boxes.has(kind):return boxes[kind]
 var s:=SkyStyle.frame(kind)
 boxes[kind]=s;return s

static func theme(font: Font) -> Theme:
 var t:=SkyStyle.theme(font)
 for type in ["Label","RichTextLabel","Button","LineEdit","SpinBox","OptionButton"]:
  t.set_color("font_color",type,INK);t.set_color("font_hover_color",type,BLUE)
  t.set_color("font_pressed_color",type,INK);t.set_color("font_focus_color",type,INK)
  t.set_color("font_disabled_color",type,MUTED)
 t.set_stylebox("panel","Panel",frame())
 for type in ["Button","OptionButton"]:
  for state in {"normal":"button","hover":"hover","pressed":"pressed","hover_pressed":"pressed","disabled":"disabled"}:
   t.set_stylebox(state,type,frame({"normal":"button","hover":"hover","pressed":"pressed","hover_pressed":"pressed","disabled":"disabled"}[state]))
  var focus:=StyleBoxFlat.new();focus.bg_color=Color(0,0,0,0);focus.border_color=BLUE;focus.set_border_width_all(2);focus.set_corner_radius_all(9)
  t.set_stylebox("focus",type,focus)
 t.set_stylebox("normal","LineEdit",frame("paper"));t.set_stylebox("focus","LineEdit",frame("selected"))
 t.set_color("caret_color","LineEdit",BLUE);t.set_color("selection_color","LineEdit",Color("bdd5ff"))
 t.set_color("font_placeholder_color","LineEdit",MUTED)
 t.set_color("font_selected_color","LineEdit",INK)
 t.set_icon("up","SpinBox",load("res://assets/ui/arrow_up.svg"));t.set_icon("down","SpinBox",load("res://assets/ui/arrow_down.svg"))
 for type in ["VScrollBar","HScrollBar"]:
  t.set_stylebox("scroll",type,frame("sky"));t.set_stylebox("scroll_focus",type,frame("sky"))
  t.set_stylebox("grabber",type,frame("selected"));t.set_stylebox("grabber_highlight",type,frame("hover"));t.set_stylebox("grabber_pressed",type,frame("pressed"))
 t.set_constant("separation","VBoxContainer",12)
 return t

static func label(parent: Node,text: String,pos: Vector2,size: Vector2,font_size: int = 22,color: Color = INK) -> Label:
 var l:=Label.new();l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE
 l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color)
 l.text=text;l.position=pos;l.size=size;parent.add_child(l);return l

static func panel(parent: Node,pos: Vector2,size: Vector2,kind: String = "panel") -> Panel:
 return SkyStyle.panel(parent,pos,size,kind)

static func icon(parent: Node,name: String,pos: Vector2,size: Vector2) -> TextureRect:
 var r:=TextureRect.new();r.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;r.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 r.texture=load("res://assets/ui/"+name+".svg");r.position=pos;r.size=size
 r.mouse_filter=Control.MOUSE_FILTER_IGNORE;r.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;parent.add_child(r);return r

static func mascot(parent: Node,pos: Vector2,size: Vector2) -> TextureRect:
 var r:=TextureRect.new();r.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;r.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 r.texture=load("res://assets/ui/whale_mascot.png");r.position=pos;r.size=size
 r.mouse_filter=Control.MOUSE_FILTER_IGNORE;r.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;parent.add_child(r);return r

static func card_button(b: Button,selected: bool = false) -> void:
 b.add_theme_stylebox_override("normal",frame("selected" if selected else "card"))
 b.add_theme_stylebox_override("hover",frame("selected"));b.add_theme_stylebox_override("pressed",frame("selected"))
 b.add_theme_color_override("font_pressed_color",INK)

static var _grabber_tex: Texture2D

## Native slider handle; no external icon asset.
static func _grabber() -> Texture2D:
 if _grabber_tex != null:return _grabber_tex
 var side:=18
 var img:=Image.create(side,side,false,Image.FORMAT_RGBA8)
 img.fill(Color(0,0,0,0))
 for y in side:
  for x in side:
   var dx:=float(x)-side/2.0+0.5;var dy:=float(y)-side/2.0+0.5
   var distance:=sqrt(dx*dx+dy*dy)
   if distance<=side/2.0-1.5:img.set_pixel(x,y,GOLD)
   elif distance<=side/2.0-0.5:img.set_pixel(x,y,Color("ffffff"))
 _grabber_tex=ImageTexture.create_from_image(img)
 return _grabber_tex

## Shared blue slider for title and in-game settings.
static func style_slider(bar: HSlider) -> void:
 var track:=StyleBoxFlat.new();track.bg_color=Color("e4f0f4");track.border_color=Color("cfdde5")
 track.set_border_width_all(1);track.set_corner_radius_all(7)
 track.content_margin_top=7;track.content_margin_bottom=7
 var filled:=StyleBoxFlat.new();filled.bg_color=BLUE;filled.set_corner_radius_all(7)
 filled.content_margin_top=7;filled.content_margin_bottom=7
 bar.add_theme_stylebox_override("slider",track)
 bar.add_theme_stylebox_override("grabber_area",filled)
 bar.add_theme_stylebox_override("grabber_area_highlight",filled)
 bar.add_theme_icon_override("grabber",_grabber())
 bar.add_theme_icon_override("grabber_highlight",_grabber())

static func pulse(node: Control) -> void:
 node.pivot_offset=node.size/2
 var tween:=node.create_tween();tween.tween_property(node,"scale",Vector2(1.055,1.055),.10)
 tween.tween_property(node,"scale",Vector2.ONE,.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
