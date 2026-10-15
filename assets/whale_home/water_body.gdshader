shader_type spatial;
render_mode unshaded, depth_draw_always, cull_back;

uniform sampler2D scene_colour : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 water_tint : source_color = vec4(0.15, 0.55, 0.61, 1.0);
uniform vec4 night_tint : source_color = vec4(0.086, 0.243, 0.341, 1.0);
uniform vec3 absorption = vec3(0.38, 0.105, 0.075);
uniform float refraction_strength = 0.4;
uniform float ripple_strength = 0.065;
uniform float reflection_strength = 1.0;
uniform float sun_glint_strength = 0.65;
uniform float sun_glint_power = 150.0;
uniform float foam_strength = 0.38;
uniform float open_water_depth = 24.0;
uniform vec3 sun_direction = vec3(-0.3, 0.85, 0.43);
uniform vec4 sun_colour : source_color = vec4(1.0, 0.95, 0.86, 1.0);
uniform float sun_energy = 0.4;
uniform vec4 sky_colour : source_color = vec4(0.86, 0.93, 0.9, 1.0);
uniform vec4 ambient_colour : source_color = vec4(0.83, 0.89, 0.85, 1.0);
uniform float ambient_energy = 0.35;
uniform float night_weight = 0.0;
uniform float water_level = -1.1;
uniform float wave_time = 0.0;
uniform float tide_amount = 0.5;
uniform float wave_height = 0.18;
uniform float crest_sharpness = 0.35;
uniform float shore_wave_period = 7.5;
uniform vec4 wave_a = vec4(0.37, 0.25, 0.70, 0.60);
uniform vec4 wave_b = vec4(-0.21, 0.53, 0.57, 0.28);
uniform vec4 wave_c = vec4(0.71, -0.18, 0.82, 0.12);
uniform vec2 island_half_size = vec2(42.0, 35.0);
uniform vec2 island_center = vec2(0.0, -10.0);
varying vec3 surface_position;

float shore_distance(vec2 p) {
	return length(max(abs(p - island_center) - island_half_size, vec2(0.0)));
}

vec3 phases(vec2 p) {
	return vec3(dot(p, wave_a.xy) - wave_time * wave_a.z,
		dot(p, wave_b.xy) - wave_time * wave_b.z,
		dot(p, wave_c.xy) - wave_time * wave_c.z);
}

vec3 crest_shape(vec3 phase) {
	vec3 swell = sin(phase);
	return swell + crest_sharpness * (swell * swell - vec3(0.5));
}

vec3 reconstruct_world(vec2 uv, float depth, mat4 inverse_projection, mat4 inverse_view) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	#endif
	vec4 view = inverse_projection * vec4(ndc, 1.0);
	return (inverse_view * vec4(view.xyz / view.w, 1.0)).xyz;
}

