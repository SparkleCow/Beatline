// Fondo Y2K / synthwave procedural: degradado, sol a franjas, destellos ✦ y scanlines.
// Va en un quad pegado a la cámara. Cero texturas.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled;

global uniform float beat_pulse;
global uniform float bar_index;

uniform vec4 top_color : source_color = vec4(0.02, 0.0, 0.07, 1.0);
uniform vec4 mid_color : source_color = vec4(0.32, 0.0, 0.42, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.2, 0.55, 1.0);
uniform vec4 sun_top : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform vec4 sun_bottom : source_color = vec4(1.0, 0.1, 0.65, 1.0);
uniform float horizon = 0.56;
uniform float sun_radius = 0.2;
uniform float aspect = 2.0;
// 0 = sol a franjas, 1 = eclipse (anillo), 2 = sin astro. Ver SkyPresets.
uniform int style = 0;
uniform float aurora = 0.0;
uniform float star_density = 0.18;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, horizon * 0.85, uv.y));
	col = mix(col, horizon_color.rgb, smoothstep(horizon * 0.75, horizon, uv.y));

	// Sol con franjas que bajan.
	vec2 sun_center = vec2(0.5, horizon - sun_radius * 1.25 / aspect);
	vec2 d = (uv - sun_center) * vec2(1.0, aspect);
	float r = sun_radius * (1.0 + beat_pulse * 0.04);
	float sun = 1.0 - smoothstep(r - 0.004, r, length(d));
	if (style == 1) {
		sun *= smoothstep(r * 0.80, r * 0.86, length(d));
	} else if (style == 2) {
		sun = 0.0;
	}
	float lower = smoothstep(-0.06, 0.02, d.y);
	float stripes = step(0.62, fract(uv.y * 55.0 - TIME * 0.6)) * lower;
	vec3 sun_col = mix(sun_top.rgb, sun_bottom.rgb, clamp(d.y / r * 0.5 + 0.5, 0.0, 1.0)) * 2.2;
	col = mix(col, sun_col, sun * (1.0 - stripes));
	// Halo del sol.
	col += sun_bottom.rgb * (style == 2 ? 0.0 : 0.35) * exp(-length(d) * 6.0) * (1.0 + beat_pulse);

	// Aurora: cortinas onduladas sobre el horizonte.
	if (aurora > 0.0 && uv.y < horizon) {
		float wave = sin(uv.x * 9.0 + TIME * 0.5) * 0.04 + sin(uv.x * 23.0 - TIME * 0.8) * 0.015;
		float band = exp(-abs(uv.y - (horizon * 0.55 + wave)) * 14.0);
		float curtain = 0.6 + 0.4 * sin(uv.x * 60.0 + TIME * 1.5);
		col += mix(sun_top.rgb, horizon_color.rgb, uv.x) * band * curtain * aurora * (0.8 + beat_pulse * 0.5);
	}

	// Destellos de 4 puntas (✦), titilan.
	vec2 g = uv * vec2(9.0, 9.0 * aspect);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	if (h > 1.0 - star_density && uv.y < horizon - 0.05) {
		f += (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.5;
		float tw = 0.5 + 0.5 * sin(TIME * 3.0 + h * 60.0);
		float star = 0.0025 / (abs(f.x * f.y) + 0.0025);
		star *= 1.0 - smoothstep(0.0, 0.35, length(f));
		vec3 star_col = mix(vec3(0.6, 1.0, 1.0), vec3(1.0, 0.6, 1.0), hash(id + 1.3));
		col += star_col * star * tw * 1.6;
	}

	// Scanlines CRT suaves.
	col *= 0.88 + 0.12 * sin(uv.y * 900.0);
	ALBEDO = col;
}
