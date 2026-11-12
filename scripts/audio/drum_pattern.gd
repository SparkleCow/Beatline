class_name DrumPattern
extends RefCounted
## Patrón de batería por pasos (secuenciador). Cada arreglo guarda la velocidad 0..1 por paso
## (0 = silencio). Se genera de forma determinista con el RNG de la semilla musical.

enum HatStyle { EIGHTHS, SIXTEENTHS, OFFBEAT_OPEN }

const VELOCITY_FULL: float = 1.0
const VELOCITY_GHOST: float = 0.55
const VELOCITY_HAT_ACCENT: float = 0.8
const VELOCITY_HAT: float = 0.45
const VELOCITY_FILL: float = 0.7
## Beats del compás con caja (backbeat: 2 y 4, base 0).
const SNARE_BEATS: Array[int] = [1, 3]
## Pasos (dentro del compás, semicorcheas) candidatos para bombo extra.
const EXTRA_KICK_STEPS: Array[int] = [10, 14]
## Cuántas semicorcheas finales del loop pueden llevar redoble.
const FILL_STEPS: int = 3
const HALF_BEAT_DIVISOR: int = 2

var step_count: int = 0
var steps_per_beat: int = 4
var hat_style: HatStyle = HatStyle.EIGHTHS
var kick: PackedFloat32Array = PackedFloat32Array()
var snare: PackedFloat32Array = PackedFloat32Array()
var hat: PackedFloat32Array = PackedFloat32Array()
var open_hat: PackedFloat32Array = PackedFloat32Array()


static func generate(rng: RandomNumberGenerator, cfg: MusicConfig) -> DrumPattern:
	var p := DrumPattern.new()
	p.step_count = cfg.step_count()
	p.steps_per_beat = cfg.steps_per_beat
	p.kick.resize(p.step_count)
	p.snare.resize(p.step_count)
	p.hat.resize(p.step_count)
	p.open_hat.resize(p.step_count)

	p.hat_style = rng.randi_range(0, HatStyle.size() - 1) as HatStyle
	var steps_per_bar: int = cfg.beats_per_bar * cfg.steps_per_beat
	var half_beat: int = floori(float(cfg.steps_per_beat) / HALF_BEAT_DIVISOR)

	for bar_index: int in cfg.loop_bars:
		var bar_start: int = bar_index * steps_per_bar
		# Bombo en cada beat: el pulso siempre es claro (manda el ritmo).
		for b: int in cfg.beats_per_bar:
			p.kick[bar_start + b * cfg.steps_per_beat] = VELOCITY_FULL
		for b: int in SNARE_BEATS:
			if b < cfg.beats_per_bar:
				p.snare[bar_start + b * cfg.steps_per_beat] = VELOCITY_FULL
		if rng.randf() < cfg.extra_kick_probability:
			var extra: int = EXTRA_KICK_STEPS[rng.randi_range(0, EXTRA_KICK_STEPS.size() - 1)]
			if extra < steps_per_bar:
				p.kick[bar_start + extra] = VELOCITY_GHOST
		for s: int in steps_per_bar:
			var step: int = bar_start + s
			var on_beat: bool = s % cfg.steps_per_beat == 0
			var on_half: bool = half_beat > 0 and s % half_beat == 0
			match p.hat_style:
				HatStyle.EIGHTHS:
					if on_half:
						p.hat[step] = VELOCITY_HAT_ACCENT if on_beat else VELOCITY_HAT
				HatStyle.SIXTEENTHS:
					p.hat[step] = VELOCITY_HAT_ACCENT if on_half else VELOCITY_HAT
				HatStyle.OFFBEAT_OPEN:
					if on_half and not on_beat:
						p.open_hat[step] = VELOCITY_HAT_ACCENT
					elif on_beat:
						p.hat[step] = VELOCITY_HAT

	if rng.randf() < cfg.fill_probability:
		for i: int in FILL_STEPS:
			var step: int = p.step_count - 1 - i
			p.snare[step] = maxf(p.snare[step], VELOCITY_FILL)
	return p
