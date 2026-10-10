shader_type canvas_item;
render_mode unshaded;
void fragment(){
 // Remove low-alpha generator speckles, retaining the soft solid silhouette.
 // CanvasItem's fragment COLOR already contains the sampled texture.
 COLOR.a=smoothstep(.18,.65,COLOR.a);
}
