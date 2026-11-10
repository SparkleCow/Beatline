// Piso de la pista: oscuro con líneas de carril cian y líneas transversales magenta.
// Usa coordenadas locales del segmento, así se mueve con él (sin tiempo propio).
shader_type spatial;
render_mode unshaded;

global uniform float beat_pulse;

uniform vec4 base_color : source_color = vec4(0.03, 0.0, 0.07, 1.0);
uniform vec4 lane_color : source_color = vec4(0.1, 0.95, 1.0, 1.0);
uniform vec4 cross_color : source_color = vec4(1.0, 0.16, 0.72, 1.0);
uniform float lane_width = 2.0;
uniform float lane_count = 3.0;
uniform float cross_spacing = 2.5;
uniform float line_width = 0.07;
uniform float glow = 2.5;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float line(float coord, float spacing, float width) {
	float dist = abs(fract(coord / spacing + 0.5) - 0.5) * spacing;
	float aa = fwidth(coord) + 0.0001;
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + aa, dist);
}

void fragment() {
	float half_w = lane_width * lane_count * 0.5;
	float lanes = line(local_pos.x + half_w, lane_width, line_width);
	float cross = line(local_pos.z, cross_spacing, line_width * 0.6);
	vec3 col = base_color.rgb;
	col += cross_color.rgb * cross * (0.5 + beat_pulse * 1.5);
	col += lane_color.rgb * lanes * glow;
	ALBEDO = col;
}
