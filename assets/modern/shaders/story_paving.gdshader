shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(.74,.57,.43,1.);
uniform vec4 joint_color : source_color = vec4(.82,.73,.62,1.);
uniform int paving_kind = 0;
uniform vec2 tile_size = vec2(1.2,1.2);
varying vec3 world_point;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=world_point.xz;vec2 tile=p/tile_size;
 float joint;float variation;float rim;float bevel;
 if(paving_kind==1){
  // Fan-shaped setts: concentric courses with radial joints, visible at game scale.
  vec2 fan=vec2(p.x/3.4,p.y/3.2);float row=floor(fan.y);
  fan.x+=mod(row,2.)*.5;
  vec2 local=vec2((fract(fan.x)-.5)*3.4,fract(fan.y)*3.2+.12);
  float radius=length(local);float course=radius/.40;
  float number=max(floor(course)*2.+4.,6.);
  float wedge=(atan(local.y,local.x)/3.14159265)*number+mod(floor(course),2.)*.5;
  vec2 edge=min(fract(vec2(course,wedge)),1.-fract(vec2(course,wedge)));
  // Differentiate the continuous coordinates, not the changing course count.
  // Otherwise neighboring courses produce oversized filtering at each ring.
  vec2 radial=local/max(radius,.001);
  vec2 angular=vec2(-local.y,local.x)/max(radius*radius,.001);
  vec2 dx=dFdx(p);vec2 dy=dFdy(p);
  vec2 aa=max(vec2((abs(dot(radial,dx))+abs(dot(radial,dy)))/.40,
    (abs(dot(angular,dx))+abs(dot(angular,dy)))*number/3.14159265),vec2(.015));
  vec2 line=1.-smoothstep(vec2(.045)-aa*.45,vec2(.045)+aa*.45,edge);
  joint=max(line.x,line.y);rim=1.-smoothstep(.045,.14,min(edge.x,edge.y));
  vec2 course_edge=fract(vec2(course,wedge));
  vec2 edge_light=(1.-smoothstep(vec2(.06),vec2(.22),course_edge))-
    (1.-smoothstep(vec2(.06),vec2(.22),1.-course_edge));
  bevel=.075*edge_light.x*dot(radial,normalize(vec2(-.65,-.75)))+
    .055*edge_light.y*dot(normalize(vec2(-local.y,local.x)),normalize(vec2(-.65,-.75)));
  variation=hash21(vec2(floor(fan.x)*31.+floor(course),row*29.+floor(wedge)));
 }else{
  tile.x+=mod(floor(tile.y),2.)*(paving_kind==2?.5:0.);
  vec2 edge=min(fract(tile),1.-fract(tile));vec2 aa=max(fwidth(tile),vec2(.002));
  vec2 line=1.-smoothstep(vec2(.013)-aa*.45,vec2(.013)+aa*.45,edge);
  joint=max(line.x,line.y);rim=1.-smoothstep(.013,.052,min(edge.x,edge.y));
  vec2 brick_edge=fract(tile);
  vec2 edge_light=(1.-smoothstep(vec2(.018),vec2(.085),brick_edge))-
    (1.-smoothstep(vec2(.018),vec2(.085),1.-brick_edge));
  bevel=dot(edge_light,vec2(.095,.075));
  variation=hash21(floor(tile));
 }
 float wash=sin(p.x*.52+p.y*.31)*sin(p.y*.41-p.x*.16)*.025;
 vec3 color=base_color.rgb*((paving_kind==1?.92:.95)+variation*(paving_kind==1?.16:.10)+wash);
 color+=base_color.rgb*(rim*.045+bevel);
 color=mix(color,joint_color.rgb,joint);
 ALBEDO=color;ROUGHNESS=.86;SPECULAR=.12;
}
