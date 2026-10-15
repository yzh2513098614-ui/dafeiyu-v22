extends RefCounted
## Opaque seabed provides real depth and transmitted colour to the water pass.
## It has no collision and never changes the playable island or dock geometry.
const BED_SHADER = preload("res://assets/whale_home/seabed.gdshader")

static func build(sea: Node3D, ocean: MeshInstance3D, water: ShaderMaterial) -> ShaderMaterial:
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/whale_home/water_body.json"))
	var motion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/whale_home/coastal_water.json"))
	for key: String in settings.surface:
		var value: Variant = settings.surface[key]
		if value is String: value = Color(value)
		elif value is Array: value = Vector3(value[0], value[1], value[2])
		water.set_shader_parameter(key, value)
	var material := ShaderMaterial.new()
	material.shader = BED_SHADER
	for key: String in settings.seabed:
		var value: Variant = settings.seabed[key]
		material.set_shader_parameter(key, Color(value) if value is String else value)
	for key: String in ["absorption", "scattering"]:
		var coefficients: Array = settings.surface[key]
		material.set_shader_parameter(key, Vector3(coefficients[0], coefficients[1], coefficients[2]))
	material.set_shader_parameter("water_ior", settings.surface.water_ior)
	var grid := PlaneMesh.new()
	grid.size = (ocean.mesh as PlaneMesh).size
	grid.subdivide_width = int(settings.shelf.subdivisions[0])
	grid.subdivide_depth = int(settings.shelf.subdivisions[1])
	var arrays: Array = grid.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in vertices.size():
		var point := Vector2(vertices[i].x + ocean.position.x, vertices[i].z + ocean.position.z)
		vertices[i] = Vector3(point.x, _height(point, settings.shelf, motion), point.y)
		var dx: float = (_height(point + Vector2(.1, 0), settings.shelf, motion) - _height(point - Vector2(.1, 0), settings.shelf, motion)) / .2
		var dz: float = (_height(point + Vector2(0, .1), settings.shelf, motion) - _height(point - Vector2(0, .1), settings.shelf, motion)) / .2
		normals[i] = Vector3(-dx, 1, -dz).normalized()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var bed := MeshInstance3D.new()
	bed.name = "CoastalSeabed"
	bed.mesh = mesh
	bed.material_override = material
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.add_child(bed)
	return material

static func _height(point: Vector2, shelf: Dictionary, motion: Dictionary) -> float:
	var coast := point - Vector2(motion.island_center[0], motion.island_center[1])
	var outside := Vector2(maxf(absf(coast.x) - float(motion.island_half_size[0]), 0), maxf(absf(coast.y) - float(motion.island_half_size[1]), 0))
	var shore: float = outside.length()
	var depth: float = float(shelf.near_depth) + shore * float(shelf.slope)
	depth += smoothstep(float(shelf.drop_start), float(shelf.drop_end), shore) * float(shelf.drop)
	var relief: float = sin(point.x * .43 + sin(point.y * .19)) * cos(point.y * .37) * float(shelf.relief)
	return float(motion.base_level) - depth + relief
