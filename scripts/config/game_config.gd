class_name GameConfig
extends Resource
## Parámetros de juego: pista, jugador, obstáculos y cámara.
## Valores editables en res://resources/game_config.tres. Nada de números mágicos en los sistemas.

@export_group("Pista")
## Número de carriles.
@export var lane_count: int = 3
## Ancho de cada carril (unidades de mundo).
@export var lane_width: float = 2.0
## Distancia que avanza el mundo por beat. La velocidad real = units_per_beat * bpm / 60.
@export var units_per_beat: float = 9.0
## Largo de cada segmento reciclable de la pista.
@export var segment_length: float = 10.0
## Cantidad de segmentos en el pool (deben cubrir view_distance + lo que queda detrás de cámara).
@export var segment_count: int = 10
## Distancia hacia adelante a la que aparecen los obstáculos.
@export var view_distance: float = 70.0
## Distancia detrás del jugador a la que se reciclan obstáculos.
@export var despawn_distance: float = 8.0
## Grosor del piso de la pista.
@export var floor_thickness: float = 0.2
## Ancho de las líneas divisorias entre carriles.
@export var divider_width: float = 0.08

@export_group("Jugador")
## Tiempo (s) que tarda la interpolación de cambio de carril.
@export var lane_change_time: float = 0.11
## Altura máxima del salto.
@export var jump_height: float = 1.8
## Duración del salto medida en beats (se adapta al tempo del día).
@export var jump_duration_beats: float = 1.0
## Ventana (s) en la que un salto pedido antes de aterrizar se guarda y se ejecuta al tocar suelo.
@export var jump_buffer_time: float = 0.12
## Tamaño del cubo del jugador.
@export var player_size: Vector3 = Vector3(0.9, 0.9, 0.9)
## Fracción del ancho usada para colisión lateral (<1 perdona roces).
@export_range(0.5, 1.0) var collision_forgiveness: float = 0.85
## Fracción de la velocidad vertical que queda al soltar el salto mientras sube
## (toque corto = salto bajo). 1.0 desactiva el salto variable.
@export_range(0.3, 1.0) var jump_cut_factor: float = 0.7
## Desnivel máximo que el cubo "pisa" sin chocar al aterrizar (perdona bordes).
@export var step_tolerance: float = 0.3
## Profundidad bajo la pista a la que una caída cuenta como derrota.
@export var fall_death_depth: float = 3.0

@export_group("Obstáculos")
## Tamaño de un muro (hay que esquivarlo cambiando de carril).
@export var wall_size: Vector3 = Vector3(1.6, 1.6, 0.8)
## Tamaño de una barrera baja (se salta).
@export var low_size: Vector3 = Vector3(1.6, 0.5, 0.8)
## Obstáculos pre-instanciados en el pool.
@export var obstacle_pool_size: int = 48
## Largo (Z) de un hueco corto (se cruza con un toque) y de un abismo (salto completo).
@export var gap_short_length: float = 3.0
@export var gap_long_length: float = 7.0
## Grosor visual del panel de vacío.
@export var gap_panel_height: float = 0.06
## Plataforma elevada: hay que saltar (completo) para subirse; se recorre por arriba.
@export var platform_size: Vector3 = Vector3(1.9, 1.2, 9.0)
## Rampa de impulso (cuña) y el súper salto que provoca.
@export var ramp_size: Vector3 = Vector3(1.6, 0.5, 1.8)
@export var ramp_jump_height: float = 3.4
@export var ramp_jump_beats: float = 2.0
## Beats después de la rampa en que llega la línea de muros que se sobrevuela.
@export var ramp_wall_delay_beats: float = 1.0
## Gemas: tamaño, altura sobre el suelo y altura cuando van sobre un salto.
@export var gem_size: float = 0.55
@export var gem_ground_height: float = 0.7
@export var gem_jump_height: float = 1.3

@export_group("Cámara")
## Posición de la cámara relativa al jugador (detrás y arriba).
@export var camera_offset: Vector3 = Vector3(0.0, 5.0, 7.0)
## Punto hacia adelante al que mira la cámara.
@export var camera_look_ahead: float = 12.0
## Campo de visión horizontal (la cámara mantiene el ancho en vertical).
@export var camera_fov: float = 70.0
## Margen extra del plano lejano respecto a view_distance.
@export var camera_far_margin: float = 10.0
## Cuánto sigue la cámara al cubo en X / Y (0 = fija, 1 = pegada).
@export_range(0.0, 1.0) var camera_follow_x: float = 0.45
@export_range(0.0, 1.0) var camera_follow_y: float = 0.25
## Rapidez del suavizado exponencial de la cámara (1/s).
@export var camera_smoothing: float = 9.0

@export_group("Flujo")
## Tiempo mínimo (s) tras morir antes de aceptar reinicio, para evitar toques accidentales.
@export var restart_lockout: float = 0.3


## Velocidad del mundo en unidades por segundo para un tempo dado.
func scroll_speed(bpm: float) -> float:
	return units_per_beat * bpm / 60.0


## Coordenada X del centro de un carril.
func lane_x(lane: int) -> float:
	return (float(lane) - float(lane_count - 1) * 0.5) * lane_width


## Mitad del ancho total de la pista.
func track_half_width() -> float:
	return float(lane_count) * lane_width * 0.5


## Carril central (inicio del jugador).
func center_lane() -> int:
	return floori(float(lane_count - 1) * 0.5)
