extends "res://tests/base_test.gd"
## El reloj deriva del audio, es monótono y emite cada beat/compás exactamente una vez.

const TOLERANCE: float = 0.000001


func test_compute_song_time_compensates_latency() -> void:
	assert_almost(RhythmClock.compute_song_time(2.0, 0.01, 0.05), 1.96, TOLERANCE, "mezclado + desde_mezcla - latencia")


func test_beat_time_conversions() -> void:
	assert_almost(RhythmClock.beat_at(1.0, 120.0), 2.0, TOLERANCE, "1 s a 120 BPM = 2 beats")
	assert_almost(RhythmClock.time_of_beat(3.0, 120.0), 1.5, TOLERANCE, "beat 3 a 120 BPM = 1.5 s")
	assert_almost(RhythmClock.beat_at(RhythmClock.time_of_beat(7.25, 137.0), 137.0), 7.25, TOLERANCE, "ida y vuelta")


func test_emits_each_beat_once_and_monotonic() -> void:
	var clock := RhythmClock.new()
	clock.compensate_latency = false
	var fake: Dictionary = {"t": 0.0}
	var beats: Array[int] = []
	var bars: Array[int] = []
	clock.beat.connect(func(b: int) -> void: beats.append(b))
	clock.bar.connect(func(b: int) -> void: bars.append(b))
	clock.start(func() -> float: return fake["t"], 120.0, 4)

	# Avanza en saltos irregulares (como llega la mezcla de audio), incluido un retroceso.
	for t: float in [0.01, 0.2, 0.49, 0.51, 1.3, 1.2, 2.01, 4.0]:
		fake["t"] = t
		clock.update()
	assert_almost(clock.song_time, 4.0, TOLERANCE, "tiempo final")
	assert_eq(beats, [0, 1, 2, 3, 4, 5, 6, 7, 8] as Array[int], "beats sin saltos ni duplicados")
	assert_eq(bars, [0, 1, 2] as Array[int], "compases")
	clock.free()


func test_time_never_goes_backwards() -> void:
	var clock := RhythmClock.new()
	clock.compensate_latency = false
	var fake: Dictionary = {"t": 1.0}
	clock.start(func() -> float: return fake["t"], 120.0, 4)
	clock.update()
	fake["t"] = 0.8
	clock.update()
	assert_almost(clock.song_time, 1.0, TOLERANCE, "no retrocede")
	clock.free()


func test_stop_freezes_state() -> void:
	var clock := RhythmClock.new()
	clock.start(func() -> float: return 0.0, 120.0, 4)
	assert_true(clock.is_running(), "corriendo")
	clock.stop()
	assert_false(clock.is_running(), "detenido")
	clock.free()
