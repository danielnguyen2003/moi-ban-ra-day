shader_type spatial;
// Additive glow for VFX meshes (slashes, rings, fireballs). Fades with `alpha` and a soft edge on UV.y.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float alpha = 1.0;
uniform float energy = 2.0;
uniform float edge_soft = 1.0;   // 1 = fade towards UV.y edges (ribbons), 0 = flat
void fragment() {
	float e = mix(1.0, sin(UV.y * 3.14159), edge_soft);
	ALBEDO = color.rgb * energy * e * alpha;
}
