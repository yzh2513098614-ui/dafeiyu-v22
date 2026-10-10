// Source-pixel contour overlay. Does not change alpha or expand the silhouette.
uniform bool edge_ink_enabled = true;
uniform float edge_ink_width : hint_range(0.5, 3.0) = 1.75;
uniform float edge_ink_strength : hint_range(0.0, 1.0) = 0.90;
uniform int edge_ink_style : hint_range(0, 2) = 0;

vec3 edge_ink_colour(vec2 pixel_position) {
 // Short, static clusters: no scrolling noise or sparkling animation.
 vec2 cluster = floor(pixel_position / 4.0);
 float grain = mod(cluster.x + cluster.y * 3.0, 9.0);
 vec3 base = vec3(0.035, 0.065, 0.16);
 vec3 accent = vec3(0.065, 0.12, 0.23);
 if (edge_ink_style == 1) {
  base = vec3(0.025, 0.09, 0.12);
  accent = vec3(0.055, 0.17, 0.19);
 } else if (edge_ink_style == 2) {
  base = vec3(0.065, 0.045, 0.14);
  accent = vec3(0.13, 0.08, 0.21);
 }
 return mix(base, accent, grain < 2.0 ? 0.45 : 0.0);
}

vec4 edge_ink_paint(vec4 paint, vec2 pixel_position, float nearby_alpha) {
 if (!edge_ink_enabled) return paint;
 float boundary = 1.0-smoothstep(0.05,0.95,nearby_alpha);
 paint.rgb = mix(paint.rgb,edge_ink_colour(pixel_position),boundary*edge_ink_strength);
 return paint;
}
