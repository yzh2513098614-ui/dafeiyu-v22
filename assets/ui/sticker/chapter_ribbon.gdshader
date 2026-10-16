shader_type canvas_item;
void fragment() {
 float bottom = 0.78 + abs(UV.x - 0.5) * 0.44;
 COLOR.a *= 1.0 - smoothstep(bottom - 0.015, bottom, UV.y);
}
