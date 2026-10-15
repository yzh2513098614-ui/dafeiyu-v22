shader_type spatial;
render_mode unshaded, depth_draw_always, cull_back;

uniform sampler2D scene_colour : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 water_tint : source_color = vec4(0.15, 0.55, 0.61, 1.0);
uniform vec4 night_tint : source_color = vec4(0.086, 0.243, 0.341, 1.0);
uniform vec3 absorption = vec3(0.38, 0.105, 0.075);
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.65;
uniform float water_ior = 1.333;
uniform float ripple_strength = 0.055;
uniform float ripple_scale = 1.0;
uniform float ripple_warp = 0.8;
uniform vec3 wind_direction = vec3(0.94, 0.0, 0.34);
uniform float reflection_strength = 1.25;
uniform float reflection_roughness : hint_range(0.0, 1.0) = 0.2;
uniform bool ssr_enabled = true;
uniform float ssr_steps : hint_range(4.0, 24.0, 1.0) = 16.0;
uniform float ssr_distance = 26.0;
uniform float ssr_thickness = 0.45;
uniform float ssr_edge_fade = 0.08;
uniform float ssr_strength : hint_range(0.0, 1.0) = 0.8;
uniform float sun_glint_strength = 0.85;
uniform float sun_roughness : hint_range(0.04, 1.0) = 0.24;
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

vec3 reconstruct_view(vec2 uv, float depth, mat4 inverse_projection) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	#endif
	vec4 view = inverse_projection * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

vec3 reconstruct_world(vec2 uv, float depth, mat4 inverse_projection, mat4 inverse_view) {
	return (inverse_view * vec4(reconstruct_view(uv, depth, inverse_projection), 1.0)).xyz;
}

float valid_bottom(float depth, vec3 bottom, float surface_y) {
	return step(0.000001, depth) * step(depth, 0.999999) * step(0.002, surface_y - bottom.y);
}

vec2 project_uv(vec3 point, mat4 projection) {
	vec4 clip = projection * vec4(point, 1.0);
	return clip.xy / clip.w * 0.5 + 0.5;
}

// GPU Gems ch. 1 separates geometric swell from optical surface detail.
// Independent, warped wave packets avoid a rigid grid of crossing sine bands.
vec2 wind_ripple(vec2 p, vec2 k, float speed, float seed) {
	vec2 bend_k = vec2(-k.y, k.x) * 0.13;
	float bend = dot(p, bend_k) + wave_time * 0.19 + seed;
	float phase = dot(p, k) - wave_time * speed + sin(bend) * ripple_warp;
	vec2 phase_gradient = k + bend_k * cos(bend) * ripple_warp;
	float packet = 0.72 + 0.28 * sin(dot(p, k * 0.071) + wave_time * 0.11 + seed * 1.7);
	float filtered = 1.0 - smoothstep(0.45, 1.8, fwidth(phase));
	return phase_gradient * cos(phase) * (1.0 + 0.35 * sin(phase)) * packet * filtered;
}

