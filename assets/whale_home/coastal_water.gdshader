shader_type spatial;
render_mode unshaded, depth_draw_always;

uniform float night_weight = 0.0;
uniform float water_level = -1.1;
uniform float wave_height : hint_range(0.0, 0.2) = 0.065;
uniform vec2 island_half_size = vec2(28.0, 25.0);
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
varying vec3 surface_position;

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

float shore_distance(vec2 p) {
	return length(max(abs(p) - island_half_size, vec2(0.0)));
}

// Three long, low swells; the same phases drive geometry and shading.
vec3 waves(vec2 p) {
	return vec3(dot(p, vec2(0.37, 0.25)) - TIME * 0.55,
		dot(p, vec2(-0.21, 0.53)) - TIME * 0.43,
		dot(p, vec2(0.71, -0.18)) - TIME * 0.63);
}

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec3 phase = waves(p);
	float calm_shore = mix(0.22, 1.0, smoothstep(0.2, 4.0, shore_distance(p)));
	VERTEX.y += dot(sin(phase), vec3(0.60, 0.28, 0.12)) * wave_height * calm_shore;
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = surface_position.xz;
	float shore = shore_distance(p);
	vec3 phase = waves(p);
	float calm_shore = mix(0.22, 1.0, smoothstep(0.2, 4.0, shore));
	vec3 slope = cos(phase) * vec3(0.60, 0.28, 0.12) * wave_height * calm_shore;
	vec2 gradient = vec2(dot(slope, vec3(0.37, -0.21, 0.71)),
		dot(slope, vec3(0.25, 0.53, -0.18)));
	vec3 normal = normalize(vec3(-gradient.x, 1.0, -gradient.y));
	float broad = noise(p * 0.13 + vec2(TIME * 0.016, -TIME * 0.012));
	float detail = noise(p * 0.64 - vec2(TIME * 0.035, TIME * 0.026));
	vec3 deep = vec3(0.48, 0.73, 0.72);
	vec3 shallow = vec3(0.68, 0.86, 0.79);
	vec3 sea = mix(deep, vec3(0.60, 0.82, 0.79), broad * 0.60);
	sea *= 1.0 + (detail - 0.5) * 0.045 + dot(sin(phase), vec3(0.028, 0.014, 0.008));

	// Read opaque land, reefs, piles and hulls before drawing the water.
	float depth = texture(scene_depth, SCREEN_UV).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 behind = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
	float gap = surface_position.y - behind.y;
	float geometry_below = step(0.006, gap) * step(0.00001, depth) * step(depth, 0.99999);
	float shoal = max(1.0 - smoothstep(0.3, 5.0, shore),
		(1.0 - smoothstep(0.12, 2.1, gap)) * geometry_below);
	sea = mix(sea, shallow, shoal * 0.60);

	float breakup = noise(p * 2.1 + vec2(TIME * 0.06, -TIME * 0.035));
	float contact = (1.0 - smoothstep(0.025, 0.30, gap)) * geometry_below;
	float tide = shore + (breakup - 0.5) * 0.22 + sin(TIME * 0.48) * 0.10;
	float shoreline = 1.0 - smoothstep(0.04, 0.38, tide);
	float wash = exp(-abs(tide - 0.78 - sin(TIME * 0.48) * 0.13) * 15.0);
	float foam = max(contact, shoreline) * (0.38 + 0.62 * smoothstep(0.26, 0.70, breakup));
	foam = max(foam, wash * smoothstep(0.43, 0.74, breakup) * 0.32);
	sea = mix(sea, vec3(0.92, 0.97, 0.92), foam * 0.78);

	// Orthographic gameplay needs a constant view direction across the image.
	vec3 view_direction = normalize(INV_VIEW_MATRIX[3].xyz - surface_position);
	if (PROJECTION_MATRIX[3][3] > 0.5) {
		view_direction = normalize(INV_VIEW_MATRIX[2].xyz);
	}
	float fresnel = pow(1.0 - max(dot(normal, view_direction), 0.0), 3.0);
	sea = mix(sea, vec3(0.80, 0.91, 0.87), fresnel * 0.20 * (1.0 - night_weight));
	vec3 sun_direction = normalize(vec3(-0.3, 0.85, 0.43));
	float highlight = pow(max(dot(normal, normalize(sun_direction + view_direction)), 0.0), 96.0);
	float footprint = max(fwidth(p.x), fwidth(p.y));
	float sparkle = smoothstep(0.72, 0.91, noise(p * 3.1 + TIME * vec2(0.07, 0.04)));
	sparkle *= 1.0 - smoothstep(0.15, 0.45, footprint);
	sea = mix(sea, vec3(0.95, 0.98, 0.94), (highlight * 0.16 + sparkle * 0.035) * (1.0 - night_weight));
	ALBEDO = mix(sea, sea * vec3(0.21, 0.32, 0.49), night_weight * 0.82);
	// ALPHA=1 routes this surface after opaque geometry without fading it.
	ALPHA = 1.0;
}
