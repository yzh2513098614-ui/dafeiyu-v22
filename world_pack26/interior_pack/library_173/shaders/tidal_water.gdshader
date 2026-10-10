shader_type spatial;
render_mode cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.28, 0.55, 0.62, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.57, 0.75, 0.72, 1.0);
uniform float tide_level = 0.0;
uniform float animation_time = 0.0;
uniform float wave_amplitude : hint_range(0.0, 0.05) = 0.014;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.85;
varying vec2 local_xz;

float beach_height(vec2 p) {
	float offset = 0.13 * sin(0.75 * p.x) + 0.09 * sin(1.9 * p.x + 0.4);
	return clamp(0.16 * (p.y + 4.5 - offset), -0.48, 0.30);
}

void vertex() {
	local_xz = VERTEX.xz;
	float phase_a = VERTEX.z * 1.8 + VERTEX.x * 0.45 - animation_time * wave_speed;
	float phase_b = VERTEX.z * 2.9 - VERTEX.x * 0.3 - animation_time * wave_speed * 0.62;
	VERTEX.y += wave_amplitude * (sin(phase_a) * 0.7 + sin(phase_b) * 0.3);
	float dx = wave_amplitude * (cos(phase_a) * 0.315 - cos(phase_b) * 0.09);
	float dz = wave_amplitude * (cos(phase_a) * 1.26 + cos(phase_b) * 0.87);
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	float bed = beach_height(local_xz);
	// The full sea mesh can cover the shore; hide the part above the water level.
	if (bed > tide_level + 0.006) {
		discard;
	}
	float depth = max(tide_level - bed, 0.0);
	float shallow = 1.0 - smoothstep(0.04, 0.38, depth);
	float ripple = sin(local_xz.y * 5.0 - animation_time * 0.6 + sin(local_xz.x * 0.65)) * 0.014;
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, shallow * 0.65) + vec3(ripple);
	ROUGHNESS = mix(0.32, 0.53, shallow);
	METALLIC = 0.04;
	SPECULAR = 0.38;
}
