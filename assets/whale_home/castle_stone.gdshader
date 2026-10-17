shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
uniform vec4 stone_color : source_color = vec4(0.91, 0.86, 0.76, 1.0);
varying vec3 world_point;
varying vec3 world_normal;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float horizontal = abs(world_normal.z) > abs(world_normal.x) ? world_point.x : world_point.z;
	vec2 cell = vec2(horizontal / 1.8, world_point.y / 0.85);
	cell.x += mod(floor(cell.y), 2.0) * 0.5;
	vec2 tile = fract(cell);
	vec2 gap = min(tile, vec2(1.0) - tile) * vec2(1.8, 0.85);
	float width = max(fwidth(horizontal), fwidth(world_point.y));
	float joint = 1.0 - smoothstep(0.008 - width * 0.5, 0.018 + width * 0.5, min(gap.x, gap.y));
	float tone = fract(sin(dot(floor(cell), vec2(17.31, 43.17))) * 3719.13);
	float vertical = 1.0 - smoothstep(0.65, 0.92, abs(world_normal.y));
	ALBEDO = stone_color.rgb * (0.982 + tone * 0.025 - joint * vertical * 0.065);
	ROUGHNESS = 0.96;
	SPECULAR = 0.08;
}
