shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_lambert, specular_schlick_ggx;
#include "res://assets/whale_home/garden_wind.gdshaderinc"

void vertex() {
	float tip = pow(UV.y, 1.7);
	float breeze = garden_breeze(VERTEX.xz);
	float flutter = sin(wind_clock * 3.2 + dot(VERTEX.xz, vec2(1.7, -1.3)));
	vec2 crosswind = vec2(-wind_direction.y, wind_direction.x);
	VERTEX.xz += (wind_direction * 0.13 + crosswind * flutter * 0.035) * tip * breeze;
	VERTEX.y -= tip * breeze * 0.025;
	NORMAL = normalize(NORMAL + vec3(wind_direction.x, 0.0, wind_direction.y) * tip * breeze * 0.35);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.04;
}
