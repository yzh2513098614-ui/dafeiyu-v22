@tool
extends Panel
## Native rounded gradient, inset keyline and top highlight. No input or extra nodes.

static var _gradients: Dictionary = {}

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var box := get_theme_stylebox("panel") as StyleBoxFlat
	paint(self, box)

static func paint(control: Control, box: StyleBoxFlat) -> void:
	var dimensions := control.size
	if box == null or dimensions.x < 16 or dimensions.y < 16:
		return
	if not _gradients.has(box.bg_color):
		var texture := GradientTexture2D.new()
		var colors := Gradient.new()
		colors.colors = PackedColorArray([box.bg_color.lightened(0.65), box.bg_color.lightened(0.18), box.bg_color])
		colors.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
		texture.gradient = colors
		texture.width = 128
		texture.height = 128
		texture.fill_from = Vector2.ZERO
		texture.fill_to = Vector2.ONE
		_gradients[box.bg_color] = texture
	var inset := float(box.border_width_left) + 2.0
	var rect := Rect2(Vector2.ONE * inset, dimensions - Vector2.ONE * inset * 2.0)
	var radius := minf(float(box.corner_radius_top_left) - inset, minf(rect.size.x, rect.size.y) * 0.5)
	radius = maxf(2.0, radius)
	var centers: Array[Vector2] = [rect.position + Vector2(rect.size.x - radius, radius), rect.end - Vector2.ONE * radius, rect.position + Vector2(radius, rect.size.y - radius), rect.position + Vector2.ONE * radius]
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for corner in 4:
		for step in 9:
			var angle := -PI * 0.5 + float(corner) * PI * 0.5 + float(step) * PI / 16.0
			var point := centers[corner] + Vector2(cos(angle), sin(angle)) * radius
			points.append(point)
			uvs.append((point - rect.position) / rect.size)
	control.draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, _gradients[box.bg_color])
	var line := StyleBoxFlat.new()
	line.bg_color = Color.TRANSPARENT
	line.border_color = Color("8cb6ed", box.bg_color.a * 0.85)
	line.set_border_width_all(1)
	line.set_corner_radius_all(roundi(radius))
	control.draw_style_box(line, rect)
	if dimensions.y >= 40:
		control.draw_line(Vector2(inset + radius, inset + 4), Vector2(dimensions.x - inset - radius, inset + 4), Color(1, 1, 1, box.bg_color.a * 0.8), 2, true)
