extends "res://tests/base_test.gd"
## Integración: un piloto automático juega el nivel real (ObstacleSpawner + PlayerController
## + colisiones) con ticks simulados. Si el nivel es posible, el piloto nunca debe chocar.
## Esto comprueba que el modelo de LevelPattern coincide con la geometría real del juego.

const SEEDS: Array[int] = [1, 2, 3, 2026, 99999, 1813764870]
const BEATS_TO_PLAY: float = 220.0
const TICK: float = 1.0 / 60.0
const INPUT_EPSILON: float = 0.005
const PLAN_EXTRA_BEATS: float = 16.0

var _game: GameConfig = load("res://resources/game_config.tres") as GameConfig
var _difficulty: DifficultyConfig = load("res://resources/difficulty_config.tres") as DifficultyConfig
var _music: MusicConfig = load("res://resources/music_config.tres") as MusicConfig


func test_autopilot_survives_every_seed_and_tempo() -> void:
	for i: int in SEEDS.size():
		var bpm: float = float(_music.bpm_options[i % _music.bpm_options.size()])
		var result: String = _play(SEEDS[i], bpm)
		if result != "":
			fail("semilla %d bpm %d: %s" % [SEEDS[i], bpm, result])


func test_idle_player_eventually_hits() -> void:
	# Control negativo: sin input el jugador debe chocar (las colisiones funcionan).
	var spawner := ObstacleSpawner.new()
	var player := PlayerController.new()
	spawner.setup(_game, _difficulty, 7, 120.0)
	player.setup(_game, 120.0)
	player.moved.connect(spawner.on_player_moved)
	var hits: Array[int] = []
	spawner.player_hit.connect(func(_l: int, _k: int) -> void: hits.append(1))
	var t: float = 0.0
	while t < RhythmClock.time_of_beat(BEATS_TO_PLAY, 120.0) and hits.is_empty():
		player.on_tick(t)
		spawner.on_tick(t)
		t += TICK
	assert_false(hits.is_empty(), "un jugador quieto debería chocar")
	spawner.free()
	player.free()


## Devuelve "" si sobrevive, o la descripción del choque.
func _play(level_seed: int, bpm: float) -> String:
	var spawner := ObstacleSpawner.new()
	var player := PlayerController.new()
	spawner.setup(_game, _difficulty, level_seed, bpm)
	player.setup(_game, bpm)
	player.moved.connect(spawner.on_player_moved)
	var hit: Dictionary = {}
	spawner.player_hit.connect(func(lane: int, kind: int) -> void:
		if hit.is_empty():
			hit["lane"] = lane
			hit["kind"] = kind)

	# Plan: copia independiente del patrón para planificar la ruta completa.
	var plan_pattern := LevelPattern.new(level_seed, bpm, _game, _difficulty)
	# Planificar más allá de lo que se juega: el spawner ya ve filas por delante.
	plan_pattern.generate_until(BEATS_TO_PLAY + PLAN_EXTRA_BEATS)
	var rows: Array[LevelPattern.Row] = plan_pattern.rows
	var plan: PackedInt32Array = _plan_lanes(plan_pattern)
	if plan.size() != rows.size():
		return "el planificador no encontró ruta (patrón imposible)"

	var end_time: float = RhythmClock.time_of_beat(BEATS_TO_PLAY, bpm)
	var half_occupancy: float = plan_pattern.occupancy_time * 0.5
	var half_jump: float = plan_pattern.jump_time * 0.5
	var next_row: int = 0
	var jumped_row: int = -1
	var last_move_time: float = -INF
	var t: float = 0.0
	var result: String = ""
	while t < end_time and hit.is_empty():
		player.on_tick(t)
		# Avanzar a la siguiente fila una vez cruzada la actual.
		while next_row < rows.size() and t > rows[next_row].time + half_occupancy:
			next_row += 1
		if next_row < rows.size():
			var target: int = plan[next_row]
			if player.lane != target and t - last_move_time >= _game.lane_change_time + INPUT_EPSILON:
				player.request_lane_change(1 if target > player.lane else -1)
				last_move_time = t
			var row: LevelPattern.Row = rows[next_row]
			if row.lanes[target] == LevelPattern.Kind.LOW and jumped_row != next_row \
					and t >= row.time - half_jump:
				player.request_jump()
				jumped_row = next_row
		spawner.on_tick(t)
		t += TICK
	if not hit.is_empty():
		result = "choque en t=%.2fs (beat %.1f) carril %d tipo %d" % [
			t, RhythmClock.beat_at(t, bpm), int(hit["lane"]), int(hit["kind"])]
	spawner.free()
	player.free()
	return result


## Programación dinámica: hacia adelante conjuntos alcanzables, hacia atrás elige carriles.
func _plan_lanes(p: LevelPattern) -> PackedInt32Array:
	var rows: Array[LevelPattern.Row] = p.rows
	var reach: PackedInt32Array = PackedInt32Array()
	var moves: PackedInt32Array = PackedInt32Array()
	var mask: int = 1 << p.start_lane
	var last_time: float = -INF
	for row: LevelPattern.Row in rows:
		var dt: float = row.time - last_time
		var m: int = LevelPattern.max_moves(dt, p.time_per_move, p.occupancy_time, p.lane_count)
		var can_jump: bool = dt >= p.jump_time + _difficulty.jump_margin
		mask = LevelPattern.expand_mask(mask, m, p.lane_count) & LevelPattern.passable_mask(row.lanes, can_jump)
		if mask == 0:
			return PackedInt32Array()
		reach.append(mask)
		moves.append(m)
		last_time = row.time
	var plan := PackedInt32Array()
	plan.resize(rows.size())
	var lane: int = _first_lane(reach[rows.size() - 1]) if rows.size() > 0 else 0
	for i: int in range(rows.size() - 1, -1, -1):
		plan[i] = lane
		if i > 0:
			var allowed: int = LevelPattern.expand_mask(1 << lane, moves[i], p.lane_count) & reach[i - 1]
			lane = _first_lane(allowed)
	return plan


static func _first_lane(mask: int) -> int:
	var i: int = 0
	while mask > 0 and (mask & 1) == 0:
		mask >>= 1
		i += 1
	return i
