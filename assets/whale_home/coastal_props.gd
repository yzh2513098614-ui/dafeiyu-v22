extends RefCounted
## Coast pieces for whale_home: shared timber modules and bevelled reef meshes.
const Geo = preload("res://district/story_geometry.gd")
const WOOD_SHADER = preload("res://assets/whale_home/coastal_wood.gdshader")
const ROCK_SHADER = preload("res://assets/whale_home/coastal_rock.gdshader")
static var wood_materials: Dictionary = {}
static var stone_materials: Array[ShaderMaterial] = []
static var plank_meshes: Dictionary = {}
static var reef_meshes: Array[ArrayMesh] = []
static var starfish_mesh: ArrayMesh

static func timber(tone: int = 0, nails: bool = false) -> ShaderMaterial:
	var key := str(tone % 5) + str(nails)
	if not wood_materials.has(key):
		var palette := [Color("c6b087"), Color("cdb68e"), Color("c3ac83"), Color("d0bb98"), Color("bfaa83")]
		var material := ShaderMaterial.new()
		material.shader = WOOD_SHADER
		material.set_shader_parameter("wood_color", palette[tone % 5])
		material.set_shader_parameter("grain_phase", float(tone % 5) * 1.71)
		material.set_shader_parameter("board_nails", nails)
		wood_materials[key] = material
	return wood_materials[key]

static func stone(tone: int) -> ShaderMaterial:
	if stone_materials.is_empty():
		for color: Color in [Color("cdd3bd"), Color("b9c6b4"), Color("dedcc7")]:
			var material := ShaderMaterial.new()
			material.shader = ROCK_SHADER
			material.set_shader_parameter("stone_color", color)
			stone_materials.append(material)
	return stone_materials[tone % stone_materials.size()]

static func _box(parent: Node3D, size: Vector3, point: Vector3, tone: int = 0, board: bool = false) -> MeshInstance3D:
	var key := str(size)
	if not plank_meshes.has(key):
		var arrays := Geo.beveled_mesh(size, 0.024).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv := PackedVector2Array()
		for vertex in vertices:
			uv.append(Vector2(vertex.x / size.x + 0.5, vertex.z / size.z + 0.5))
		arrays[Mesh.ARRAY_TEX_UV] = uv
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		plank_meshes[key] = mesh
	var node := MeshInstance3D.new()
	node.mesh = plank_meshes[key]
	node.material_override = timber(tone, board)
	node.position = point
	parent.add_child(node)
	return node

