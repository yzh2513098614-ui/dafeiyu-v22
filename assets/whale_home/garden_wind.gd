extends Node
## Map-local field drives linked trunk joints, crown follow-through and grass shaders.
const TREE_SHADER = preload("res://assets/whale_home/garden_tree.gdshader")
var game
var settings: Dictionary
var rng := RandomNumberGenerator.new()
var materials: Array[ShaderMaterial] = []
var tree_materials: Dictionary = {}
var trees: Array[Dictionary] = []
var clock := 0.0
var strength := 0.075
var direction := Vector2(0.883, -0.469)
var field_center := Vector2.ZERO
var field_half_size := Vector2(22,17)
var cycle_time := 0.0
var lull := 0.0
var rise := 0.0
var hold := 0.0
var fall := 0.0
var peak := 0.0
var gust_count := 0

func configure(owner_game) -> void:
	name = "GardenWind"
	game = owner_game
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://assets/whale_home/garden_wind.json"))
	rng.randomize()
	direction = Vector2.from_angle(deg_to_rad(float(settings.direction_degrees)))
	field_half_size = Vector2(settings.field_half_size[0],settings.field_half_size[1])
	strength = float(settings.base_strength)
	_update_field()
	_schedule()

func _range(key: String) -> float:
	return rng.randf_range(float(settings[key][0]), float(settings[key][1]))

func _schedule() -> void:
	lull = _range("lull_seconds"); rise = _range("rise_seconds")
	hold = _range("hold_seconds"); fall = _range("fall_seconds")
	peak = _range("gust_strength")
	gust_count += 1

func _update_field() -> void:
	var distance := fposmod(float(settings.field_start_distance)+clock*float(settings.field_speed),float(settings.field_travel_distance))
	var start := Vector2(settings.field_path_start[0],settings.field_path_start[1])
	var crosswind := Vector2(-direction.y,direction.x)
	field_center = start+direction*distance+crosswind*sin(clock*float(settings.field_drift_frequency))*float(settings.field_lateral_drift)

func sample_field(point: Vector2) -> Vector2:
	var offset := point-field_center
	var crosswind := Vector2(-direction.y,direction.x)
	var along := absf(offset.dot(direction))/field_half_size.x
	var across := absf(offset.dot(crosswind))/field_half_size.y
	var region := (1.0-smoothstep(.55,1.0,along))*(1.0-smoothstep(.45,1.0,across))
	var ripple := .92+.08*sin(point.dot(direction)*.20-clock*1.1)
	return direction*(float(settings.background_strength)+strength*region*ripple)

func bind_material(material: ShaderMaterial) -> void:
	materials.append(material)
	_write(material)

func bind_tree(tree: Node3D) -> void:
	tree.set_meta("garden_wind_tree", true)
	tree.set_meta("home_dynamic", true)
	var record: Dictionary={"root":tree,"joints":[],"crowns":[],"phase":tree.global_position.x*.13+tree.global_position.z*.19,"response":.85 if tree.get_meta("tree_form")=="low_green" else 1.0}
	for node: Node3D in tree.find_children("*", "Node3D", true, false):
		if node.has_meta("trunk_wind_weight"):
			record.joints.append({"node":node,"rest":node.basis,"weight":node.get_meta("trunk_wind_weight")})
		if node.has_meta("crown_wind_phase"):
			record.crowns.append({"node":node,"rest":node.basis,"phase":node.get_meta("crown_wind_phase")})
	trees.append(record)
	for mesh: MeshInstance3D in tree.find_children("*", "MeshInstance3D", true, false):
		var source: ShaderMaterial = mesh.material_override
		var color: Color = source.get_shader_parameter("base_color")
		var foliage := not mesh.mesh is CylinderMesh
		var key := color.to_html() + str(foliage) + str(tree.get_instance_id())
		if not tree_materials.has(key):
			var material := ShaderMaterial.new()
			material.shader = TREE_SHADER
			material.set_shader_parameter("base_color", color)
			material.set_shader_parameter("foliage", foliage)
			material.set_shader_parameter("tree_origin", tree.global_position)
			material.set_meta("garden_tree_wind", true)
			tree_materials[key] = material
			bind_material(material)
		mesh.material_override = tree_materials[key]
	_pose_tree(record)

func _pose_tree(record: Dictionary) -> void:
	var tree: Node3D=record.root
	var breeze: float=sample_field(Vector2(tree.global_position.x,tree.global_position.z)).length()
	var force: float=clampf(breeze,0.0,1.2)
	var phase: float=clock*float(settings.tree_sway_frequency)+float(record.phase)
	var amplitude: float=deg_to_rad(float(settings.tree_background_sway_degrees)+force*float(settings.tree_field_sway_degrees))*float(record.response)
	var along: float=deg_to_rad(float(settings.tree_lean_degrees))*force+amplitude*(.78*sin(phase)+.22*sin(phase*.61+1.15))
	var across: float=deg_to_rad(float(settings.tree_cross_sway_degrees))*(.5+force)*sin(phase*.71+.8)
	# Convert the world wind into each rotated tree's local frame.
	var local_direction: Vector3=tree.global_basis.orthonormalized().inverse()*Vector3(direction.x,0,direction.y)
	var bend_axis: Vector3=Vector3.UP.cross(local_direction).normalized()
	var cross_axis: Vector3=Vector3.UP.cross(Vector3.UP.cross(local_direction)).normalized()
	var rotation_vector: Vector3=bend_axis*along+cross_axis*across
	var angle: float=rotation_vector.length()
	var axis: Vector3=rotation_vector.normalized() if angle>.00001 else bend_axis
	for joint: Dictionary in record.joints:
		joint.node.basis=Basis(axis,angle*float(joint.weight))*joint.rest
	# Branches follow the stem with a small phase lag, without separating at joints.
	for crown: Dictionary in record.crowns:
		var follow: float=deg_to_rad(float(settings.crown_follow_degrees))*(.45+force)*sin(phase-.65+float(crown.phase)*.30)
		crown.node.basis=Basis(bend_axis,follow)*crown.rest

func _write(material: ShaderMaterial) -> void:
	material.set_shader_parameter("wind_direction", direction)
	material.set_shader_parameter("wind_strength", strength)
	material.set_shader_parameter("wind_clock", clock)
	material.set_shader_parameter("wind_field_center", field_center)
	material.set_shader_parameter("wind_field_half_size", field_half_size)
	material.set_shader_parameter("wind_background", float(settings.background_strength))

func advance(delta: float) -> void:
	clock += delta
	cycle_time += delta
	if cycle_time >= lull + rise + hold + fall:
		cycle_time -= lull + rise + hold + fall
		_schedule()
	var time := cycle_time - lull
	var gust := 0.0
	if time > 0.0:
		if time < rise: gust = smoothstep(0.0, rise, time)
		elif time < rise + hold: gust = 1.0
		else: gust = 1.0 - smoothstep(0.0, fall, time - rise - hold)
	strength = float(settings.base_strength) + peak * gust + 0.018 * sin(clock * 0.47) + 0.009 * sin(clock * 0.83 + 1.3)
	_update_field()
	for material in materials: _write(material)
	for record in trees: _pose_tree(record)

func _process(delta: float) -> void:
	if game.pause_menu and game.pause_menu.active: return
	advance(delta)
