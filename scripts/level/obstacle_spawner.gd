class_name ObstacleSpawner
extends Node3D
## Coloca obstáculos según LevelPattern y el reloj de audio.
##
## REGLA DE ORO: la posición de cada obstáculo es z = (song_time - hit_time) * velocidad.
## No hay movimiento acumulado con delta: si el audio se atrasa, el mundo se atrasa con él.
## Usa un pool pre-instanciado; nunca crea ni libera nodos durante la partida.

signal player_hit(lane: int, kind: int)
## El jugador pisó una rampa de impulso.
signal ramp_hit
signal gem_collected(total: int)

## Altura de suelo que significa "vacío" (hueco o fuera de la pista).
const VOID: float = -INF

## Beats extra que se generan por delante de lo visible.
const GENERATION_MARGIN_BEATS: float = 8.0
## Beats por compás para elegir el color neón de cada fila.
const COLOR_BEATS_PER_BAR: float = 4.0
## El muro móvil queda fijo en su carril estos beats antes de llegar al jugador.
const MOVER_SETTLE_BEATS: float = 1.0
## Fracción final de cada beat en la que el muro móvil se desliza al otro carril.
const MOVER_SLIDE_FRACTION: float = 0.3
## Margen para que estar parado sobre una plataforma no cuente como choque.
const TOP_EPSILON: float = 0.05
const GEM_SPIN_SPEED: float = 4.0
## La gema se recoge con una caja algo mayor que la visual.
const GEM_PICKUP_SCALE: float = 1.5
const GEM_GLOW: float = 3.5
const RAMP_GLOW: float = 2.6
const GAP_COLOR: Color = Color(1.0, 0.08, 0.2)
const GEM_COLOR: Color = Color(1.0, 0.9, 0.2)

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
## Un material por color de la paleta (compartidos por todo el pool).
var _wall_materials: Array[ShaderMaterial] = []
var _low_materials: Array[ShaderMaterial] = []
var _mover_materials: Array[ShaderMaterial] = []
var _platform_materials: Array[ShaderMaterial] = []
var _platform_mesh: BoxMesh
var _gap_mesh: BoxMesh
var _long_gap_mesh: BoxMesh
var _gap_material: ShaderMaterial
var _long_gap_material: ShaderMaterial
var _ramp_mesh: PrismMesh
var _ramp_material: ShaderMaterial
var _gem_mesh: SphereMesh
var _gem_material: ShaderMaterial
var _gap_size: Vector3 = Vector3.ONE
var _long_gap_size: Vector3 = Vector3.ONE
var _gem_size: Vector3 = Vector3.ONE
var _seconds_per_beat: float = 0.5
var _gems: int = 0


func setup(game: GameConfig, difficulty: DifficultyConfig, level_seed: int, bpm: float) -> void:
	_game = game
	_difficulty = difficulty
	_level_seed = level_seed
	_bpm = bpm
	_speed = game.scroll_speed(bpm)
	_look_time = game.view_distance / _speed
	_player_size = game.player_size
	_seconds_per_beat = RhythmClock.time_of_beat(1.0, bpm)
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
	_gems = 0


func active_count() -> int:
	return _active.size()


## Altura del suelo bajo un punto X en el instante `song_time`: 0 = pista, la cima de una
## plataforma si hay una debajo, o VOID sobre un hueco o fuera de la pista. Se calcula
## desde los tiempos de impacto (no desde los nodos), así vale para cualquier instante.
func ground_height_at(x: float, song_time: float) -> float:
	if absf(x) > _game.track_half_width():
		return VOID
	var ground: float = 0.0
	for obstacle: Obstacle in _active:
		var kind: int = obstacle.kind
		var is_gap: bool = kind == LevelPattern.Kind.GAP or kind == LevelPattern.Kind.LONG_GAP
		if not is_gap and kind != LevelPattern.Kind.PLATFORM:
			continue
		var z: float = (song_time - obstacle.hit_time) * _speed
		if is_gap:
			# El hueco cuenta por el centro del cubo: medio cubo de perdón en cada borde.
			if absf(z) < obstacle.size.z * 0.5 \
					and absf(x - obstacle.to_x) < _game.lane_width * 0.5 * _game.collision_forgiveness:
				return VOID
		elif absf(z) < (obstacle.size.z + _player_size.z) * 0.5 \
				and absf(x - obstacle.to_x) < (obstacle.size.x + _player_size.x) * 0.5 * _game.collision_forgiveness:
			ground = maxf(ground, obstacle.size.y)
	return ground


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
		if obstacle.position.z - obstacle.size.z * 0.5 > despawn_z:
			_recycle(i)
			continue
		match obstacle.kind:
			LevelPattern.Kind.MOVER:
				obstacle.position.x = _mover_x(obstacle, song_time)
			Obstacle.KIND_GEM:
				obstacle.rotation.y = song_time * GEM_SPIN_SPEED
		if _hit_emitted or not _overlaps_player(obstacle):
			continue
		match obstacle.kind:
			LevelPattern.Kind.GAP, LevelPattern.Kind.LONG_GAP:
				pass  # Los huecos no chocan: el jugador cae (ver ground_height_at).
			LevelPattern.Kind.RAMP:
				if not obstacle.triggered:
					obstacle.triggered = true
					ramp_hit.emit()
			Obstacle.KIND_GEM:
				_recycle(i)
				_gems += 1
				gem_collected.emit(_gems)
			_:
				_hit_emitted = true
				player_hit.emit(obstacle.lane, obstacle.kind)


