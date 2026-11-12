class_name PlayerController
extends Node3D
## Jugador: cambio de carril interpolado, salto balístico de altura variable, caídas y
## animación del cubo (inclinación, giro, squash & stretch).
##
## Todo se evalúa con el tiempo de canción (RhythmClock.tick), igual que los obstáculos,
## para que la colisión sea coherente con la música aunque haya tirones de frames.
## El aire se modela por tramos balísticos: y = y0 + v0·τ − ½·g·τ², con τ = song_time − t0.
## Recibe órdenes por métodos conectados a señales de InputHandler; no conoce a otros sistemas.

signal moved(position: Vector3, size: Vector3)
signal lane_changed(lane: int)
signal jumped
signal landed
## Súper salto de rampa.
signal launched
## Cayó al vacío (hueco o borde sin riel) más allá de la profundidad de derrota.
signal fell

const TRAIL_AMOUNT: int = 28
const TRAIL_LIFETIME: float = 0.35
const TRAIL_PARTICLE_SIZE: float = 0.22
const BURST_AMOUNT: int = 48
const BURST_LIFETIME: float = 0.9
const BURST_SPEED: Vector2 = Vector2(4.0, 11.0)
const BURST_PARTICLE_SIZE: float = 0.18
const DUST_AMOUNT: int = 12
const DUST_LIFETIME: float = 0.3
const DUST_SPEED: Vector2 = Vector2(2.0, 4.5)
const DUST_PARTICLE_SIZE: float = 0.12
const PARTICLE_GLOW: float = 3.0
const GRAVITY: Vector3 = Vector3(0.0, -14.0, 0.0)
## Inclinación máxima (rad) hacia el lado del cambio de carril.
const TILT_MAX: float = 0.45
## Un salto normal da un cuarto de vuelta hacia adelante; la rampa, una vuelta entera.
const JUMP_SPIN: float = PI * 0.5
const RAMP_SPIN: float = TAU
## Estiramiento vertical máximo en el aire y aplastamiento al aterrizar.
const STRETCH_MAX: float = 0.22
const SQUASH_AMOUNT: float = 0.32
## Rapidez con que se recupera del aplastamiento (1/s).
const SQUASH_RECOVERY: float = 14.0
const GROUND_EPSILON: float = 0.001

var lane: int = 1
var alive: bool = true
## (x: float, song_time: float) -> float. Altura del suelo; -INF = vacío. Lo cablea GameManager
## con ObstacleSpawner.ground_height_at. Sin asignar, el suelo es plano.
var ground_query: Callable = Callable()
## True mientras la pista no tiene rieles: salirse del borde hace caer.
var edges_open: bool = false

var _game: GameConfig
var _jump_time: float = 0.5
var _song_time: float = 0.0
var _from_x: float = 0.0
var _to_x: float = 0.0
var _change_start: float = -INF
var _change_dir: int = 0
var _buffered_jump_at: float = -INF
var _airborne: bool = false
## Altura del suelo que pisa (0 = pista, >0 = plataforma).
var _ground_y: float = 0.0
## Tramo balístico actual.
var _air_t0: float = 0.0
var _air_y0: float = 0.0
var _air_v0: float = 0.0
var _air_gravity: float = 30.0
var _last_y: float = 0.0
## El salto actual se puede recortar al soltar (no aplica a rampas ni caídas).
var _can_cut: bool = false
var _off_track: bool = false
var _fell_emitted: bool = false
## Gravedad y velocidad inicial del salto normal (derivadas de altura y duración).
var _gravity: float = 30.0
var _jump_v0: float = 8.0
## Giro en el aire: interpola de _spin_from a _spin_to durante _spin_time.
var _spin_from: float = 0.0
var _spin_to: float = 0.0
var _spin_t0: float = 0.0
var _spin_time: float = 0.0
var _land_time: float = -INF
var _mesh_instance: MeshInstance3D
var _trail: CPUParticles3D
var _burst: CPUParticles3D
var _dust: CPUParticles3D
var _speed: float = 14.0


