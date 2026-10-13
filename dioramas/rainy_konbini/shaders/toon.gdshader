shader_type spatial;
render_mode specular_toon;
uniform vec4 ink_color : source_color = vec4(0.6,0.7,0.8,1.0);
uniform float glow = 0.0;
uniform float surface_roughness = 0.7;
void fragment() {
    ALBEDO = ink_color.rgb;
    ROUGHNESS = surface_roughness;
    SPECULAR = 0.25;
    EMISSION = ink_color.rgb * glow;
}
void light() {
    float n = dot(NORMAL, LIGHT);
    float band = mix(0.24, 0.66, smoothstep(0.12,0.18,n));
    band = mix(band, 1.0, smoothstep(0.64,0.70,n));
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * band * ATTENUATION / PI;
}
