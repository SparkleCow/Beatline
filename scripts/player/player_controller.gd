class_name PlayerController
extends Node3D
## Jugador: cambio de carril interpolado y salto parabólico.
##
## Toda la animación se evalúa con el tiempo de canción (RhythmClock.tick), igual que los
## obstáculos, para que la colisión sea coherente con la música aunque haya tirones de frames.
## Recibe órdenes por métodos conectados a señales de InputHandler; no conoce a otros sistemas.

signal moved(position: Vector3, size: Vector3)
signal lane_changed(lane: int)
signal jumped
signal landed

const PLAYER_COLOR: Color = Color(0.92, 0.92, 0.95)

var lane: int = 1
var alive: bool = true

var _game: GameConfig
var _jump_time: float = 0.5
var _song_time: float = 0.0
var _from_x: float = 0.0
var _to_x: float = 0.0
var _change_start: float = -INF
var _jump_start: float = -INF
var _buffered_jump_at: float = -INF
var _airborne: bool = false
var _mesh_instance: MeshInstance3D


func setup(game: GameConfig, bpm: float) -> void:
	_game = game
	_jump_time = RhythmClock.time_of_beat(game.jump_duration_beats, bpm)
	if _mesh_instance == null:
		_build_mesh()
	reset()


func reset() -> void:
	lane = _game.center_lane()
	alive = true
	_song_time = 0.0
	_from_x = _game.lane_x(lane)
	_to_x = _from_x
	_change_start = -INF
	_jump_start = -INF
	_buffered_jump_at = -INF
	_airborne = false
	position = Vector3(_from_x, _game.player_size.y * 0.5, 0.0)


func set_dead() -> void:
	alive = false


## Conectado a InputHandler.lane_change_requested.
func request_lane_change(direction: int) -> void:
	if not alive:
		return
	var target: int = clampi(lane + direction, 0, _game.lane_count - 1)
	if target == lane:
		return
	lane = target
	_from_x = position.x
	_to_x = _game.lane_x(lane)
	_change_start = _song_time
	lane_changed.emit(lane)


## Conectado a InputHandler.jump_requested.
func request_jump() -> void:
	if not alive:
		return
	if _airborne:
		_buffered_jump_at = _song_time
		return
	_start_jump()


## Conectado a RhythmClock.tick.
func on_tick(song_time: float) -> void:
	_song_time = song_time
	if not alive:
		return
	var x: float = _to_x
	if _game.lane_change_time > 0.0:
		var p: float = clampf((song_time - _change_start) / _game.lane_change_time, 0.0, 1.0)
		x = lerpf(_from_x, _to_x, ease_out(p))

	var y: float = 0.0
	if _airborne:
		var jp: float = (song_time - _jump_start) / _jump_time
		if jp >= 1.0:
			_airborne = false
			landed.emit()
			if song_time - _buffered_jump_at <= _game.jump_buffer_time:
				_start_jump()
		else:
			y = 4.0 * _game.jump_height * jp * (1.0 - jp)

	position = Vector3(x, y + _game.player_size.y * 0.5, 0.0)
	moved.emit(position, _game.player_size)


## Curva de salida cuadrática: rápida al inicio, suave al llegar.
static func ease_out(p: float) -> float:
	return 1.0 - (1.0 - p) * (1.0 - p)


func _start_jump() -> void:
	_airborne = true
	_jump_start = _song_time
	_buffered_jump_at = -INF
	jumped.emit()


func _build_mesh() -> void:
	var box := BoxMesh.new()
	box.size = _game.player_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLAYER_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Body"
	_mesh_instance.mesh = box
	_mesh_instance.material_override = mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
