extends RefCounted
## Furniture finishes use per-board UVs so batching keeps the grain attached.
const Geo = preload("res://district/story_geometry.gd")
const SURFACE = preload("res://assets/whale_home/furniture_surface.gdshader")
const PARTS = {"body": 0, "top": 1, "back": 2}
static var profiles: Dictionary = {}
static var materials: Dictionary = {}
static var panels: Dictionary = {}

static func material(profile: String, part: String) -> ShaderMaterial:
	if profiles.is_empty():
		profiles = JSON.parse_string(FileAccess.get_file_as_string("res://assets/whale_home/furniture_finishes.json"))
	var key := profile + ":" + part
	if not materials.has(key):
		var settings: Dictionary = profiles[profile]
		var index: int = PARTS[part]
		var surface := ShaderMaterial.new()
		surface.shader = SURFACE
		surface.set_shader_parameter("base_color", Color(settings.colors[index]))
		surface.set_shader_parameter("detail_color", Color(settings.details[index]))
		surface.set_shader_parameter("pattern", int(settings.patterns[index]))
		surface.set_shader_parameter("pattern_scale", Vector2(settings.scale[0], settings.scale[1]))
		surface.set_shader_parameter("detail_strength", float(settings.contrast))
		surface.set_shader_parameter("roughness_value", float(settings.roughness))
		materials[key] = surface
	return materials[key]

static func panel(size: Vector3, bevel: float) -> ArrayMesh:
	var key := str(size) + ":" + str(bevel)
	if not panels.has(key):
		var arrays := Geo.beveled_mesh(size, bevel).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var grain_axis := size.max_axis_index()
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		for i in vertices.size():
			var face_axis := normals[i].abs().max_axis_index()
			var along := grain_axis
			if along == face_axis:
				along = (face_axis + 1) % 3
				if size[(face_axis + 2) % 3] > size[along]: along = (face_axis + 2) % 3
			var across := 3 - face_axis - along
			uv.append(Vector2(vertices[i][along] + size[along] * 0.5, vertices[i][across] + size[across] * 0.5))
			uv2.append(Vector2(1.0 if face_axis == grain_axis else 0.0, 0.0))
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		panels[key] = mesh
	return panels[key]

static func apply(node: MeshInstance3D, size: Vector3, bevel: float, profile: String, part: String) -> void:
	node.mesh = panel(size, bevel)
	node.material_override = material(profile, part)
