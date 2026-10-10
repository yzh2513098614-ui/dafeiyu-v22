// Match the video's painted palette, before real scene illumination.
// Alpha, native textures and pose geometry are never changed by this pass.
uniform bool palette_match_enabled = false;
uniform vec3 hair_palette_gamma = vec3(1.0);
uniform vec3 skin_palette_gamma = vec3(1.0);
uniform float hair_palette_strength : hint_range(0.0,1.0) = 0.0;
uniform float skin_palette_strength : hint_range(0.0,1.0) = 0.0;

vec3 matched_character_pigment(vec2 source_uv, vec3 pigment) {
 if (!palette_match_enabled) { return pigment; }
 // Select blue hair above the costume, excluding near-black ink and whites.
 // A smooth colour/height mask stays consistent across the whole video cycle.
 float blue = smoothstep(.014,.070,pigment.b-max(pigment.r,pigment.g));
 float coloured_hair = smoothstep(.022,.075,pigment.b);
 float head_area = 1.0-smoothstep(hair_split.x,hair_split.y,source_uv.y);
 float hair = blue*coloured_hair*head_area;
 float warm = smoothstep(.024,.085,pigment.r-pigment.b);
 float skin = warm*smoothstep(.015,.045,pigment.r-pigment.g)
             *smoothstep(.18,.32,pigment.g)*smoothstep(.15,.28,pigment.b);
 vec3 hair_colour = pow(max(pigment,vec3(0.00001)),hair_palette_gamma);
 vec3 skin_colour = pow(max(pigment,vec3(0.00001)),skin_palette_gamma);
 vec3 result = mix(pigment,hair_colour,hair*hair_palette_strength);
 return mix(result,skin_colour,skin*skin_palette_strength);
}
