// Rendering-only recovery: sample untouched video RGB/alpha, never erode lace.
uniform bool safe_matte_enabled = false;
uniform sampler2D original_frame : source_color, filter_linear;
uniform sampler2D before_holes : filter_nearest;
uniform sampler2D after_holes : filter_nearest;
uniform float original_shift = 0.0;

vec4 original_sample(vec2 uv) {
 vec2 size = vec2(textureSize(original_frame, 0));
 vec2 source_uv = uv - vec2(0.0, original_shift / size.y);
 vec4 c = texture(original_frame, source_uv);
 float lo = min(c.r, min(c.g, c.b));
 float hi = max(c.r, max(c.g, c.b));
 // The studio flood-fill leaked through the left ear's pale contour.
 // Recover its enclosed white interior from untouched RGB, not nearby hair.
 bool left_ear = uv.x > 0.205 && uv.x < 0.315 && uv.y > 0.335 && uv.y < 0.41;
 if (left_ear && c.a < 0.1 && lo > 0.77 && hi-lo < 0.14) {
  vec2 pixel = 1.0 / size;
  bool left_edge = false;
  bool right_edge = false;
  bool top_edge = false;
  bool bottom_edge = false;
  for (int i = 1; i <= 64; i++) {
   float d = float(i);
   vec4 l = texture(original_frame, source_uv-vec2(pixel.x*d,0.0));
   vec4 r = texture(original_frame, source_uv+vec2(pixel.x*d,0.0));
   vec4 t = texture(original_frame, source_uv-vec2(0.0,pixel.y*d));
   vec4 b = texture(original_frame, source_uv+vec2(0.0,pixel.y*d));
   left_edge = left_edge || (l.a > 0.5 && l.b-l.r > 0.06);
   right_edge = right_edge || (r.a > 0.5 && r.b-r.r > 0.06);
   top_edge = top_edge || (t.a > 0.5 && t.b-t.r > 0.06);
   bottom_edge = bottom_edge || (b.a > 0.5 && b.b-b.r > 0.06);
   if (left_edge && right_edge && top_edge && bottom_edge) break;
  }
  if (left_edge && right_edge && top_edge && bottom_edge) c.a = 1.0;
 }
 // Reuse only the recorded studio holes, with an original neutral-colour gate.
 // No dilation around the hole: thin hair, ears and costume keep their alpha.
 if (!left_ear && lo > 0.78 && hi-lo < 0.12 &&
     texture(before_holes, uv).a > 0.5 && texture(after_holes, uv).a < 0.1) {
  c.a = 0.0;
 }
 return c;
}

bool in_studio_gap_zone(vec2 uv) {
 return (uv.x < 0.31 && uv.y > 0.41 && uv.y < 0.655) ||
        (uv.x < 0.36 && uv.y > 0.41 && uv.y < 0.54) ||
        (uv.x > 0.74 && uv.y > 0.405 && uv.y < 0.625) ||
        (uv.x > 0.68 && uv.y > 0.45 && uv.y < 0.625) ||
        (uv.x > 0.68 && uv.y > 0.61 && uv.y < 0.658) ||
        (uv.x > 0.72 && uv.y >= 0.625 && uv.y < 0.715);
}

vec4 studio_gap_sample(vec2 uv) {
 vec4 c = original_sample(uv);
 vec2 size = vec2(textureSize(original_frame,0));
 vec2 source_uv = uv-vec2(0.0,original_shift/size.y);
 float lo = min(c.r,min(c.g,c.b));
 float hi = max(c.r,max(c.g,c.b));
 // Residual studio islands between blue hair locks and at the tail root.
 // White cuffs, apron, face, lace and ear interiors are outside these zones.
 bool hair_gap = in_studio_gap_zone(uv);
 bool tail_arc = uv.x > 0.68 && uv.y > 0.61 && uv.y < 0.658;
 if (hair_gap && c.a > 0.1 && lo > (tail_arc ? 0.60 : 0.70) && hi-lo < (tail_arc ? 0.25 : 0.12)) {
  vec2 pixel = 1.0 / size;
  bvec4 enclosed = bvec4(false);
  for (int i = 1; i <= 96; i++) {
   float d = float(i);
   vec4 l = texture(original_frame, source_uv-vec2(pixel.x*d,0.0));
   vec4 r = texture(original_frame, source_uv+vec2(pixel.x*d,0.0));
   vec4 t = texture(original_frame, source_uv-vec2(0.0,pixel.y*d));
   vec4 b = texture(original_frame, source_uv+vec2(0.0,pixel.y*d));
   enclosed.x = enclosed.x || (l.a > 0.5 && l.b-l.r > 0.07);
   enclosed.y = enclosed.y || (r.a > 0.5 && r.b-r.r > 0.07);
   enclosed.z = enclosed.z || (t.a > 0.5 && t.b-t.r > 0.07);
   enclosed.w = enclosed.w || (b.a > 0.5 && b.b-b.r > 0.07);
   if (all(enclosed)) break;
  }
  if (all(enclosed)) c.a = 0.0;
 }
 return c;
}

vec4 safe_matte_sample(vec2 uv) {
 vec4 c = studio_gap_sample(uv);
 if (c.a < 0.01) return c;
 // Correct mixed studio colour only at an exposed boundary next to a blue
 // outline. Solid costume interiors never see transparent neighbours.
 float lo = min(c.r, min(c.g, c.b));
 float hi = max(c.r, max(c.g, c.b));
 if (c.b < c.r) return c;
 vec2 pixel = 1.0 / vec2(textureSize(original_frame, 0));
 vec4 inside = c;
 float outside = 1.0;
 for (int y = -3; y <= 3; y++) {
  for (int x = -3; x <= 3; x++) {
   vec4 q = original_sample(uv + vec2(float(x), float(y)) * pixel);
   outside = min(outside, q.a);
   float q_min = min(q.r,min(q.g,q.b));
   float q_max = max(q.r,max(q.g,q.b));
   vec2 q_uv = uv+vec2(float(x),float(y))*pixel;
   bool q_arc = q_uv.x > 0.68 && q_uv.y > 0.61 && q_uv.y < 0.658;
   if (in_studio_gap_zone(q_uv) && q_min > (q_arc ? 0.60 : 0.70) && q_max-q_min < (q_arc ? 0.25 : 0.12)) outside = 0.0;
   if (q.a > 0.99 && q.b-q.r > 0.08 && q.b-q.g > 0.025 && q.r < inside.r) inside = q;
  }
 }
 if (outside < 0.2 && inside.r + 0.025 < c.r) {
  // Recover white-matte coverage rather than deleting an opaque rim.
  vec3 studio = vec3(0.95, 0.945, 0.958);
  vec3 coverage = clamp((studio-c.rgb) / max(studio-inside.rgb, vec3(0.05)), vec3(0.0), vec3(1.0));
  float a = max(coverage.r, max(coverage.g, coverage.b));
  c.rgb = clamp((c.rgb-studio*(1.0-a)) / max(a, 0.01), vec3(0.0), vec3(1.0));
  c.a *= a;
 }
 return c;
}
