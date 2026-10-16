@tool
extends Button
## Small surface highlight; the native style owns the single dark outline.

func _draw() -> void:
	var state := "disabled" if disabled else ("pressed" if is_pressed() else ("hover" if is_hovered() else "normal"))
	var box := get_theme_stylebox(state) as StyleBoxFlat
	draw_line(Vector2(16, 9), Vector2(size.x - 16, 9), box.bg_color.lightened(0.7), 2, true)
