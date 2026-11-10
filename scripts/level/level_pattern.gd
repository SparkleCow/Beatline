class_name LevelPattern
extends RefCounted
## Genera las filas de obstáculos del nivel, ancladas a beats, de forma determinista.
##
## Garantías (verificadas por tests/test_level_pattern.gd):
## - Nunca se bloquean todos los carriles con muros.
## - Siempre existe un camino: se modela el conjunto de carriles alcanzables y se abre
##   un carril si una fila lo dejaría vacío.
## - Entre filas hay al menos `min_reaction_time` segundos y `min_row_gap_beats` beats.
## - Las barreras bajas solo aparecen si hay tiempo de aterrizar y volver a saltar.
##
## Generación incremental: generate_until() puede llamarse por partes y el resultado es
## idéntico a generarlo todo de una vez (modo infinito / pista sin fin).

enum Kind { EMPTY = 0, WALL = 1, LOW = 2 }

## Resolución de beats candidatos (0.5 = contratiempos posibles).
const BEAT_SUBDIVISION: float = 0.5
const OFFBEAT_EPSILON: float = 0.001
const TIME_EPSILON: float = 0.000001
## La rampa de dificultad se mide en compases de 4/4.
const RAMP_BEATS_PER_BAR: float = 4.0


class Row:
	extends RefCounted
	var beat: float
	var time: float
	var lanes: PackedInt32Array

	func _init(p_beat: float, p_time: float, p_lanes: PackedInt32Array) -> void:
		beat = p_beat
		time = p_time
		lanes = p_lanes


var rows: Array[Row] = []
var lane_count: int = 3
var start_lane: int = 1
var bpm: float = 120.0
var seconds_per_beat: float = 0.5
## Segundos mínimos por cada carril que se cambia entre filas (máx. entre animación y humano).
var time_per_move: float = 0.25
## Segundos que el jugador y un obstáculo se solapan en Z al cruzarse.
var occupancy_time: float = 0.1
## Duración del salto en segundos.
var jump_time: float = 0.5
var min_gap_time: float = 0.45

var _difficulty: DifficultyConfig
var _rng := RandomNumberGenerator.new()
var _next_candidate_beat: float = 0.0
var _last_row_time: float = -INF
var _reachable_mask: int = 0


func _init(level_seed: int, p_bpm: float, game: GameConfig, difficulty: DifficultyConfig) -> void:
	_difficulty = difficulty
	_rng.seed = level_seed
	bpm = p_bpm
	lane_count = game.lane_count
	start_lane = game.center_lane()
	seconds_per_beat = RhythmClock.time_of_beat(1.0, bpm)
	time_per_move = maxf(game.lane_change_time, difficulty.min_time_per_lane_move)
	var speed: float = game.scroll_speed(bpm)
	occupancy_time = (maxf(game.wall_size.z, game.low_size.z) + game.player_size.z) / speed
	jump_time = game.jump_duration_beats * seconds_per_beat
	min_gap_time = maxf(difficulty.min_reaction_time, difficulty.min_row_gap_beats * seconds_per_beat)
	_next_candidate_beat = float(difficulty.warmup_beats)
	_reachable_mask = 1 << start_lane


## Genera filas hasta (sin incluir) el beat indicado.
func generate_until(beat_limit: float) -> void:
	while _next_candidate_beat < beat_limit:
		var b: float = _next_candidate_beat
		_next_candidate_beat += BEAT_SUBDIVISION
		var t: float = b * seconds_per_beat
		var progress: float = _progress(b)
		var is_offbeat: bool = absf(b - roundf(b)) > OFFBEAT_EPSILON
		if is_offbeat:
			if progress < _difficulty.offbeat_unlock_progress:
				continue
			if _rng.randf() >= _difficulty.offbeat_probability:
				continue
		if t - _last_row_time < min_gap_time - TIME_EPSILON:
			continue
		if _rng.randf() >= lerpf(_difficulty.start_density, _difficulty.max_density, progress):
			continue
		_add_row(b, t, progress)


## Cantidad de carriles que se pueden cambiar en `dt` segundos.
static func max_moves(dt: float, p_time_per_move: float, p_occupancy: float, p_lane_count: int) -> int:
	if is_inf(dt):
		return p_lane_count
	return clampi(floori((dt - p_occupancy) / p_time_per_move), 0, p_lane_count)


## Expande una máscara de carriles alcanzables `moves` pasos a izquierda y derecha.
static func expand_mask(mask: int, moves: int, p_lane_count: int) -> int:
	var full: int = (1 << p_lane_count) - 1
	var result: int = mask
	for i: int in moves:
		result = (result | (result << 1) | (result >> 1)) & full
	return result


## Máscara de carriles transitables de una fila (vacíos, o bajos si se puede saltar).
static func passable_mask(lanes: PackedInt32Array, can_jump: bool) -> int:
	var mask: int = 0
	for i: int in lanes.size():
		var kind: int = lanes[i]
		if kind == Kind.EMPTY or (kind == Kind.LOW and can_jump):
			mask |= 1 << i
	return mask


