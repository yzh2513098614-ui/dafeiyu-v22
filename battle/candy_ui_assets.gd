extends RefCounted
## Native replacement for old painted-frame calls; keeps their API stable.
const S=preload("res://ui/candy_skin.gd")
static func apply(control: Control,key: String,color_driver: StyleBoxFlat=null) -> void:
 control.set_meta("candy_role",key)
 if control is Button:
  S.button(control,key=="primary");return
 if control is Panel:
  var kind: String={"title":"dark","enemy_plate":"dark","energy":"dark","info":"paper","tag":"tag","portrait":"sky","gauge_track":"gauge_track"}.get(key,"panel")
  var box:=S.frame(kind).duplicate() as StyleBoxFlat
  if key=="gauge_fill" and color_driver:
   box=color_driver;box.set_corner_radius_all(8);box.set_border_width_all(0);box.shadow_size=0
  control.add_theme_stylebox_override("panel",box)
  if key not in ["gauge_fill","gauge_track"]:S.decorate_panel(control)
static func panel(control: Panel,kind: String) -> void:
 control.set_meta("candy_role",kind);S.decorate_panel(control)
static func button(control: Button,role: String="secondary") -> void:
 control.set_meta("candy_role",role)
 S.button(control,role in ["primary","attack"],role=="target")