func setup(game: GameConfig, bpm: float) -> void:
	_game = game
	_jump_time = RhythmClock.time_of_beat(game.jump_duration_beats, bpm)
	# Parábola que sube `jump_height` y dura `_jump_time`: v0 = 4h/T, g = 8h/T².
	_jump_v0 = 4.0 * game.jump_height / _jump_time
	_gravity = 8.0 * game.jump_height / (_jump_time * _jump_time)
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
	edges_open = false
	_song_time = 0.0
	_from_x = _game.lane_x(lane)
	_to_x = _from_x
	_change_start = -INF
	_change_dir = 0
	_buffered_jump_at = -INF
	_airborne = false
	_ground_y = 0.0
	_last_y = 0.0
	_can_cut = false
	_off_track = false
	_fell_emitted = false
	_spin_time = 0.0
	_land_time = -INF
	position = Vector3(_from_x, _game.player_size.y * 0.5, 0.0)
	_mesh_instance.visible = true
	_mesh_instance.rotation = Vector3.ZERO
	_mesh_instance.scale = Vector3.ONE
	_mesh_instance.position = Vector3.ZERO
	_trail.emitting = true


func set_dead() -> void:
	alive = false
	_mesh_instance.visible = false
	_trail.emitting = false
	_burst.restart()
	_burst.emitting = true


func is_airborne() -> bool:
	return _airborne


## Conectado a InputHandler.lane_change_requested.
func request_lane_change(direction: int) -> void:
	if not alive or _off_track:
		return
	var target: int = lane + direction
	if target < 0 or target >= _game.lane_count:
		if not edges_open:
			return
		_off_track = true  # Sin riel: se sale de la pista y cae.
	lane = target
	_from_x = position.x
	_to_x = _game.lane_x(lane)
	_change_start = _song_time
	_change_dir = direction
	lane_changed.emit(lane)


## Conectado a InputHandler.jump_requested (botón pulsado).
func request_jump() -> void:
	if not alive:
		return
	if _airborne:
		_buffered_jump_at = _song_time
		return
	_start_jump()


## Conectado a InputHandler.jump_released: soltar mientras sube recorta el salto.
func request_jump_release() -> void:
	if not alive or not _airborne or not _can_cut:
		return
	_can_cut = false
	var tau: float = _song_time - _air_t0
	var velocity: float = _air_v0 - _air_gravity * tau
	if velocity <= 0.0:
		return
	var cut_velocity: float = velocity * _game.jump_cut_factor
	_begin_air(_air_y0 + _air_v0 * tau - 0.5 * _air_gravity * tau * tau, cut_velocity, _air_gravity)
	# El giro termina justo al volver a la altura de despegue.
	_begin_spin(_mesh_instance.rotation.x, -JUMP_SPIN, 2.0 * cut_velocity / _air_gravity)


## Súper salto de rampa (conectado a ObstacleSpawner.ramp_hit vía GameManager).
func launch_from_ramp() -> void:
	if not alive:
		return
	var time: float = RhythmClock.time_of_beat(_game.ramp_jump_beats, 60.0 * _speed / _game.units_per_beat)
	var gravity: float = 8.0 * _game.ramp_jump_height / (time * time)
	var base: float = _last_y if _airborne else _ground_y
	_airborne = true
	_can_cut = false
	_buffered_jump_at = -INF
	_begin_air(base, 4.0 * _game.ramp_jump_height / time, gravity)
	_begin_spin(0.0, -RAMP_SPIN, time)
	launched.emit()


