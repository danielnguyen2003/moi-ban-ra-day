shader_type spatial;
// Mice drawn with one MultiMesh. INSTANCE_CUSTOM: x = phase, y = speed01, z = scared, w = ghost.
render_mode diffuse_toon, specular_disabled;
uniform vec4 shade_color : source_color = vec4(0.3, 0.28, 0.5, 1.0);
uniform vec4 rim_color : source_color = vec4(0.6, 0.8, 1.0, 1.0);
varying float v_ghost;
varying float v_angry;
varying vec3 v_col;
varying float v_mat;

void vertex() {
	float ph = INSTANCE_CUSTOM.x * 6.2831;
	float sp = INSTANCE_CUSTOM.y;
	float hop = abs(sin(TIME * (8.0 + 10.0 * sp) + ph));
	// bound gait: squash on landing, stretch in the air
	float sq = mix(1.0, 0.82 + 0.3 * hop, sp);
	VERTEX.y *= sq;
	VERTEX.z *= 2.0 - sq;
	VERTEX.y += hop * 0.12 * sp;
	// startled hops when a cat is close
	VERTEX.y += INSTANCE_CUSTOM.z * 0.18 * abs(sin(TIME * 13.0 + ph * 2.0));
	// tail (vertices behind the body) wiggles
	if (VERTEX.z > 0.32) {
		VERTEX.x += sin(TIME * 10.0 + ph + VERTEX.z * 6.0) * 0.08 * (VERTEX.z - 0.32) * 4.0;
	}
	// scared shiver
	VERTEX.x += sin(TIME * 70.0 + ph) * 0.015 * INSTANCE_CUSTOM.z;
	v_angry = step(1.5, INSTANCE_CUSTOM.w);
	v_ghost = INSTANCE_CUSTOM.w - 2.0 * v_angry;
	v_col = COLOR.rgb;
	v_mat = UV.x;
}

void fragment() {
	vec3 c = v_col;
	if (v_mat > 0.75) { c = mix(vec3(0.02), vec3(1.0, 0.15, 0.1), v_angry); } else if (v_mat > 0.25) { c = vec3(0.95, 0.55, 0.62); }
	ALBEDO = c;
	ROUGHNESS = 0.85;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = (v_mat > 0.75 ? mix(vec3(0.9) * 0.15, vec3(3.0, 0.3, 0.2), v_angry) : rim_color.rgb * rim * 0.6) + v_col * v_ghost * (0.6 + 0.4 * sin(TIME * 4.0));

}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float q = floor(ndl * 3.0 + 0.5) / 3.0;
	DIFFUSE_LIGHT += ALBEDO * mix(shade_color.rgb * 0.6, vec3(1.0), q) * LIGHT_COLOR * ATTENUATION / PI * 1.6;
}
