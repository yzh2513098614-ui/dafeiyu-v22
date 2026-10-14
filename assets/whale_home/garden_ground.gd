extends RefCounted
## Low garden surfaces and shared grass geometry; the existing floor stays solid.
const Geo = preload("res://district/story_geometry.gd")
const PAVING = preload("res://assets/whale_home/garden_paving.gdshader")
const GRASS = preload("res://assets/whale_home/garden_grass.gdshader")
static var settings: Dictionary = {}
static var stones: Array[ShaderMaterial] = []
static var field: ShaderMaterial
static var turf: ShaderMaterial
static var blade_material: StandardMaterial3D
static var blade_mesh: ArrayMesh

static func prepare() -> void:
	if not settings.is_empty(): return
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://assets/whale_home/garden_ground.json"))
	for color in settings.stone_palette:
		var material := ShaderMaterial.new()
		material.shader = PAVING
		material.set_shader_parameter("stone_color", Color(color))
		stones.append(material)
	field = stones[0].duplicate()
	field.set_shader_parameter("field_pattern", true)
	turf = ShaderMaterial.new()
	turf.shader = GRASS
	turf.set_shader_parameter("grass_color", Color(settings.grass_color))
	turf.set_shader_parameter("grass_shadow", Color(settings.grass_shadow))
	blade_material = StandardMaterial3D.new()
	blade_material.vertex_color_use_as_albedo = true
	blade_material.vertex_color_is_srgb = true
	blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade_material.roughness = 1.0
	blade_material.metallic_specular = 0.08
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var angle := i * TAU / 3.0
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.035
		var middle := Vector3(sin(angle) * 0.025, 0.55, cos(angle) * 0.025)
		var tip := Vector3(sin(angle) * 0.085, 1.0, cos(angle) * 0.085)
		var normal := (Vector3(sin(angle), 0, -cos(angle)) * 0.4 + Vector3.UP * 0.6).normalized()
		var vertices: Array[Vector3] = [-side, side, middle + side * 0.65, -side, middle + side * 0.65, middle - side * 0.65, middle - side * 0.65, middle + side * 0.65, tip]
		for vertex in vertices:
			tool.set_normal(normal)
			tool.set_color(Color(settings.grass_shadow).lerp(Color("d0dcaa"), vertex.y * 0.70))
			tool.set_uv(Vector2(vertex.x, vertex.y))
			tool.add_vertex(vertex)
	blade_mesh = tool.commit()

static func _box(parent: Node3D, size: Vector3, point: Vector3, material: Material) -> MeshInstance3D:
	var node := Geo.box(parent, size, point, Color.WHITE, 0, 0.018)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func base(parent: Node3D) -> void:
	prepare()
	_box(parent, Vector3(55.8, 0.06, 49.8), Vector3(0, float(settings.base_top) - 0.03, 0), field)

static func path(parent: Node3D, rect: Rect2, label: String = "GardenStonePath") -> void:
	prepare()
	var root := Node3D.new()
	root.name = label
	root.set_meta("garden_paving", true)
	root.set_meta("surface_top", settings.paving_top)
	parent.add_child(root)
	var center := rect.get_center()
	var top: float = settings.paving_top
	_box(root, Vector3(rect.size.x, 0.025, rect.size.y), Vector3(center.x, top - 0.018, center.y), stones[1])
	var cell := Vector2(settings.paver_size[0], settings.paver_size[1])
	var gap: float = settings.paver_gap
	var rows := ceili(rect.size.y / cell.y)
	var row_depth := rect.size.y / float(rows)
	for row in rows:
		var z := rect.position.y + row * row_depth
		var depth := row_depth
		var start := rect.position.x - (0.5 * cell.x if row % 2 else 0.0)
		for column in ceili((rect.end.x - start) / cell.x):
			var left := maxf(rect.position.x, start + column * cell.x)
			var right := minf(rect.end.x, start + (column + 1) * cell.x)
			if right - left <= gap: continue
			_box(root, Vector3(right - left - gap, 0.07, depth - gap), Vector3((left + right) * 0.5, top - 0.035, z + depth * 0.5), stones[(row * 2 + column) % 3])

