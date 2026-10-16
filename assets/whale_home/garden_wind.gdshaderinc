uniform vec2 wind_direction = vec2(0.883, -0.469);
uniform float wind_strength = 0.48;
uniform float wind_clock = 0.0;
uniform vec2 wind_field_center = vec2(-40.51, 17.92);
uniform vec2 wind_field_half_size = vec2(22.0, 17.0);
uniform float wind_background = 0.10;

// One directional wind region moves through the garden, with a soft edge.
float garden_breeze(vec2 point) {
	vec2 offset = point - wind_field_center;
	vec2 crosswind = vec2(-wind_direction.y, wind_direction.x);
	float along = abs(dot(offset, wind_direction)) / wind_field_half_size.x;
	float across = abs(dot(offset, crosswind)) / wind_field_half_size.y;
	float region = (1.0 - smoothstep(0.55, 1.0, along)) * (1.0 - smoothstep(0.45, 1.0, across));
	float ripple = 0.92 + 0.08 * sin(dot(point, wind_direction) * 0.20 - wind_clock * 1.1);
	return wind_background + wind_strength * region * ripple;
}
