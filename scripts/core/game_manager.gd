class_name GameManager
extends Node3D
## Orquesta una partida: prepara los sistemas desde la semilla, los conecta por señales
## y maneja el ciclo jugar -> morir -> reiniciar (< 1 s).
##
## Los sistemas no se conocen entre sí: este nodo solo hace el cableado de señales.

signal run_started(seed_value: int, bpm: float)
signal score_changed(score: int)
## `reason` es un EndReason: choque, caída al vacío o nivel superado.
signal run_ended(score: int, best: int, reason: int)
signal gems_changed(gems: int)
## Progreso 0..1 hacia la meta del nivel fijo (no se emite en niveles sin meta).
signal goal_progress_changed(progress: float)
signal debug_stats_changed(stats: Dictionary)
signal debug_toggled

enum State { MENU, PLAYING, DEAD }
enum EndReason { CRASH, FALL, CLEARED }

const DEBUG_REFRESH_USEC: int = 100_000
const MSEC_PER_SEC: float = 1000.0
const DEFAULT_GAME_CONFIG: String = "res://resources/game_config.tres"
const DEFAULT_MUSIC_CONFIG: String = "res://resources/music_config.tres"
const DEFAULT_DIFFICULTY_CONFIG: String = "res://resources/difficulty_config.tres"
const SKY_SHADER: Shader = preload("res://assets/shaders/y2k_sky.gdshader")
## El fondo va justo antes del plano lejano, para no tapar obstáculos.
const SKY_DISTANCE_MARGIN: float = 2.0
## Sobredimensión del fondo para cubrir cualquier aspecto.
const SKY_OVERSCAN: float = 1.4
## Alto/ancho del fondo (vertical 9:16 con margen).
const SKY_ASPECT: float = 2.0

@export var game_config: GameConfig
@export var music_config: MusicConfig
@export var difficulty_config: DifficultyConfig

var state: State = State.MENU
var seed_value: int = 0
var score: int = 0
var best_score: int = 0
var gems: int = 0
## Beats a sobrevivir para superar el nivel (0 = sin meta, partida infinita).
var goal_beats: int = 0

var _prepared: bool = false
var _death_usec: int = 0
var _last_debug_usec: int = 0
var _speed: float = 14.0
## Pista .ogg activa (null = música procedural).
var _track: TrackLibrary.Track = null
var _bpm: float = 120.0
var _sky_material: ShaderMaterial

@onready var _music: MusicGenerator = $MusicGenerator
@onready var _clock: RhythmClock = $RhythmClock
@onready var _input: InputHandler = $InputHandler
@onready var _track_node: LaneTrack = $LaneTrack
@onready var _spawner: ObstacleSpawner = $ObstacleSpawner
@onready var _player: PlayerController = $Player
@onready var _camera: CameraRig = $Camera3D
@onready var _fx: NeonFx = $NeonFx
@onready var _tracks: TrackPlayer = $TrackPlayer
@onready var _sfx: SfxPlayer = $SfxPlayer


func _ready() -> void:
	_load_default_configs()
	_setup_camera()
	_build_sky()
	_connect_signals()
	# El mundo se prepara con el nivel del día para que se vea detrás del menú.
	prepare(DailySeed.current_seed(), difficulty_config)


## Prepara todos los sistemas para una semilla y dificultad. Re-renderiza la música solo
## si cambió la semilla. No arranca la partida.
func prepare(new_seed: int, difficulty: DifficultyConfig) -> void:
	var seed_changed: bool = not _prepared or new_seed != seed_value
	seed_value = new_seed
	difficulty_config = difficulty
	if seed_changed:
		_prepare_music(DailySeed.derive(seed_value, DailySeed.SALT_MUSIC))
	_speed = game_config.scroll_speed(_bpm)
	_track_node.setup(game_config, _bpm)
	_player.setup(game_config, _bpm)
	_spawner.setup(game_config, difficulty_config, DailySeed.derive(seed_value, DailySeed.SALT_LEVEL), _bpm)
	_camera.snap_to_base()
	_fx.setup(_bpm, _speed, music_config.beats_per_bar)
	SkyPresets.apply(_sky_material, seed_value)
	if seed_changed:
		best_score = 0
	_prepared = true


## Prepara (si hace falta) y arranca una partida. Lo llama el menú.
## `p_goal_beats` > 0 convierte la partida en un nivel con meta.
func begin(new_seed: int, difficulty: DifficultyConfig, p_goal_beats: int = 0) -> void:
	goal_beats = p_goal_beats
	if not _prepared or new_seed != seed_value or difficulty != difficulty_config:
		prepare(new_seed, difficulty)
	start_run()


## Detiene todo y deja el mundo quieto detrás del menú.
func go_to_menu() -> void:
	_clock.stop()
	_stop_music()
	_fx.calm()
	_spawner.reset()
	_player.reset()
	_camera.snap_to_base()
	_track_node.on_tick(0.0)
	state = State.MENU


func current_bpm() -> float:
	return _bpm


## BPM que tendrá una semilla (pista .ogg si hay, si no el tempo procedural). Barato:
## lo usa el menú para mostrarlo antes de jugar.
static func bpm_for_seed(level_seed: int, cfg: MusicConfig) -> float:
	var music_seed: int = DailySeed.derive(level_seed, DailySeed.SALT_MUSIC)
	var track: TrackLibrary.Track = TrackLibrary.pick(music_seed)
	if track != null:
		return track.bpm
	var rng := RandomNumberGenerator.new()
	rng.seed = music_seed
	return MusicGenerator.choose_bpm(rng, cfg)


