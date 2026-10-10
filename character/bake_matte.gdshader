shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D source_frame : source_color, filter_nearest;
uniform bool mask_only = false;
#include "res://character/safe_matte.gdshaderinc"
#include "res://character/edge_ink.gdshaderinc"
vec4 cleaned(vec2 uv) {
 if (safe_matte_enabled) return safe_matte_sample(uv);
 return texture(source_frame,uv);
}
void fragment() {
 vec4 p = cleaned(UV);
 if (mask_only) {
  COLOR = vec4(vec3(p.a),1.0);
 } else {
  vec2 pixel = 1.0/vec2(textureSize(source_frame,0));
  vec2 step = pixel*edge_ink_width;
  float neighbour_alpha = min(min(cleaned(UV+vec2(step.x,0.0)).a,cleaned(UV-vec2(step.x,0.0)).a),
                              min(cleaned(UV+vec2(0.0,step.y)).a,cleaned(UV-vec2(0.0,step.y)).a));
  COLOR = edge_ink_paint(p,UV/pixel,neighbour_alpha);
 }
}
