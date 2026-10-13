shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_prepass_alpha;
uniform sampler2D character_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 character_tint : source_color = vec3(1.0,1.0,1.0);
uniform float floor_height = 0.056;
uniform float illumination_gain : hint_range(0.5, 2.0) = 1.45;
uniform float direct_light_limit : hint_range(0.4, 1.2) = 1.05;
uniform float illustration_fill : hint_range(0.0, 0.2) = 0.10;
uniform float texture_lod_bias : hint_range(-2.0,0.0) = -1.0;
uniform float soft_contour_strength : hint_range(0.0,0.6) = 0.28;
uniform float soft_contour_width : hint_range(0.5,3.0) = 1.8;
uniform vec3 soft_contour_colour : source_color = vec3(0.10,0.15,0.22);
varying vec3 sprite_world;
#include "res://character/safe_matte.gdshaderinc"
#include "res://character/edge_ink.gdshaderinc"
#include "res://character/sprite_surface.gdshaderinc"
#include "res://character/proportion_warp.gdshaderinc"
#include "res://character/palette_match.gdshaderinc"
vec4 character_sample(vec2 uv) {
 return texture(character_atlas,proportion_source_uv(uv),texture_lod_bias);
}
void vertex() {
 // Extend only the top of the card so the enlarged head/antenna cannot clip.
 // Destination UVs and geometry expand together; the foot row stays fixed.
 if (proportion_warp_enabled) {
  VERTEX.y += (1.0-UV.y)*proportion_top_padding*proportion_canvas_height;
  UV.y = UV.y*(1.0+proportion_top_padding)-proportion_top_padding;
 }
 vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
 vec3 forward = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
 card_right=right;
 card_forward=forward;
 mat4 billboard_model = mat4(vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(forward, 0.0), MODEL_MATRIX[3]);
 MODELVIEW_MATRIX = VIEW_MATRIX * billboard_model;
 MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
 sprite_world = (billboard_model * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
 vec2 source_uv = proportion_source_uv(UV);
 // Screen-pixel width keeps the contour visible at the normal game zoom.
 vec2 contour_pixel = abs(dFdx(UV)) + abs(dFdy(UV));
 vec4 paint = character_sample(UV);
 if (safe_matte_enabled) paint = safe_matte_sample(source_uv);
 // Keep the antialiased silhouette translucent. Treating every surviving
 // edge pixel as opaque makes the pale matte read as a white outline.
 vec2 texel = 1.0 / vec2(textureSize(character_atlas, 0));
 vec4 sample_right = character_sample(UV + vec2(texel.x, 0.0));
 vec4 sample_left = character_sample(UV - vec2(texel.x, 0.0));
 vec4 sample_down = character_sample(UV + vec2(0.0, texel.y));
 vec4 sample_up = character_sample(UV - vec2(0.0, texel.y));
 if (safe_matte_enabled) {
  sample_right = original_sample(proportion_source_uv(UV + vec2(texel.x, 0.0)));
  sample_left = original_sample(proportion_source_uv(UV - vec2(texel.x, 0.0)));
  sample_down = original_sample(proportion_source_uv(UV + vec2(0.0, texel.y)));
  sample_up = original_sample(proportion_source_uv(UV - vec2(0.0, texel.y)));
 }
 if (paint.a < 0.98) {
  // Video matting left pale RGB in some semi-transparent edge pixels. Borrow
  // the nearest opaque interior colour without changing the solid drawing.
  vec4 inner = paint;
  if (sample_right.a > inner.a) inner = sample_right;
  if (sample_left.a > inner.a) inner = sample_left;
  if (sample_down.a > inner.a) inner = sample_down;
  if (sample_up.a > inner.a) inner = sample_up;
  paint.rgb = mix(paint.rgb, inner.rgb, clamp((inner.a - paint.a) * 2.0, 0.0, 0.85));
 }
 // Preserve the native painting and its cleaned alpha contour.
 if (edge_ink_enabled) {
  vec2 step = texel * edge_ink_width;
  float border_alpha;
  if (safe_matte_enabled) {
   border_alpha = min(min(original_sample(proportion_source_uv(UV+vec2(step.x,0.0))).a, original_sample(proportion_source_uv(UV-vec2(step.x,0.0))).a),
                      min(original_sample(proportion_source_uv(UV+vec2(0.0,step.y))).a, original_sample(proportion_source_uv(UV-vec2(0.0,step.y))).a));
  } else {
   border_alpha = min(min(character_sample(UV+vec2(step.x,0.0)).a,character_sample(UV-vec2(step.x,0.0)).a),
                      min(character_sample(UV+vec2(0.0,step.y)).a,character_sample(UV-vec2(0.0,step.y)).a));
  }
  paint = edge_ink_paint(paint,source_uv/texel,border_alpha);
 }
 paint.rgb = matched_character_pigment(source_uv,paint.rgb);
 // Darken inside the authored silhouette; coverage and the foot pivot stay native.
 if (edge_surface_enabled) {
  paint.rgb *= 1.0-texture(edge_surface_map,source_uv).a*edge_vignette_strength;
 }
 // A soft blue-grey outer rim separates the drawing from the floor. Only
 // cleaned, solid alpha creates it; pale discarded matte cannot come back.
 vec2 contour_step = max(texel,contour_pixel) * soft_contour_width;
 float surrounding_alpha = 0.0;
 float near_coverage = 0.0;
 float far_coverage = 0.0;
 vec2 coverage_gradient = vec2(0.0);
 for (int ring = 0; ring < 2; ring++) {
  float radius = ring == 0 ? 0.55 : 1.0;
  for (int i = 0; i < 8; i++) {
   float angle = TAU * (float(i)+float(ring)*0.5) / 8.0;
   vec2 direction = vec2(cos(angle),sin(angle));
   vec2 sample_uv = UV + direction * contour_step * radius;
   float coverage = safe_matte_enabled ? original_sample(proportion_source_uv(sample_uv)).a : character_sample(sample_uv).a;
   if (coverage < 0.42) { coverage = 0.0; }
   surrounding_alpha += min(coverage,paint.a);
   if (ring == 0) {
    near_coverage = max(near_coverage,coverage);
   } else {
    far_coverage = max(far_coverage,coverage);
    coverage_gradient += direction*coverage;
   }
  }
 }
 float soft_boundary = 1.0-clamp(surrounding_alpha/(16.0*max(paint.a,0.001)),0.0,1.0);
 paint.rgb *= 1.0-soft_boundary*soft_contour_strength*0.60;
 // A contour whose opaque neighbours are below it faces upward. Suppress
 // its outer rim, retaining the clean upper silhouette from the previous pass.
 float side_lower = 1.0-smoothstep(0.10,0.42,coverage_gradient.y/4.0);
 float native_alpha = paint.a >= 0.42 ? paint.a : 0.0;
 float rim_alpha = (near_coverage*0.65+far_coverage*0.35)*soft_contour_strength*side_lower;
 float rim_contribution = (1.0-native_alpha)*rim_alpha;
 ALPHA = native_alpha+rim_contribution;
 if (ALPHA < 0.008) { discard; }
 paint.rgb = (paint.rgb*native_alpha+soft_contour_colour*rim_contribution)/ALPHA;
 vec2 alpha_slope = vec2(sample_right.a - sample_left.a, sample_down.a - sample_up.a);
 vec3 form_normal=character_surface_normal(source_uv,paint.rgb,alpha_slope);
 // An explicit billboard basis prevents tangent-space highlights from rotating
 // incorrectly when the camera turns or a different full-picture frame is used.
 vec3 world_normal=card_right*form_normal.x+vec3(0.0,1.0,0.0)*form_normal.y+card_forward*form_normal.z;
 NORMAL=normalize(mat3(VIEW_MATRIX)*world_normal);
 hair_satin=character_hair_mask(source_uv,paint.rgb);
 ALBEDO = paint.rgb * character_tint * 0.96;
 ROUGHNESS = mix(.94,.70,hair_satin);
 METALLIC = 0.0;
 SPECULAR = 0.0;
 // Gentle pigment-coloured fill lifts painted midtones without washing out
 // dark outlines; the scene's direct lighting and shadows remain active.
 EMISSION = ALBEDO * illustration_fill;
 // Forward soles belong to the floor plane. Preserve their screen position
 // while assigning their floor depth, so they cannot sink below the mesh.
 vec3 point = sprite_world;
 if (point.y < floor_height) {
  vec3 down = normalize(vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z));
  float slope = max(abs(INV_VIEW_MATRIX[2].y) / length(INV_VIEW_MATRIX[2].xz), 0.2);
  float lift = floor_height - point.y;
  point.y += lift;
  point += down * (lift / slope);
 }
 // Shadows and light attenuation use the same corrected sole position as depth.
 LIGHT_VERTEX = (VIEW_MATRIX * vec4(point, 1.0)).xyz;
 vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(point, 1.0);
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 DEPTH = clip.z / clip.w * 0.5 + 0.5;
 #else
 DEPTH = clip.z / clip.w;
 #endif
}

