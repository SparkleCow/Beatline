class_name GameManager
extends Node3D
## Orquesta una partida: prepara los sistemas desde la semilla, los conecta por señales
## y maneja el ciclo jugar -> morir -> reiniciar (< 1 s).
##
## Los sistemas no se conocen entre sí: este nodo solo hace el cableado de señales.

signal run_started(seed_value: int, bpm: float)
signal score_changed(score: int)
signal run_ended(score: int, best: int)
signal debug_stats_changed(stats: Dictionary)
signal debug_toggled

enum State { BOOT, PLAYING, DEAD }

const DEBUG_REFRESH_USEC: int = 100_000
const MSEC_PER_SEC: float = 1000.0
const DEFAULT_GAME_CONFIG: String = "res://resources/game_config.tres"
const DEFAULT_MUSIC_CONFIG: String = "res://resources/music_config.tres"
const DEFAULT_DIFFICULTY_CONFIG: String = "res://resources/difficulty_config.tres"
const SKY_SHADER: Shader = preload("res://assets/shaders/y2k_sky.gdshader")
## El fondo va justo antes del plano lejano, para no tapar obstáculos.
const SKY_DISTANCE_MARGIN: float = 2.0
## Sobredimensión del fondo para cubrir cualquier aspecto y el golpe de FOV.
const SKY_OVERSCAN: float = 1.4
## Alto/ancho del fondo (vertical 9:16 con margen).
const SKY_ASPECT: float = 2.0

@export var game_config: GameConfig
@export var music_config: MusicConfig
@export var difficulty_config: DifficultyConfig

var state: State = State.BOOT
var seed_value: int = 0
var score: int = 0
var best_score: int = 0

var _death_usec: int = 0
var _last_debug_usec: int = 0
var _speed: float = 14.0

@onready var _music: MusicGenerator = $MusicGenerator
@onready var _clock: RhythmClock = $RhythmClock
@onready var _input: InputHandler = $InputHandler
@onready var _track: LaneTrack = $LaneTrack
@onready var _spawner: ObstacleSpawner = $ObstacleSpawner
@onready var _player: PlayerController = $Player
@onready var _camera: Camera3D = $Camera3D
@onready var _fx: NeonFx = $NeonFx


func _ready() -> void:
	_load_default_configs()
	seed_value = DailySeed.current_seed()
	_music.setup(music_config, DailySeed.derive(seed_value, DailySeed.SALT_MUSIC))
	var bpm: float = _music.bpm
	_speed = game_config.scroll_speed(bpm)

	_track.setup(game_config, bpm)
	_player.setup(game_config, bpm)
	_spawner.setup(game_config, difficulty_config, DailySeed.derive(seed_value, DailySeed.SALT_LEVEL), bpm)
	_setup_camera()
	_build_sky()
	_fx.setup(bpm, _speed, music_config.beats_per_bar, _camera)
	_connect_signals()
	start_run()


func start_run() -> void:
	_spawner.reset()
	_player.reset()
	score = 0
	score_changed.emit(score)
	_music.play_from_start()
	_clock.start(_music.get_mixed_seconds, _music.bpm, music_config.beats_per_bar)
	state = State.PLAYING
	run_started.emit(seed_value, _music.bpm)


func _connect_signals() -> void:
	# Orden importa: el jugador se posiciona antes de que el spawner compruebe colisiones.
	_clock.tick.connect(_player.on_tick)
	_clock.tick.connect(_track.on_tick)
	_clock.tick.connect(_spawner.on_tick)
	_clock.tick.connect(_fx.on_tick)
	_clock.tick.connect(_on_tick)
	_player.moved.connect(_spawner.on_player_moved)
	_spawner.player_hit.connect(_on_player_hit)
	_input.lane_change_requested.connect(_player.request_lane_change)
	_input.jump_requested.connect(_on_jump_requested)
	_input.debug_toggled.connect(debug_toggled.emit)


func _on_jump_requested() -> void:
	match state:
		State.PLAYING:
			_player.request_jump()
		State.DEAD:
			var elapsed: float = float(Time.get_ticks_usec() - _death_usec) / 1_000_000.0
			if elapsed >= game_config.restart_lockout:
				start_run()


func _on_tick(song_time: float) -> void:
	var new_score: int = floori(maxf(song_time, 0.0) * _speed)
	if new_score != score:
		score = new_score
		score_changed.emit(score)
	var now: int = Time.get_ticks_usec()
	if now - _last_debug_usec >= DEBUG_REFRESH_USEC:
		_last_debug_usec = now
		debug_stats_changed.emit(_collect_debug_stats(song_time))


func _on_player_hit(_lane: int, _kind: int) -> void:
	if state != State.PLAYING:
		return
	state = State.DEAD
	_death_usec = Time.get_ticks_usec()
	_clock.stop()
	_music.stop()
	_player.set_dead()
	_fx.calm()
	best_score = maxi(best_score, score)
	run_ended.emit(score, best_score)


func _collect_debug_stats(song_time: float) -> Dictionary:
	var beat_value: float = _clock.current_beat()
	return {
		"bpm": _music.bpm,
		"beat": floori(beat_value),
		"bar": floori(beat_value / float(music_config.beats_per_bar)),
		"seed": seed_value,
		"forced_seed": DailySeed.has_forced_seed(),
		"fps": Engine.get_frames_per_second(),
		"song_time": song_time,
		"latency_ms": _clock.current_latency() * MSEC_PER_SEC,
		"clock_mode": RhythmClock.Mode.keys()[_clock.mode],
		"obstacles": _spawner.active_count(),
	}


func _setup_camera() -> void:
	_camera.position = game_config.camera_offset
	_camera.look_at(Vector3(0.0, 0.0, -game_config.camera_look_ahead), Vector3.UP)
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = game_config.camera_fov
	_camera.far = game_config.view_distance + game_config.camera_far_margin


## Fondo Y2K procedural en un quad hijo de la cámara (cero texturas, un solo draw call).
func _build_sky() -> void:
	var distance: float = _camera.far - SKY_DISTANCE_MARGIN
	var width: float = 2.0 * distance * tan(deg_to_rad(game_config.camera_fov * 0.5)) * SKY_OVERSCAN
	var quad := QuadMesh.new()
	quad.size = Vector2(width, width * SKY_ASPECT)
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.set_shader_parameter(&"aspect", SKY_ASPECT)
	var sky := MeshInstance3D.new()
	sky.name = "Y2KSky"
	sky.mesh = quad
	sky.material_override = mat
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.position = Vector3(0.0, 0.0, -distance)
	_camera.add_child(sky)


func _load_default_configs() -> void:
	if game_config == null:
		game_config = load(DEFAULT_GAME_CONFIG) as GameConfig
	if music_config == null:
		music_config = load(DEFAULT_MUSIC_CONFIG) as MusicConfig
	if difficulty_config == null:
		difficulty_config = load(DEFAULT_DIFFICULTY_CONFIG) as DifficultyConfig
