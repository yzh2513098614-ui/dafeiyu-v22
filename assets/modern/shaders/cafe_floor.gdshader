shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
uniform int zone_kind=0;
varying vec2 point;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
 vec2 p=point;vec3 color;
 if(zone_kind==1){
  vec2 uv=p/vec2(.34,2.1);uv.y+=mod(floor(uv.x),3.)*.33;
  vec2 edge=min(fract(uv),1.-fract(uv));
  vec2 aa=max(fwidth(uv),vec2(.001));
  float seams=max(1.-smoothstep(.015-aa.x,.015+aa.x,edge.x),1.-smoothstep(.009-aa.y,.009+aa.y,edge.y));
  float grain=sin(p.y*11.+sin(p.x*25.))*exp(-fwidth(p.y*11.)*2.);
  color=vec3(.65,.47,.31)*(.94+hash21(floor(uv))*.13+grain*.028);
  color=mix(color,vec3(.49,.37,.27),seams*.55);
 }else if(zone_kind==2){
  vec2 q=(UV-.5)*2.;float edge=max(abs(q.x),abs(q.y));
  float waves=sin(p.x*1.45+sin(p.y*.65)*1.2);
  color=mix(vec3(.31,.49,.49),vec3(.40,.57,.55),smoothstep(-.6,.6,waves));
  color=mix(color,vec3(.81,.70,.47),smoothstep(.88,.90,edge)*(1.-smoothstep(.94,.96,edge)));
  color=mix(color,vec3(.31,.44,.43),smoothstep(.985,1.,edge));
 }else{
  vec2 uv=p/.84;
  float parity=mod(floor(uv.x)+floor(uv.y),2.);
  vec2 edge=min(fract(uv),1.-fract(uv));vec2 aa=max(fwidth(uv),vec2(.002));
  float seam=max(1.-smoothstep(.014-aa.x,.014+aa.x,edge.x),1.-smoothstep(.014-aa.y,.014+aa.y,edge.y));
  color=mix(vec3(.84,.85,.78),vec3(.62,.74,.73),parity);
  color*=.965+hash21(floor(uv))*.07;
  vec2 f=fract(uv);vec2 bevel=(1.-smoothstep(vec2(.02),vec2(.065),f))-(1.-smoothstep(vec2(.02),vec2(.065),1.-f));
  color*=1.+dot(bevel,vec2(.06,.045));
  color=mix(color,vec3(.88,.88,.80),seam);
 }
 ALBEDO=color;ROUGHNESS=.81;SPECULAR=.15;
}
