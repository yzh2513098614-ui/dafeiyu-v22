shader_type spatial;
render_mode diffuse_lambert,cull_disabled;
uniform int motif = 0;
uniform vec4 background : source_color = vec4(0.97,0.96,0.90,1.0);
float oval(vec2 p,vec2 c,vec2 r){return length((p-c)/r);}
float shape(float d){float a=max(fwidth(d),0.001);return 1.0-smoothstep(1.0-a,1.0+a,d);}
void fragment(){
 vec2 p=UV;
 vec3 blue=vec3(0.26,0.53,0.86);
 vec3 c=background.rgb;
 float body=shape(oval(p,vec2(0.48,0.52),vec2(0.29,0.24)));
 float tail=shape(oval(p,vec2(0.77,0.34),vec2(0.08,0.14)))+shape(oval(p,vec2(0.86,0.47),vec2(0.12,0.07)));
 c=mix(c,blue,clamp(body+tail,0.0,1.0));
 float belly=shape(oval(p,vec2(0.43,0.63),vec2(0.21,0.12)))*body;
 c=mix(c,vec3(0.96,0.93,0.85),belly);
 c=mix(c,vec3(0.12,0.20,0.31),shape(oval(p,vec2(0.31,0.50),vec2(0.018))));
 c=mix(c,vec3(0.97,0.60,0.65),shape(oval(p,vec2(0.29,0.56),vec2(0.029,0.019))));
 float dots=0.0;
 for(int i=0;i<7;i++){float t=float(i);dots+=shape(oval(p,vec2(0.10+t*0.13,0.16+sin(t*1.9)*0.045),vec2(0.014)));}
 c=mix(c,vec3(0.96,0.74,0.33),clamp(dots,0.0,1.0));
 if(motif==1){float lines=1.0-smoothstep(0.0,0.045,abs(sin(p.y*48.0+p.x*7.0)));c=mix(c,blue,lines*0.16);}
 ALBEDO=c;ROUGHNESS=0.90;
}
