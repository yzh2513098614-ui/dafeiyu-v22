shader_type canvas_item;
render_mode unshaded;
uniform sampler2D atlas_image : source_color, filter_linear;
uniform vec4 region=vec4(0.0,0.0,1.0,1.0);
uniform vec4 source_border=vec4(.1,.2,.1,.2);
uniform vec4 border_pixels=vec4(16.0);
uniform vec2 view_size=vec2(200.0,70.0);
uniform vec4 surface_tint : source_color=vec4(1.0);
uniform float face_lighten=0.0;
uniform float state_gray=0.0;
uniform float state_lift=0.0;
varying vec4 inherited_tint;
void vertex(){inherited_tint=COLOR;}
float patch(float u,float extent,float near_px,float far_px,float near_uv,float far_uv){
 float a=min(near_px,extent*.45);
 float b=min(far_px,extent*.45);
 float p=u*extent;
 if(p<a){return p/max(a,.001)*near_uv;}
 if(p>extent-b){return 1.0-(extent-p)/max(b,.001)*far_uv;}
 return near_uv+(p-a)/max(extent-a-b,.001)*(1.0-near_uv-far_uv);
}
void fragment(){
 vec2 uv=vec2(patch(UV.x,view_size.x,border_pixels.x,border_pixels.z,source_border.x,source_border.z),
              patch(UV.y,view_size.y,border_pixels.y,border_pixels.w,source_border.y,source_border.w));
 vec4 surface=texture(atlas_image,region.xy+clamp(uv,vec2(.001),vec2(.999))*region.zw);
 vec2 edge=min(UV*view_size,(1.0-UV)*view_size);
 float interior=smoothstep(2.0,8.0,min(edge.x,edge.y));
 surface.rgb=mix(surface.rgb,vec3(.99,.99,.96),face_lighten*interior);
 float luminance=dot(surface.rgb,vec3(.2126,.7152,.0722));
 surface.rgb=mix(surface.rgb,vec3(luminance),state_gray);
 surface.rgb=mix(surface.rgb,vec3(.97),state_lift);
 // Retain the painted antialiasing while suppressing barely visible atlas speckles.
 COLOR=vec4(surface.rgb,surface.a*smoothstep(.06,.22,surface.a))*surface_tint*inherited_tint;
}