func start_run() -> void:
	_spawner.reset()
	_player.reset()
	_camera.snap_to_base()
	score = 0
	gems = 0
	score_changed.emit(score)
	gems_changed.emit(gems)
	if goal_beats > 0:
		goal_progress_changed.emit(0.0)
	if _track != null:
		_tracks.play_from_start()
		_clock.start(_tracks.get_mixed_seconds, _bpm, music_config.beats_per_bar)
	else:
		_music.play_from_start()
		_clock.start(_music.get_mixed_seconds, _bpm, music_config.beats_per_bar)
	state = State.PLAYING
	run_started.emit(seed_value, _bpm)


## Elige la música de la semilla: una pista .ogg si hay (la misma para todos ese día) o,
## si no hay ninguna o falla la carga, la música procedural.
func _prepare_music(music_seed: int) -> void:
	_track = TrackLibrary.pick(music_seed)
	if _track != null and not _tracks.setup(_track, music_config.volume_db):
		_track = null
	if _track != null:
		_bpm = _track.bpm
	else:
		_music.setup(music_config, music_seed)
		_bpm = _music.bpm


func _stop_music() -> void:
	_music.stop()
	_tracks.stop()


func _connect_signals() -> void:
	# Orden importa: el jugador se posiciona antes de que el spawner compruebe colisiones.
	_clock.tick.connect(_player.on_tick)
	_clock.tick.connect(_track_node.on_tick)
	_clock.tick.connect(_spawner.on_tick)
	_clock.tick.connect(_fx.on_tick)
	_clock.tick.connect(_on_tick)
	_player.moved.connect(_spawner.on_player_moved)
	_player.moved.connect(_camera.on_player_moved)
	_player.fell.connect(_end_run.bind(EndReason.FALL))
	_player.ground_query = _spawner.ground_height_at
	_track_node.open_edge_query = _is_span_open
	_spawner.player_hit.connect(_on_player_hit)
	_spawner.ramp_hit.connect(_player.launch_from_ramp)
	_spawner.gem_collected.connect(_on_gem_collected)
	_input.lane_change_requested.connect(_player.request_lane_change)
	_input.jump_requested.connect(_on_jump_requested)
	_input.jump_released.connect(_player.request_jump_release)
	# Efectos de sonido.
	_player.jumped.connect(_sfx.play_jump)
	_player.lane_changed.connect(_sfx.play_lane)
	_player.landed.connect(_sfx.play_land)
	_player.launched.connect(_sfx.play_ramp)
	_spawner.gem_collected.connect(_sfx.play_gem)
	_input.debug_toggled.connect(debug_toggled.emit)


func _on_jump_requested() -> void:
	match state:
		State.PLAYING:
			_player.request_jump()
		State.DEAD:
			retry()


## Reinicia tras morir (respeta el bloqueo anti-toque accidental).
func retry() -> void:
	if state != State.DEAD:
		return
	var elapsed: float = float(Time.get_ticks_usec() - _death_usec) / 1_000_000.0
	if elapsed >= game_config.restart_lockout:
		start_run()


func _is_span_open(beat_value: float) -> bool:
	return _spawner.pattern != null and _spawner.pattern.in_open_span(beat_value)


func _on_gem_collected(total: int) -> void:
	gems = total
	gems_changed.emit(gems)


func _on_tick(song_time: float) -> void:
	if state != State.PLAYING:
		return  # La partida terminó en este mismo tick: el marcador ya quedó fijado.
	var new_score: int = floori(maxf(song_time, 0.0) * _speed)
	if new_score != score:
		score = new_score
		score_changed.emit(score)
	var beat_value: float = RhythmClock.beat_at(song_time, _bpm)
	# El borde solo se abre donde ya no se ven rieles (con margen).
	_player.edges_open = _spawner.pattern.is_edge_open(beat_value)
	if goal_beats > 0:
		goal_progress_changed.emit(clampf(beat_value / float(goal_beats), 0.0, 1.0))
		if beat_value >= float(goal_beats):
			_end_run(EndReason.CLEARED)
			return
	var now: int = Time.get_ticks_usec()
	if now - _last_debug_usec >= DEBUG_REFRESH_USEC:
		_last_debug_usec = now
		debug_stats_changed.emit(_collect_debug_stats(song_time))


func _on_player_hit(_lane: int, _kind: int) -> void:
	_end_run(EndReason.CRASH)


## Termina la partida (choque, caída o meta alcanzada) y congela el mundo.
func _end_run(reason: EndReason) -> void:
	if state != State.PLAYING:
		return
	state = State.DEAD
	_death_usec = Time.get_ticks_usec()
	_clock.stop()
	_stop_music()
	_fx.calm()
	match reason:
		EndReason.CRASH:
			_player.set_dead()
			_sfx.play(SfxPlayer.Sfx.CRASH)
		EndReason.FALL:
			_player.set_dead()
			_sfx.play(SfxPlayer.Sfx.FALL)
		EndReason.CLEARED:
			_sfx.play(SfxPlayer.Sfx.CLEAR)
	best_score = maxi(best_score, score)
	run_ended.emit(score, best_score, reason)


func _collect_debug_stats(song_time: float) -> Dictionary:
	var beat_value: float = _clock.current_beat()
	return {
		"bpm": _bpm,
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
	_camera.setup(game_config)


## Fondo Y2K procedural en un quad hijo de la cámara (cero texturas, un solo draw call).
func _build_sky() -> void:
	var distance: float = _camera.far - SKY_DISTANCE_MARGIN
	var width: float = 2.0 * distance * tan(deg_to_rad(game_config.camera_fov * 0.5)) * SKY_OVERSCAN
	var quad := QuadMesh.new()
	quad.size = Vector2(width, width * SKY_ASPECT)
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.set_shader_parameter(&"aspect", SKY_ASPECT)
	_sky_material = mat
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
