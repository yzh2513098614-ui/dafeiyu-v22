shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 stone_color : source_color = vec4(0.80, 0.82, 0.73, 1.0);
varying vec3 world_position;
varying float upper_face;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	upper_face = smoothstep(0.35, 0.9, NORMAL.y);
}

void fragment() {
	float layer = sin(world_position.y * 6.4 + sin(world_position.x * 0.48 + world_position.z * 0.31) * 0.7);
	vec3 color = stone_color.rgb * COLOR.rgb * (0.98 + layer * 0.022);
	color = mix(color, stone_color.rgb * 1.035, upper_face * 0.15);
	float wet = 1.0 - smoothstep(-1.12, -0.76, world_position.y);
	ALBEDO = mix(color, color * vec3(0.67, 0.78, 0.73), wet * 0.60);
	ROUGHNESS = mix(0.94, 0.60, wet);
	SPECULAR = mix(0.10, 0.22, wet);
}
