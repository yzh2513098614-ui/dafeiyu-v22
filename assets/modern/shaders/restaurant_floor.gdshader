shader_type spatial;
render_mode specular_schlick_ggx;
#include "res://assets/modern/shaders/filtered_grid.gdshaderinc"
uniform sampler2D wood_grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 base_color=vec3(.72,.68,.57);
uniform bool diagonal=false;
varying vec3 world_point;
varying vec3 world_normal;
float hash21(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 p=world_point.xz;
 // Interlocking rectangles retain a genuine herringbone layout without mirrors.
 if(diagonal){p=vec2(p.x+p.y,p.y-p.x)*.7071068;}
 vec2 planks=p/vec2(2.15,.24);
 planks.x+=mod(floor(planks.y),3.)/3.;
 vec2 cell=floor(planks);
 vec2 grain_coords=p;
 if(diagonal){
  vec2 grid=p/.24;vec2 square=floor(grid);float band=mod(square.x+square.y,12.);
  bool horizontal=band<6.;
  vec2 origin=horizontal?vec2(square.x-band,square.y):vec2(square.x,square.y-band+6.);
  vec2 within=grid-origin;
  planks=horizontal?within/vec2(6.,1.):within.yx/vec2(6.,1.);
  cell=origin+vec2(horizontal?0.:.35,0.);
  grain_coords=(horizontal?within:within.yx)*.24;
 }
 vec2 edges=filtered_grid_axes(planks,vec2(.0012)/vec2(2.15,.24));
 float joint=edges.x+edges.y-edges.x*edges.y;
 vec2 uv=vec2(grain_coords.y/.62,grain_coords.x/2.4)+vec2(hash21(cell)*.38,hash21(cell+8.)*.31);
 uv=1.-abs(mod(uv,2.)-1.);
 float grain=clamp(dot(texture(wood_grain,uv).rgb,vec3(.2126,.7152,.0722))/.721,-0.,1.35)-1.;
 float visibility=1.-smoothstep(.045,.18,max(length(dFdx(p)),length(dFdy(p))));
 float board=hash21(cell)-.5;
 ALBEDO=base_color*(1.+board*.035+grain*.19*visibility)*(1.-joint*.10);
 ROUGHNESS=clamp(.63+board*.025+grain*.05+joint*.16,.52,.86);SPECULAR=.30;
 float top=smoothstep(.7,.95,world_normal.y);
 float height=(grain*.0006*visibility-joint*.0008)*top;
 vec3 sx=dFdx(VERTEX);vec3 sy=dFdy(VERTEX);vec3 rx=cross(sy,NORMAL);vec3 ry=cross(NORMAL,sx);
 float determinant=dot(sx,rx);
 vec3 gradient=(rx*dFdx(height)+ry*dFdy(height))*sign(determinant)/max(abs(determinant),.0001);
 NORMAL=normalize(NORMAL-gradient*.35);
}
