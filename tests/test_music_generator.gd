extends "res://tests/base_test.gd"
## La música del día es determinista, está en rango de tempo y el loop dura lo exacto.

const SEEDS_TO_CHECK: int = 50
const MIN_BPM: float = 110.0
const OCTAVE: int = 12
const MAX_BPM: float = 140.0

var _cfg: MusicConfig = load("res://resources/music_config.tres") as MusicConfig


func test_bpm_in_range_for_many_seeds() -> void:
	for i: int in SEEDS_TO_CHECK:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var bpm: float = MusicGenerator.choose_bpm(rng, _cfg)
		assert_true(bpm >= MIN_BPM and bpm <= MAX_BPM, "bpm %f fuera de rango" % bpm)


func test_same_seed_same_pattern_and_audio() -> void:
	var a: Dictionary = _render(12345)
	var b: Dictionary = _render(12345)
	assert_eq(a["bpm"], b["bpm"], "mismo tempo")
	var buf_a: PackedVector2Array = a["buffer"]
	var buf_b: PackedVector2Array = b["buffer"]
	assert_eq(buf_a.size(), buf_b.size(), "mismo largo")
	assert_true(buf_a == buf_b, "mismas muestras")


func test_loop_length_matches_tempo() -> void:
	var r: Dictionary = _render(777)
	var bpm: float = r["bpm"]
	var expected: float = _cfg.mix_rate * RhythmClock.time_of_beat(float(_cfg.loop_bars * _cfg.beats_per_bar), bpm)
	var buf: PackedVector2Array = r["buffer"]
	assert_almost(float(buf.size()), expected, 1.0, "frames del loop")


func test_kick_on_every_beat() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var p: DrumPattern = DrumPattern.generate(rng, _cfg)
	for step: int in range(0, p.step_count, _cfg.steps_per_beat):
		assert_true(p.kick[step] > 0.0, "bombo en el paso %d" % step)


func test_no_clipping_beyond_unit() -> void:
	var buf: PackedVector2Array = _render(2026)["buffer"]
	for v: Vector2 in buf:
		if absf(v.x) > 1.0 or absf(v.y) > 1.0:
			fail("muestra fuera de [-1, 1]")
			return


func _render(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bpm: float = MusicGenerator.choose_bpm(rng, _cfg)
	var pattern: DrumPattern = DrumPattern.generate(rng, _cfg)
	var melody: MelodyPattern = MelodyPattern.generate(rng, _cfg)
	return {"bpm": bpm, "buffer": SynthVoices.render_pattern(pattern, melody, _cfg, bpm, seed_value)}


func test_melody_stays_in_key() -> void:
	# Todas las notas de bajo y arpegio pertenecen a la menor natural de la fundamental.
	for seed_value: int in SEEDS_TO_CHECK:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var m: MelodyPattern = MelodyPattern.generate(rng, _cfg)
		for arr: PackedInt32Array in [m.bass, m.arp]:
			for note: int in arr:
				if note == MelodyPattern.NO_NOTE:
					continue
				if not _cfg.scale_natural_minor.has(posmod(note - m.root_midi, OCTAVE)):
					fail("semilla %d: nota %d fuera de escala" % [seed_value, note])
					return
