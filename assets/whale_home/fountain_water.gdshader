shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform float water_time = 0.0;

void vertex() {
	VERTEX.y += sin(UV.x * 16.0 + water_time * 1.1) * sin(UV.y * 13.0 - water_time * 0.8) * 0.007;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float wave = sin(p.x * 13.0 + water_time * 0.9) * sin(p.y * 11.0 - water_time * 0.6);
	float caustic = pow(0.5 + 0.5 * sin(p.x * 17.0 + p.y * 8.0 + wave * 1.2 - water_time), 8.0);
	float ripple = 0.0;
	for (int i = 0; i < 4; i++) {
		float angle = float(i) * 1.570796 + 0.20;
		float d = length(p - vec2(cos(angle), sin(angle)) * 0.76);
		ripple += pow(0.5 + 0.5 * sin(d * 51.0 - water_time * 3.0 + float(i)), 12.0) * exp(-d * 7.0);
	}
	ALBEDO = mix(vec3(0.32, 0.65, 0.75), vec3(0.53, 0.79, 0.85), 0.48 + wave * 0.12);
	ALBEDO = mix(ALBEDO, vec3(0.84, 0.96, 0.97), clamp(caustic * 0.14 + ripple * 0.40, 0.0, 0.65));
	ALPHA = 1.0;
	ROUGHNESS = 0.32;
	SPECULAR = 0.35;
}
