extends Node
## Escena raíz: conecta el juego con la interfaz (solo cableado de señales).

@onready var _game: GameManager = $Game
@onready var _hud: Hud = $Hud


func _ready() -> void:
	_game.run_started.connect(_hud.on_run_started)
	_game.score_changed.connect(_hud.on_score_changed)
	_game.run_ended.connect(_hud.on_run_ended)
	_game.debug_stats_changed.connect(_hud.on_debug_stats_changed)
	_game.debug_toggled.connect(_hud.on_debug_toggled)
