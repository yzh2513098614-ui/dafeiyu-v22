shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
uniform vec4 grass_color : source_color = vec4(0.74, 0.81, 0.59, 1.0);
uniform vec4 grass_shadow : source_color = vec4(0.66, 0.74, 0.52, 1.0);
varying vec2 ground_point;

void vertex() {
	ground_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), u.x), u.y);
}

void fragment() {
	float broad = noise(ground_point * 0.25);
	float patches = noise(ground_point * 0.72 + vec2(9.3, 17.1));
	vec3 color = mix(grass_shadow.rgb, grass_color.rgb, 0.40 + broad * 0.55);
	color *= 0.98 + patches * 0.045;
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
