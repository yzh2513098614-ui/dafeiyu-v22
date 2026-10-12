// Authored low-frequency form, independent of the drawing's luminance.
// Bright lace is not a height map; hair strokes keep their painted shading.
uniform vec4 head_profile=vec4(.50,.33,.235,.19);
uniform vec4 body_profile=vec4(.50,.64,.235,.17);
uniform vec4 tail_profile=vec4(.73,.77,.15,.15);
uniform vec4 face_profile=vec4(.50,.433,.125,.08);
uniform vec2 head_split=vec2(.47,.60);
uniform vec2 hair_split=vec2(.56,.67);
uniform vec2 tail_split=vec2(.62,.71);
uniform float surface_strength : hint_range(0.0,1.0)=.70;
// Per-frame linear lighting data: RGB normal, alpha inward edge vignette.
uniform sampler2D edge_surface_map : filter_linear_mipmap, repeat_disable;
uniform bool edge_surface_enabled=false;
uniform float edge_surface_strength : hint_range(0.0,2.0)=0.0;
uniform float edge_vignette_strength : hint_range(0.0,0.5)=0.0;
varying vec3 card_right;
varying vec3 card_forward;
varying float hair_satin;

vec2 profile_position(vec2 uv,vec4 profile) {
 return (uv-profile.xy)/max(profile.zw,vec2(.001));
}

vec3 character_surface_normal(vec2 uv,vec3 pigment,vec2 alpha_slope) {
 vec2 head=clamp(profile_position(uv,head_profile),vec2(-1.0),vec2(1.0));
 vec2 body=clamp(profile_position(uv,body_profile),vec2(-1.0),vec2(1.0));
 float head_weight=1.0-smoothstep(head_split.x,head_split.y,uv.y);
 vec2 slope=mix(body*vec2(.26,-.12),head*vec2(.42,-.32),head_weight);
 vec2 tail=profile_position(uv,tail_profile);
 float tail_weight=(1.0-smoothstep(.65,1.15,length(tail)))*smoothstep(tail_split.x,tail_split.y,uv.y);
 slope=mix(slope,clamp(tail,vec2(-1.0),vec2(1.0))*vec2(.30,-.22),tail_weight);
 float skin=smoothstep(.025,.10,pigment.r-pigment.b);
 // The drawing owns eyes, nose and lace detail. Only a soft surface light is added.
 slope*=mix(1.0,.45,skin);
 slope+=vec2(-alpha_slope.x,alpha_slope.y)*.09;
 if (edge_surface_enabled) {
  vec3 edge_normal=texture(edge_surface_map,uv).rgb*2.0-1.0;
  slope+=edge_normal.xy/max(edge_normal.z,.25)*edge_surface_strength;
 }
 return normalize(vec3(slope*surface_strength,1.0));
}

float character_hair_mask(vec2 uv,vec3 pigment) {
 float blue=smoothstep(.025,.10,pigment.b-max(pigment.r,pigment.g));
 float shade=smoothstep(.075,.22,max(pigment.r,max(pigment.g,pigment.b)));
 float head_area=1.0-smoothstep(hair_split.x,hair_split.y,uv.y);
 float face=face_profile.z>.001 ? 1.0-smoothstep(.65,1.05,length(profile_position(uv,face_profile))) : 0.0;
 return blue*shade*head_area*(1.0-face);
}
