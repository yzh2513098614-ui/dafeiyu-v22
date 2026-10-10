shader_type spatial;
render_mode unshaded,cull_disabled;
uniform int motif=0;
uniform float night_weight=0.;
void fragment(){
 vec2 p=UV;vec3 paper=vec3(.93,.89,.77);vec3 ink=vec3(.23,.43,.47);
 float line;
 if(motif==1 || motif==2){
  paper=mix(vec3(.57,.76,.78),vec3(.86,.91,.84),p.y);
  float horizon=smoothstep(.45,.47,p.y);
  paper=mix(paper,vec3(.49,.68,.73),horizon);
  paper=mix(paper,vec3(.15,.27,.36),night_weight*.85);
  for(int i=0;i<6;i++){
   float wave=.55+float(i)*.072+sin(p.x*8.+float(i)*.7)*.006;
   float line=1.-smoothstep(.001,.002+fwidth(p.y)*1.2,abs(p.y-wave));
   paper=mix(paper,mix(vec3(.77,.86,.83),vec3(.44,.59,.65),night_weight),line*.45);
  }
  float sun=(1.-smoothstep(.12,.13,length((p-vec2(.78,.27))*vec2(1.,1.4))))*(motif==1?1.:0.);
  paper=mix(paper,mix(vec3(.98,.87,.59),vec3(.77,.85,.85),night_weight),sun*.65);
 }else if(motif==3){
  float ring=abs(length((p-vec2(.5,.51))*vec2(1.,1.35))-.27);
  paper=mix(paper,ink,(1.-smoothstep(.008,.016,ring))*.8);
  for(int i=0;i<5;i++){
   float a=float(i)*1.2566+.3;
   vec2 center=vec2(.5,.51)+vec2(cos(a)*.20,sin(a)*.15);
   float leaf=1.-smoothstep(.052,.064,length((p-center)*vec2(1.,1.7)));
   paper=mix(paper,vec3(.48,.63,.53),leaf);
  }
  float centre=1.-smoothstep(.070,.078,length(p-vec2(.5,.51)));
  paper=mix(paper,vec3(.79,.43,.33),centre);
 }else{
  float curve=.56+sin(p.x*5.6+1.7)*.12;
  line=1.-smoothstep(.007,.016,abs(p.y-curve));
  paper=mix(paper,ink,line);
  float sun=1.-smoothstep(.13,.14,length(p-vec2(.70,.29)));
  paper=mix(paper,vec3(.79,.43,.33),sun);
  for(int i=0;i<4;i++){
   float y=.66+float(i)*.062+sin(p.x*5.6+1.7)*.08;
   line=1.-smoothstep(.004,.009,abs(p.y-y));
   paper=mix(paper,vec3(.52,.64,.57),line*.65);
  }
 }
 ALBEDO=paper;
}
