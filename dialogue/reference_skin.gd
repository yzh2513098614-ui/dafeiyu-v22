extends RefCounted
## Original navy/gold dialogue skin based on the supplied layout reference.
const SkyStyle=preload("res://ui/handheld_skin.gd")
const Decor=preload("res://dialogue/reference_panel.gd")
const INK=Color("30365e")
const MUTED=Color("a9b4d9")
static func frame(kind: String="dialogue") -> StyleBoxFlat:
 var s:=StyleBoxFlat.new()
 s.bg_color=Color("252b55")
 s.border_color=Color("b7a875")
 s.set_border_width_all(2);s.set_corner_radius_all(16)
 s.anti_aliasing=true
 if kind=="speaker":
  s.bg_color=Color("f1f0fa");s.border_color=Color("b9acd0");s.set_corner_radius_all(30)
 elif kind in ["button","selected"]:
  s.bg_color=Color("404b78") if kind=="selected" else Color("2e365e")
  s.border_color=Color("a8b8de");s.set_border_width_all(1);s.set_corner_radius_all(10)
  s.content_margin_left=12;s.content_margin_right=12;s.content_margin_top=5;s.content_margin_bottom=5
 return s
static func theme(font: Font) -> Theme:
 var t:=SkyStyle.theme(font)
 t.set_color("font_color","Button",Color("edf0ff"))
 t.set_color("font_hover_color","Button",Color.WHITE)
 t.set_color("font_pressed_color","Button",Color("fff3c6"))
 t.set_font_size("font_size","Button",20)
 t.set_stylebox("normal","Button",frame("button"))
 t.set_stylebox("hover","Button",frame("selected"))
 t.set_stylebox("pressed","Button",frame("selected"))
 return t
static func label(parent: Node,text: String,pos: Vector2,size: Vector2,font_size: int=22,color: Color=INK) -> Label:
 var l:=Label.new();l.text=text;l.position=pos;l.size=size
 l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE
 l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color)
 parent.add_child(l);return l
static func panel(parent: Node,pos: Vector2,size: Vector2,kind: String="dialogue") -> Panel:
 var p:=Panel.new();p.position=pos;p.size=size;p.set_script(Decor);p.role=kind
 p.add_theme_stylebox_override("panel",frame(kind));parent.add_child(p);return p
