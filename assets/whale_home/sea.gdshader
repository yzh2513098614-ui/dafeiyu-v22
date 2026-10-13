shader_type spatial;
render_mode unshaded;
uniform float night_weight = 0.0;
varying vec2 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
 float broad=sin(p.y*.24+sin(p.x*.18)-TIME*.12);
 float line=smoothstep(.91,.99,sin(p.y*2.4+sin(p.x*.7)*.55-TIME*.35));
 float broken=smoothstep(.20,.78,sin(p.x*1.15+p.y*.16));
 vec3 sea=mix(vec3(.53,.75,.70),vec3(.66,.84,.80),broad*.5+.5);
 sea=mix(sea,vec3(.88,.95,.90),line*broken*.38);
 ALBEDO=mix(sea,sea*vec3(.21,.32,.49),night_weight*.82);
}