func _recycle(index: int) -> void:
	var obstacle: Obstacle = _active[index]
	obstacle.deactivate()
	_active.remove_at(index)
	_pool.append(obstacle)


## X de un muro móvil: alterna de carril cada beat y queda fijo MOVER_SETTLE_BEATS antes.
func _mover_x(obstacle: Obstacle, song_time: float) -> float:
	var k: float = (obstacle.hit_time - song_time) / _seconds_per_beat - MOVER_SETTLE_BEATS
	if k <= 0.0:
		return obstacle.to_x
	var n: int = floori(k)
	var here: float = obstacle.from_x if n % 2 == 0 else obstacle.to_x
	var next: float = obstacle.to_x if n % 2 == 0 else obstacle.from_x
	return lerpf(next, here, smoothstep(0.0, MOVER_SLIDE_FRACTION, k - float(n)))


func _overlaps_player(obstacle: Obstacle) -> bool:
	var half_z: float = (obstacle.size.z + _player_size.z) * 0.5
	if absf(obstacle.position.z - _player_position.z) >= half_z:
		return false
	var half_x: float = (obstacle.size.x + _player_size.x) * 0.5 * _game.collision_forgiveness
	if absf(obstacle.position.x - _player_position.x) >= half_x:
		return false
	if obstacle.kind == Obstacle.KIND_GEM:
		return absf(obstacle.position.y - _player_position.y) < (obstacle.size.y + _player_size.y) * 0.5
	var player_bottom: float = _player_position.y - _player_size.y * 0.5
	return player_bottom < obstacle.size.y - TOP_EPSILON


func _spawn_row(row: LevelPattern.Row) -> void:
	var color_index: int = posmod(floori(row.beat / COLOR_BEATS_PER_BAR), _wall_materials.size())
	var has_ramp: bool = false
	for lane: int in row.lanes.size():
		var kind: int = row.lanes[lane]
		if kind == LevelPattern.Kind.EMPTY:
			continue
		has_ramp = has_ramp or kind == LevelPattern.Kind.RAMP
		_spawn_kind(kind, lane, row, color_index)
	if has_ramp:
		# Línea de muros que se sobrevuela durante el súper salto.
		var wall_time: float = row.time + _game.ramp_wall_delay_beats * _seconds_per_beat
		for lane: int in row.lanes.size():
			_place(lane, LevelPattern.Kind.WALL, wall_time, _game.wall_size, _wall_mesh,
					_wall_materials[(color_index + 1) % _wall_materials.size()])
	if row.gem_lane != LevelPattern.NO_GEM:
		_spawn_gem(row, has_ramp)


func _spawn_kind(kind: int, lane: int, row: LevelPattern.Row, color_index: int) -> void:
	match kind:
		LevelPattern.Kind.WALL:
			_place(lane, kind, row.time, _game.wall_size, _wall_mesh, _wall_materials[color_index])
		LevelPattern.Kind.LOW:
			_place(lane, kind, row.time, _game.low_size, _low_mesh, _low_materials[color_index])
		LevelPattern.Kind.GAP:
			_place(lane, kind, row.time, _gap_size, _gap_mesh, _gap_material)
		LevelPattern.Kind.LONG_GAP:
			_place(lane, kind, row.time, _long_gap_size, _long_gap_mesh, _long_gap_material)
		LevelPattern.Kind.PLATFORM:
			# El frente llega al cubo justo en row.time (cima del salto); el centro, después.
			var lead: float = (_game.platform_size.z + _player_size.z) * 0.5 / _speed
			_place(lane, kind, row.time + lead, _game.platform_size, _platform_mesh,
					_platform_materials[color_index])
		LevelPattern.Kind.RAMP:
			var ramp: Obstacle = _place(lane, kind, row.time, _game.ramp_size, _ramp_mesh, _ramp_material)
			ramp.rotation.y = PI * 0.5  # La cuña sube en el sentido de la marcha.
		LevelPattern.Kind.MOVER:
			var mover: Obstacle = _place(lane, kind, row.time, _game.wall_size, _wall_mesh,
					_mover_materials[color_index])
			mover.from_x = _game.lane_x(_mover_partner_lane(lane, row.lanes))


