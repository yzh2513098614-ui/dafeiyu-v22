shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Deterministic video-matte cleanup. Keep RGB inside the silhouette unchanged.
uniform float radius = 2.0;
void fragment() {
 vec4 paint=texture(TEXTURE,UV);
 vec2 step=TEXTURE_PIXEL_SIZE*radius;
 float coverage=paint.a;
 coverage=min(coverage,texture(TEXTURE,UV+vec2(step.x,0.0)).a);
 coverage=min(coverage,texture(TEXTURE,UV-vec2(step.x,0.0)).a);
 coverage=min(coverage,texture(TEXTURE,UV+vec2(0.0,step.y)).a);
 coverage=min(coverage,texture(TEXTURE,UV-vec2(0.0,step.y)).a);
 coverage=min(coverage,texture(TEXTURE,UV+step).a);
 coverage=min(coverage,texture(TEXTURE,UV-step).a);
 coverage=min(coverage,texture(TEXTURE,UV+vec2(step.x,-step.y)).a);
 coverage=min(coverage,texture(TEXTURE,UV+vec2(-step.x,step.y)).a);
 COLOR=vec4(paint.rgb,coverage);
}
