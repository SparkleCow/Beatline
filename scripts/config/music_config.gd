class_name MusicConfig
extends Resource
## Parámetros de la música procedural. Valores en res://resources/music_config.tres.

@export_group("Tempo")
## Tempos posibles (BPM). La semilla elige uno. Fijos entre 110 y 140.
@export var bpm_options: PackedInt32Array = PackedInt32Array([110, 115, 120, 125, 130, 135, 140])
## Beats por compás.
@export var beats_per_bar: int = 4
## Pasos del secuenciador por beat (4 = semicorcheas).
@export var steps_per_beat: int = 4
## Compases que dura el loop pre-renderizado.
@export var loop_bars: int = 2

@export_group("Audio")
## Frecuencia de muestreo del generador. 22050 Hz basta para batería y abarata el render en gama baja.
@export var mix_rate: float = 22050.0
## Tamaño del buffer del AudioStreamGenerator en segundos.
@export var buffer_length: float = 0.15
## Volumen del reproductor.
@export var volume_db: float = -4.0

@export_group("Patrón")
## Probabilidad de un bombo extra en el contratiempo.
@export_range(0.0, 1.0) var extra_kick_probability: float = 0.5
## Probabilidad de redoble de caja al final del loop.
@export_range(0.0, 1.0) var fill_probability: float = 0.6

@export_group("Escalas (hito 2)")
## Pentatónica menor, en semitonos desde la tónica.
@export var scale_pentatonic_minor: PackedInt32Array = PackedInt32Array([0, 3, 5, 7, 10])
## Menor natural (eólica), en semitonos desde la tónica.
@export var scale_natural_minor: PackedInt32Array = PackedInt32Array([0, 2, 3, 5, 7, 8, 10])


## Total de pasos del loop.
func step_count() -> int:
	return loop_bars * beats_per_bar * steps_per_beat
