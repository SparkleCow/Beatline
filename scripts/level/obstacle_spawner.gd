class_name ObstacleSpawner
extends Node3D
## Coloca obstáculos según LevelPattern y el reloj de audio.
##
## REGLA DE ORO: la posición de cada obstáculo es z = (song_time - hit_time) * velocidad.
## No hay movimiento acumulado con delta: si el audio se atrasa, el mundo se atrasa con él.
## Usa un pool pre-instanciado; nunca crea ni libera nodos durante la partida.

signal player_hit(lane: int, kind: int)

## Beats extra que se generan por delante de lo visible.
const GENERATION_MARGIN_BEATS: float = 8.0
const WALL_COLOR: Color = Color(0.55, 0.55, 0.58)
const LOW_COLOR: Color = Color(0.75, 0.75, 0.78)

var pattern: LevelPattern

var _game: GameConfig
var _difficulty: DifficultyConfig
var _level_seed: int = 0
var _bpm: float = 120.0
var _speed: float = 14.0
var _look_time: float = 5.0
var _pool: Array[Obstacle] = []
var _active: Array[Obstacle] = []
var _next_row: int = 0
var _player_position: Vector3 = Vector3.ZERO
var _player_size: Vector3 = Vector3.ONE
var _hit_emitted: bool = false
var _wall_mesh: BoxMesh
var _low_mesh: BoxMesh
var _wall_material: StandardMaterial3D
var _low_material: StandardMaterial3D


func setup(game: GameConfig, difficulty: DifficultyConfig, level_seed: int, bpm: float) -> void:
	_game = game
	_difficulty = difficulty
	_level_seed = level_seed
	_bpm = bpm
	_speed = game.scroll_speed(bpm)
	_look_time = game.view_distance / _speed
	_player_size = game.player_size
	_build_shared_resources()
	_build_pool()
	reset()


## Recicla todo y regenera el patrón desde la semilla (mismo nivel en cada intento).
func reset() -> void:
	for obstacle: Obstacle in _active:
		obstacle.deactivate()
		_pool.append(obstacle)
	_active.clear()
	pattern = LevelPattern.new(_level_seed, _bpm, _game, _difficulty)
	_next_row = 0
	_hit_emitted = false


func active_count() -> int:
	return _active.size()


## Conectado a PlayerController.moved.
func on_player_moved(p_position: Vector3, p_size: Vector3) -> void:
	_player_position = p_position
	_player_size = p_size


## Conectado a RhythmClock.tick.
func on_tick(song_time: float) -> void:
	var horizon: float = song_time + _look_time
	pattern.generate_until(RhythmClock.beat_at(horizon, _bpm) + GENERATION_MARGIN_BEATS)
	while _next_row < pattern.rows.size() and pattern.rows[_next_row].time <= horizon:
		_spawn_row(pattern.rows[_next_row])
		_next_row += 1

	var despawn_z: float = _game.despawn_distance
	for i: int in range(_active.size() - 1, -1, -1):
		var obstacle: Obstacle = _active[i]
		obstacle.position.z = (song_time - obstacle.hit_time) * _speed
		if obstacle.position.z > despawn_z:
			obstacle.deactivate()
			_active.remove_at(i)
			_pool.append(obstacle)
		elif not _hit_emitted and _overlaps_player(obstacle):
			_hit_emitted = true
			player_hit.emit(obstacle.lane, obstacle.kind)


func _overlaps_player(obstacle: Obstacle) -> bool:
	var half_z: float = (obstacle.size.z + _player_size.z) * 0.5
	if absf(obstacle.position.z - _player_position.z) >= half_z:
		return false
	var half_x: float = (obstacle.size.x + _player_size.x) * 0.5 * _game.collision_forgiveness
	if absf(obstacle.position.x - _player_position.x) >= half_x:
		return false
	var player_bottom: float = _player_position.y - _player_size.y * 0.5
	return player_bottom < obstacle.size.y


func _spawn_row(row: LevelPattern.Row) -> void:
	for lane: int in row.lanes.size():
		var kind: int = row.lanes[lane]
		if kind == LevelPattern.Kind.EMPTY:
			continue
		var obstacle: Obstacle = _take_from_pool()
		var is_low: bool = kind == LevelPattern.Kind.LOW
		obstacle.activate(lane, kind, row.time, _game.low_size if is_low else _game.wall_size,
				_game.lane_x(lane), _low_mesh if is_low else _wall_mesh,
				_low_material if is_low else _wall_material)
		obstacle.position.z = -_game.view_distance
		_active.append(obstacle)


func _take_from_pool() -> Obstacle:
	if _pool.is_empty():
		push_warning("ObstacleSpawner: pool agotado, ampliando. Subir obstacle_pool_size en GameConfig.")
		_pool.append(_create_obstacle())
	return _pool.pop_back()


func _build_pool() -> void:
	if not _pool.is_empty() or not _active.is_empty():
		return
	for i: int in _game.obstacle_pool_size:
		_pool.append(_create_obstacle())


func _create_obstacle() -> Obstacle:
	var obstacle := Obstacle.new()
	obstacle.name = "Obstacle%d" % (_pool.size() + _active.size())
	obstacle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	obstacle.deactivate()
	add_child(obstacle)
	return obstacle


func _build_shared_resources() -> void:
	if _wall_mesh != null:
		return
	_wall_mesh = BoxMesh.new()
	_wall_mesh.size = _game.wall_size
	_low_mesh = BoxMesh.new()
	_low_mesh.size = _game.low_size
	_wall_material = _make_material(WALL_COLOR)
	_low_material = _make_material(LOW_COLOR)


static func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return mat