float valid_bottom(float depth, vec3 bottom, float surface_y) {
	return step(0.000001, depth) * step(depth, 0.999999) * step(0.002, surface_y - bottom.y);
}

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	// Keep displacement identical to coastal_motion.gd, including shore damping.
	float damping = mix(0.22, 1.0, smoothstep(0.2, 4.0, shore_distance(p)));
	VERTEX.y += dot(crest_shape(phases(p)), vec3(wave_a.w, wave_b.w, wave_c.w)) * wave_height * damping;
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = surface_position.xz;
	float shore = shore_distance(p);
	float u = clamp((shore - 0.2) / 3.8, 0.0, 1.0);
	float damping = 0.22 + 0.78 * u * u * (3.0 - 2.0 * u);
	vec3 phase = phases(p);
	vec3 weights = vec3(wave_a.w, wave_b.w, wave_c.w);
	float crest = dot(crest_shape(phase), weights);
	vec3 slope = cos(phase) * (vec3(1.0) + 2.0 * crest_sharpness * sin(phase)) * weights;
	vec2 gradient = vec2(dot(slope, vec3(wave_a.x, wave_b.x, wave_c.x)), dot(slope, vec3(wave_a.y, wave_b.y, wave_c.y))) * damping;
	vec2 outside = max(abs(p - island_center) - island_half_size, vec2(0.0));
	gradient += outside * sign(p - island_center) / max(shore, 0.001) * (0.78 * 6.0 * u * (1.0 - u) / 3.8) * crest;
	gradient *= wave_height;
	// Fine ripples change the optical normal only; boats still share the swell.
	vec3 ripple_phase = vec3(dot(p, vec2(1.3, 1.8)) - wave_time * 1.05,
		dot(p, vec2(2.7, -1.2)) - wave_time * 1.37,
		dot(p, vec2(-3.1, 2.4)) - wave_time * 1.61);
	vec3 ripple = cos(ripple_phase) * (vec3(1.0) - smoothstep(vec3(0.45), vec3(1.8), fwidth(ripple_phase))) * vec3(0.55, 0.28, 0.17) * ripple_strength;
	gradient += vec2(dot(ripple, vec3(1.3, 2.7, -3.1)), dot(ripple, vec3(1.8, -1.2, 2.4)));
	vec3 normal = normalize(vec3(-gradient.x, 1.0, -gradient.y));
	// VIEW works for both the game's orthographic camera and perspective views.
	vec3 to_camera = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float raw_depth = textureLod(scene_depth, SCREEN_UV, 0.0).r;
	vec3 bottom = reconstruct_world(SCREEN_UV, raw_depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float has_bottom = valid_bottom(raw_depth, bottom, surface_position.y);
	float gap = max(surface_position.y - bottom.y, 0.0);
	float path = mix(open_water_depth, min(length(bottom - surface_position), open_water_depth), has_bottom);
	vec2 sample_uv = SCREEN_UV;
	// Project a world-space displacement so refraction retains its scale in Z overview.
	vec3 shifted = surface_position + vec3(normal.x, 0.0, normal.z) * min(path, 4.0) * refraction_strength;
	vec4 projected = PROJECTION_MATRIX * VIEW_MATRIX * vec4(shifted, 1.0);
	vec4 original = PROJECTION_MATRIX * VIEW_MATRIX * vec4(surface_position, 1.0);
	vec2 offset = (projected.xy / projected.w - original.xy / original.w) * 0.5;
	offset *= smoothstep(0.0, 0.45, gap) * has_bottom;
	vec2 edge = vec2(1.5) / VIEWPORT_SIZE;
	vec2 refracted_uv = clamp(SCREEN_UV + offset, edge, vec2(1.0) - edge);
	float refracted_depth = textureLod(scene_depth, refracted_uv, 0.0).r;
	vec3 refracted_bottom = reconstruct_world(refracted_uv, refracted_depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	// Reject above-water silhouettes: a dock or hull must not smear into the water.
	float refract_ok = has_bottom * valid_bottom(refracted_depth, refracted_bottom, min(surface_position.y, water_level));
	sample_uv = mix(sample_uv, refracted_uv, refract_ok);
	bottom = mix(bottom, refracted_bottom, refract_ok);
	path = mix(open_water_depth, min(length(bottom - surface_position), open_water_depth), has_bottom);
	vec3 transmission = exp(-absorption * path) * has_bottom;
	float light_level = clamp(ambient_energy * 2.0 + 0.25, 0.1, 1.0);
	vec3 scatter = mix(water_tint.rgb, night_tint.rgb, night_weight) * light_level;
	vec3 water = textureLod(scene_colour, sample_uv, 0.0).rgb * transmission + scatter * (vec3(1.0) - transmission);
	float facing = clamp(dot(normal, to_camera), 0.0, 1.0);
	float fresnel = clamp((0.0204 + 0.9796 * pow(1.0 - facing, 5.0)) * reflection_strength, 0.0, 1.0);
	vec3 reflection_ray = reflect(-to_camera, normal);
	vec3 reflected_sky = mix(ambient_colour.rgb, sky_colour.rgb, smoothstep(0.0, 0.75, reflection_ray.y));
	water = mix(water, reflected_sky, fresnel);
	vec3 half_vector = normalize(to_camera + normalize(sun_direction));
	float glint = pow(max(dot(normal, half_vector), 0.0), sun_glint_power) * sun_glint_strength;
	water += sun_colour.rgb * sun_energy * glint;
	// Small broken contact foam only; depth and moving light carry the water body.
	float foam = (1.0 - smoothstep(0.025, 0.16, gap)) * has_bottom;
	float broken = smoothstep(-0.2, 0.7, sin(p.x * 3.7 + sin(p.y * 2.3) + wave_time * 0.7));
	foam *= broken * foam_strength;
	vec3 foam_colour = mix(vec3(0.9, 0.96, 0.91), vec3(0.20, 0.31, 0.38), night_weight);
	ALBEDO = mix(water, foam_colour, foam);
	// Transmission is already composed above. Alpha keeps water in the late pass.
	ALPHA = 1.0;
}
