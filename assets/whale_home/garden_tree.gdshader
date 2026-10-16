shader_type spatial;
render_mode world_vertex_coords, diffuse_lambert, specular_schlick_ggx;
#include "res://assets/whale_home/garden_wind.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.65, 0.75, 0.5, 1.0);
uniform bool foliage = true;
uniform vec3 tree_origin = vec3(0.0, 0.06, 0.0);
uniform float tree_response = 1.0;
varying vec3 plant_point;

void vertex() {
	vec3 rest = VERTEX;
	vec3 local = rest - tree_origin;
	float height = max(local.y - 0.25, 0.0);
	// Sample once at the tree root so the whole crown receives one coherent force.
	float breeze = garden_breeze(tree_origin.xz) * tree_response;
	float phase = dot(tree_origin.xz, vec2(0.13, 0.19));
	float flex = breeze * (0.82 + 0.22 * sin(wind_clock * 0.93 + phase) + 0.07 * sin(wind_clock * 1.67 + phase));
	// Identical trunk/crown bending keeps branch junctions connected; roots stay fixed.
	vec2 crosswind = vec2(-wind_direction.y, wind_direction.x);
	vec3 bent = local;
	bent.xz += wind_direction * height * height * 0.014 * flex;
	bent.xz += crosswind * height * height * 0.0018 * breeze * sin(wind_clock * 0.75 + phase);
	bent *= length(local) / max(length(bent), 0.001);
	VERTEX = tree_origin + bent;
	NORMAL.y -= dot(NORMAL.xz, wind_direction) * height * 0.028 * flex;
	if (foliage) {
		float flutter = sin(wind_clock * 1.9 + dot(local, vec3(1.1, 0.8, 0.7)) + phase);
		VERTEX.xz += crosswind * flutter * breeze * 0.025;
		VERTEX.y += sin(wind_clock * 1.5 + phase + local.x * 0.7) * breeze * 0.018;
	}
	NORMAL = normalize(NORMAL);
	plant_point = rest;
}

void fragment() {
	float variation = sin(dot(plant_point, vec3(0.73, 0.57, 0.41))) * 0.022;
	ALBEDO = base_color.rgb * COLOR.rgb * (1.0 + (foliage ? variation : 0.0));
	if (foliage) EMISSION = base_color.rgb * 0.025;
	ROUGHNESS = 0.95;
	SPECULAR = 0.06;
}
