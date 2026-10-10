extends RefCounted
const INK=Color("334475")
const MUTED=Color("687998")
const BLUE=Color("4d659e")
static var styles: Dictionary={}
static func frame(kind: String="dialogue") -> StyleBoxTexture:
 if styles.has(kind):return styles[kind]
 var s:=StyleBoxTexture.new();s.texture=load("res://assets/dialogue/"+kind+".svg")
 s.texture_margin_left=16;s.texture_margin_right=16;s.texture_margin_top=16;s.texture_margin_bottom=16
 s.content_margin_left=20;s.content_margin_right=20;s.content_margin_top=12;s.content_margin_bottom=12
 styles[kind]=s;return s
static func theme(font: Font) -> Theme:
 var t:=Theme.new();t.default_font=font;t.default_font_size=21
 for type in ["Label","Button","RichTextLabel"]:
  t.set_color("font_color",type,INK);t.set_color("font_hover_color",type,BLUE);t.set_color("font_pressed_color",type,INK);t.set_color("font_disabled_color",type,MUTED)
 for type in ["Button"]:
  for state in ["normal","hover","pressed","focus","disabled"]:t.set_stylebox(state,type,frame("selected" if state in ["hover","pressed","focus"] else "dialogue"))
 t.set_stylebox("panel","Panel",frame())
 return t
static func label(parent: Node,text: String,pos: Vector2,size: Vector2,font_size: int=22,color: Color=INK) -> Label:
 var l:=Label.new();l.text=text;l.position=pos;l.size=size;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
static func panel(parent: Node,pos: Vector2,size: Vector2,kind: String="dialogue") -> Panel:
 var p:=Panel.new();p.position=pos;p.size=size;p.add_theme_stylebox_override("panel",frame(kind));p.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;parent.add_child(p);return p