static func _beam(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var node := _box(parent, Vector3(0.13, a.distance_to(b), 0.13), (a + b) * 0.5, 4)
	var axis := (b - a).normalized()
	var guide := Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD
	var right := axis.cross(guide).normalized()
	node.basis = Basis(right, axis, right.cross(axis).normalized())

static func dock(parent: Node3D, rect: Rect2, cross_bridge: bool = false) -> void:
	var root := Node3D.new()
	root.name = "CrossBridgeTimber" if cross_bridge else "PierTimber"
	parent.add_child(root)
	var length := rect.size.x if cross_bridge else rect.size.y
	var width := rect.size.y if cross_bridge else rect.size.x
	var start := rect.position.x if cross_bridge else rect.position.y
	var across := rect.position.y if cross_bridge else rect.position.x
	var rows := ceili(length / 0.54)
	var columns := ceili(width / 3.0)
	var row_depth := length / float(rows)
	var count := 0
	for row in rows:
		# Alternate the end joint, with four centimetres of open seam.
		var joint := width * (0.47 if row % 2 == 0 else 0.53)
		var cuts: Array = [0.0, joint, width] if columns == 2 else [0.0, width]
		for column in cuts.size() - 1:
			var plank_width: float = cuts[column + 1] - cuts[column] - 0.04
			var point := Vector3(across + (cuts[column] + cuts[column + 1]) * 0.5, -0.04, start + (row + 0.5) * row_depth)
			if cross_bridge:
				point = Vector3(point.z, point.y, point.x)
			var plank := _box(root, Vector3(plank_width, 0.13, row_depth - 0.04), point, (row * 7 + column * 3) % 5, true)
			if cross_bridge:
				plank.rotation.y = PI * 0.5
			plank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			count += 1
	# Continuous fascia, two bearing beams, and regularly spaced joists.
	for side in [-1.0, 1.0]:
		var edge := rect.get_center()
		edge.y += side * (width * 0.5 - 0.08) if cross_bridge else 0.0
		edge.x += side * (width * 0.5 - 0.08) if not cross_bridge else 0.0
		_box(root, Vector3(length, 0.28, 0.16) if cross_bridge else Vector3(0.16, 0.28, length), Vector3(edge.x, -0.15, edge.y), 4)
		var bearing := rect.get_center()
		bearing.y += side * width * 0.29 if cross_bridge else 0.0
		bearing.x += side * width * 0.29 if not cross_bridge else 0.0
		_box(root, Vector3(length, 0.22, 0.19) if cross_bridge else Vector3(0.19, 0.22, length), Vector3(bearing.x, -0.33, bearing.y), 2)
	for i in ceili(length / 2.3) + 1:
		var along := minf(start + 0.18 + i * 2.3, start + length - 0.18)
		var point := Vector3(along, -0.23, rect.get_center().y) if cross_bridge else Vector3(rect.get_center().x, -0.23, along)
		_box(root, Vector3(0.16, 0.18, width - 0.12) if cross_bridge else Vector3(width - 0.12, 0.18, 0.16), point, 2)
	root.set_meta("plank_count", count)
	root.set_meta("coastal_dock", true)

static func pile(parent: Node3D, point: Vector3) -> void:
	var node := Geo.cylinder(parent, 0.20, 1.95, point + Vector3(0, -1.37, 0), Color.WHITE, 0.17)
	node.name = "TidalTimberPile"
	node.material_override = timber(4)
	_box(parent, Vector3(0.45, 0.12, 0.44), point + Vector3(0, -0.40, 0), 2)

static func trestle(parent: Node3D, left: Vector3, right: Vector3) -> void:
	var header := _box(parent, Vector3(left.distance_to(right) + 0.35, 0.18, 0.25), (left + right) * 0.5 + Vector3(0, -0.45, 0), 4)
	header.rotation.y = -atan2(right.z - left.z, right.x - left.x)
	var middle := (left + right) * 0.5 + Vector3(0, -0.43, 0)
	_beam(parent, left + Vector3(0, -1.0, 0), middle)
	_beam(parent, right + Vector3(0, -1.0, 0), middle)

static func bridge_ropes(parent: Node3D) -> Array[Vector3]:
	var posts: Array[Vector3] = []
	for z in [28.16, 30.84]:
		var anchors: Array[Vector3] = []
		for x in [-16.25, -12.0, -7.7, -3.25]:
			var point := Vector3(x, 0, z)
			posts.append(point)
			var post := Geo.cylinder(parent, 0.10, 0.75, point + Vector3(0, 0.32, 0), Color.WHITE, 0.095)
			post.material_override = timber(2)
			Geo.cylinder(parent, 0.115, 0.065, point + Vector3(0, 0.715, 0), Color("f3eedb"))
			anchors.append(point + Vector3(0, 0.58, 0))
		for span in anchors.size() - 1:
			for i in 8:
				var ta := i / 8.0
				var tb := (i + 1) / 8.0
				var a := anchors[span].lerp(anchors[span + 1], ta) - Vector3.UP * sin(ta * PI) * 0.11
				var b := anchors[span].lerp(anchors[span + 1], tb) - Vector3.UP * sin(tb * PI) * 0.11
				Geo.rod(parent, a, b, 0.035, Color("baa785"))
	return posts

static func _reef_mesh(variant: int) -> ArrayMesh:
	while reef_meshes.size() <= variant:
		var rng := RandomNumberGenerator.new()
		rng.seed = 43081 + reef_meshes.size() * 7907
		var outline: Array[Vector2] = []
		for i in 8:
			var angle := i * TAU / 8.0 + rng.randf_range(-0.10, 0.10)
			outline.append(Vector2(cos(angle), sin(angle)) * rng.randf_range(0.43, 0.54))
		var rings: Array = []
		# A broad fractured body, a narrow shoulder bevel, and an offset crown.
		for tier: Vector4 in [Vector4(0.76, -0.63, -0.03, 0.01), Vector4(1.04, -0.18, 0.0, 0.0), Vector4(0.98, 0.23, 0.04, 0.02), Vector4(0.78, 0.43, 0.075, -0.015), Vector4(0.64, 0.48, 0.07, -0.01)]:
			var ring: Array[Vector3] = []
			for p: Vector2 in outline:
				ring.append(Vector3(p.x * tier.x + tier.z, tier.y, p.y * tier.x + tier.w))
			rings.append(ring)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for tier in rings.size() - 1:
			for side in 8:
				var next := (side + 1) % 8
				var a: Vector3 = rings[tier][side]
				var b: Vector3 = rings[tier][next]
				var c: Vector3 = rings[tier + 1][next]
				var d: Vector3 = rings[tier + 1][side]
				var normal := (b - a).cross(d - a).normalized()
				if normal.dot(Vector3(a.x, 0, a.z)) < 0:
					normal = -normal
				tool.set_color(Color.WHITE * rng.randf_range(0.96, 1.035))
				Geo._face(tool, [a, b, c, d], normal)
		tool.set_color(Color.WHITE)
		var crown: Array[Vector3] = rings.back()
		var base: Array[Vector3] = rings.front()
		Geo._face(tool, crown, Vector3.UP)
		Geo._face(tool, base, Vector3.DOWN)
		reef_meshes.append(tool.commit())
	return reef_meshes[variant]

static func _starfish(parent: Node3D, point: Vector3, size: float) -> void:
	if not starfish_mesh:
		var outline: Array[Vector3] = []
		for i in 10:
			var angle := i * TAU / 10.0
			outline.append(Vector3(cos(angle), 0.0, sin(angle)) * (0.5 if i % 2 == 0 else 0.22))
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 10:
			var a: Vector3 = outline[i]
			var b: Vector3 = outline[(i + 1) % 10]
			Geo._face(tool, [Vector3(0, 0.055, 0), a + Vector3.UP * 0.015, b + Vector3.UP * 0.015], Vector3.UP)
			Geo._face(tool, [a, b, b + Vector3.UP * 0.015, a + Vector3.UP * 0.015], (a + b).normalized())
		starfish_mesh = tool.commit()
	var node := MeshInstance3D.new()
	node.name = "RestingStarfish"
	node.mesh = starfish_mesh
	node.material_override = Geo.material(Color("edb7ac"))
	node.position = point
	node.scale = Vector3.ONE * size
	parent.add_child(node)

static func reef(parent: Node3D, point: Vector3, size: Vector3, variant: int, keepouts: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "CoastalReefCluster"
	root.position = point
	root.set_meta("coastal_reef", true)
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5813 * (variant + 1) + int((point.x + 50) * 19 + (point.z + 40) * 73)
	var main := MeshInstance3D.new()
	main.name = "FracturedReef"
	main.mesh = _reef_mesh(variant % 8)
	main.material_override = stone(variant % 3)
	main.scale = size * rng.randf_range(0.92, 1.08)
	main.rotation.y = variant * 0.53 + rng.randf_range(-0.22, 0.22)
	root.add_child(main)
	var outward := Vector3(point.x / 28.0, 0, point.z / 25.0).normalized()
	var tangent := Vector3(-outward.z, 0, outward.x)
	for i in 2:
		var small := MeshInstance3D.new()
		small.name = "TidePebble"
		small.mesh = _reef_mesh((variant + i * 3 + 1) % 8)
		small.material_override = stone((variant + i + 1) % 3)
		small.position = outward * minf(size.x, size.z) * 0.42 + tangent * (i - 0.5) * minf(size.x, size.z) * 0.65 + Vector3(0, -0.38, 0)
		small.scale = size * (0.25 + i * 0.12)
		small.rotation.y = rng.randf_range(-PI, PI)
		root.add_child(small)
	if variant % 4 == 0:
		_starfish(root, Vector3(0.06 * main.scale.x, 0.48 * main.scale.y + 0.01, 0), minf(size.x, size.z) * 0.23)
	var bounds: AABB = main.transform * main.mesh.get_aabb()
	for child in root.get_children():
		if child is MeshInstance3D: bounds = bounds.merge(child.transform * child.mesh.get_aabb())
	# Keep the end of both side promenades clear for the full character silhouette.
	if point.z > 24.0: root.position.z = maxf(root.position.z, 24.2 - bounds.position.z)
	elif point.z < -24.0: root.position.z = minf(root.position.z, -24.2 - bounds.end.z)
	var occupied := Rect2(Vector2(root.position.x + bounds.position.x, root.position.z + bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
	for area: Rect2 in keepouts:
		if occupied.intersects(area.grow(0.35)):
			root.free()
			return null
	root.set_meta("reef_bounds", occupied)
	for child in root.get_children():
		if not child is MeshInstance3D or child.name == "RestingStarfish": continue
		var vertices := PackedVector3Array()
		for vertex in child.mesh.get_faces(): vertices.append(child.transform * vertex)
		var shape := ConvexPolygonShape3D.new()
		shape.points = vertices
		var collision := CollisionShape3D.new()
		collision.shape = shape
		var body := StaticBody3D.new()
		body.name = String(child.name) + "Collision"
		body.collision_layer = 1
		body.collision_mask = 4
		body.add_child(collision)
		root.add_child(body)
	return root
