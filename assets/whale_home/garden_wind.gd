extends Node
## Map-local gusts use their own RNG and clock; material motion survives static batching.
const TREE_SHADER = preload("res://assets/whale_home/garden_tree.gdshader")
var game
var settings: Dictionary
var rng := RandomNumberGenerator.new()
var materials: Array[ShaderMaterial] = []
var tree_materials: Dictionary = {}
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
			material.set_shader_parameter("tree_response", .80 if tree.get_meta("tree_form")=="low_green" else 1.0)
			material.set_meta("garden_tree_wind", true)
			tree_materials[key] = material
			bind_material(material)
		mesh.material_override = tree_materials[key]

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

func _process(delta: float) -> void:
	if game.pause_menu and game.pause_menu.active: return
	advance(delta)