// Screen-space marching approach: Marcel Bankmann's GodotSSRWater.
// Bounded world-distance marching with a refined crossing, above-water hit mask,
// and confidence fading. An unsuccessful ray always keeps the sky reflection.
vec4 scene_reflection(vec3 origin, vec3 direction, mat4 projection, mat4 inverse_projection, mat4 inverse_view) {
	float previous = 0.0;
	float previous_difference = -1.0;
	for (int i = 1; i <= 24; i++) {
		if (float(i) > ssr_steps) { break; }
		float fraction = float(i) / ssr_steps;
		float travel = ssr_distance * fraction * fraction;
		vec3 probe = origin + direction * travel;
		if (probe.z >= -0.05) { break; }
		vec2 uv = project_uv(probe, projection);
		if (any(lessThanEqual(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) { break; }
		float raw = textureLod(scene_depth, uv, 0.0).r;
		if (raw <= 0.000001 || raw >= 0.999999) {
			previous = travel;
			previous_difference = -1.0;
			continue;
		}
		float difference = reconstruct_view(uv, raw, inverse_projection).z - probe.z;
		if (difference >= 0.0 && previous_difference < 0.0) {
			float low = previous;
			float high = travel;
			for (int refine = 0; refine < 4; refine++) {
				float middle = (low + high) * 0.5;
				vec3 mid_probe = origin + direction * middle;
				vec2 mid_uv = project_uv(mid_probe, projection);
				float mid_raw = textureLod(scene_depth, mid_uv, 0.0).r;
				float mid_difference = reconstruct_view(mid_uv, mid_raw, inverse_projection).z - mid_probe.z;
				if (mid_raw > 0.000001 && mid_raw < 0.999999 && mid_difference >= 0.0) { high = middle; }
				else { low = middle; }
			}
			probe = origin + direction * high;
			uv = project_uv(probe, projection);
			raw = textureLod(scene_depth, uv, 0.0).r;
			vec3 hit_view = reconstruct_view(uv, raw, inverse_projection);
			vec3 hit_world = (inverse_view * vec4(hit_view, 1.0)).xyz;
			difference = hit_view.z - probe.z;
			if (raw <= 0.000001 || raw >= 0.999999 || hit_world.y < water_level + 0.03 || difference < 0.0 || difference > ssr_thickness) { return vec4(0.0); }
			float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
			float confidence = smoothstep(0.0, ssr_edge_fade, edge);
			confidence *= 1.0 - smoothstep(ssr_distance * 0.7, ssr_distance, high);
			confidence *= 1.0 - smoothstep(ssr_thickness * 0.5, ssr_thickness, difference);
			return vec4(textureLod(scene_colour, uv, reflection_roughness * 3.0).rgb, confidence);
		}
		previous = travel;
		previous_difference = difference;
	}
	return vec4(0.0);
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
	vec2 wind = normalize(wind_direction.xz);
	vec2 cross_wind = vec2(-wind.y, wind.x);
	vec2 wind_p = vec2(dot(p, wind), dot(p, cross_wind)) * ripple_scale;
	vec2 fine = wind_ripple(wind_p, vec2(1.7, 0.42), 1.05, 0.7) * 0.36;
	fine += wind_ripple(wind_p, vec2(2.8, -0.83), 1.37, 3.1) * 0.25;
	fine += wind_ripple(wind_p, vec2(4.3, 1.42), 1.61, 5.8) * 0.15;
	fine += wind_ripple(wind_p, vec2(6.1, -2.1), 1.92, 9.2) * 0.08;
	gradient += (wind * fine.x + cross_wind * fine.y) * ripple_strength;
	vec3 normal = normalize(vec3(-gradient.x, 1.0, -gradient.y));
	// VIEW works for both the game's orthographic camera and perspective views.
	vec3 to_camera = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float raw_depth = textureLod(scene_depth, SCREEN_UV, 0.0).r;
	vec3 bottom = reconstruct_world(SCREEN_UV, raw_depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float has_bottom = valid_bottom(raw_depth, bottom, surface_position.y);
	float gap = max(surface_position.y - bottom.y, 0.0);
	float path = mix(open_water_depth, min(length(bottom - surface_position), open_water_depth), has_bottom);
	vec2 sample_uv = SCREEN_UV;
	// Snell's law bends the sight ray into water; project it for either camera type.
	vec3 refracted_ray = refract(-to_camera, normal, 1.0 / water_ior);
	vec3 shifted = surface_position + refracted_ray * min(gap / max(-refracted_ray.y, 0.08), open_water_depth);
	vec2 projected_uv = project_uv((VIEW_MATRIX * vec4(shifted, 1.0)).xyz, PROJECTION_MATRIX);
	vec2 offset = (projected_uv - SCREEN_UV) * refraction_strength;
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
	float f0 = pow((water_ior - 1.0) / (water_ior + 1.0), 2.0);
	float fresnel = clamp((f0 + (1.0 - f0) * pow(1.0 - facing, 5.0)) * reflection_strength, 0.0, 1.0);
	vec3 reflection_ray = reflect(-to_camera, normal);
	vec3 reflected_sky = mix(ambient_colour.rgb, sky_colour.rgb, smoothstep(0.0, 0.75, reflection_ray.y));
	if (ssr_enabled && ssr_distance > 0.0 && reflection_ray.y > 0.02) {
		vec3 ray_origin = (VIEW_MATRIX * vec4(surface_position + normal * 0.08, 1.0)).xyz;
		vec3 ray_direction = normalize((VIEW_MATRIX * vec4(reflection_ray, 0.0)).xyz);
		vec4 reflected_scene = scene_reflection(ray_origin, ray_direction, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
		reflected_sky = mix(reflected_sky, reflected_scene.rgb, reflected_scene.a * ssr_strength);
	}
	water = mix(water, reflected_sky, fresnel);
	// GGX microfacet highlights, broadened by sub-pixel normal variance in overview.
	vec3 light = normalize(sun_direction);
	vec3 half_vector = normalize(to_camera + light);
	float no_l = max(dot(normal, light), 0.001);
	float no_v = max(facing, 0.001);
	float no_h = max(dot(normal, half_vector), 0.0);
	float vo_h = max(dot(to_camera, half_vector), 0.0);
	vec3 dx = dFdx(normal);
	vec3 dy = dFdy(normal);
	float a2 = clamp(pow(sun_roughness, 4.0) + (dot(dx, dx) + dot(dy, dy)) * 0.25, 0.0001, 1.0);
	float denominator = no_h * no_h * (a2 - 1.0) + 1.0;
	float distribution = a2 / (PI * denominator * denominator);
	float smith_v = 2.0 * no_v / (no_v + sqrt(a2 + (1.0 - a2) * no_v * no_v));
	float smith_l = 2.0 * no_l / (no_l + sqrt(a2 + (1.0 - a2) * no_l * no_l));
	float sun_fresnel = f0 + (1.0 - f0) * pow(1.0 - vo_h, 5.0);
	float glint = distribution * smith_v * smith_l * sun_fresnel / (4.0 * no_v);
	water += sun_colour.rgb * sun_energy * glint * sun_glint_strength * step(0.0, dot(normal, light));
	// Small broken contact foam only; depth and moving light carry the water body.
	float foam = (1.0 - smoothstep(0.025, 0.16, gap)) * has_bottom;
	float broken = smoothstep(-0.2, 0.7, sin(p.x * 3.7 + sin(p.y * 2.3) + wave_time * 0.7));
	foam *= broken * foam_strength;
	vec3 foam_colour = mix(vec3(0.9, 0.96, 0.91), vec3(0.20, 0.31, 0.38), night_weight);
	ALBEDO = mix(water, foam_colour, foam);
	// Transmission is already composed above. Alpha keeps water in the late pass.
	ALPHA = 1.0;
}
