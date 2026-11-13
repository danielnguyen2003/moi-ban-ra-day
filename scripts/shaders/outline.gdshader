shader_type spatial;
// Inverted-hull ink outline (used as next_pass). Width in world units, scaled down with distance a bit.
render_mode unshaded, cull_front, depth_draw_opaque;
uniform vec4 line_color : source_color = vec4(0.06, 0.04, 0.1, 1.0);
uniform float width = 0.035;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
