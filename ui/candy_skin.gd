extends RefCounted
## Shared original game-ui specification for the whole playable game.
const INK:=Color("383655")
const MUTED:=Color("696d90")
const BLUE:=Color("596cde")
const PINK:=Color("ff86b2")
const MINT:=Color("4ad9c5")
const GOLD:=Color("ffe071")
const PAPER:=Color("eaf1ff")
const DARK:=Color("414a7b")
static var boxes: Dictionary={}
static var design_theme: Theme
static func editable_theme()->Theme:
 if design_theme==null and ResourceLoader.exists("res://ui/design/game_ui_theme.tres"):design_theme=load("res://ui/design/game_ui_theme.tres")
 return design_theme

static func frame(kind: String="panel") -> StyleBoxFlat:
 var editable:=editable_theme()
 if editable!=null and editable.has_stylebox(kind,"GameUI"):return editable.get_stylebox(kind,"GameUI")
 if boxes.has(kind):return boxes[kind]
 var fills: Dictionary={"shell":"aab2de","panel":"dce5ff","dialogue":"dce5ff","paper":"eaf1ff","detail":"e5e9ff","sky":"ccf4f1","bag":"b4eeeb","chest":"d9d7ff","mint":"4ad9c5","pink":"ff86b2","quote":"ccf4f1","status":"cfdef4","button":"b6cbff","white":"eaf1ff","hover":"d5e4ff","pressed":"8ea7eb","primary":"ff86b2","primary_hover":"ffadd0","primary_pressed":"dc649b","disabled":"b7bfd4","selected":"4ad9c5","card":"eaf1ff","empty":"aacbd8","nameplate":"414a7b","screen":"414a7b","dark":"414a7b","plate":"d5e2ff","hand_tray":"aab2de","focus":"00000000","gauge_track":"c3cce6","tag":"596cde"}
 var b:=StyleBoxFlat.new();b.bg_color=Color(fills.get(kind,"dce5ff"));b.border_color=INK;b.set_border_width_all(3);b.set_corner_radius_all(14);b.anti_aliasing=true
 b.content_margin_left=12;b.content_margin_right=12;b.content_margin_top=4;b.content_margin_bottom=4
 b.shadow_color=Color(.12,.12,.27,.22);b.shadow_size=2;b.shadow_offset=Vector2(0,4)
 if kind in ["shell","panel","dialogue","hand_tray"]:b.set_border_width_all(4);b.set_corner_radius_all(26);b.shadow_size=5;b.shadow_offset=Vector2(0,6)
 elif kind in ["bag","chest","detail","status","sky","mint","pink"]:b.set_corner_radius_all(21);b.set_border_width_all(3)
 elif kind in ["pressed","primary_pressed"]:b.shadow_offset.y=1
 elif kind=="disabled":b.shadow_size=0;b.border_color=Color("8589a6")
 elif kind=="empty":b.shadow_size=0;b.set_border_width_all(2);b.border_color=Color("8aabbd")
 elif kind=="selected":b.set_border_width_all(4)
 elif kind=="focus":b.bg_color=Color.TRANSPARENT;b.border_color=BLUE;b.set_expand_margin_all(3);b.shadow_size=0
 elif kind=="gauge_track":b.set_corner_radius_all(9);b.set_border_width_all(2);b.shadow_size=0
 boxes[kind]=b;return b

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
