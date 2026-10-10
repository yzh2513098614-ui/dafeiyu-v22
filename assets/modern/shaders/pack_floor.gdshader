shader_type spatial;
#include "res://assets/modern/shaders/filtered_grid.gdshaderinc"

uniform vec4 tile_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec2 tile_size = vec2(2.0);
uniform vec2 tile_origin = vec2(0.0);
uniform vec2 line_axes = vec2(1.0);
uniform float roughness_value = 0.76;
varying vec2 world_position;
varying float top_face;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	top_face = max(NORMAL.y, 0.0);
}

void fragment() {
	vec2 coordinates = (world_position - tile_origin) / tile_size;
	vec2 lines = filtered_grid_axes(coordinates, vec2(0.006) / tile_size) * line_axes;
	float grout = lines.x + lines.y - lines.x * lines.y;
	ALBEDO = tile_color.rgb * (1.0 - grout * top_face * 0.24);
	ROUGHNESS = roughness_value;
	SPECULAR = 0.08;
}
