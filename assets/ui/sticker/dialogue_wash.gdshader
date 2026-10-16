shader_type canvas_item;
uniform vec4 blush : source_color = vec4(0.949, 0.6, 0.733, 1.0);
uniform float strength = 0.82;
void fragment() {
 float opacity = mix(0.0, 0.5, clamp(UV.y / 0.24, 0.0, 1.0));
 opacity = UV.y > 0.24 ? mix(0.5, 0.86, clamp((UV.y - 0.24) / 0.38, 0.0, 1.0)) : opacity;
 opacity = UV.y > 0.62 ? mix(0.86, 1.0, (UV.y - 0.62) / 0.38) : opacity;
 COLOR = vec4(blush.rgb, opacity * strength);
}
