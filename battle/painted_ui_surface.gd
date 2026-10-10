extends TextureRect
## Size and state affect sampling, never the original asset.
var color_driver:StyleBoxFlat
var _previous_tint:=Color(-1,-1,-1,-1)
var _button_tint:=Color.WHITE
func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 resized.connect(_sync_size)
 _sync_size()
 set_process(get_parent() is BaseButton or color_driver!=null)
func _sync_size()->void:
 if material: material.set_shader_parameter("view_size",Vector2(maxf(size.x,1),maxf(size.y,1)))
func _process(delta:float)->void:
 var tint:=color_driver.bg_color if color_driver else Color.WHITE
 var button:=get_parent() as BaseButton
 if button:
  match button.get_draw_mode():
   BaseButton.DRAW_DISABLED:tint=Color(1,1,1,.9)
   BaseButton.DRAW_PRESSED,BaseButton.DRAW_HOVER_PRESSED:tint=Color(.91,.94,.94)
   BaseButton.DRAW_HOVER:tint=Color(1.04,1.04,1.02)
  # Only interpolate button colour. Gauge values and disabled states remain immediate.
  _button_tint=_button_tint.lerp(tint,1.0-exp(-18.0*delta))
  tint=_button_tint
 if tint!=_previous_tint:
  _previous_tint=tint
  material.set_shader_parameter("surface_tint",tint)
  material.set_shader_parameter("state_gray",.8 if button and button.disabled else 0.0)
  material.set_shader_parameter("state_lift",.25 if button and button.disabled else 0.0)