static func _outline(rect: Rect2, radius: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var centers: Array[Vector2] = [rect.position + Vector2(radius, radius), Vector2(rect.end.x - radius, rect.position.y + radius), rect.end - Vector2(radius, radius), Vector2(rect.position.x + radius, rect.end.y - radius)]
	for corner in 4:
		for step in 4:
			var angle := -PI + corner * PI * 0.5 + step * PI / 6.0
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _clearing(point: Vector2, clearings: Array[Rect2]) -> bool:
	for rect in clearings:
		if rect.has_point(point): return true
	return false

static func lawn(parent: Node3D, rect: Rect2, clearings: Array[Rect2], seed_value: int) -> int:
	prepare()
	var radius: float = settings.lawn_corner_radius
	var outer := _outline(rect, radius)
	var inner := _outline(rect.grow(-0.10), radius - 0.10)
	var top: float = settings.grass_top
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(rect.get_center().x, top, rect.get_center().y)
	for i in inner.size():
		var next := (i + 1) % inner.size()
		var a := Vector3(inner[i].x, top, inner[i].y)
		var b := Vector3(inner[next].x, top, inner[next].y)
		var c := Vector3(outer[next].x, top - 0.014, outer[next].y)
		var d := Vector3(outer[i].x, top - 0.014, outer[i].y)
		Geo._face(tool, [center, a, b], Vector3.UP)
		Geo._face(tool, [a, b, c, d], Vector3.UP)
	var node := MeshInstance3D.new()
	node.name = "RoundedGardenLawn"
	node.mesh = tool.commit()
	node.material_override = turf
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	var curb_material := Geo.material(Color(settings.curb_color))
	for i in outer.size():
		var a := outer[i]
		var b := outer[(i + 1) % outer.size()]
		var count := ceili(a.distance_to(b) / 1.5)
		for segment in count:
			var left := a.lerp(b, float(segment) / count)
			var right := a.lerp(b, float(segment + 1) / count)
			var middle := (left + right) * 0.5
			middle += Vector2(-(right - left).y, (right - left).x).normalized() * float(settings.curb_width) * 0.5
			var curb := _box(parent, Vector3(left.distance_to(right) - 0.025, 0.06, float(settings.curb_width)), Vector3(middle.x, float(settings.paving_top) - 0.03, middle.y), curb_material)
			curb.rotation.y = -atan2(right.y - left.y, right.x - left.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.mesh = blade_mesh
	mesh.instance_count = ceili(rect.get_area() * float(settings.tufts_per_square_meter))
	var inset := rect.grow(-0.24)
	var polygon := PackedVector2Array(inner)
	var count := 0
	for i in mesh.instance_count:
		var point := Vector2(rng.randf_range(inset.position.x, inset.end.x), rng.randf_range(inset.position.y, inset.end.y))
		if not Geometry2D.is_point_in_polygon(point, polygon) or _clearing(point, clearings): continue
		var height := rng.randf_range(settings.grass_height_range[0], settings.grass_height_range[1])
		var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3(rng.randf_range(0.65, 1.1), height, rng.randf_range(0.65, 1.1)))
		mesh.set_instance_transform(count, Transform3D(basis, Vector3(point.x, top, point.y)))
		mesh.set_instance_color(count, Color(rng.randf_range(0.90, 1.0), rng.randf_range(0.93, 1.0), rng.randf_range(0.87, 1.0)))
		count += 1
	mesh.visible_instance_count = count
	var grass := MultiMeshInstance3D.new()
	grass.name = "GardenGrassTufts"
	grass.multimesh = mesh
	grass.material_override = blade_material
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(grass)
	return count

static func gardens(parent: Node3D, tree_specs: Array) -> Dictionary:
	var clearings: Array[Rect2] = [Rect2(7.5, 14.1, 3.2, 2.1), Rect2(-22.8, 18.6, 4.8, 2.4), Rect2(-23.4, 7.7, 4.9, 5.2), Rect2(18.3, 15.4, 3.9, 3.2)]
	for spec: Array in tree_specs:
		var point: Vector3 = spec[0]
		clearings.append(Rect2(point.x - 0.85, point.z - 0.85, 1.7, 1.7))
	for side in [-1.0, 1.0]:
		for i in 7:
			clearings.append(Rect2(side * 20.5 - 2.65, -18 + i * 5.8 - 2.2, 5.3, 4.4))
		clearings.append(Rect2(side * 20.5 - 2.65, -14.55, 5.3, 4.7))
	var count := 0
	for side in [-1.0, 1.0]:
		count += lawn(parent, Rect2(side * 23.25 - 4.25, -23.8, 8.5, 47.0), clearings, 19273 if side < 0 else 32931)
		count += lawn(parent, Rect2(side * 10.3 - 4.1, 12.5, 8.2, float(settings.front_lawn_depth)), clearings, 1837 if side < 0 else 4791)
		path(parent, Rect2(side * 20.5 - 2.4, -14.3, 4.8, 4.2), "PergolaStonePad")
	return {"tufts": count, "lawns": 4}

static func tree_ring(parent: Node3D, point: Vector3) -> void:
	prepare()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		var a := i * TAU / 16.0
		var b := (i + 1) * TAU / 16.0
		Geo._face(tool, [Vector3(cos(a) * 0.23, 0, sin(a) * 0.23), Vector3(cos(a) * 0.70, 0, sin(a) * 0.70), Vector3(cos(b) * 0.70, 0, sin(b) * 0.70), Vector3(cos(b) * 0.23, 0, sin(b) * 0.23)], Vector3.UP)
	var node := MeshInstance3D.new()
	node.name = "TreeMulchRing"
	node.mesh = tool.commit()
	node.material_override = Geo.material(Color(settings.mulch_color))
	node.position = Vector3(point.x, float(settings.grass_top) + 0.002, point.z)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
