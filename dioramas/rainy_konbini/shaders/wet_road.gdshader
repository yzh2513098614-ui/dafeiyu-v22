shader_type spatial;
uniform vec4 asphalt : source_color = vec4(0.075,0.115,0.19,1.0);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
    float grain = hash(floor(world.xz*110.0));
    float shimmer = sin(world.z*28.0+TIME*1.3)*sin(world.x*23.0-TIME*0.7);
    ALBEDO = asphalt.rgb * (0.91+grain*0.15);
    ROUGHNESS = 0.18 + shimmer*0.035;
    METALLIC = 0.28;
    SPECULAR = 0.85;
}
