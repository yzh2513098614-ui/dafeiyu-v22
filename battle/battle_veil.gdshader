shader_type canvas_item;
render_mode unshaded;
void fragment(){
 float bottom=smoothstep(.48,1.,UV.y)*.12;
 float top=(1.-smoothstep(.0,.26,UV.y))*.08;
 COLOR=vec4(.86,.92,.94,max(bottom,top));
}
