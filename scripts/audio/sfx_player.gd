class_name SfxPlayer
extends Node
## Efectos de sonido sintetizados por código (cero samples externos): salto, carril,
## aterrizaje, gema, rampa, choque, caída y nivel superado.
##
## Cada efecto se renderiza una vez al arrancar a un AudioStreamWAV y se reproduce con un
## pequeño pool de AudioStreamPlayer (sin crear nodos en partida). Va por el bus "SFX".

enum Sfx { JUMP, LANE, LAND, GEM, RAMP, CRASH, FALL, CLEAR, CLICK }

const BUS_NAME: StringName = &"SFX"
const MIX_RATE: float = 22050.0
const VOICES: int = 5
const PEAK_16_BIT: float = 32767.0
const BYTES_PER_SAMPLE: int = 2
## Volumen relativo de los efectos respecto a la música.
const VOLUME_DB: float = -5.0

var _streams: Dictionary[int, AudioStreamWAV] = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
	ensure_bus()
	for id: int in Sfx.values():
		_streams[id] = _to_stream(render(id, MIX_RATE))
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.bus = BUS_NAME
		player.volume_db = VOLUME_DB
		add_child(player)
		_players.append(player)


func play(id: int) -> void:
	if _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = _streams[id]
	player.play()


## Atajos para conectar señales sin argumentos (o con argumentos que no importan).
func play_jump() -> void:
	play(Sfx.JUMP)


func play_lane(_lane: int = 0) -> void:
	play(Sfx.LANE)


func play_land() -> void:
	play(Sfx.LAND)


func play_gem(_total: int = 0) -> void:
	play(Sfx.GEM)


func play_ramp() -> void:
	play(Sfx.RAMP)


func play_click() -> void:
	play(Sfx.CLICK)


## Crea el bus de efectos si el proyecto no lo define (sale por Master).
static func ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS_NAME)
	AudioServer.set_bus_send(index, &"Master")


## Renderiza un efecto a muestras mono en [-1, 1]. Función pura (testeable).
static func render(id: int, rate: float) -> PackedFloat32Array:
	match id:
		Sfx.JUMP:
			return _sweep(rate, 0.13, 300.0, 760.0, 0.0, 9.0, 0.7)
		Sfx.LANE:
			return _sweep(rate, 0.05, 920.0, 640.0, 1.0, 30.0, 0.35)
		Sfx.LAND:
			return _mix(_sweep(rate, 0.09, 150.0, 55.0, 0.0, 22.0, 0.8), _noise(rate, 0.04, 60.0, 0.25, 11))
		Sfx.GEM:
			return _concat(_sweep(rate, 0.06, 1318.5, 1318.5, 1.0, 14.0, 0.4),
					_sweep(rate, 0.16, 1975.5, 1975.5, 1.0, 12.0, 0.4))
		Sfx.RAMP:
			return _sweep(rate, 0.4, 180.0, 1500.0, 1.0, 4.0, 0.45)
		Sfx.CRASH:
			return _mix(_noise(rate, 0.5, 7.0, 0.8, 23), _sweep(rate, 0.5, 110.0, 35.0, 0.0, 6.0, 0.9))
		Sfx.FALL:
			return _sweep(rate, 0.7, 760.0, 70.0, 0.0, 2.5, 0.7)
		Sfx.CLEAR:
			var out := PackedFloat32Array()
			for freq: float in [523.25, 659.25, 783.99, 1046.5]:
				out = _concat(out, _sweep(rate, 0.11, freq, freq, 1.0, 7.0, 0.4))
			return out
		Sfx.CLICK:
			return _sweep(rate, 0.03, 1200.0, 900.0, 1.0, 40.0, 0.3)
	return PackedFloat32Array()


## Barrido de frecuencia con caída exponencial. `square` mezcla seno (0) con cuadrada (1).
static func _sweep(rate: float, length: float, from_hz: float, to_hz: float, square: float,
		decay: float, gain: float) -> PackedFloat32Array:
	var count: int = int(length * rate)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	for i: int in count:
		var p: float = float(i) / float(count)
		phase += lerpf(from_hz, to_hz, p) / rate
		var sine: float = sin(phase * TAU)
		var value: float = lerpf(sine, signf(sine), square)
		# Rampa final corta para que no haga "clic" al cortar.
		out[i] = value * gain * exp(-p * length * decay) * minf(1.0, (1.0 - p) * 20.0)
	return out


static func _noise(rate: float, length: float, decay: float, gain: float, noise_seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	var count: int = int(length * rate)
	var out := PackedFloat32Array()
	out.resize(count)
	for i: int in count:
		var t: float = float(i) / rate
		out[i] = rng.randf_range(-1.0, 1.0) * gain * exp(-t * decay)
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(a.size(), b.size()))
	for i: int in out.size():
		var value: float = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
		out[i] = clampf(value, -1.0, 1.0)
	return out


static func _concat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = a.duplicate()
	out.append_array(b)
	return out


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * BYTES_PER_SAMPLE)
	for i: int in samples.size():
		bytes.encode_s16(i * BYTES_PER_SAMPLE, int(clampf(samples[i], -1.0, 1.0) * PEAK_16_BIT))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(MIX_RATE)
	stream.stereo = false
	stream.data = bytes
	return stream
