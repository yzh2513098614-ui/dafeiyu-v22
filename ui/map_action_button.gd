extends RefCounted
## One compact world action, using the project's current button palette.
static func create(game,parent:Node,text:String,action:Callable,alternate:Callable=Callable())->Button:
 var button:Button=game._button(text,Vector2.ZERO,Vector2(156,40),parent,action)
 button.focus_mode=Control.FOCUS_NONE
 button.add_theme_font_size_override("font_size",18)
 button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
  var style:StyleBox=button.get_theme_stylebox(state).duplicate()
  style.content_margin_left=12;style.content_margin_right=12
  style.content_margin_top=4;style.content_margin_bottom=4
  if style is StyleBoxFlat:
   style.set_corner_radius_all(10);style.set_border_width_all(2)
   style.shadow_offset=Vector2(0,2)
  button.add_theme_stylebox_override(state,style)
 if alternate.is_valid():
  button.gui_input.connect(func(event:InputEvent):
   if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
    button.accept_event();alternate.call())
 return button

static func fit_text(button:Button)->void:
 var font:Font=button.get_theme_font("font")
 var width:float=font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x+28
 button.size=Vector2(clampf(width,132,240),40)

static func place(button:Button,camera:Camera3D,point:Vector3)->void:
 if camera.is_position_behind(point):button.hide();return
 var screen:Vector2=camera.unproject_position(point)
 var area:Vector2=button.get_viewport().get_visible_rect().size
 button.position=Vector2(clampf(screen.x-button.size.x*.5,16,maxf(16,area.x-button.size.x-16)),clampf(screen.y-button.size.y-16,96,maxf(96,area.y-button.size.y-100)))
