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
@export var units_per_beat: float = 7.0
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

@export_group("Obstáculos")
## Tamaño de un muro (hay que esquivarlo cambiando de carril).
@export var wall_size: Vector3 = Vector3(1.6, 1.6, 0.8)
## Tamaño de una barrera baja (se salta).
@export var low_size: Vector3 = Vector3(1.6, 0.5, 0.8)
## Obstáculos pre-instanciados en el pool.
@export var obstacle_pool_size: int = 48

@export_group("Cámara")
## Posición de la cámara relativa al jugador (detrás y arriba).
@export var camera_offset: Vector3 = Vector3(0.0, 5.0, 7.0)
## Punto hacia adelante al que mira la cámara.
@export var camera_look_ahead: float = 12.0
## Campo de visión horizontal (la cámara mantiene el ancho en vertical).
@export var camera_fov: float = 70.0
## Margen extra del plano lejano respecto a view_distance.
@export var camera_far_margin: float = 10.0

@export_group("Flujo")
## Tiempo mínimo (s) tras morir antes de aceptar reinicio, para evitar toques accidentales.
@export var restart_lockout: float = 0.3


## Velocidad del mundo en unidades por segundo para un tempo dado.
func scroll_speed(bpm: float) -> float:
	return units_per_beat * bpm / 60.0


## Coordenada X del centro de un carril.
func lane_x(lane: int) -> float:
	return (float(lane) - float(lane_count - 1) * 0.5) * lane_width


## Carril central (inicio del jugador).
func center_lane() -> int:
	return floori(float(lane_count - 1) * 0.5)