## Valida una secuencia de filas con el mismo modelo de movimiento. Devuelve "" si es
## jugable, o un texto describiendo el primer problema.
static func validate(p_rows: Array[Row], p_lane_count: int, p_start_lane: int, p_time_per_move: float,
		p_occupancy: float, p_jump_time: float, p_min_gap: float, p_jump_margin: float) -> String:
	var reachable: int = 1 << p_start_lane
	var last_time: float = -INF
	for idx: int in p_rows.size():
		var row: Row = p_rows[idx]
		if row.lanes.size() != p_lane_count:
			return "fila %d: tamaño de carriles incorrecto" % idx
		var dt: float = row.time - last_time
		if dt < p_min_gap - TIME_EPSILON:
			return "fila %d (beat %.1f): separación %.3fs < mínimo %.3fs" % [idx, row.beat, dt, p_min_gap]
		var walls: int = 0
		for kind: int in row.lanes:
			if kind == Kind.WALL:
				walls += 1
		if walls >= p_lane_count:
			return "fila %d (beat %.1f): todos los carriles bloqueados" % [idx, row.beat]
		var can_jump: bool = dt >= p_jump_time + p_jump_margin
		var before: int = expand_mask(reachable, max_moves(dt, p_time_per_move, p_occupancy, p_lane_count), p_lane_count)
		reachable = before & passable_mask(row.lanes, can_jump)
		if reachable == 0:
			return "fila %d (beat %.1f): no hay camino posible" % [idx, row.beat]
		last_time = row.time
	return ""


## Atajo: valida las filas de este patrón con sus propios parámetros.
func validate_self() -> String:
	return validate(rows, lane_count, start_lane, time_per_move, occupancy_time, jump_time,
			min_gap_time, _difficulty.jump_margin)


func _progress(beat_value: float) -> float:
	var bars: float = beat_value / RAMP_BEATS_PER_BAR
	return clampf(bars / float(maxi(_difficulty.ramp_bars, 1)), 0.0, 1.0)


func _add_row(b: float, t: float, progress: float) -> void:
	var dt: float = t - _last_row_time
	var before: int = expand_mask(_reachable_mask, max_moves(dt, time_per_move, occupancy_time, lane_count), lane_count)
	var can_jump: bool = dt >= jump_time + _difficulty.jump_margin

	var lanes := PackedInt32Array()
	lanes.resize(lane_count)
	var shape_roll: float = _rng.randf()
	if can_jump and shape_roll < _difficulty.jump_gate_probability:
		lanes = _fill_jump_gate(lanes, before)
	elif can_jump and shape_roll < _difficulty.jump_gate_probability + _difficulty.full_low_probability:
		lanes.fill(Kind.LOW)
	else:
		lanes = _fill_blocks(lanes, progress, can_jump)

	var after: int = before & passable_mask(lanes, can_jump)
	if after == 0:
		# Abrir un carril alcanzable al azar: siempre hay camino.
		var candidates: Array[int] = []
		for i: int in lane_count:
			if before & (1 << i):
				candidates.append(i)
		var open_lane: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
		lanes[open_lane] = Kind.EMPTY
		after = before & passable_mask(lanes, can_jump)

	if passable_mask(lanes, false) == (1 << lane_count) - 1:
		return  # Fila vacía tras la corrección: no se agrega ni cambia el estado.
	rows.append(Row.new(b, t, lanes))
	_reachable_mask = after
	_last_row_time = t


## (Los Packed*Array se copian al pasarlos: los helpers devuelven el arreglo.)
## Bloques sueltos: 1 o 2 carriles (la probabilidad de 2 sube con la rampa), muros o bajos.
func _fill_blocks(lanes: PackedInt32Array, progress: float, can_jump: bool) -> PackedInt32Array:
	var blocked: int = 1
	var double_p: float = lerpf(_difficulty.double_block_start, _difficulty.double_block_probability, progress)
	if _rng.randf() < double_p:
		blocked = 2
	blocked = mini(blocked, lane_count - 1)
	var free_lanes: Array[int] = []
	for i: int in lane_count:
		free_lanes.append(i)
	for i: int in blocked:
		var pick: int = _rng.randi_range(0, free_lanes.size() - 1)
		var lane: int = free_lanes[pick]
		free_lanes.remove_at(pick)
		var is_low: bool = can_jump and _rng.randf() < _difficulty.low_probability
		lanes[lane] = Kind.LOW if is_low else Kind.WALL
	return lanes


## Puerta de salto: muros en todos los carriles menos uno, que tiene barrera baja.
## Prefiere el centro; el hueco siempre cae en un carril alcanzable.
func _fill_jump_gate(lanes: PackedInt32Array, reachable_before: int) -> PackedInt32Array:
	lanes.fill(Kind.WALL)
	var center: int = floori(float(lane_count - 1) * 0.5)
	var gap: int = center
	if not (reachable_before & (1 << center)) or _rng.randf() >= _difficulty.jump_gate_center_bias:
		var candidates: Array[int] = []
		for i: int in lane_count:
			if reachable_before & (1 << i):
				candidates.append(i)
		gap = candidates[_rng.randi_range(0, candidates.size() - 1)]
	lanes[gap] = Kind.LOW
	return lanes
