@tool
extends Panel
## Native decorative rims; no extra children or input interception.
func _ready() -> void:resized.connect(queue_redraw)

func _draw() -> void:
 var base:=get_theme_stylebox("panel")
 if not base is StyleBoxFlat or size.x<40 or size.y<27:return
 var inset:=8.0 if base.get_border_width(SIDE_LEFT)>=5 else 5.0
 var rim:=StyleBoxFlat.new();rim.bg_color=Color.TRANSPARENT
 rim.border_color=Color(1,1,1,.45);rim.set_border_width_all(2)
 rim.set_corner_radius_all(maxi(4,base.corner_radius_top_left-int(inset)))
 rim.anti_aliasing=true;rim.draw(get_canvas_item(),Rect2(Vector2.ONE*inset,size-Vector2.ONE*inset*2))
