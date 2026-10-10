shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth_color : source_color=vec4(.73,.81,.73,1.);
varying vec3 world_point;
void vertex(){
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 float free_edge=UV.y*UV.y;
 VERTEX.z+=sin(TIME*1.5+world_point.x*.55+UV.y*3.0)*free_edge*.11;
 VERTEX.x+=sin(TIME*.65+world_point.x*.8)*free_edge*.025;
}
void fragment(){
 float fiber=sin(UV.x*90.)*sin(UV.y*76.)*.012;
 ALBEDO=cloth_color.rgb*(.98+fiber);ROUGHNESS=.89;
}
