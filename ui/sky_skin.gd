extends RefCounted
## Native blue/white UI, derived from the project's UI prototype. No bitmap/icon dependencies.
const INK := Color("30465b")
const MUTED := Color("6b8294")
const BLUE := Color("269ecb")
const PINK := Color("fa91ae")
static var styles: Dictionary = {}

static func frame(kind: String = "panel") -> StyleBoxFlat:
 if styles.has(kind):return styles[kind]
 var fills: Dictionary={"panel":"fdfefe","dialogue":"fdfefe","paper":"ffffff","sky":"f0f6fa","quote":"e4f0f4","status":"eef6fa","button":"ffffff","hover":"e7f5fc","pressed":"cceaf7","disabled":"eff3f5","selected":"d9edf7","card":"ffffff","nameplate":"2298c1","speaker":"fa91ae"}
 var s:=StyleBoxFlat.new()
 s.bg_color=Color(fills.get(kind,"fdfefe"));s.border_color=Color("cfdde5")
 s.set_border_width_all(1);s.set_corner_radius_all(9);s.anti_aliasing=true
 s.content_margin_left=15;s.content_margin_right=15;s.content_margin_top=9;s.content_margin_bottom=9
 if kind in ["panel","dialogue","paper"]:
  s.set_corner_radius_all(12);s.shadow_color=Color(.12,.28,.39,.13);s.shadow_size=8;s.shadow_offset=Vector2(0,4)
 elif kind in ["button","card"]:
  s.shadow_color=Color(.12,.28,.39,.09);s.shadow_size=3;s.shadow_offset=Vector2(0,2)
 if kind in ["selected","pressed"]:s.border_color=BLUE
 if kind in ["nameplate","speaker"]:
  s.set_border_width_all(0);s.shadow_color=Color(.12,.28,.39,.12);s.shadow_size=5;s.shadow_offset=Vector2(0,3)
 styles[kind]=s
 return s

static func theme(font: Font) -> Theme:
 var t:=Theme.new();t.default_font=font;t.default_font_size=22
 for type in ["Label","RichTextLabel","Button","LineEdit","OptionButton","SpinBox"]:
  t.set_color("font_color",type,INK);t.set_color("font_hover_color",type,BLUE)
  t.set_color("font_pressed_color",type,INK);t.set_color("font_focus_color",type,INK)
  t.set_color("font_disabled_color",type,MUTED)
 t.set_stylebox("panel","Panel",frame())
 t.set_stylebox("panel","PanelContainer",frame())
 for type in ["Button","OptionButton"]:
  for state in {"normal":"button","hover":"hover","pressed":"pressed","hover_pressed":"pressed","disabled":"disabled"}:
   t.set_stylebox(state,type,frame({"normal":"button","hover":"hover","pressed":"pressed","hover_pressed":"pressed","disabled":"disabled"}[state]))
  var focus:=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=BLUE
  focus.set_border_width_all(2);focus.set_corner_radius_all(9);focus.set_expand_margin_all(2)
  t.set_stylebox("focus",type,focus)
 t.set_stylebox("normal","LineEdit",frame("paper"));t.set_stylebox("focus","LineEdit",frame("selected"))
 t.set_color("caret_color","LineEdit",BLUE);t.set_color("selection_color","LineEdit",Color("cceaf7"))
 t.set_color("font_placeholder_color","LineEdit",MUTED);t.set_color("font_selected_color","LineEdit",INK)
 for type in ["VScrollBar","HScrollBar"]:
  var track:=frame("sky").duplicate();track.set_border_width_all(0);track.set_corner_radius_all(4)
  var thumb:=frame("selected").duplicate();thumb.set_border_width_all(0);thumb.set_corner_radius_all(4)
  t.set_stylebox("scroll",type,track);t.set_stylebox("scroll_focus",type,track)
  t.set_stylebox("grabber",type,thumb);t.set_stylebox("grabber_highlight",type,frame("hover"));t.set_stylebox("grabber_pressed",type,frame("pressed"))
 t.set_constant("separation","VBoxContainer",12)
 return t

static func panel(parent: Node,pos: Vector2,dimensions: Vector2,kind: String="panel") -> Panel:
 var p:=Panel.new();p.position=pos;p.size=dimensions;p.add_theme_stylebox_override("panel",frame(kind))
 if kind in ["nameplate","speaker"]:
  p.set_script(preload("res://ui/sky_header.gd"))
 p.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;parent.add_child(p)
 return p
