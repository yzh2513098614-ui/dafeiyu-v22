extends RefCounted
## Title and departure menus use the same candy specification as battle and inventory.
const Base=preload("res://ui/handheld_skin.gd")
const S=preload("res://ui/candy_skin.gd")
const INK=S.INK
const MUTED=S.MUTED
const BLUE=S.BLUE
const CREAM=S.PAPER

static func frame(kind: String="panel") -> StyleBoxFlat:
 var box:=S.frame("pink" if kind=="portrait" else kind).duplicate() as StyleBoxFlat
 if kind=="shell":box.set_corner_radius_all(48)
 return box

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
 S.button(button,true)

static func alternate(button: Button,white: bool) -> void:
 S.button(button)
 if white:button.add_theme_stylebox_override("normal",frame("paper"))
 button.set_meta("white_button",white)
