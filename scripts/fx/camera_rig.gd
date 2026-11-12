class_name CameraRig
extends Camera3D
## Cámara estable con seguimiento suave del cubo. FOV fijo: nada de zoom ni "latidos".
##
## Solo se traslada (la orientación se fija una vez), así la perspectiva no se deforma.
## El suavizado es exponencial e independiente de los FPS; es puramente visual, por eso
## puede usar delta sin romper la regla del ritmo (la jugabilidad no depende de la cámara).

var _game: GameConfig
var _base: Vector3 = Vector3.ZERO
var _target: Vector3 = Vector3.ZERO


func setup(game: GameConfig) -> void:
	_game = game
	_base = game.camera_offset
	position = _base
	look_at(Vector3(0.0, 0.0, -game.camera_look_ahead), Vector3.UP)
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = game.camera_fov
	far = game.view_distance + game.camera_far_margin
	_target = _base


## Conectado a PlayerController.moved.
func on_player_moved(player_position: Vector3, player_size: Vector3) -> void:
	if _game == null:
		return
	var height: float = maxf(player_position.y - player_size.y * 0.5, 0.0)
	_target = _base + Vector3(player_position.x * _game.camera_follow_x, height * _game.camera_follow_y, 0.0)


## Vuelve al encuadre base sin transición (reinicio, menú).
func snap_to_base() -> void:
	_target = _base
	position = _base


func _process(delta: float) -> void:
	if _game == null:
		return
	position = position.lerp(_target, 1.0 - exp(-_game.camera_smoothing * delta))
