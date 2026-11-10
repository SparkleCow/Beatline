class_name RhythmClock
extends Node
## Reloj musical. La fuente de verdad es el AUDIO, no el delta de _process.
##
## song_time = segundos_de_audio_ya_mezclados + tiempo_desde_la_última_mezcla - latencia_de_salida
##
## - `time_source` devuelve los segundos de audio que el mezclador ya consumió
##   (ver MusicGenerator.get_mixed_seconds()).
## - El tiempo es monótono: nunca retrocede aunque la mezcla llegue a saltos.
## - Si el audio no avanza (sin dispositivo de salida, headless), cae a reloj de pared
##   absoluto (Time.get_ticks_usec, nunca delta acumulado) y avisa.
##
## Emite `tick` cada frame (para posicionar el mundo), y `beat` / `bar` al cruzar cada uno.

signal tick(song_time: float)
signal beat(beat_index: int)
signal bar(bar_index: int)

enum Mode { STOPPED, AUDIO, WALL_CLOCK }

## Corre después de MusicGenerator (que llena el buffer) y antes que el resto.
const PROCESS_PRIORITY: int = -50
const FALLBACK_TIMEOUT_USEC: int = 500_000
const USEC_PER_SEC: float = 1_000_000.0
const SECONDS_PER_MINUTE: float = 60.0

var bpm: float = 120.0
var beats_per_bar: int = 4
## Si es false no se usa AudioServer para compensar latencia (tests).
var compensate_latency: bool = true
var song_time: float = 0.0
var mode: Mode = Mode.STOPPED

var _time_source: Callable = Callable()
var _start_usec: int = 0
var _last_beat: int = -1
var _has_time: bool = false


func _ready() -> void:
	process_priority = PROCESS_PRIORITY


func _process(_delta: float) -> void:
	if mode != Mode.STOPPED:
		update()


## Arranca el reloj. `time_source` debe devolver float (segundos de audio mezclados).
func start(time_source: Callable, p_bpm: float, p_beats_per_bar: int) -> void:
	_time_source = time_source
	bpm = p_bpm
	beats_per_bar = p_beats_per_bar
	_start_usec = Time.get_ticks_usec()
	_last_beat = -1
	_has_time = false
	song_time = 0.0
	mode = Mode.AUDIO


func stop() -> void:
	mode = Mode.STOPPED


func is_running() -> bool:
	return mode != Mode.STOPPED


## Lee el reloj, emite tick y los beats/compases cruzados. Llamado por _process.
func update() -> void:
	var t: float = _read_time()
	if _has_time and t < song_time:
		t = song_time
	song_time = t
	_has_time = true
	tick.emit(song_time)
	_emit_crossed_beats()


func seconds_per_beat() -> float:
	return SECONDS_PER_MINUTE / bpm


func current_beat() -> float:
	return beat_at(song_time, bpm)


func current_latency() -> float:
	return AudioServer.get_output_latency() if compensate_latency else 0.0


## Tiempo de canción compensado. Función pura para poder testearla.
static func compute_song_time(mixed_seconds: float, since_last_mix: float, output_latency: float) -> float:
	return mixed_seconds + since_last_mix - output_latency


static func beat_at(time: float, p_bpm: float) -> float:
	return time * p_bpm / SECONDS_PER_MINUTE


static func time_of_beat(beat_value: float, p_bpm: float) -> float:
	return beat_value * SECONDS_PER_MINUTE / p_bpm


func _read_time() -> float:
	var elapsed_usec: int = Time.get_ticks_usec() - _start_usec
	if mode == Mode.AUDIO:
		var mixed: float = float(_time_source.call())
		if mixed <= 0.0 and elapsed_usec > FALLBACK_TIMEOUT_USEC:
			push_warning("RhythmClock: el audio no avanza; usando reloj de pared como respaldo.")
			mode = Mode.WALL_CLOCK
		else:
			var since_mix: float = AudioServer.get_time_since_last_mix() if compensate_latency else 0.0
			return compute_song_time(mixed, since_mix, current_latency())
	return float(elapsed_usec) / USEC_PER_SEC


func _emit_crossed_beats() -> void:
	var current: int = floori(beat_at(song_time, bpm))
	while _last_beat < current:
		_last_beat += 1
		beat.emit(_last_beat)
		if _last_beat % beats_per_bar == 0:
			bar.emit(floori(float(_last_beat) / float(beats_per_bar)))
