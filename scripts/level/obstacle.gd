class_name Obstacle
extends MeshInstance3D
## Un obstáculo reciclable. Lo administra ObstacleSpawner (pool); nunca se libera en juego.
## Su posición Z la calcula el spawner desde el reloj de audio, no se mueve sola.

var lane: int = 0
var kind: int = LevelPattern.Kind.EMPTY
## Momento (s de canción) en que el obstáculo cruza al jugador.
var hit_time: float = 0.0
var size: Vector3 = Vector3.ONE
var active: bool = false


func activate(p_lane: int, p_kind: int, p_hit_time: float, p_size: Vector3, x: float,
		p_mesh: Mesh, p_material: Material) -> void:
	lane = p_lane
	kind = p_kind
	hit_time = p_hit_time
	size = p_size
	mesh = p_mesh
	material_override = p_material
	position = Vector3(x, p_size.y * 0.5, 0.0)
	active = true
	visible = true


func deactivate() -> void:
	active = false
	visible = false
