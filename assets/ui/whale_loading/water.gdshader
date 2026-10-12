shader_type canvas_item;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform float animation_time = 0.0;

void fragment() {
 vec2 size=vec2(994.0,86.0);
 vec2 p=(UV-.5)*size;
 vec2 q=abs(p)-(size*.5-vec2(43.0));
 float distance=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-43.0;
 float mask=1.0-smoothstep(-1.0,1.0,distance);
 float width=progress*size.x;
 float radius=min(43.0,width*.5);
 vec2 fill_point=vec2(UV.x*size.x-width*.5,p.y);
 vec2 fill_q=abs(fill_point)-(vec2(width*.5,43.0)-vec2(radius));
 float fill_distance=length(max(fill_q,vec2(0.0)))+min(max(fill_q.x,fill_q.y),0.0)-radius;
 float filled=(1.0-smoothstep(-1.0,1.0,fill_distance))*step(.001,progress);
 float wave=.59+sin(UV.x*24.0-animation_time*3.0)*.055+sin(UV.x*41.0+animation_time*2.0)*.023;
 vec3 liquid=mix(vec3(.29,.88,1.0),vec3(.05,.50,1.0),UV.y);
 liquid=mix(liquid,vec3(.05,.48,.98),smoothstep(wave-.015,wave+.015,UV.y)*.65);
 float gloss=(1.0-smoothstep(.07,.39,UV.y))*.44;
 liquid=mix(liquid,vec3(.83,1.0,1.0),gloss);
 float sweep=pow(max(0.0,1.0-abs(UV.x-fract(animation_time*.34))*9.0),3.0)*.20;
 liquid+=sweep;
 for(int i=0;i<5;i++) {
  float index=float(i);
  vec2 center=vec2(fract(index*.193+animation_time*(.027+index*.007)),.53+sin(animation_time*1.7+index*2.0)*.22);
  float bubble=1.0-smoothstep(5.0,8.0,length((UV-center)*size));
  liquid=mix(liquid,vec3(.91,1.0,1.0),bubble*.52);
 }
 COLOR=vec4(mix(vec3(.87,.90,.96),liquid,filled),mask);
}
