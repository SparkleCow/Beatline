extends Node
## Escena raíz: conecta juego, HUD y menú (solo cableado de señales) y aplica preferencias.

const DIFFICULTIES: Array[DifficultyConfig] = [
	preload("res://resources/difficulty_easy.tres"),
	preload("res://resources/difficulty_config.tres"),
	preload("res://resources/difficulty_hard.tres"),
]

var _settings: SettingsStore

@onready var _game: GameManager = $Game
@onready var _hud: Hud = $Hud
@onready var _menu: MainMenu = $MenuLayer/MainMenu


func _ready() -> void:
	_settings = SettingsStore.load_or_default()
	_apply_settings()
	_game.run_started.connect(_hud.on_run_started)
	_game.score_changed.connect(_hud.on_score_changed)
	_game.run_ended.connect(_hud.on_run_ended)
	_game.debug_stats_changed.connect(_hud.on_debug_stats_changed)
	_game.debug_toggled.connect(_hud.on_debug_toggled)
	_hud.retry_requested.connect(_game.retry)
	_hud.menu_requested.connect(_on_menu_requested)
	_menu.play_requested.connect(_on_play_requested)
	_menu.settings_changed.connect(_on_settings_changed)
	_menu.setup(_settings, DIFFICULTIES)


func _on_play_requested(seed_value: int, difficulty: DifficultyConfig) -> void:
	_hud.set_in_game(true)
	_game.begin(seed_value, difficulty)


func _on_menu_requested() -> void:
	_game.go_to_menu()
	_hud.set_in_game(false)
	_menu.show_menu()


func _on_settings_changed() -> void:
	_apply_settings()
	_settings.save()


func _apply_settings() -> void:
	_settings.apply_audio()
	_hud.set_debug_visible(_settings.show_debug)
