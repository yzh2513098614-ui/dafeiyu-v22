shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.8, 0.7, 0.6, 1.0);
uniform vec4 detail_color : source_color = vec4(0.6, 0.5, 0.4, 1.0);
uniform int pattern = 0;
uniform vec2 pattern_scale = vec2(1.0, 6.0);
uniform float detail_strength = 0.2;
uniform float roughness_value = 0.9;
varying float world_height;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), u.x), u.y);
}
float filtered_sine(float phase) {
	float footprint = max(fwidth(phase), 0.001);
	return sin(phase) * clamp(sin(footprint * 0.5) / (footprint * 0.5), 0.0, 1.0);
}
void vertex() { world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() {
	// UVs are baked in metres along each board before static mesh batching.
	vec2 p = UV * pattern_scale;
	float tone = 0.0;
	vec3 color = base_color.rgb;
	if (pattern == 0 || pattern == 1) {
		float bend = noise(vec2(p.x * 0.7, p.y * 0.12)) * 1.2;
		if (pattern == 1) bend += sin(p.x * 0.85) * 1.3 + sin(p.x * 1.8) * 0.3;
		float phase = (p.y + bend) * 6.283185;
		if (UV2.x > 0.5) phase = length((UV - vec2(0.12, 0.08)) * pattern_scale) * 6.283185;
		tone = 0.32 + 0.45 * (0.5 + 0.5 * filtered_sine(phase));
		tone += 0.15 * (0.5 + 0.5 * filtered_sine(phase * 2.15));
	} else if (pattern == 2) {
		// Matte painted panels: low-contrast brush marks, without wood knots.
		tone = 0.20 + 0.22 * (0.5 + 0.5 * filtered_sine(p.y * 12.56637));
		tone += noise(vec2(p.x * 2.0, p.y * 0.5)) * 0.16;
	} else if (pattern == 3) {
		// Fine mineral chips on cabinet counters and the blush tea table.
		vec2 stone_point = UV * 12.0;
		vec2 cell = floor(stone_point);
		vec2 center = vec2(hash(cell), hash(cell + vec2(7.0, 3.0))) * 0.6 + 0.2;
		float distance = length((fract(stone_point) - center) * vec2(1.0, 1.35));
		float radius = 0.08 + hash(cell + vec2(4.0, 8.0)) * 0.09;
		float aa = max(fwidth(distance), 0.025);
		float chip = 1.0 - smoothstep(radius - aa, radius + aa, distance);
		tone = chip * 0.8 + noise(UV * 1.4) * 0.16;
		color = mix(color, color * 1.035, chip * step(0.55, hash(cell)));
	} else {
		// Soft cross-grain laminate for the blue display shelf and craft desk.
		float cross_grain = filtered_sine(p.x * 6.283185) * filtered_sine(p.y * 6.283185);
		tone = 0.28 + cross_grain * 0.22 + noise(UV * 3.0) * 0.18;
	}
	color = mix(color, detail_color.rgb, clamp(tone * detail_strength, 0.0, 1.0));
	color *= mix(0.92, 1.0, smoothstep(0.04, 0.65, world_height));
	ALBEDO = color;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.10;
}
