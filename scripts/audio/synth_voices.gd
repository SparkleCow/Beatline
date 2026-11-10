class_name SynthVoices
extends RefCounted
## Voces sintetizadas por código (sin samples externos) y render del loop.
##
## Estrategia de rendimiento: cada voz se sintetiza UNA vez como "one-shot" y luego se
## suma al loop en su posición. El loop completo se pre-renderiza al iniciar; durante el
## juego solo se copian bloques de memoria al AudioStreamGenerator.

const TAU_F: float = TAU

const KICK_LENGTH: float = 0.35
const KICK_FREQ_END: float = 48.0
const KICK_FREQ_SWEEP: float = 110.0
const KICK_SWEEP_DECAY: float = 28.0
const KICK_AMP_DECAY: float = 7.0
const KICK_GAIN: float = 0.9

const SNARE_LENGTH: float = 0.2
const SNARE_TONE_FREQ: float = 185.0
const SNARE_TONE_DECAY: float = 24.0
const SNARE_NOISE_DECAY: float = 18.0
const SNARE_TONE_GAIN: float = 0.35
const SNARE_NOISE_GAIN: float = 0.5

const HAT_LENGTH: float = 0.05
const HAT_DECAY: float = 70.0
const OPEN_HAT_LENGTH: float = 0.18
const OPEN_HAT_DECAY: float = 16.0
const HAT_GAIN: float = 0.25

const MASTER_GAIN: float = 0.8
const NOISE_SALT: int = 0x5EED


static func kick(rate: float) -> PackedFloat32Array:
	var n: int = roundi(KICK_LENGTH * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / rate
		var freq: float = KICK_FREQ_END + KICK_FREQ_SWEEP * exp(-t * KICK_SWEEP_DECAY)
		phase += TAU_F * freq / rate
		out[i] = sin(phase) * exp(-t * KICK_AMP_DECAY) * KICK_GAIN
	return out


static func snare(rate: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = roundi(SNARE_LENGTH * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / rate
		var tone: float = sin(TAU_F * SNARE_TONE_FREQ * t) * exp(-t * SNARE_TONE_DECAY) * SNARE_TONE_GAIN
		var noise: float = rng.randf_range(-1.0, 1.0) * exp(-t * SNARE_NOISE_DECAY) * SNARE_NOISE_GAIN
		out[i] = tone + noise
	return out


## Hi-hat: ruido blanco con un pasa-altos de primer orden (diferencia) y caída exponencial.
static func hat(rate: float, rng: RandomNumberGenerator, length: float, decay: float) -> PackedFloat32Array:
	var n: int = roundi(length * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev: float = 0.0
	for i: int in n:
		var t: float = float(i) / rate
		var white: float = rng.randf_range(-1.0, 1.0)
		out[i] = (white - prev) * 0.5 * exp(-t * decay) * HAT_GAIN
		prev = white
	return out


## Frames exactos del loop para un tempo dado.
static func loop_frame_count(pattern: DrumPattern, bpm: float, rate: float) -> int:
	return roundi(_step_frames(pattern, bpm, rate) * float(pattern.step_count))


## Renderiza el patrón completo como buffer estéreo listo para push_buffer().
static func render_pattern(pattern: DrumPattern, bpm: float, rate: float, noise_seed: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed ^ NOISE_SALT
	var kick_s: PackedFloat32Array = kick(rate)
	var snare_s: PackedFloat32Array = snare(rate, rng)
	var hat_s: PackedFloat32Array = hat(rate, rng, HAT_LENGTH, HAT_DECAY)
	var open_s: PackedFloat32Array = hat(rate, rng, OPEN_HAT_LENGTH, OPEN_HAT_DECAY)

	var total: int = loop_frame_count(pattern, bpm, rate)
	var step_frames: float = _step_frames(pattern, bpm, rate)
	var mono := PackedFloat32Array()
	mono.resize(total)
	var voices: Array[PackedFloat32Array] = [kick_s, snare_s, hat_s, open_s]
	var velocities: Array[PackedFloat32Array] = [pattern.kick, pattern.snare, pattern.hat, pattern.open_hat]
	# Los Packed*Array se pasan por copia (COW) a funciones: la suma va en línea a propósito.
	for step: int in pattern.step_count:
		var offset: int = roundi(step_frames * float(step))
		for v: int in voices.size():
			var velocity: float = velocities[v][step]
			if velocity <= 0.0:
				continue
			var sample: PackedFloat32Array = voices[v]
			# La cola que pasa del final da la vuelta: el loop no tiene cortes.
			for i: int in sample.size():
				var idx: int = (offset + i) % total
				mono[idx] += sample[i] * velocity

	var out := PackedVector2Array()
	out.resize(total)
	for i: int in total:
		var v: float = clampf(mono[i] * MASTER_GAIN, -1.0, 1.0)
		out[i] = Vector2(v, v)
	return out


static func _step_frames(pattern: DrumPattern, bpm: float, rate: float) -> float:
	return rate * (60.0 / bpm) / float(pattern.steps_per_beat)

