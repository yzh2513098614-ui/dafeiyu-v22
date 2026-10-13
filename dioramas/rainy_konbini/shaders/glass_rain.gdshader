shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.36,0.69,0.74,0.10);
void fragment() {
    vec2 uv = UV;
    float lane = floor(uv.x * 36.0);
    float seed = fract(sin(lane*31.79)*937.5);
    float x = abs(fract(uv.x*36.0)-0.5);
    float fall = fract(uv.y*1.4 + TIME*(0.09+seed*0.14)+seed);
    float streak = (1.0-smoothstep(0.03,0.12,x))*(1.0-smoothstep(0.0,0.26,fall));
    ALBEDO = mix(tint.rgb,vec3(0.68,0.85,0.89),streak*0.5);
    ALPHA = tint.a+streak*0.18;
    ROUGHNESS = 0.16;
    SPECULAR = 0.65;
}
