shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(.75,.65,.5,1.);
uniform int finish_kind = 0;
uniform float roughness_value = .82;
varying vec3 local_point;
varying float floor_height;
void vertex(){local_point=VERTEX;floor_height=(MODEL_MATRIX*vec4(VERTEX,1.)).y;}
void fragment(){
 vec3 color=base_color.rgb;
 if(finish_kind==1){
  float phase=local_point.x*13.+sin(local_point.z*29.)*1.6;
  float footprint=max(fwidth(phase),.001);
  float grain=sin(phase)*(sin(footprint*.5)/(footprint*.5));
  color*=.98+grain*.035+sin(local_point.x*2.3+local_point.z*3.1)*.018;
 }
 color*=mix(.89,1.,smoothstep(.04,.65,floor_height));
 ALBEDO=color;ROUGHNESS=roughness_value;SPECULAR=finish_kind==2?.28:.12;
 METALLIC=finish_kind==2?.18:0.;
}