## Conectado a RhythmClock.tick.
func on_tick(song_time: float) -> void:
	_song_time = song_time
	if not alive:
		return
	var x: float = _to_x
	var change_p: float = 1.0
	if _game.lane_change_time > 0.0:
		change_p = clampf((song_time - _change_start) / _game.lane_change_time, 0.0, 1.0)
		x = lerpf(_from_x, _to_x, ease_out(change_p))

	var ground: float = _ground_at(x, song_time)
	var y: float = _ground_y
	var velocity: float = 0.0
	if _airborne:
		var tau: float = song_time - _air_t0
		y = _air_y0 + _air_v0 * tau - 0.5 * _air_gravity * tau * tau
		velocity = _air_v0 - _air_gravity * tau
		# Aterriza si baja hasta un suelo que tenía por debajo (o casi: perdona bordes).
		if velocity <= 0.0 and y <= ground and _last_y >= ground - _game.step_tolerance:
			y = ground
			_land(ground)
	elif ground < _ground_y - GROUND_EPSILON:
		# Se acabó el suelo (fin de plataforma, hueco o borde): empieza a caer.
		_airborne = true
		_can_cut = false
		_spin_time = 0.0
		_begin_air(_ground_y, 0.0, _gravity)
	elif ground > _ground_y and ground - _ground_y <= _game.step_tolerance:
		_ground_y = ground
		y = ground

	_last_y = y
	if y < -_game.fall_death_depth and not _fell_emitted:
		_fell_emitted = true
		fell.emit()
	position = Vector3(x, y + _game.player_size.y * 0.5, 0.0)
	_animate(song_time, change_p, velocity)
	moved.emit(position, _game.player_size)


## Curva de salida cuadrática: rápida al inicio, suave al llegar.
static func ease_out(p: float) -> float:
	return 1.0 - (1.0 - p) * (1.0 - p)


func _start_jump() -> void:
	_airborne = true
	_can_cut = true
	_buffered_jump_at = -INF
	_begin_air(_ground_y, _jump_v0, _gravity)
	_begin_spin(0.0, -JUMP_SPIN, _jump_time)
	jumped.emit()


func _begin_air(y0: float, v0: float, gravity: float) -> void:
	_air_t0 = _song_time
	_air_y0 = y0
	_air_v0 = v0
	_air_gravity = gravity
	_last_y = y0


func _begin_spin(from: float, to: float, time: float) -> void:
	_spin_from = from
	_spin_to = to
	_spin_t0 = _song_time
	_spin_time = time


func _land(ground: float) -> void:
	_airborne = false
	_ground_y = ground
	_land_time = _song_time
	_spin_time = 0.0
	if is_inside_tree():
		_dust.restart()
		_dust.emitting = true
	landed.emit()
	if _song_time - _buffered_jump_at <= _game.jump_buffer_time:
		_start_jump()


func _ground_at(x: float, song_time: float) -> float:
	if ground_query.is_valid():
		return float(ground_query.call(x, song_time))
	return 0.0


## Animación del cubo: solo visual, pero derivada de song_time (se congela con el reloj).
func _animate(song_time: float, change_p: float, velocity: float) -> void:
	var roll: float = -float(_change_dir) * TILT_MAX * (1.0 - change_p)
	var spin: float = 0.0
	var stretch: float = 1.0
	var widen: float = 1.0
	if _airborne:
		if _spin_time > 0.0:
			var p: float = clampf((song_time - _spin_t0) / _spin_time, 0.0, 1.0)
			spin = lerpf(_spin_from, _spin_to, p)
		stretch = 1.0 + STRETCH_MAX * clampf(absf(velocity) / _jump_v0, 0.0, 1.0)
		widen = 1.0 / sqrt(stretch)
	else:
		var squash: float = SQUASH_AMOUNT * exp(-(song_time - _land_time) * SQUASH_RECOVERY)
		stretch = 1.0 - squash
		widen = 1.0 + squash * 0.6
	_mesh_instance.rotation = Vector3(spin, 0.0, roll)
	_mesh_instance.scale = Vector3(widen, stretch, widen)
	# Al aplastarse, la base sigue apoyada en el suelo.
	_mesh_instance.position.y = (stretch - 1.0) * _game.player_size.y * 0.5 if not _airborne else 0.0


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
	# Polvo al aterrizar.
	_dust = _make_particles("Dust", DUST_AMOUNT, DUST_LIFETIME, DUST_PARTICLE_SIZE, NeonPalette.WHITE)
	_dust.one_shot = true
	_dust.explosiveness = 1.0
	_dust.emitting = false
	_dust.direction = Vector3.UP
	_dust.spread = 80.0
	_dust.initial_velocity_min = DUST_SPEED.x
	_dust.initial_velocity_max = DUST_SPEED.y
	_dust.gravity = GRAVITY
	_dust.position.y = -_game.player_size.y * 0.5
	_dust.scale_amount_curve = _shrink_curve()


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
