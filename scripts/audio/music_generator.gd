class_name MusicGenerator
extends Node
## Música procedural del día (hito 1: patrón de batería).
##
## Usa un AudioStreamGenerator alimentado con un loop pre-renderizado desde la semilla.
## Lleva la cuenta exacta de frames empujados para que RhythmClock sepa cuánto audio
## ya consumió el mezclador: esa es la fuente de verdad del ritmo.

signal music_started(bpm: float)
signal music_stopped

## Corre antes que RhythmClock para que el buffer esté lleno cuando se lee el reloj.
const PROCESS_PRIORITY: int = -100

var config: MusicConfig
var bpm: float = 0.0
var pattern: DrumPattern

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _loop: PackedVector2Array = PackedVector2Array()
var _read_index: int = 0
var _frames_pushed: int = 0
var _capacity: int = 0


func _ready() -> void:
	process_priority = PROCESS_PRIORITY


func _process(_delta: float) -> void:
	fill_buffer()


func _notification(what: int) -> void:
	# Al cerrar, soltar la reproducción antes de que el AudioServer se apague (evita fugas).
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_release_playback()


func _exit_tree() -> void:
	_release_playback()


func _release_playback() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()
		_player.stream = null
	_playback = null


## Prepara tempo y loop a partir de la semilla musical. Costoso: llamar una vez por semilla.
func setup(cfg: MusicConfig, music_seed: int) -> void:
	config = cfg
	var rng := RandomNumberGenerator.new()
	rng.seed = music_seed
	bpm = choose_bpm(rng, cfg)
	pattern = DrumPattern.generate(rng, cfg)
	_loop = SynthVoices.render_pattern(pattern, bpm, cfg.mix_rate, music_seed)
	_ensure_player()


## Elige el tempo de la lista de la configuración.
static func choose_bpm(rng: RandomNumberGenerator, cfg: MusicConfig) -> float:
	return float(cfg.bpm_options[rng.randi_range(0, cfg.bpm_options.size() - 1)])


## Reinicia la reproducción desde el frame 0 (reinicio instantáneo, sin re-renderizar).
func play_from_start() -> void:
	_ensure_player()
	_player.stop()
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_read_index = 0
	_frames_pushed = 0
	_capacity = _playback.get_frames_available() if _playback else 0
	fill_buffer()
	music_started.emit(bpm)


func stop() -> void:
	if _player:
		_player.stop()
	_playback = null
	music_stopped.emit()


## Segundos de audio ya consumidos por el mezclador (empujados - en cola).
func get_mixed_seconds() -> float:
	if _playback == null or config == null:
		return 0.0
	var queued: int = _capacity - _playback.get_frames_available()
	return float(_frames_pushed - queued) / config.mix_rate


func get_loop() -> PackedVector2Array:
	return _loop


func fill_buffer() -> void:
	if _playback == null or _loop.is_empty():
		return
	var free: int = _playback.get_frames_available()
	while free > 0:
		var chunk: int = mini(free, _loop.size() - _read_index)
		_playback.push_buffer(_loop.slice(_read_index, _read_index + chunk))
		_read_index = (_read_index + chunk) % _loop.size()
		_frames_pushed += chunk
		free -= chunk


func _ensure_player() -> void:
	if _player != null:
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = config.mix_rate
	stream.buffer_length = config.buffer_length
	_player = AudioStreamPlayer.new()
	_player.name = "GeneratorPlayer"
	_player.stream = stream
	_player.volume_db = config.volume_db
	add_child(_player)
