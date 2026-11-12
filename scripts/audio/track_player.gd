class_name TrackPlayer
extends Node
## Reproduce una pista .ogg en loop y expone su posición como fuente del RhythmClock.
##
## Misma interfaz que MusicGenerator (bpm, play_from_start, stop, get_mixed_seconds), así
## GameManager puede usar una u otra. La posición es monótona aunque la pista haga loop.

var bpm: float = 0.0
var title: String = ""

var _player: AudioStreamPlayer
var _length: float = 0.0
var _loops: int = 0
var _last_position: float = 0.0


## Carga la pista. Devuelve false si no se pudo (el llamador cae a la música procedural).
func setup(track: TrackLibrary.Track, volume_db: float) -> bool:
	var stream: AudioStream = load(track.path) as AudioStream
	if stream == null:
		push_warning("TrackPlayer: no se pudo cargar '%s'." % track.path)
		return false
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "TrackStream"
		add_child(_player)
	_player.stream = stream
	_player.volume_db = volume_db
	_length = stream.get_length()
	bpm = track.bpm
	title = track.title
	return true


func play_from_start() -> void:
	if _player == null:
		return
	_loops = 0
	_last_position = 0.0
	_player.play(0.0)


func stop() -> void:
	if _player:
		_player.stop()


## Segundos de pista ya mezclados, acumulando las vueltas del loop.
func get_mixed_seconds() -> float:
	if _player == null or not _player.playing:
		return 0.0
	var position: float = _player.get_playback_position()
	if position < _last_position - _length * 0.5:
		_loops += 1
	_last_position = position
	return float(_loops) * _length + position
