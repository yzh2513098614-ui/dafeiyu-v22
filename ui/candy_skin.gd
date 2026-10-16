extends RefCounted
## Shared original game-ui specification for the whole playable game.
const INK:=Color("2857c9")
const MUTED:=Color("7690b5")
const BLUE:=Color("638eff")
const PINK:=Color("e697b8")
const MINT:=Color("31b9c6")
const GOLD:=Color("edbf65")
const PAPER:=Color("fcfdff")
const DARK:=Color("355fae")
const Sticker=preload("res://ui/harbor_inventory_skin.gd")
static var design_theme: Theme
static func editable_theme()->Theme:
 if design_theme==null and ResourceLoader.exists("res://ui/design/sticker_shared_theme.tres"):design_theme=load("res://ui/design/sticker_shared_theme.tres")
 return design_theme

static func frame(kind: String="panel") -> StyleBoxFlat:
 var editable:=editable_theme()
 if editable!=null and editable.has_stylebox(kind,"GameUI"):return editable.get_stylebox(kind,"GameUI")
 return Sticker.frame(kind)

static func decorate_panel(panel: Panel) -> void:
 panel.set_script(preload("res://ui/handheld_panel.gd"))

static func decorate_button(button: Button) -> void:
 button.set_script(preload("res://ui/ocean_menu_button.gd"))

static func button(button: Button,primary: bool=false,selected: bool=false) -> void:
 for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
  var kind:String=state
  if state=="normal":kind="primary" if primary else ("selected" if selected else "button")
  elif state=="hover":kind="primary_hover" if primary else "hover"
  elif state in ["pressed","hover_pressed"]:kind="primary_pressed" if primary else "pressed"
  button.add_theme_stylebox_override(state,frame(kind))
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,INK)
 button.add_theme_color_override("font_disabled_color",Color("70758f"));decorate_button(button)
