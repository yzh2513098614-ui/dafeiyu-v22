shader_type spatial;
render_mode cull_disabled;
void vertex() {
    VERTEX.y += sin(VERTEX.x * 1.2 + TIME * 1.1) * 0.025 + cos(VERTEX.z * 1.7 - TIME * 0.8) * 0.018;
}
void fragment() {
    float ripple = sin(UV.x * 140.0 + sin(UV.y * 63.0 + TIME) + TIME * 1.8);
    ALBEDO = vec3(0.20,0.52,0.64) + vec3(0.025,0.035,0.04)*ripple + vec3(0.035)*pow(max(0.0,ripple),18.0);
    ROUGHNESS = 0.27;
    METALLIC = 0.15;
}
