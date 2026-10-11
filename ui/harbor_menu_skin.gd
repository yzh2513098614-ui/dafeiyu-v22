extends RefCounted
## Native adapter for ocean-ui-code-demo, with the requested blue/white buttons.
const Base=preload("res://ui/handheld_skin.gd")
const S=preload("res://ui/ocean_sample_skin.gd")
const INK=S.INK
const MUTED=Color("756e88")
const BLUE=Color("397dbc")
const CREAM=S.CREAM
static var boxes: Dictionary={}

static func frame(kind: String="panel") -> StyleBoxFlat:
 if boxes.has(kind):return boxes[kind]
 var fills: Dictionary={"shell":"b8b9c1","panel":"7adcc4","portrait":"f48bb7","white":"f9fcff","button":"91b9df","hover":"b4d5f1","pressed":"759fc7","selected":"7adcc4","primary":"689bd0","disabled":"c9cdd4","nameplate":"45465f","screen":"45465f","dialogue":"fff7dd","paper":"fff7dd"}
 var radius:=68 if kind=="shell" else (24 if kind in ["panel","portrait","nameplate","screen"] else 16)
 var border:=6 if kind in ["shell","panel","portrait"] else 4
 var shadow:=7 if kind in ["shell","panel","portrait","nameplate","screen"] else 2
 var box:=S.box(Color(fills.get(kind,"fff7dd")),radius,INK,border,shadow)
 # Compact native margins keep the existing 44px tabs and music rows intact.
 box.content_margin_top=4;box.content_margin_bottom=4
 if kind in ["button","white","hover","pressed","primary","selected","disabled"]:
  box.shadow_color=box.bg_color.darkened(.3);box.shadow_offset=Vector2(0,2 if kind=="pressed" else 7)
 boxes[kind]=box;return box

static func theme(font: Font) -> Theme:
 var result:=Base.theme(font)
 for type in ["Button","OptionButton"]:
  for state in ["normal","hover","pressed","hover_pressed","disabled"]:
   result.set_stylebox(state,type,frame("button" if state=="normal" else ("pressed" if state=="hover_pressed" else state)))
 return result

static func label(parent: Node,text: String,pos: Vector2,dimensions: Vector2,font_size: int=22,color: Color=INK) -> Label:
 return preload("res://dialogue/pixel_skin.gd").label(parent,text,pos,dimensions,font_size,color)

static func panel(parent: Node,pos: Vector2,dimensions: Vector2,kind: String="panel") -> Panel:
 var item:=Panel.new();item.position=pos;item.size=dimensions;item.mouse_filter=Control.MOUSE_FILTER_IGNORE
 item.set_meta("ocean_kind",kind);item.add_theme_stylebox_override("panel",frame(kind))
 item.set_script(preload("res://ui/ocean_menu_panel.gd"));parent.add_child(item);return item

static func decorate(button: Button) -> void:
 button.set_script(preload("res://ui/ocean_menu_button.gd"))

static func primary(button: Button) -> void:
 for state in ["normal","hover","pressed","hover_pressed"]:
  var box:=frame("primary").duplicate()
  if state=="hover":box.bg_color=Color("80afe0")
  elif state in ["pressed","hover_pressed"]:box.bg_color=Color("4d7eb3");box.shadow_offset.y=2
  button.add_theme_stylebox_override(state,box)
 for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
  button.add_theme_color_override(key,CREAM)
 button.add_theme_color_override("font_outline_color",INK);button.add_theme_constant_override("outline_size",3)

static func alternate(button: Button,white: bool) -> void:
 button.add_theme_stylebox_override("normal",frame("white" if white else "button"))
 button.set_meta("white_button",white)
 for state in ["hover","pressed","hover_pressed"]:
  var box:=frame("pressed" if state=="hover_pressed" else state).duplicate()
  if white:box.bg_color=Color("e5f1fc") if state=="hover" else Color("d1e4f6")
  button.add_theme_stylebox_override(state,box)
