class_name SkyPresets
extends RefCounted
## Fondos Y2K: variantes del shader del cielo (paleta + astro + aurora). Cada semilla
## tiene el suyo, así cada día y cada nivel se ven distintos. Sin texturas.

## `style`: 0 = sol a franjas, 1 = eclipse (anillo), 2 = sin astro.
const PRESETS: Array[Dictionary] = [
	{  # Atardecer synthwave (el original).
		&"top_color": Color(0.02, 0.0, 0.07), &"mid_color": Color(0.32, 0.0, 0.42),
		&"horizon_color": Color(1.0, 0.2, 0.55), &"sun_top": Color(1.0, 0.85, 0.2),
		&"sun_bottom": Color(1.0, 0.1, 0.65), &"style": 0, &"aurora": 0.0, &"star_density": 0.18,
	},
	{  # Hielo cibernético con eclipse.
		&"top_color": Color(0.0, 0.01, 0.06), &"mid_color": Color(0.0, 0.12, 0.35),
		&"horizon_color": Color(0.1, 0.9, 1.0), &"sun_top": Color(0.8, 1.0, 1.0),
		&"sun_bottom": Color(0.2, 0.5, 1.0), &"style": 1, &"aurora": 0.0, &"star_density": 0.3,
	},
	{  # Tóxico: verde ácido sobre negro, con aurora.
		&"top_color": Color(0.0, 0.03, 0.01), &"mid_color": Color(0.02, 0.2, 0.08),
		&"horizon_color": Color(0.65, 1.0, 0.15), &"sun_top": Color(0.9, 1.0, 0.3),
		&"sun_bottom": Color(0.1, 0.8, 0.3), &"style": 0, &"aurora": 0.7, &"star_density": 0.12,
	},
	{  # Luna de sangre: anillo rojo, casi sin estrellas.
		&"top_color": Color(0.03, 0.0, 0.0), &"mid_color": Color(0.25, 0.0, 0.04),
		&"horizon_color": Color(1.0, 0.1, 0.1), &"sun_top": Color(1.0, 0.5, 0.2),
		&"sun_bottom": Color(0.9, 0.0, 0.1), &"style": 1, &"aurora": 0.0, &"star_density": 0.08,
	},
	{  # Vaporwave pastel: solo aurora y muchas estrellas.
		&"top_color": Color(0.08, 0.02, 0.2), &"mid_color": Color(0.45, 0.2, 0.6),
		&"horizon_color": Color(0.4, 1.0, 0.85), &"sun_top": Color(1.0, 0.7, 0.9),
		&"sun_bottom": Color(0.5, 0.9, 1.0), &"style": 2, &"aurora": 1.0, &"star_density": 0.4,
	},
]

## Semillas con fondo fijo (niveles establecidos).
static var _assigned: Dictionary[int, int] = {}


static func assign(level_seed: int, index: int) -> void:
	_assigned[level_seed] = index


static func index_for(level_seed: int) -> int:
	return _assigned.get(level_seed, posmod(level_seed, PRESETS.size()))


static func apply(material: ShaderMaterial, level_seed: int) -> void:
	var preset: Dictionary = PRESETS[posmod(index_for(level_seed), PRESETS.size())]
	for key: StringName in preset:
		material.set_shader_parameter(key, preset[key])
