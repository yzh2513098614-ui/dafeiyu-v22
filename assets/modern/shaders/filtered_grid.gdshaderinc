// Integrate periodic stripes over the pixel's world-space footprint.
// A narrow seam contributes fractional coverage instead of switching on/off.
vec2 grid_stripe_integral(vec2 position, vec2 half_width) {
	vec2 cell = floor(position);
	vec2 part = position - cell;
	return cell * (2.0 * half_width) + min(part, half_width)
		+ max(part - (vec2(1.0) - half_width), vec2(0.0));
}

vec2 filtered_grid_axes(vec2 position, vec2 half_width) {
	vec2 footprint = max(fwidth(position), vec2(0.00001));
	vec2 area = grid_stripe_integral(position + footprint * 0.5, half_width)
		- grid_stripe_integral(position - footprint * 0.5, half_width);
	return clamp(area / footprint, vec2(0.0), vec2(1.0));
}
