extends "res://tests/base_test.gd"
## El generador de obstáculos nunca debe producir un patrón imposible.

const SEEDS_TO_CHECK: int = 150
const BEATS_TO_GENERATE: float = 600.0
const CHUNK_BEATS: float = 7.5
const START_SEED: int = 1000

var _game: GameConfig = load("res://resources/game_config.tres") as GameConfig
var _difficulty: DifficultyConfig = load("res://resources/difficulty_config.tres") as DifficultyConfig
var _music: MusicConfig = load("res://resources/music_config.tres") as MusicConfig


func _make(seed_value: int, bpm: float) -> LevelPattern:
	return LevelPattern.new(seed_value, bpm, _game, _difficulty)


func test_never_impossible_across_seeds_and_tempos() -> void:
	for i: int in SEEDS_TO_CHECK:
		var bpm: float = float(_music.bpm_options[i % _music.bpm_options.size()])
		var p: LevelPattern = _make(START_SEED + i, bpm)
		p.generate_until(BEATS_TO_GENERATE)
		var err: String = p.validate_self()
		if err != "":
			fail("semilla %d bpm %d: %s" % [START_SEED + i, bpm, err])
			return


func test_extreme_density_still_possible() -> void:
	var hard: DifficultyConfig = _difficulty.duplicate() as DifficultyConfig
	hard.start_density = 1.0
	hard.max_density = 1.0
	hard.double_block_probability = 1.0
	hard.offbeat_unlock_progress = 0.0
	hard.offbeat_probability = 1.0
	hard.ramp_bars = 1
	for i: int in SEEDS_TO_CHECK:
		var p := LevelPattern.new(START_SEED + i, 140.0, _game, hard)
		p.generate_until(BEATS_TO_GENERATE)
		assert_true(p.rows.size() > 0, "debe haber filas")
		var err: String = p.validate_self()
		if err != "":
			fail("semilla %d (densidad extrema): %s" % [START_SEED + i, err])
			return


func test_min_reaction_time_respected() -> void:
	for bpm: int in _music.bpm_options:
		var p: LevelPattern = _make(START_SEED, float(bpm))
		p.generate_until(BEATS_TO_GENERATE)
		for i: int in range(1, p.rows.size()):
			var gap: float = p.rows[i].time - p.rows[i - 1].time
			if gap < _difficulty.min_reaction_time - 0.0001:
				fail("bpm %d fila %d: separación %.3f s" % [bpm, i, gap])
				return


func test_rows_anchored_to_beat_grid() -> void:
	var p: LevelPattern = _make(START_SEED, 128.0)
	p.generate_until(BEATS_TO_GENERATE)
	for row: LevelPattern.Row in p.rows:
		var half_beats: float = row.beat / LevelPattern.BEAT_SUBDIVISION
		assert_almost(half_beats, roundf(half_beats), 0.0001, "beat fuera de la grilla")
		assert_almost(row.time, RhythmClock.time_of_beat(row.beat, 128.0), 0.0001, "tiempo = beat * spb")
		assert_true(row.beat >= float(_difficulty.warmup_beats), "respeta calentamiento")


func test_never_all_walls_and_always_some_obstacle() -> void:
	var p: LevelPattern = _make(START_SEED + 7, 120.0)
	p.generate_until(BEATS_TO_GENERATE)
	for row: LevelPattern.Row in p.rows:
		var walls: int = row.lanes.count(LevelPattern.Kind.WALL)
		var empties: int = row.lanes.count(LevelPattern.Kind.EMPTY)
		assert_true(walls < _game.lane_count, "fila con todos muros")
		assert_true(empties < _game.lane_count, "fila vacía guardada")


func test_deterministic_same_seed() -> void:
	var a: LevelPattern = _make(START_SEED + 3, 125.0)
	var b: LevelPattern = _make(START_SEED + 3, 125.0)
	a.generate_until(BEATS_TO_GENERATE)
	b.generate_until(BEATS_TO_GENERATE)
	assert_eq(_signature(a), _signature(b), "misma semilla => mismo nivel")


func test_chunked_generation_equals_one_shot() -> void:
	var one_shot: LevelPattern = _make(START_SEED + 5, 135.0)
	one_shot.generate_until(BEATS_TO_GENERATE)
	var chunked: LevelPattern = _make(START_SEED + 5, 135.0)
	var limit: float = 0.0
	while limit < BEATS_TO_GENERATE:
		limit = minf(limit + CHUNK_BEATS, BEATS_TO_GENERATE)
		chunked.generate_until(limit)
	assert_eq(_signature(chunked), _signature(one_shot), "por partes == de una vez")


func test_different_seeds_differ() -> void:
	var a: LevelPattern = _make(START_SEED + 11, 120.0)
	var b: LevelPattern = _make(START_SEED + 12, 120.0)
	a.generate_until(BEATS_TO_GENERATE)
	b.generate_until(BEATS_TO_GENERATE)
	assert_ne(_signature(a), _signature(b), "semillas distintas => niveles distintos")


func test_validator_detects_impossible_pattern() -> void:
	var rows: Array[LevelPattern.Row] = []
	var all_walls := PackedInt32Array([LevelPattern.Kind.WALL, LevelPattern.Kind.WALL, LevelPattern.Kind.WALL])
	rows.append(LevelPattern.Row.new(8.0, 4.0, all_walls))
	assert_ne(LevelPattern.validate(rows, 3, 1, 0.25, 0.1, 0.5, 0.45, 0.05), "", "todos muros")

	rows.clear()
	# Carril 0 libre a 0.3 s de una fila con solo el carril 2 libre: 2 carriles, sin tiempo.
	rows.append(LevelPattern.Row.new(8.0, 4.0, PackedInt32Array([0, 1, 1])))
	rows.append(LevelPattern.Row.new(9.0, 4.5, PackedInt32Array([1, 1, 0])))
	assert_ne(LevelPattern.validate(rows, 3, 0, 0.25, 0.1, 0.5, 0.45, 0.05), "", "salto de 2 carriles imposible")


func _signature(p: LevelPattern) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for row: LevelPattern.Row in p.rows:
		parts.append("%.1f:%s" % [row.beat, str(row.lanes)])
	return ",".join(parts)