// Wrapped diffuse preserves the drawing's painted form on a camera-facing
// sheet. ATTENUATION includes actual range falloff and world shadow maps.
void light() {
 float ndl = max(dot(NORMAL, LIGHT), 0.0);
 float wrap = LIGHT_IS_DIRECTIONAL ? 0.45 : 0.28;
 float diffuse = wrap + (1.0 - wrap) * ndl;
 // A pigment-coloured satin response is deliberately small. Skin and apron
 // stay matte; the real light and its shadow drive the hair highlight.
 vec3 half_light=normalize(LIGHT+VIEW);
 float satin=pow(max(dot(NORMAL,half_light),0.0),22.0)*hair_satin*.09*surface_strength;
 diffuse+=satin*ndl;
 vec3 incoming = LIGHT_COLOR / PI * ATTENUATION * diffuse * illumination_gain;
 // Recover accumulated radiance before adding another light. Applying the
 // same shoulder again without this inverse would make lamp order matter.
 float limit = max(direct_light_limit, 0.05);
 float knee = limit * 0.70;
 float span = limit - knee;
 float previous_peak = max(DIFFUSE_LIGHT.r, max(DIFFUSE_LIGHT.g, DIFFUSE_LIGHT.b));
 float raw_peak = previous_peak;
 if (previous_peak > knee) {
  raw_peak = knee - span * log(max(1.0 - (previous_peak - knee) / span, 0.0001));
 }
 vec3 total = DIFFUSE_LIGHT * (raw_peak / max(previous_peak, 0.0001)) + incoming;
 float peak = max(total.r, max(total.g, total.b));
 float shoulder = peak <= knee ? peak : knee + span * (1.0 - exp(-(peak - knee) / span));
 // A shared RGB scale preserves warm/blue hue instead of clipping channels.
 DIFFUSE_LIGHT = total * (shoulder / max(peak, 0.0001));
}
