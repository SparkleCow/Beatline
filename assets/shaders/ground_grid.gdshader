// Suelo infinito synthwave alrededor de la pista. Se desplaza con world_scroll (reloj de audio).
shader_type spatial;
render_mode unshaded;

global uniform float beat_pulse;
global uniform float world_scroll;

uniform vec4 base_color : source_color = vec4(0.04, 0.0, 0.08, 1.0);
uniform vec4 line_color : source_color = vec4(0.62, 0.25, 1.0, 1.0);
uniform float spacing = 4.0;
uniform float line_width = 0.08;
uniform float glow = 1.6;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float line(float coord, float width) {
	float dist = abs(fract(coord / spacing + 0.5) - 0.5) * spacing;
	float aa = fwidth(coord) + 0.0001;
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + aa, dist);
}

void fragment() {
	float g = max(line(world_pos.x, line_width), line(world_pos.z - world_scroll, line_width));
	ALBEDO = base_color.rgb + line_color.rgb * g * glow * (1.0 + beat_pulse * 0.6);
}
