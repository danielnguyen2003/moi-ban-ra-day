shader_type canvas_item;
// Film grain + vignette + heartbeat pulse that tightens the vignette as fear rises.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float fear : hint_range(0.0, 1.0) = 0.0;
uniform float time_s = 0.0;
uniform float grain_amount = 0.045;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	// Faint chromatic split under fear.
	float ca = 0.0015 * fear;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;
	// Heartbeat: two quick pulses per beat, faster with fear.
	float bpm = mix(60.0, 140.0, fear);
	float ph = fract(time_s * bpm / 60.0);
	float beat = exp(-pow((ph - 0.05) * 30.0, 2.0)) + 0.6 * exp(-pow((ph - 0.22) * 30.0, 2.0));
	float r = length((uv - 0.5) * vec2(1.6, 1.0));
	float vig_start = mix(0.75, 0.42, fear) - beat * 0.05 * fear;
	float vig = smoothstep(vig_start + 0.5, vig_start, r);
	col *= mix(0.15, 1.0, vig);
	float g = hash(uv * vec2(1920.0, 1080.0) + fract(time_s * 24.0) * 100.0) - 0.5;
	col += g * grain_amount;
	COLOR = vec4(col, 1.0);
}
