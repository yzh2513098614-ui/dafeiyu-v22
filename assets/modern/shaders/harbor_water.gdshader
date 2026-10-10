shader_type spatial;
render_mode unshaded;
uniform vec4 water_color : source_color = vec4(.47,.65,.70,1.);
uniform float night_weight=0.;
varying vec2 point;
float box_distance(vec2 p,vec2 center,vec2 half_size){vec2 q=abs(p-center)-half_size;return length(max(q,vec2(0.)))+min(max(q.x,q.y),0.);}
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
 vec2 p=point;float phase=p.y*2.7+sin(p.x*.55+TIME*.22)*.50-TIME*.28;
 float stripe=abs(sin(phase));float aa=max(fwidth(phase),.004);
 float glint=smoothstep(.977-aa,.995+aa,stripe);
 float shore=smoothstep(-21.,-18.,p.x);
 float edge=min(box_distance(p,vec2(-23.5,-6.),vec2(5.5,2.)),box_distance(p,vec2(-23.5,9.),vec2(5.5,2.)));
 edge=min(edge,box_distance(p,vec2(0.),vec2(18.,20.)));
 float ripple=sin(p.y*3.5+p.x*1.2-TIME*.38)*.045;
 float foam=(1.-smoothstep(.09,.28,abs(edge-.18-ripple)))*smoothstep(0.,.10,edge);
 foam*=.60+.40*sin(p.x*1.9+p.y*2.1+TIME*.20);
 vec3 base=water_color.rgb*(.88+.10*sin(p.x*.14+p.y*.08));
 base=mix(base,base*.77,shore*.20);
 base+=vec3(.09,.12,.11)*glint*.36;
 base=mix(base,vec3(.71,.83,.82),foam*.35);
 ALBEDO=mix(base,base*vec3(.27,.38,.53),night_weight*.70);
}
