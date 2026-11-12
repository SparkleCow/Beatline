class_name NeonFx
extends Node
## Efectos globales sincronizados al ritmo: pulso por beat, desplazamiento del suelo
## e índice de compás (para los shaders). La cámara NO late: el FOV es fijo (ver CameraRig).
## Todo se deriva de song_time (señal RhythmClock.tick), nunca de delta.

const PARAM_PULSE: StringName = &"beat_pulse"
const PARAM_SCROLL: StringName = &"world_scroll"
const PARAM_BAR: StringName = &"bar_index"
## Qué tan rápido se apaga el pulso dentro del beat (más alto = más seco).
const PULSE_DECAY: float = 5.0

var _bpm: float = 120.0
var _speed: float = 14.0
var _beats_per_bar: int = 4


func setup(bpm: float, speed: float, beats_per_bar: int) -> void:
	_bpm = bpm
	_speed = speed
	_beats_per_bar = beats_per_bar
	on_tick(0.0)


## Conectado a RhythmClock.tick.
func on_tick(song_time: float) -> void:
	var beat_value: float = RhythmClock.beat_at(song_time, _bpm)
	var pulse: float = pulse_at(beat_value) if song_time >= 0.0 else 0.0
	RenderingServer.global_shader_parameter_set(PARAM_PULSE, pulse)
	RenderingServer.global_shader_parameter_set(PARAM_SCROLL, song_time * _speed)
	RenderingServer.global_shader_parameter_set(PARAM_BAR, floorf(beat_value / float(_beats_per_bar)))


## Apaga el pulso (al morir).
func calm() -> void:
	RenderingServer.global_shader_parameter_set(PARAM_PULSE, 0.0)


## 1.0 justo en el beat, decae exponencialmente hasta el siguiente.
static func pulse_at(beat_value: float) -> float:
	return exp(-fposmod(beat_value, 1.0) * PULSE_DECAY)
