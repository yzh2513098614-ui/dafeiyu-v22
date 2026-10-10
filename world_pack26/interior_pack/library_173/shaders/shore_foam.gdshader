shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec4 foam_color : source_color = vec4(0.83, 0.94, 0.88, 1.0);
uniform float animation_time = 0.0;
varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float offset = 0.13 * sin(0.75 * local_xz.x) + 0.09 * sin(1.9 * local_xz.x + 0.4);
	float center_z = -4.5 + offset;
	float edge = 1.0 - smoothstep(0.03, 0.077, abs(local_xz.y - center_z));
	float gaps = smoothstep(-0.45, 0.25, sin(local_xz.x * 2.4 + animation_time * 0.16));
	float pulse = 0.72 + 0.16 * sin(animation_time * 0.85);
	ALBEDO = foam_color.rgb;
	ALPHA = edge * mix(0.35, 0.92, gaps) * pulse;
	ROUGHNESS = 0.9;
}
