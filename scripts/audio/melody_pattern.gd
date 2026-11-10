class_name MelodyPattern
extends RefCounted
## Bajo y arpegio darkwave por pasos, en menor natural, siguiendo una progresión de acordes.
## Cada arreglo guarda una nota MIDI por paso, o NO_NOTE. Determinista desde el RNG musical.

const NO_NOTE: int = -1
const SEMITONES_PER_OCTAVE: int = 12
## Grados (desde la fundamental del acorde) que forman el arpegio: 1ª, 3ª, 5ª y octava.
const CHORD_DEGREES: Array[int] = [0, 2, 4, 7]
## Formas de arpegio: índices en CHORD_DEGREES.
const ARP_SHAPES: Array[Array] = [
	[0, 1, 2, 3],
	[0, 1, 2, 3, 2, 1],
	[3, 2, 1, 0],
	[0, 2, 1, 3, 1, 2],
]
const HALF_BEAT_STEPS_DIVISOR: int = 2

var step_count: int = 0
var root_midi: int = 33
var progression: PackedInt32Array = PackedInt32Array()
var bass: PackedInt32Array = PackedInt32Array()
var arp: PackedInt32Array = PackedInt32Array()


static func generate(rng: RandomNumberGenerator, cfg: MusicConfig) -> MelodyPattern:
	var m := MelodyPattern.new()
	m.step_count = cfg.step_count()
	m.root_midi = cfg.root_midi_options[rng.randi_range(0, cfg.root_midi_options.size() - 1)]
	m.progression = cfg.progressions[rng.randi_range(0, cfg.progressions.size() - 1)]
	var shape: Array = ARP_SHAPES[rng.randi_range(0, ARP_SHAPES.size() - 1)]
	var gallop: bool = rng.randf() < cfg.bass_gallop_probability
	var scale: PackedInt32Array = cfg.scale_natural_minor
	var steps_per_bar: int = cfg.beats_per_bar * cfg.steps_per_beat
	var half_beat: int = maxi(1, floori(float(cfg.steps_per_beat) / HALF_BEAT_STEPS_DIVISOR))
	m.bass.resize(m.step_count)
	m.arp.resize(m.step_count)

	for step: int in m.step_count:
		var bar: int = floori(float(step) / float(steps_per_bar))
		var chord_degree: int = m.progression[bar % m.progression.size()]
		var chord_root: int = m.root_midi + degree_to_semitones(chord_degree, scale)
		var in_beat: int = step % cfg.steps_per_beat
		# Bajo: corcheas constantes (o galope x.xx) con saltos de octava en contratiempo.
		var plays_bass: bool = in_beat % half_beat == 0 or (gallop and in_beat == cfg.steps_per_beat - 1)
		if plays_bass:
			var octave_up: bool = in_beat != 0 and rng.randf() < cfg.bass_octave_probability
			m.bass[step] = chord_root + (SEMITONES_PER_OCTAVE if octave_up else 0)
		else:
			m.bass[step] = NO_NOTE
		# Arpegio en semicorcheas, con silencios ocasionales.
		if rng.randf() < cfg.arp_rest_probability:
			m.arp[step] = NO_NOTE
		else:
			var idx: int = shape[step % shape.size()]
			m.arp[step] = chord_root + cfg.arp_octave_offset + degree_to_semitones(chord_degree + CHORD_DEGREES[idx], scale) \
					- degree_to_semitones(chord_degree, scale)
	return m


## Grado de escala (puede pasar de la octava) a semitonos desde la tónica.
static func degree_to_semitones(degree: int, scale: PackedInt32Array) -> int:
	var n: int = scale.size()
	return scale[posmod(degree, n)] + SEMITONES_PER_OCTAVE * floori(float(degree) / float(n))


static func midi_to_freq(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)
