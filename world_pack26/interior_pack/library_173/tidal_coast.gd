extends Node3D
## Reusable visual tidal coastline. No camera or UI is created here.
## Place this scene in a Node3D world; its own local coordinates drive the shore.

signal tide_changed(level: float, shore_z: float)

@export_range(30.0, 3600.0, 1.0) var cycle_seconds := 180.0
@export var low_level := -0.18
@export var high_level := 0.18
@export var automatic := true
@export var create_ground_collision := true
@export_range(0.0, 0.05, 0.001) var wave_amplitude := 0.014

const SHORE_ORIGIN := -4.5
const BEACH_SLOPE := 0.16

var current_level := -0.18
var cycle_phase := 0.0
var wet_reference := 0.18
var visual_time := 0.0
var frozen := false
var manual_level := -0.18
var water_root: Node3D
var foam_root: Node3D
var floating_parts: Array[MeshInstance3D] = []
var water_material: ShaderMaterial
var foam_material: ShaderMaterial
var sand_material: ShaderMaterial

func _ready() -> void:
	current_level = low_level
	manual_level = low_level
	wet_reference = high_level
	var coast_scene := load("res://world_pack26/interior_pack/library_173/models/scenes/beach_scene.glb") as PackedScene
	if coast_scene == null:
		push_error("TidalCoast: missing beach_scene.glb")
		set_process(false)
		return
	var coast := coast_scene.instantiate() as Node3D
	_mark_source(coast, "lib_beach_scene")
	add_child(coast)
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://world_pack26/interior_pack/library_173/shaders/tidal_water.gdshader") as Shader
	foam_material = ShaderMaterial.new()
	foam_material.shader = load("res://world_pack26/interior_pack/library_173/shaders/shore_foam.gdshader") as Shader
	sand_material = ShaderMaterial.new()
	sand_material.shader = load("res://world_pack26/interior_pack/library_173/shaders/wet_sand.gdshader") as Shader
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(coast, meshes)
	for mesh in meshes:
		var part_name := str(mesh.name)
		if part_name.begins_with("tidal_water_surface") or part_name.begins_with("shore_foam") or part_name.begins_with("surface_glint"):
			mesh.visible = false
		elif part_name.begins_with("tidal_sand_"):
			mesh.material_override = sand_material
			if create_ground_collision:
				mesh.create_trimesh_collision()
		elif part_name.begins_with("floating_buoy_"):
			floating_parts.append(mesh)
	water_root = _load_effect("res://world_pack26/interior_pack/library_173/models/tidal/water_surface.glb", water_material)
	foam_root = _load_effect("res://world_pack26/interior_pack/library_173/models/tidal/shore_foam_strip.glb", foam_material)
	if water_root == null or foam_root == null:
		set_process(false)
		return
	_apply_state()

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, result)

func _load_effect(path: String, material: ShaderMaterial) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("TidalCoast: missing effect " + path)
		return null
	var instance := packed.instantiate() as Node3D
	_mark_source(instance, "lib_water_surface" if path.ends_with("water_surface.glb") else "lib_shore_foam_strip")
	add_child(instance)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(instance, meshes)
	for mesh in meshes:
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Waves exceed the un-displaced mesh AABB; grow its culling bounds.
		mesh.extra_cull_margin = 0.10
	return instance

func _mark_source(node: Node3D, asset_id: String) -> void:
	var assets = JSON.parse_string(FileAccess.get_file_as_string("res://world_pack26/interior_pack/all_assets.json"))
	for definition in assets:
		if definition.id == asset_id:
			node.set_meta("asset_definition", definition)
			return

func _process(delta: float) -> void:
	if frozen:
		return
	visual_time += delta
	var target_level := manual_level
	if automatic:
		cycle_phase = fposmod(cycle_phase + delta / maxf(cycle_seconds, 30.0), 1.0)
		target_level = lerpf(low_level, high_level, 0.5 - 0.5 * cos(TAU * cycle_phase))
	# Manual low/high buttons also transition gently, rather than jumping the sea.
	current_level = move_toward(current_level, target_level, delta * 0.08)
	wet_reference = maxf(current_level, move_toward(wet_reference, current_level, delta * 0.006))
	_apply_state()

func _apply_state() -> void:
	water_root.position.y = current_level
	water_material.set_shader_parameter("tide_level", current_level)
	water_material.set_shader_parameter("animation_time", visual_time)
	water_material.set_shader_parameter("wave_amplitude", wave_amplitude)
	foam_root.position.y = current_level + 0.006
	foam_root.position.z = current_level / BEACH_SLOPE
	foam_material.set_shader_parameter("animation_time", visual_time)
	sand_material.set_shader_parameter("wet_reference", wet_reference)
	for part in floating_parts:
		part.position.y = current_level + 0.018 * sin(visual_time * 0.85 + 1.4)
	tide_changed.emit(current_level, SHORE_ORIGIN + current_level / BEACH_SLOPE)

func set_manual_level(level: float) -> void:
	automatic = false
	manual_level = clampf(level, low_level, high_level)

func resume_cycle() -> void:
	# Resume on the rising limb at the current water level, preventing a jump.
	var fraction := clampf((current_level - low_level) / maxf(high_level - low_level, 0.001), 0.0, 1.0)
	cycle_phase = acos(1.0 - 2.0 * fraction) / TAU
	automatic = true

func get_depth_at(local_point: Vector3) -> float:
	# Analytic water depth for gameplay. Positive = under water; negative = dry.
	var offset := 0.13 * sin(0.75 * local_point.x) + 0.09 * sin(1.9 * local_point.x + 0.4)
	var ground := clampf(BEACH_SLOPE * (local_point.z - SHORE_ORIGIN - offset), -0.48, 0.30)
	return current_level - ground
