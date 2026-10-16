@tool
extends Button
## Native button labels stay above the fill; only the inset line and highlight are drawn.

func _draw() -> void:
	var state := "disabled" if disabled else ("pressed" if is_pressed() else ("hover" if is_hovered() else "normal"))
	var box := get_theme_stylebox(state) as StyleBoxFlat
	var line := StyleBoxFlat.new()
	line.bg_color = Color.TRANSPARENT
	line.border_color = Color("9dbfe8", 0.7)
	line.set_border_width_all(1)
	line.set_corner_radius_all(9)
	draw_style_box(line, Rect2(Vector2(5, 5), size - Vector2(10, 10)))
	draw_line(Vector2(16, 9), Vector2(size.x - 16, 9), box.bg_color.lightened(0.7), 2, true)
