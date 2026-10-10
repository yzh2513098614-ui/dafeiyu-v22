shader_type canvas_item;
render_mode unshaded;
uniform sampler2D painting_image : source_color, filter_linear;
uniform vec4 region = vec4(0.0, 0.0, .25, .25);
uniform vec2 view_size = vec2(126.0,112.0);
uniform vec2 painting_crop = vec2(1.0);
varying vec4 painting_tint;
void vertex(){ painting_tint=COLOR; }
void fragment(){
 vec2 p=UV*view_size-view_size*.5;
 vec2 q=abs(p)-(view_size*.5-vec2(9.0));
 float d=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-9.0;
 vec2 painting_uv=(UV-.5)*painting_crop+.5;
 vec4 paint=texture(painting_image,region.xy+clamp(painting_uv,vec2(.002),vec2(.998))*region.zw);
 COLOR=vec4(paint.rgb,paint.a*(1.0-smoothstep(-.7,.7,d)))*painting_tint;
}
