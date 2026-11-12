// Color neón sólido que late con el beat (rieles, arcos, partículas).
shader_type spatial;
render_mode unshaded, cull_disabled;

global uniform float beat_pulse;

uniform vec4 color : source_color = vec4(0.1, 0.95, 1.0, 1.0);
uniform float glow = 2.5;
uniform float pulse_amount = 1.2;

void fragment() {
	ALBEDO = color.rgb * glow * (1.0 + beat_pulse * pulse_amount);
}
