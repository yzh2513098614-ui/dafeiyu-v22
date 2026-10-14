shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
uniform vec4 stone_color : source_color = vec4(0.89, 0.87, 0.80, 1.0);
uniform bool field_pattern = false;
varying vec2 ground_point;

void vertex() {
	ground_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = ground_point;
	float cloud = sin(p.x * 0.63 + sin(p.y * 0.41)) * sin(p.y * 0.53 + p.x * 0.17);
	vec3 color = stone_color.rgb * (0.985 + cloud * 0.018);
	if (field_pattern) {
		vec2 grid = p / vec2(2.6, 1.3);
		grid.x += mod(floor(grid.y), 2.0) * 0.5;
		vec2 tile = fract(grid);
		vec2 edge = min(tile, vec2(1.0) - tile) * vec2(2.6, 1.3);
		float aa = max(fwidth(p.x), fwidth(p.y)) * 0.65;
		float grout = 1.0 - smoothstep(0.018 - aa, 0.030 + aa, min(edge.x, edge.y));
		color *= 0.97 + hash(floor(grid)) * 0.055;
		color = mix(color, stone_color.rgb * vec3(0.77, 0.81, 0.75), grout * 0.42);
	}
	ALBEDO = color;
	ROUGHNESS = 0.94;
	SPECULAR = 0.10;
}
