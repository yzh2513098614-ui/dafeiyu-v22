shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
uniform vec4 light_color : source_color = vec4(0.3,0.65,0.75,0.25);
uniform float phase = 0.0;
void fragment() {
    vec2 p=UV*2.0-1.0;
    float d=length(p);
    float edge=(1.0-smoothstep(0.72,1.0,d));
    float wave = sin(d*55.0-TIME*3.0+phase)*0.055;
    float stripe = 0.68+0.32*sin(UV.y*67.0+sin(UV.x*22.0+TIME)*0.9);
    ALBEDO=light_color.rgb*(0.72+stripe*0.28+wave);
    ALPHA=light_color.a*edge*stripe;
}
