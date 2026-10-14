shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 wood_color : source_color = vec4(0.78, 0.69, 0.53, 1.0);
uniform float grain_phase = 0.0;
uniform bool board_nails = false;
uniform float water_level = -1.1;
uniform float wet_level = -1.1;
varying vec3 world_position;
varying float top_face;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top_face = step(0.7, NORMAL.y);
}

void fragment() {
	vec2 p = UV * vec2(3.0, 0.52);
	float grain = p.y * 53.0 + sin(p.x * 1.6 + grain_phase) * 0.9;
	float footprint = max(fwidth(grain), 0.001);
	float fine = sin(grain) * clamp(1.8 / footprint, 0.0, 1.0);
	float broad = sin(p.y * 17.0 + sin(p.x * 0.85 + grain_phase) * 0.5);
	vec3 color = wood_color.rgb * (0.98 + fine * 0.025 + broad * 0.025);
	float knot = length(vec2((UV.x - 0.34) * 14.0, (UV.y - 0.56) * 27.0));
	color *= 1.0 - (1.0 - smoothstep(0.10, 1.1, knot)) * 0.085;
	if (board_nails) {
		vec2 nail_point = vec2(min(UV.x, 1.0 - UV.x) - 0.075,
			min(UV.y, 1.0 - UV.y) - 0.22);
		float aa = max(fwidth(UV.x), fwidth(UV.y));
		float nail = 1.0 - smoothstep(0.009 - aa, 0.009 + aa, length(nail_point));
		color = mix(color, wood_color.rgb * 0.56, nail * top_face * 0.65);
	}
	float wet = 1.0 - smoothstep(water_level - 0.04, wet_level + 0.25, world_position.y);
	ALBEDO = mix(color, color * vec3(0.62, 0.73, 0.66), wet * 0.48);
	ROUGHNESS = mix(0.88, 0.65, wet);
	SPECULAR = 0.12;
}
