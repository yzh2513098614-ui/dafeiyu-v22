shader_type spatial;
render_mode specular_schlick_ggx, shadows_disabled;
uniform sampler2D grain_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 base_color=vec3(.7);
uniform vec3 grain_axis=vec3(1.,0.,0.);
uniform float grain_mean=.72;
uniform float roughness_value=.65;
uniform float metallic_value=0.;
uniform float specular_value=.30;
uniform int finish_type=0;
varying vec3 local_point;
varying vec3 local_normal;
void vertex(){local_point=VERTEX;local_normal=NORMAL;}
float wave(float phase){float width=max(fwidth(phase)*.5,.0001);return sin(phase)*sin(width)/width;}
void fragment(){
 vec2 coords=abs(local_normal.y)>.5?local_point.xz:vec2(dot(local_point,grain_axis),local_point.y);
 vec2 uv=coords/vec2(.42,1.7);
 if(finish_type==0){uv=uv.yx;}
 uv=1.-abs(mod(uv,2.)-1.);
 float grain=clamp(dot(texture(grain_texture,uv).rgb,vec3(.2126,.7152,.0722))/grain_mean,.70,1.30)-1.;
 float footprint=max(length(dFdx(coords)),length(dFdy(coords)));
 float detail=1.-smoothstep(.02,.09,footprint);
 float strength=finish_type==1?.12:(finish_type==2?.025:.24);
 ALBEDO=base_color*(1.+grain*strength*detail);
 ROUGHNESS=clamp(roughness_value+grain*(finish_type==1?.015:.065)*detail,.24,.99);
 METALLIC=metallic_value;SPECULAR=specular_value;
 // Fine brushing and weave are geometrical signals, separate from albedo.
 float relief=finish_type==1?wave(coords.x*360.)*wave(coords.y*360.)*.00012:grain*.00065;
 if(finish_type==2){relief=wave(coords.y*270.)*.000045;}
 relief*=detail;
 vec3 sx=dFdx(VERTEX);vec3 sy=dFdy(VERTEX);vec3 rx=cross(sy,NORMAL);vec3 ry=cross(NORMAL,sx);
 float determinant=dot(sx,rx);
 vec3 gradient=(rx*dFdx(relief)+ry*dFdy(relief))*sign(determinant)/max(abs(determinant),.0001);
 NORMAL=normalize(NORMAL-gradient*.25);
}
