shader_type canvas_item;
render_mode unshaded;
uniform sampler2D painting_image : source_color, filter_linear_mipmap, repeat_disable;
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
 vec2 atlas_uv=region.xy+painting_uv*region.zw;
 // Keep the minification footprint inside this card's atlas cell.
 vec2 inset=max(.5/vec2(textureSize(painting_image,0)),fwidth(atlas_uv));
 vec2 sample_uv=clamp(atlas_uv,region.xy+inset,region.xy+region.zw-inset);
 vec4 paint=textureGrad(painting_image,sample_uv,dFdx(atlas_uv),dFdy(atlas_uv));
 COLOR=vec4(paint.rgb,paint.a*(1.0-smoothstep(-.7,.7,d)))*painting_tint;
}
