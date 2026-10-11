@tool
extends Button
## The sample's top highlight; drawn decoration never intercepts input.
func _ready() -> void:
 mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
 button_down.connect(queue_redraw);button_up.connect(queue_redraw);resized.connect(queue_redraw)
func _draw() -> void:
 var state:="disabled" if disabled else ("pressed" if is_pressed() else ("hover" if is_hovered() else "normal"))
 var box:=get_theme_stylebox(state)
 if box is StyleBoxFlat and size.x>30:
  var highlight:=StyleBoxFlat.new();highlight.bg_color=box.bg_color.lightened(.32);highlight.set_corner_radius_all(2)
  highlight.draw(get_canvas_item(),Rect2(12,8,size.x-24,4))
