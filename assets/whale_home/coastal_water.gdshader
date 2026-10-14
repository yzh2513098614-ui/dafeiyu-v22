shader_type spatial;
render_mode unshaded, depth_draw_always;

uniform float night_weight = 0.0;
uniform float water_level = -1.1;
uniform float wave_time = 0.0;
uniform float tide_amount = 0.5;
uniform float wave_height : hint_range(0.0, 0.4) = 0.18;
uniform float crest_sharpness : hint_range(0.0, 0.5) = 0.35;
uniform float shore_wave_period = 7.5;
uniform vec4 wave_a = vec4(0.37, 0.25, 0.70, 0.60);
uniform vec4 wave_b = vec4(-0.21, 0.53, 0.57, 0.28);
uniform vec4 wave_c = vec4(0.71, -0.18, 0.82, 0.12);
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

// Sharper crests and broad troughs, using the controller's pausable clock.
vec3 waves(vec2 p) {
	return vec3(dot(p, wave_a.xy) - wave_time * wave_a.z,
		dot(p, wave_b.xy) - wave_time * wave_b.z,
		dot(p, wave_c.xy) - wave_time * wave_c.z);
}

vec3 crest_shape(vec3 phase) {
	vec3 swell = sin(phase);
	return swell + crest_sharpness * (swell * swell - vec3(0.5));
}

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec3 phase = waves(p);
	float calm_shore = mix(0.22, 1.0, smoothstep(0.2, 4.0, shore_distance(p)));
	VERTEX.y += dot(crest_shape(phase), vec3(wave_a.w, wave_b.w, wave_c.w)) * wave_height * calm_shore;
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = surface_position.xz;
	float shore = shore_distance(p);
	vec3 phase = waves(p);
	float calm_shore = mix(0.22, 1.0, smoothstep(0.2, 4.0, shore));
	vec3 weights = vec3(wave_a.w, wave_b.w, wave_c.w);
	float crest_height = dot(crest_shape(phase), weights);
	vec3 slope = cos(phase) * (vec3(1.0) + 2.0 * crest_sharpness * sin(phase)) * weights * wave_height * calm_shore;
	vec2 gradient = vec2(dot(slope, vec3(wave_a.x, wave_b.x, wave_c.x)),
		dot(slope, vec3(wave_a.y, wave_b.y, wave_c.y)));
	vec2 outside = max(abs(p) - island_half_size, vec2(0.0));
	float shore_u = clamp((shore - 0.2) / 3.8, 0.0, 1.0);
	gradient += outside * sign(p) / max(shore, 0.001) * (0.78 * 6.0 * shore_u * (1.0 - shore_u) / 3.8) * crest_height * wave_height;
	vec3 normal = normalize(vec3(-gradient.x, 1.0, -gradient.y));
	float broad = noise(p * 0.13 + vec2(wave_time * 0.016, -wave_time * 0.012));
	float detail = noise(p * 0.64 - vec2(wave_time * 0.035, wave_time * 0.026));
	vec3 deep = vec3(0.48, 0.73, 0.72);
	vec3 shallow = vec3(0.68, 0.86, 0.79);
	vec3 sea = mix(deep, vec3(0.60, 0.82, 0.79), broad * 0.60);
	sea *= 1.0 + (detail - 0.5) * 0.045 + crest_height * 0.11;

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
	float shoal = max(1.0 - smoothstep(0.3, mix(3.2, 6.0, tide_amount), shore),
		(1.0 - smoothstep(0.12, 2.1, gap)) * geometry_below);
	sea = mix(sea, shallow, shoal * 0.60);

	float breakup = noise(p * 2.1 + vec2(wave_time * 0.06, -wave_time * 0.035));
	float contact = (1.0 - smoothstep(0.025, 0.30, gap)) * geometry_below;
	float edge_distance = shore + (breakup - 0.5) * 0.22;
	float shoreline = 1.0 - smoothstep(0.04, mix(0.27, 0.46, tide_amount), edge_distance);
	// A broken foam front moves toward shore; a thinner backwash recedes.
	float progress = fract(wave_time / shore_wave_period + noise(p * 0.14) * 0.12);
	float front = (1.0 - progress) * mix(1.6, 2.5, tide_amount);
	float life = smoothstep(0.0, 0.15, progress) * (1.0 - smoothstep(0.78, 1.0, progress));
	float wash = exp(-pow((edge_distance - front) / (0.12 + breakup * 0.09), 2.0)) * life;
	float retreat = fract(wave_time / shore_wave_period + 0.48);
	float backwash = exp(-abs(edge_distance - 0.20 - retreat * 1.5) * 21.0);
	backwash *= sin(retreat * PI) * 0.24;
	float foam = max(contact, shoreline) * (0.38 + 0.62 * smoothstep(0.26, 0.70, breakup));
	foam = max(foam, (wash * 0.58 + backwash) * smoothstep(0.24, 0.64, breakup));
	float crest_foam = smoothstep(0.54, 0.94, crest_height) * smoothstep(0.52, 0.78, breakup);
	foam = max(foam, crest_foam * smoothstep(1.2, 5.0, shore) * 0.40);
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
	float sparkle = smoothstep(0.72, 0.91, noise(p * 3.1 + wave_time * vec2(0.07, 0.04)));
	sparkle *= 1.0 - smoothstep(0.15, 0.45, footprint);
	sea = mix(sea, vec3(0.95, 0.98, 0.94), (highlight * 0.16 + sparkle * 0.035) * (1.0 - night_weight));
	ALBEDO = mix(sea, sea * vec3(0.21, 0.32, 0.49), night_weight * 0.82);
	// ALPHA=1 routes this surface after opaque geometry without fading it.
	ALPHA = 1.0;
}
