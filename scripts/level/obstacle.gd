class_name Obstacle
extends MeshInstance3D
## Un obstáculo (o gema) reciclable. Lo administra ObstacleSpawner (pool); nunca se libera
## en juego. Su posición la calcula el spawner desde el reloj de audio, no se mueve solo.

## Tipo extra (fuera de LevelPattern.Kind) para las gemas, que comparten pool.
const KIND_GEM: int = 100

var lane: int = 0
var kind: int = LevelPattern.Kind.EMPTY
## Momento (s de canción) en que el centro del obstáculo cruza al jugador.
var hit_time: float = 0.0
var size: Vector3 = Vector3.ONE
var active: bool = false
## Muro móvil: X de reposo final y X del carril vecino entre los que baila.
var to_x: float = 0.0
var from_x: float = 0.0
## Ya disparó su efecto (rampa pisada).
var triggered: bool = false


func activate(p_lane: int, p_kind: int, p_hit_time: float, p_size: Vector3, x: float,
		p_mesh: Mesh, p_material: Material, base_y: float = 0.0) -> void:
	lane = p_lane
	kind = p_kind
	hit_time = p_hit_time
	size = p_size
	mesh = p_mesh
	material_override = p_material
	position = Vector3(x, base_y + p_size.y * 0.5, 0.0)
	rotation = Vector3.ZERO
	to_x = x
	from_x = x
	triggered = false
	active = true
	visible = true


func deactivate() -> void:
	active = false
	visible = false
