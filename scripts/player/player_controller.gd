class_name PlayerController
extends Node3D
## Jugador: cambio de carril interpolado y salto parabólico.
##
## Toda la animación se evalúa con el tiempo de canción (RhythmClock.tick), igual que los
## obstáculos, para que la colisión sea coherente con la música aunque haya tirones de frames.
## Recibe órdenes por métodos conectados a señales de InputHandler; no conoce a otros sistemas.

signal moved(position: Vector3, size: Vector3)
signal lane_changed(lane: int)
signal jumped
signal landed

const TRAIL_AMOUNT: int = 28
const TRAIL_LIFETIME: float = 0.35
const TRAIL_PARTICLE_SIZE: float = 0.22
const BURST_AMOUNT: int = 48
const BURST_LIFETIME: float = 0.9
const BURST_SPEED: Vector2 = Vector2(4.0, 11.0)
const BURST_PARTICLE_SIZE: float = 0.18
const PARTICLE_GLOW: float = 3.0
const GRAVITY: Vector3 = Vector3(0.0, -14.0, 0.0)

var lane: int = 1
var alive: bool = true

var _game: GameConfig
var _jump_time: float = 0.5
var _song_time: float = 0.0
var _from_x: float = 0.0
var _to_x: float = 0.0
var _change_start: float = -INF
var _jump_start: float = -INF
var _buffered_jump_at: float = -INF
var _airborne: bool = false
var _mesh_instance: MeshInstance3D
var _trail: CPUParticles3D
var _burst: CPUParticles3D
var _speed: float = 14.0


func setup(game: GameConfig, bpm: float) -> void:
	_game = game
	_jump_time = RhythmClock.time_of_beat(game.jump_duration_beats, bpm)
	_speed = game.scroll_speed(bpm)
	if _mesh_instance == null:
		_build_mesh()
		_build_particles()
	_trail.initial_velocity_min = _speed
	_trail.initial_velocity_max = _speed
	reset()


func reset() -> void:
	lane = _game.center_lane()
	alive = true
	_song_time = 0.0
	_from_x = _game.lane_x(lane)
	_to_x = _from_x
	_change_start = -INF
	_jump_start = -INF
	_buffered_jump_at = -INF
	_airborne = false
	position = Vector3(_from_x, _game.player_size.y * 0.5, 0.0)
	_mesh_instance.visible = true
	_trail.emitting = true


func set_dead() -> void:
	alive = false
	_mesh_instance.visible = false
	_trail.emitting = false
	_burst.restart()
	_burst.emitting = true


## Conectado a InputHandler.lane_change_requested.
func request_lane_change(direction: int) -> void:
	if not alive:
		return
	var target: int = clampi(lane + direction, 0, _game.lane_count - 1)
	if target == lane:
		return
	lane = target
	_from_x = position.x
	_to_x = _game.lane_x(lane)
	_change_start = _song_time
	lane_changed.emit(lane)


## Conectado a InputHandler.jump_requested.
func request_jump() -> void:
	if not alive:
		return
	if _airborne:
		_buffered_jump_at = _song_time
		return
	_start_jump()


## Conectado a RhythmClock.tick.
func on_tick(song_time: float) -> void:
	_song_time = song_time
	if not alive:
		return
	var x: float = _to_x
	if _game.lane_change_time > 0.0:
		var p: float = clampf((song_time - _change_start) / _game.lane_change_time, 0.0, 1.0)
		x = lerpf(_from_x, _to_x, ease_out(p))

	var y: float = 0.0
	if _airborne:
		var jp: float = (song_time - _jump_start) / _jump_time
		if jp >= 1.0:
			_airborne = false
			landed.emit()
			if song_time - _buffered_jump_at <= _game.jump_buffer_time:
				_start_jump()
		else:
			y = 4.0 * _game.jump_height * jp * (1.0 - jp)

	position = Vector3(x, y + _game.player_size.y * 0.5, 0.0)
	moved.emit(position, _game.player_size)


## Curva de salida cuadrática: rápida al inicio, suave al llegar.
static func ease_out(p: float) -> float:
	return 1.0 - (1.0 - p) * (1.0 - p)


func _start_jump() -> void:
	_airborne = true
	_jump_start = _song_time
	_buffered_jump_at = -INF
	jumped.emit()


func _build_particles() -> void:
	# Estela: partículas en coordenadas de mundo que viajan con el suelo (+Z) a la velocidad del día.
	_trail = _make_particles("Trail", TRAIL_AMOUNT, TRAIL_LIFETIME, TRAIL_PARTICLE_SIZE, NeonPalette.CYAN)
	_trail.direction = Vector3(0.0, 0.0, 1.0)
	_trail.spread = 4.0
	_trail.initial_velocity_min = _speed
	_trail.initial_velocity_max = _speed
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_trail.emission_box_extents = _game.player_size * 0.4
	_trail.gravity = Vector3.ZERO
	_trail.scale_amount_curve = _shrink_curve()
	# Explosión al morir.
	_burst = _make_particles("Burst", BURST_AMOUNT, BURST_LIFETIME, BURST_PARTICLE_SIZE, NeonPalette.PINK)
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.emitting = false
	_burst.direction = Vector3.UP
	_burst.spread = 180.0
	_burst.initial_velocity_min = BURST_SPEED.x
	_burst.initial_velocity_max = BURST_SPEED.y
	_burst.gravity = GRAVITY
	_burst.scale_amount_curve = _shrink_curve()


func _make_particles(node_name: String, amount: int, lifetime: float, size: float, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	mesh.material = NeonPalette.solid_material(color, PARTICLE_GLOW)
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


static func _shrink_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


func _build_mesh() -> void:
	var box := BoxMesh.new()
	box.size = _game.player_size
	var mat: ShaderMaterial = NeonPalette.edges_material(NeonPalette.WHITE, _game.player_size)
	mat.set_shader_parameter(&"fill_strength", 0.6)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Body"
	_mesh_instance.mesh = box
	_mesh_instance.material_override = mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
