// One continuous map for every complete video pose; no joints or image slices.
// Source-frame UVs keep the enlarged face below a locally compressed crown;
// both the source ground row and the opaque alpha holes use the same mapping.
uniform bool proportion_warp_enabled = false;
uniform float proportion_ground = 0.9375;
uniform float proportion_head_end = 0.50;
uniform float proportion_head_height = 0.0;
uniform float proportion_head_width = 0.0;
uniform float proportion_crown_compression = 0.0;
uniform float proportion_head_drop = 0.0;
uniform float proportion_top_padding = 0.0;
uniform float proportion_canvas_height = 2.5344;
uniform float proportion_body_end = 0.82;
uniform float proportion_body_extension = 0.030;
uniform float proportion_leg_extension = 0.008;
uniform float proportion_body_width = 0.12;
uniform float proportion_skirt_width = 0.06;

float proportion_smooth_derivative(float start, float end, float value) {
 float t = clamp((value-start)/(end-start),0.0,1.0);
 return 6.0*t*(1.0-t)/(end-start);
}

float proportion_destination_y(float source_y) {
 return source_y
  +proportion_head_height*min(source_y-proportion_head_end,0.0)
  +proportion_crown_compression*(1.0-smoothstep(0.12,0.38,source_y))
  +proportion_head_drop*smoothstep(0.20,0.53,source_y)*(1.0-smoothstep(0.53,proportion_body_end,source_y))
  +proportion_body_extension*(smoothstep(proportion_head_end,proportion_body_end,source_y)-1.0)
  +proportion_leg_extension*(smoothstep(proportion_body_end,proportion_ground,source_y)-1.0);
}

vec2 proportion_source_uv(vec2 destination) {
 if (!proportion_warp_enabled) { return destination; }
 // The map is strictly increasing. Six Newton steps invert it accurately
 // without seams between the head, apron, skirt and shoes.
 float y = destination.y+proportion_body_extension+proportion_leg_extension;
 for (int i=0; i<6; i++) {
  float slope = 1.0
   +(y<proportion_head_end ? proportion_head_height : 0.0)
   -proportion_crown_compression*proportion_smooth_derivative(0.12,0.38,y)
   +proportion_head_drop*(proportion_smooth_derivative(0.20,0.53,y)*(1.0-smoothstep(0.53,proportion_body_end,y))
    -smoothstep(0.20,0.53,y)*proportion_smooth_derivative(0.53,proportion_body_end,y))
   +proportion_body_extension*proportion_smooth_derivative(proportion_head_end,proportion_body_end,y)
   +proportion_leg_extension*proportion_smooth_derivative(proportion_body_end,proportion_ground,y);
  y -= (proportion_destination_y(y)-destination.y)/slope;
 }
 float body = smoothstep(proportion_head_end,0.585,y)*(1.0-smoothstep(0.86,0.925,y));
 float head = 1.0-smoothstep(proportion_head_end-0.04,0.585,y);
 float skirt = exp(-pow((y-0.745)/0.085,2.0));
 float width = 1.0+head*proportion_head_width+body*(proportion_body_width+proportion_skirt_width*skirt);
 return vec2(0.5+(destination.x-0.5)/width,y);
}
