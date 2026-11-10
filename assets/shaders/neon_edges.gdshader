// Caja neón: relleno oscuro + aristas brillantes (estilo Tron/Y2K). Late con el beat.
shader_type spatial;
render_mode unshaded, cull_back;

global uniform float beat_pulse;

uniform vec3 half_size = vec3(0.8, 0.8, 0.4);
uniform vec4 edge_color : source_color = vec4(1.0, 0.16, 0.72, 1.0);
uniform float fill_strength = 0.18;
uniform float edge_width = 0.13;
uniform float glow = 3.0;
uniform float pulse_amount = 0.8;
// 1.0 = franjas diagonales tipo barrera en el relleno.
uniform float stripes = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 d = half_size - abs(local_pos);
	float a = min(d.x, min(d.y, d.z));
	float c = max(d.x, max(d.y, d.z));
	float b = d.x + d.y + d.z - a - c;
	float edge = 1.0 - smoothstep(edge_width * 0.5, edge_width, b);
	float stripe = stripes * step(0.5, fract((local_pos.x + local_pos.y) * 2.0));
	vec3 fill = edge_color.rgb * (fill_strength + stripe * 0.5);
	vec3 bright = edge_color.rgb * glow * (1.0 + beat_pulse * pulse_amount);
	ALBEDO = mix(fill, bright, edge);
}
