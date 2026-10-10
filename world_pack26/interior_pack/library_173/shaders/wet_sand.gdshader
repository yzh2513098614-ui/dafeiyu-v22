shader_type spatial;

uniform vec4 dry_color : source_color = vec4(0.902, 0.827, 0.667, 1.0);
uniform vec4 wet_color : source_color = vec4(0.62, 0.57, 0.45, 1.0);
uniform float wet_reference = 0.18;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float wetness = 1.0 - smoothstep(wet_reference - 0.045, wet_reference + 0.11, local_position.y);
	// Broad sand bands remain legible at the RPG's camera distance.
	float sand_band = sin(local_position.x * 0.9 + local_position.z * 3.0) * 0.009;
	ALBEDO = mix(dry_color.rgb, wet_color.rgb, wetness * 0.8) + vec3(sand_band);
	ROUGHNESS = mix(0.94, 0.5, wetness);
	SPECULAR = mix(0.12, 0.30, wetness);
}
