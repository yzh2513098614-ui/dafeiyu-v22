shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

// No color-buffer sampling or blur: only depth and reconstructed surface normals.
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 key_direction = vec3(-0.3, 0.85, 0.43);
uniform float key_weight = 1.0;
uniform float contact_radius = 0.14;
uniform float contact_strength = 0.12;
uniform float back_edge_strength = 0.16;
uniform float back_edge_width = 3.0;
uniform float back_halo_strength = 0.08;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 view_position(vec2 uv, mat4 inverse_projection) {
	float depth = texture(scene_depth, uv).r;
	// Compatibility uses OpenGL NDC, including its [-1, 1] depth range.
	vec4 position = inverse_projection * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	return position.xyz / position.w;
}

float floor_distance(float y) {
	// This map has 5.2 m storeys. The original shared pass uses other maps' floors.
	return min(abs(y), min(abs(y - 5.2), abs(y - 10.4)));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	vec3 center = view_position(uv, INV_PROJECTION_MATRIX);
	vec3 left = view_position(uv - vec2(pixel.x, 0.0), INV_PROJECTION_MATRIX);
	vec3 right = view_position(uv + vec2(pixel.x, 0.0), INV_PROJECTION_MATRIX);
	vec3 down = view_position(uv - vec2(0.0, pixel.y), INV_PROJECTION_MATRIX);
	vec3 up = view_position(uv + vec2(0.0, pixel.y), INV_PROJECTION_MATRIX);
	// At a silhouette, use the neighbour belonging to the same depth plane.
	vec3 dx = abs(right.z - center.z) < abs(center.z - left.z) ? right - center : center - left;
	vec3 dy = abs(up.z - center.z) < abs(center.z - down.z) ? up - center : center - down;
	vec3 normal = normalize(cross(dx, dy));
	if (normal.z < 0.0) { normal = -normal; }
	vec3 world_normal = normalize(mat3(INV_VIEW_MATRIX) * normal);
	vec3 world_position = (INV_VIEW_MATRIX * vec4(center, 1.0)).xyz;
	float side = 1.0 - smoothstep(0.05, 0.35, world_normal.y);
	float unlit = 1.0 - smoothstep(-0.15, 0.40, dot(world_normal, normalize(key_direction)));
	float back_face = side * unlit * key_weight;
	float ground = smoothstep(0.80, 0.96, world_normal.y) * (1.0 - smoothstep(0.025, 0.065, floor_distance(world_position.y)));
	float receiver = max(back_face, ground);
	float occlusion = 0.0;
	float back_edge = 0.0;
	float back_halo = 0.0;
	if (receiver > 0.001) {
		vec2 radius_uv = contact_radius * 0.5 * abs(vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
		vec2 edge_uv = pixel*back_edge_width;
		for (int ring = 0; ring < 2; ring++) {
			float ring_size = ring == 0 ? 0.40 : 1.0;
			for (int i = 0; i < 8; i++) {
				float angle = TAU * (float(i) + float(ring) * 0.5) / 8.0;
				vec2 sample_uv = uv + vec2(cos(angle), sin(angle)) * radius_uv * ring_size;
				vec3 delta = view_position(sample_uv, INV_PROJECTION_MATRIX) - center;
				float distance = length(delta);
				float height = dot(normal, delta);
				float range = 1.0 - smoothstep(contact_radius * 0.35, contact_radius * 1.75, distance);
				float horizon = smoothstep(0.01, 0.06, height);
				occlusion += horizon * range;
				// The side contour has a screen-pixel width, independent of the
				// small world-space ground-contact radius. No upward receiver.
				if (back_face > 0.001) {
					back_halo += smoothstep(contact_radius*2.0,contact_radius*4.0,distance);
					vec2 edge_sample_uv = uv + vec2(cos(angle),sin(angle))*edge_uv*ring_size;
					vec3 edge_delta = view_position(edge_sample_uv, INV_PROJECTION_MATRIX)-center;
					back_edge += smoothstep(0.025,0.10,abs(dot(normal,edge_delta)));
				}
			}
		}
	}
	float shade = occlusion / 16.0 * contact_strength * receiver;
	shade += back_edge / 16.0 * back_edge_strength * back_face;
	shade += back_halo / 16.0 * back_halo_strength * back_face;
	ALBEDO = vec3(1.0 - clamp(shade, 0.0, 0.38));
	ALPHA = 1.0;
}
