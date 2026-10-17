extends RefCounted
## One compact world action, using the project's current button palette.
const EncounterTheme=preload("res://ui/design/encounter_theme.tres")
const BadgeIcon=preload("res://ui/encounter_badge_icon.gd")
static func create(game,parent:Node,text:String,action:Callable,alternate:Callable=Callable())->Button:
 var button:Button=game._button(text,Vector2.ZERO,Vector2(156,40),parent,action)
 button.focus_mode=Control.FOCUS_NONE
 button.theme=EncounterTheme;button.theme_type_variation="WorldAction"
 button.add_theme_font_size_override("font_size",18)
 button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
  var style:StyleBox=EncounterTheme.get_stylebox(state,"WorldAction").duplicate()
  button.add_theme_stylebox_override(state,style)
 for state in ["font_color","font_hover_color","font_pressed_color"]:button.add_theme_color_override(state,Color.WHITE)
 var icon:=BadgeIcon.new();icon.name="WorldActionIcon";icon.kind="search";icon.position=Vector2(12,10);icon.size=Vector2(24,24);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(icon)
 var pointer:=BadgeIcon.new();pointer.name="WorldActionPointer";pointer.kind="pointer";pointer.size=Vector2(24,24);pointer.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(pointer)
 if alternate.is_valid():
  button.gui_input.connect(func(event:InputEvent):
   if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
    button.accept_event();alternate.call())
 return button

static func fit_text(button:Button)->void:
 var font:Font=button.get_theme_font("font")
 var width:float=font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x+60
 button.size=Vector2(clampf(width,144,270),44)
 button.get_node("WorldActionIcon").kind="search" if button.text.contains("物品") or button.text.contains("调查") else "chevron"
 button.get_node("WorldActionPointer").position=Vector2(button.size.x*.5-12,button.size.y+3)

static func place(button:Button,camera:Camera3D,point:Vector3)->void:
 if camera.is_position_behind(point):button.hide();return
 var screen:Vector2=camera.unproject_position(point)
 var area:Vector2=button.get_viewport().get_visible_rect().size
 button.position=Vector2(clampf(screen.x-button.size.x*.5,16,maxf(16,area.x-button.size.x-16)),clampf(screen.y-button.size.y-16,96,maxf(96,area.y-button.size.y-100)))
