class_name DifficultyConfig
extends Resource
## Parámetros de dificultad del generador de obstáculos. Valores en res://resources/difficulty_config.tres.

@export_group("Ritmo")
## Beats iniciales sin obstáculos (calentamiento).
@export var warmup_beats: int = 4
## Separación mínima entre filas, en beats.
@export var min_row_gap_beats: float = 1.0
## Tiempo mínimo de reacción (s) entre dos filas consecutivas. Se respeta aunque el tempo sea alto.
@export var min_reaction_time: float = 0.4
## Tiempo mínimo (s) que se le exige a un humano por cada carril que cambia entre filas.
@export var min_time_per_lane_move: float = 0.22
## Margen (s) extra que debe haber entre filas para permitir dos saltos seguidos.
@export var jump_margin: float = 0.05

@export_group("Densidad")
## Probabilidad de fila en un beat candidato al inicio.
@export_range(0.0, 1.0) var start_density: float = 0.7
## Probabilidad máxima de fila en un beat candidato.
@export_range(0.0, 1.0) var max_density: float = 0.95
## Compases hasta alcanzar la dificultad máxima.
@export var ramp_bars: int = 32

@export_group("Variedad")
## Nombre visible en el menú.
@export var display_name: String = "Normal"
## Probabilidad de que una fila bloquee dos carriles al inicio de la rampa.
@export_range(0.0, 1.0) var double_block_start: float = 0.45
## Probabilidad de que una fila bloquee dos carriles (al máximo de la rampa).
@export_range(0.0, 1.0) var double_block_probability: float = 0.75
## Probabilidad de que un bloqueo sea barrera baja (saltable) en vez de muro.
@export_range(0.0, 1.0) var low_probability: float = 0.35
## Progreso (0..1) a partir del cual aparecen filas en contratiempo (medio beat).
@export_range(0.0, 1.0) var offbeat_unlock_progress: float = 0.3
## Probabilidad de aceptar un contratiempo candidato una vez desbloqueado.
@export_range(0.0, 1.0) var offbeat_probability: float = 0.35

@export_group("Patrones especiales")
## Puerta de salto: muros en todos los carriles menos uno con barrera baja (hay que saltar sí o sí).
@export_range(0.0, 1.0) var jump_gate_probability: float = 0.14
## Probabilidad de que el hueco de la puerta de salto sea el carril central (si es alcanzable).
@export_range(0.0, 1.0) var jump_gate_center_bias: float = 0.7
## Barrera baja en los tres carriles (saltar sin importar el carril).
@export_range(0.0, 1.0) var full_low_probability: float = 0.06

@export_group("Terreno y obstáculos avanzados")
## De los bloqueos saltables: fracción que es hueco corto / abismo largo / plataforma elevada
## (el resto son barreras bajas).
@export_range(0.0, 1.0) var gap_probability: float = 0.0
@export_range(0.0, 1.0) var long_gap_probability: float = 0.0
@export_range(0.0, 1.0) var platform_probability: float = 0.0
## De los muros: fracción que es muro móvil (baila entre dos carriles al ritmo).
@export_range(0.0, 1.0) var mover_probability: float = 0.0
## Fila especial: abismo en todos los carriles (saltar sí o sí).
@export_range(0.0, 1.0) var full_gap_probability: float = 0.0
## Fila especial: rampa de impulso obligatoria + línea de muros que se sobrevuela.
@export_range(0.0, 1.0) var ramp_gate_probability: float = 0.0
## Probabilidad por compás de un tramo sin rieles (salirse del borde = caer).
@export_range(0.0, 1.0) var open_edge_probability: float = 0.0
## Probabilidad de que una fila traiga una gema sobre el camino posible.
@export_range(0.0, 1.0) var gem_probability: float = 0.0
