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

## Caja "gated" ochentera: cola de ruido larga que se corta de golpe.
const SNARE_LENGTH: float = 0.32
const SNARE_TONE_FREQ: float = 185.0
const SNARE_TONE_DECAY: float = 22.0
const SNARE_NOISE_DECAY: float = 7.0
const SNARE_GATE: float = 0.26
const SNARE_TONE_GAIN: float = 0.4
const SNARE_NOISE_GAIN: float = 0.55

const BASS_LENGTH: float = 0.2
const BASS_DETUNE: float = 1.007
const BASS_CUTOFF_BASE: float = 180.0
const BASS_CUTOFF_ENV: float = 1600.0
const BASS_CUTOFF_DECAY: float = 18.0
const BASS_AMP_DECAY: float = 6.0
const BASS_GAIN: float = 0.42

const ARP_LENGTH: float = 0.22
const ARP_DUTY: float = 0.3
const ARP_AMP_DECAY: float = 11.0
const ARP_CUTOFF: float = 3500.0
const ARP_GAIN: float = 0.2

const ATTACK_TIME: float = 0.003
const VOICE_BASS: String = "b"
const VOICE_ARP: String = "a"

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
		var gate: float = 1.0 if t < SNARE_GATE else 0.0
		var noise: float = rng.randf_range(-1.0, 1.0) * exp(-t * SNARE_NOISE_DECAY) * SNARE_NOISE_GAIN * gate
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


## Bajo: dos sierras desafinadas con pasa-bajos de envolvente (sonido darkwave).
static func bass_note(rate: float, freq: float) -> PackedFloat32Array:
	var n: int = roundi(BASS_LENGTH * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var p1: float = 0.0
	var p2: float = 0.0
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / rate
		p1 = fmod(p1 + freq / rate, 1.0)
		p2 = fmod(p2 + freq * BASS_DETUNE / rate, 1.0)
		var raw: float = (p1 * 2.0 - 1.0) + (p2 * 2.0 - 1.0)
		var cutoff: float = BASS_CUTOFF_BASE + BASS_CUTOFF_ENV * exp(-t * BASS_CUTOFF_DECAY)
		lp += (1.0 - exp(-TAU_F * cutoff / rate)) * (raw - lp)
		out[i] = lp * _envelope(t, BASS_AMP_DECAY) * BASS_GAIN
	return out


## Arpegio: onda de pulso filtrada, corta y brillante.
static func arp_note(rate: float, freq: float) -> PackedFloat32Array:
	var n: int = roundi(ARP_LENGTH * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	var alpha: float = 1.0 - exp(-TAU_F * ARP_CUTOFF / rate)
	for i: int in n:
		var t: float = float(i) / rate
		phase = fmod(phase + freq / rate, 1.0)
		var raw: float = 1.0 if phase < ARP_DUTY else -1.0
		lp += alpha * (raw - lp)
		out[i] = lp * _envelope(t, ARP_AMP_DECAY) * ARP_GAIN
	return out


static func _envelope(t: float, decay: float) -> float:
	return minf(t / ATTACK_TIME, 1.0) * exp(-t * decay)


static func _cached(cache: Dictionary, voice: String, midi: int, rate: float) -> PackedFloat32Array:
	var key: String = "%s%d" % [voice, midi]
	if not cache.has(key):
		var freq: float = MelodyPattern.midi_to_freq(midi)
		cache[key] = bass_note(rate, freq) if voice == VOICE_BASS else arp_note(rate, freq)
	return cache[key]


## Frames exactos del loop para un tempo dado.
static func loop_frame_count(pattern: DrumPattern, bpm: float, rate: float) -> int:
	return roundi(_step_frames(pattern, bpm, rate) * float(pattern.step_count))


## Renderiza el patrón completo como buffer estéreo listo para push_buffer().
static func render_pattern(pattern: DrumPattern, melody: MelodyPattern, cfg: MusicConfig, bpm: float,
		noise_seed: int) -> PackedVector2Array:
	var rate: float = cfg.mix_rate
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

	# Bajo y arpegio (con eco de corchea con puntillo). One-shots cacheados por nota.
	var cache: Dictionary = {}
	for step: int in pattern.step_count:
		var offset: int = roundi(step_frames * float(step))
		var hits: Array[Array] = []
		if melody.bass[step] != MelodyPattern.NO_NOTE:
			hits.append([_cached(cache, VOICE_BASS, melody.bass[step], rate), offset, 1.0])
		if melody.arp[step] != MelodyPattern.NO_NOTE:
			var arp_sample: PackedFloat32Array = _cached(cache, VOICE_ARP, melody.arp[step], rate)
			hits.append([arp_sample, offset, 1.0])
			hits.append([arp_sample, roundi(step_frames * float(step + cfg.echo_steps)), cfg.echo_gain])
		for hit: Array in hits:
			var sample: PackedFloat32Array = hit[0]
			var start: int = hit[1]
			var gain: float = hit[2]
			for i: int in sample.size():
				var idx: int = (start + i) % total
				mono[idx] += sample[i] * gain

	var out := PackedVector2Array()
	out.resize(total)
	for i: int in total:
		# Saturación suave: más fuerte sin recortar feo.
		var v: float = tanh(mono[i] * MASTER_GAIN * cfg.drive)
		out[i] = Vector2(v, v)
	return out


static func _step_frames(pattern: DrumPattern, bpm: float, rate: float) -> float:
	return rate * (60.0 / bpm) / float(pattern.steps_per_beat)

