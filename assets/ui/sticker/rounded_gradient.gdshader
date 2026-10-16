shader_type canvas_item;
uniform vec4 start_color : source_color = vec4(1.0);
uniform vec4 end_color : source_color = vec4(0.9, 0.94, 1.0, 1.0);
uniform vec2 rect_size = vec2(100.0);
uniform vec2 axis = vec2(0.7, 0.3);
uniform float radius = 12.0;
void fragment() {
    vec2 q = abs((UV - 0.5) * rect_size) - rect_size * 0.5 + radius;
    float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
    float blend = clamp(dot(UV, axis) / max(axis.x + axis.y, 0.001), 0.0, 1.0);
    COLOR = mix(start_color, end_color, blend);
    COLOR.a *= 1.0 - smoothstep(-0.8, 0.8, distance_to_edge);
}