## Carril vecino con el que baila un muro móvil: prefiere uno libre en la fila.
func _mover_partner_lane(lane: int, lanes: PackedInt32Array) -> int:
	var fallback: int = lane
	for candidate: int in [lane - 1, lane + 1]:
		if candidate < 0 or candidate >= lanes.size():
			continue
		if lanes[candidate] == LevelPattern.Kind.EMPTY:
			return candidate
		fallback = candidate
	return fallback


func _spawn_gem(row: LevelPattern.Row, over_ramp: bool) -> void:
	var kind: int = row.lanes[row.gem_lane]
	var time: float = row.time
	var base_y: float = _game.gem_ground_height
	if over_ramp:
		time += _game.ramp_wall_delay_beats * _seconds_per_beat
		base_y = _game.ramp_jump_height
	elif LevelPattern.needs_jump(kind):
		base_y = _game.gem_jump_height
	var gem: Obstacle = _take_from_pool()
	gem.activate(row.gem_lane, Obstacle.KIND_GEM, time, _gem_size, _game.lane_x(row.gem_lane),
			_gem_mesh, _gem_material, base_y - _gem_size.y * 0.5)
	gem.position.z = -_game.view_distance
	_active.append(gem)


func _place(lane: int, kind: int, hit_time: float, size: Vector3, mesh: Mesh, material: Material) -> Obstacle:
	var obstacle: Obstacle = _take_from_pool()
	obstacle.activate(lane, kind, hit_time, size, _game.lane_x(lane), mesh, material)
	obstacle.position.z = -_game.view_distance
	_active.append(obstacle)
	return obstacle


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
	_platform_mesh = BoxMesh.new()
	_platform_mesh.size = _game.platform_size
	for color: Color in NeonPalette.COLORS:
		_wall_materials.append(NeonPalette.edges_material(color, _game.wall_size))
		_low_materials.append(NeonPalette.edges_material(color, _game.low_size, true))
		_mover_materials.append(NeonPalette.edges_material(color, _game.wall_size, true))
		_platform_materials.append(NeonPalette.edges_material(color, _game.platform_size))
	# Huecos: panel negro con borde rojo a ras de pista (un "vacío" barato, sin recortar el piso).
	_gap_size = Vector3(_game.lane_width, _game.gap_panel_height, _game.gap_short_length)
	_long_gap_size = Vector3(_game.lane_width, _game.gap_panel_height, _game.gap_long_length)
	_gap_mesh = BoxMesh.new()
	_gap_mesh.size = _gap_size
	_long_gap_mesh = BoxMesh.new()
	_long_gap_mesh.size = _long_gap_size
	_gap_material = _void_material(_gap_size)
	_long_gap_material = _void_material(_long_gap_size)
	_ramp_mesh = PrismMesh.new()
	# Tras girar 90° en Y, el eje X de la cuña queda a lo largo de la pista.
	_ramp_mesh.size = Vector3(_game.ramp_size.z, _game.ramp_size.y, _game.ramp_size.x)
	_ramp_mesh.left_to_right = 1.0
	_ramp_material = NeonPalette.solid_material(NeonPalette.LIME, RAMP_GLOW)
	_gem_size = Vector3.ONE * _game.gem_size * GEM_PICKUP_SCALE
	_gem_mesh = SphereMesh.new()
	_gem_mesh.radius = _game.gem_size * 0.5
	_gem_mesh.height = _game.gem_size
	_gem_mesh.radial_segments = 4
	_gem_mesh.rings = 1
	_gem_material = NeonPalette.solid_material(GEM_COLOR, GEM_GLOW)


static func _void_material(size: Vector3) -> ShaderMaterial:
	var mat: ShaderMaterial = NeonPalette.edges_material(GAP_COLOR, size)
	mat.set_shader_parameter(&"fill_strength", 0.0)
	return mat
