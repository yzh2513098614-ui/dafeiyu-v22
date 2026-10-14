extends RefCounted
## The CPU sampler and water shader share the same wave parameters and clock.
var settings: Dictionary
var waves: Array[Vector4] = []

func _init() -> void:
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://assets/whale_home/coastal_water.json"))
	for wave: Dictionary in settings.waves:
		waves.append(Vector4(wave.vector[0], wave.vector[1], wave.speed, wave.weight))

func configure(material: ShaderMaterial) -> void:
	for key in ["wave_height", "crest_sharpness", "shore_wave_period"]:
		material.set_shader_parameter(key, settings[key])
	material.set_shader_parameter("island_half_size", Vector2(settings.island_half_size[0], settings.island_half_size[1]))
	for i in 3:
		material.set_shader_parameter("wave_" + ["a", "b", "c"][i], waves[i])

func mean_level(time: float) -> float:
	return float(settings.base_level) + sin(time * TAU / float(settings.tide_period)) * float(settings.tide_amplitude)

func wet_level(time: float) -> float:
	return maxf(mean_level(time), mean_level(time - float(settings.wet_memory_seconds)))

func sample(point: Vector2, time: float) -> Vector3:
	var half_size := Vector2(settings.island_half_size[0], settings.island_half_size[1])
	var outside := Vector2(maxf(absf(point.x) - half_size.x, 0.0), maxf(absf(point.y) - half_size.y, 0.0))
	var shore := outside.length()
	var u := clampf((shore - 0.2) / 3.8, 0.0, 1.0)
	var damping := 0.22 + 0.78 * u * u * (3.0 - 2.0 * u)
	var damping_gradient := Vector2.ZERO
	if shore > 0.0:
		damping_gradient = Vector2(outside.x * signf(point.x), outside.y * signf(point.y)) / shore * (0.78 * 6.0 * u * (1.0 - u) / 3.8)
	var height := 0.0
	var gradient := Vector2.ZERO
	for wave in waves:
		var vector := Vector2(wave.x, wave.y)
		var phase := vector.dot(point) - time * wave.z
		var swell := sin(phase)
		height += (swell + float(settings.crest_sharpness) * (swell * swell - 0.5)) * wave.w
		gradient += vector * cos(phase) * (1.0 + 2.0 * float(settings.crest_sharpness) * swell) * wave.w
	gradient = (gradient * damping + damping_gradient * height) * float(settings.wave_height)
	return Vector3(mean_level(time) + height * float(settings.wave_height) * damping, gradient.x, gradient.y)
