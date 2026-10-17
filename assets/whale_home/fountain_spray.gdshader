shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled;
uniform float water_time = 0.0;

void fragment() {
	float edge = pow(0.5 + 0.5 * cos(UV.x * 6.283185), 3.0);
	float flow = smoothstep(0.55, 0.96, 0.5 + 0.5 * sin(UV.y * 23.0 - water_time * 4.0));
	ALBEDO = mix(vec3(0.72, 0.89, 0.95), vec3(0.96, 0.99, 1.0), edge * 0.70 + flow * 0.25);
	ALPHA = 0.24 + edge * 0.28 + flow * 0.12;
}
