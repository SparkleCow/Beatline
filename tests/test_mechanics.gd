extends "res://tests/base_test.gd"
## Mecánicas nuevas: salto de altura variable, caída a huecos, tipos de obstáculo del
## generador, tramos sin riel, efectos de sonido y catálogo de pistas.

const TICK: float = 1.0 / 120.0
const BPM: float = 120.0
const BEATS_TO_GENERATE: float = 600.0

var _game: GameConfig = load("res://resources/game_config.tres") as GameConfig
var _hard: DifficultyConfig = load("res://resources/difficulty_hard.tres") as DifficultyConfig


func test_full_jump_reaches_configured_height_and_duration() -> void:
	var result: Vector2 = _jump_profile(INF)
	assert_almost(result.x, _game.jump_height, 0.02, "altura del salto completo")
	assert_almost(result.y, RhythmClock.time_of_beat(_game.jump_duration_beats, BPM), 0.02, "duración")


func test_released_jump_is_lower_and_shorter_but_clears_low_barrier() -> void:
	var full: Vector2 = _jump_profile(INF)
	var tap: Vector2 = _jump_profile(0.0)
	assert_true(tap.x < full.x * 0.6, "el toque corto debe saltar bastante menos")
	assert_true(tap.y < full.y, "y durar menos")
	assert_true(tap.x > _game.low_size.y + 0.2, "pero superar la barrera baja con margen")
	assert_true(tap.x < _game.platform_size.y, "y no alcanzar para subir a una plataforma")


func test_player_falls_into_void_and_reports_it() -> void:
	var player := PlayerController.new()
	player.setup(_game, BPM)
	player.ground_query = func(_x: float, _t: float) -> float: return ObstacleSpawner.VOID
	var fell: Array[int] = []
	player.fell.connect(func() -> void: fell.append(1))
	var t: float = 0.0
	while t < 3.0 and fell.is_empty():
		player.on_tick(t)
		t += TICK
	assert_false(fell.is_empty(), "sin suelo el cubo debe caer y avisar")
	player.free()


func test_lands_on_platform_and_drops_when_it_ends() -> void:
	var player := PlayerController.new()
	player.setup(_game, BPM)
	var top: float = _game.platform_size.y
	# Plataforma bajo el cubo solo entre 0,25 s y 1,0 s.
	player.ground_query = func(_x: float, time: float) -> float: return top if time >= 0.25 and time < 1.0 else 0.0
	player.on_tick(0.0)
	player.request_jump()
	var rode: bool = false
	var t: float = TICK
	while t < 2.0:
		player.on_tick(t)
		var bottom: float = player.position.y - _game.player_size.y * 0.5
		if t > 0.6 and t < 0.95:
			rode = rode or (not player.is_airborne() and absf(bottom - top) < 0.001)
		t += TICK
	assert_true(rode, "debe quedar parado sobre la plataforma")
	assert_almost(player.position.y - _game.player_size.y * 0.5, 0.0, 0.001, "y volver al piso al acabarse")
	player.free()


func test_edge_is_solid_with_rails_and_deadly_without() -> void:
	var player := PlayerController.new()
	player.setup(_game, BPM)
	for i: int in _game.lane_count + 2:
		player.request_lane_change(-1)
	assert_eq(player.lane, 0, "con rieles el borde frena al cubo")
	player.edges_open = true
	player.request_lane_change(-1)
	assert_eq(player.lane, -1, "sin rieles el cubo se sale de la pista")
	player.free()


func test_new_obstacle_kinds_appear_and_stay_possible() -> void:
	var seen: Dictionary[int, bool] = {}
	var open_spans: int = 0
	var gems: int = 0
	for seed_value: int in 12:
		var p := LevelPattern.new(seed_value + 1, 130.0, _game, _hard)
		p.generate_until(BEATS_TO_GENERATE)
		assert_eq(p.validate_self(), "", "semilla %d" % seed_value)
		open_spans += p.open_spans.size()
		for row: LevelPattern.Row in p.rows:
			for kind: int in row.lanes:
				seen[kind] = true
			if row.gem_lane != LevelPattern.NO_GEM:
				gems += 1
				assert_true(row.lanes[row.gem_lane] != LevelPattern.Kind.WALL
						and row.lanes[row.gem_lane] != LevelPattern.Kind.MOVER, "gema dentro de un muro")
	for kind: int in [LevelPattern.Kind.GAP, LevelPattern.Kind.LONG_GAP, LevelPattern.Kind.PLATFORM,
			LevelPattern.Kind.RAMP, LevelPattern.Kind.MOVER]:
		assert_true(seen.has(kind), "debe aparecer el tipo %d" % kind)
	assert_true(open_spans > 0, "debe haber tramos sin riel")
	assert_true(gems > 0, "debe haber gemas")


func test_fixed_stages_are_valid_and_deterministic() -> void:
	for stage: LevelCatalog.Stage in LevelCatalog.stages():
		var a := LevelPattern.new(stage.seed_value, 130.0, _game, stage.difficulty)
		var b := LevelPattern.new(stage.seed_value, 130.0, _game, stage.difficulty)
		a.generate_until(float(stage.goal_beats()))
		b.generate_until(float(stage.goal_beats()))
		assert_eq(a.validate_self(), "", stage.title)
		assert_eq(a.rows.size(), b.rows.size(), "%s determinista" % stage.title)
		assert_true(a.rows.size() > stage.goal_bars, "%s debe ser denso" % stage.title)


func test_every_sfx_renders_audible_and_unclipped() -> void:
	for id: int in SfxPlayer.Sfx.values():
		var samples: PackedFloat32Array = SfxPlayer.render(id, SfxPlayer.MIX_RATE)
		assert_true(samples.size() > 0, "efecto %d vacío" % id)
		var peak: float = 0.0
		for value: float in samples:
			peak = maxf(peak, absf(value))
		assert_true(peak > 0.1 and peak <= 1.0, "efecto %d: pico %.2f" % [id, peak])


func test_track_bpm_is_read_from_file_name() -> void:
	assert_almost(TrackLibrary.parse_bpm("neon_requiem_132bpm.ogg"), 132.0, 0.001, "bpm")
	assert_almost(TrackLibrary.parse_bpm("140BPM.ogg"), 140.0, 0.001, "sin título")
	assert_almost(TrackLibrary.parse_bpm("sin_tempo.ogg"), 0.0, 0.001, "sin bpm se ignora")
	assert_almost(TrackLibrary.parse_bpm("raro_999bpm.ogg"), 0.0, 0.001, "fuera de rango se ignora")
	assert_eq(TrackLibrary.title_of("neon_requiem_132bpm.ogg"), "NEON REQUIEM", "título")


## Salta en t=0 y suelta a los `release_after` segundos. Devuelve (altura máxima, duración).
func _jump_profile(release_after: float) -> Vector2:
	var player := PlayerController.new()
	player.setup(_game, BPM)
	player.on_tick(0.0)
	player.request_jump()
	var released: bool = false
	var peak: float = 0.0
	var t: float = 0.0
	while t < 3.0:
		if not released and t >= release_after:
			player.request_jump_release()
			released = true
		t += TICK
		player.on_tick(t)
		peak = maxf(peak, player.position.y - _game.player_size.y * 0.5)
		if not player.is_airborne():
			break
	player.free()
	return Vector2(peak, t)
