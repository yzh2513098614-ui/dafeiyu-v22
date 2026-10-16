extends SceneTree
## Run explicitly to regenerate the native, editable blue-white shared theme.
const Sticker=preload("res://ui/harbor_inventory_skin.gd")
func _initialize()->void:
 var theme:Theme=load("res://ui/design/game_ui_theme.tres").duplicate(true)
 theme.resource_name="大肥鱼 · 蓝白厚边框与糖果副色"
 var aliases:Dictionary={"dialogue":"panel","hand_tray":"shell","sky":"bag","mint":"bag","pink":"panel","quote":"paper","white":"button","nameplate":"dark","screen":"dark","plate":"status","tag":"dark","gauge_track":"empty"}
 for kind in theme.get_stylebox_list("GameUI"):
  var style:StyleBoxFlat=Sticker.frame(aliases.get(kind,kind)).duplicate();style.resource_name=kind
  if kind=="mint":style.bg_color=Color("e7f7f8")
  elif kind=="pink":style.bg_color=Color("fff0f6")
  elif kind=="quote":style.bg_color=Color("f2edff")
  theme.set_stylebox(kind,"GameUI",style)
 for type in ["Label","RichTextLabel","Button","LineEdit","SpinBox","OptionButton","PopupMenu"]:
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:theme.set_color(state,type,Sticker.INK)
  theme.set_color("font_disabled_color",type,Sticker.MUTED)
 for type in ["Button","OptionButton"]:
  for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:theme.set_stylebox(state,type,Sticker.frame("button" if state=="normal" else "pressed" if state=="hover_pressed" else state))
 theme.set_stylebox("normal","LineEdit",Sticker.frame("card"));theme.set_stylebox("focus","LineEdit",Sticker.frame("focus"))
 theme.set_stylebox("panel","Panel",Sticker.frame("panel"));theme.set_stylebox("panel","PanelContainer",Sticker.frame("panel"))
 var result:=ResourceSaver.save(theme,"res://ui/design/sticker_shared_theme.tres");print("STICKER SHARED THEME ",error_string(result));quit(result)
