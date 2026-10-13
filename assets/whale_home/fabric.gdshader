shader_type spatial;
render_mode diffuse_lambert;
uniform vec4 fabric_color : source_color = vec4(0.42,0.66,0.91,1.0);
uniform int pattern = 0;
varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){
 vec3 c=fabric_color.rgb;
 float aa=max(fwidth(p.x*12.0),0.02);
 if(pattern==1){float s=abs(sin(p.x*12.0));c=mix(c,vec3(0.97,0.96,0.90),smoothstep(0.64-aa,0.72+aa,s));}
 float weave=sin(p.x*160.0)*sin(p.z*160.0);
 float fade=1.0-smoothstep(0.2,0.8,max(fwidth(p.x*160.0),fwidth(p.z*160.0)));
 ALBEDO=c*(0.99+weave*fade*0.015);ROUGHNESS=0.94;SPECULAR=0.12;
}
