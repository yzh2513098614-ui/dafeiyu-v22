shader_type spatial;
render_mode specular_disabled;

uniform vec4 sand_light : source_color = vec4(0.79, 0.76, 0.63, 1.0);
uniform vec4 sand_dark : source_color = vec4(0.54, 0.62, 0.53, 1.0);
uniform float caustic_strength = 0.22;
uniform float caustic_scale = 0.85;
uniform float caustic_depth = 7.0;
uniform float wave_time = 0.0;
uniform float water_level = -1.1;
uniform float night_weight = 0.0;
varying vec3 bed_position;

void vertex() {
	bed_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = bed_position.xz;
	float patches = sin(p.x * 0.23 + sin(p.y * 0.17) * 1.5) * cos(p.y * 0.28 - p.x * 0.12);
	vec3 sand = mix(sand_dark.rgb, sand_light.rgb, smoothstep(-0.8, 0.75, patches));
	float ripples = sin(p.x * 4.0 + sin(p.y * 0.6) * 2.0);
	sand *= 1.0 + ripples * 0.035;
	vec2 flow = p * caustic_scale + vec2(sin(p.y * 0.47 + wave_time * 0.32), cos(p.x * 0.41 - wave_time * 0.27)) * 0.72;
	float field = sin(flow.x + wave_time * 0.21) + sin(flow.y - wave_time * 0.18) + sin(flow.x + flow.y + wave_time * 0.13);
	float width = 0.07 + fwidth(field);
	float caustic = 1.0 - smoothstep(0.0, width, abs(field));
	float depth = max(water_level - bed_position.y, 0.0);
	caustic *= exp(-depth / caustic_depth) * (1.0 - night_weight) * caustic_strength;
	ALBEDO = sand * (1.0 + caustic);
	ROUGHNESS = 1.0;
	EMISSION = sand * caustic * 0.12;
}
