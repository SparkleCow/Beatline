class_name Hud
extends CanvasLayer
## HUD del prototipo: puntaje, pantalla de muerte y overlay de depuración.
## Solo reacciona a señales; no conoce el estado interno del juego.

const DEATH_TEXT: String = "%d m\nMejor: %d m\n\nToca o pulsa Espacio para reintentar"

@onready var _score_label: Label = $ScoreLabel
@onready var _death_label: Label = $DeathLabel
@onready var _debug: DebugOverlay = $DebugOverlay


func on_run_started(_seed_value: int, _bpm: float) -> void:
	_death_label.visible = false


func on_score_changed(score: int) -> void:
	_score_label.text = "%d m" % score


func on_run_ended(score: int, best: int) -> void:
	_death_label.text = DEATH_TEXT % [score, best]
	_death_label.visible = true


func on_debug_stats_changed(stats: Dictionary) -> void:
	_debug.show_stats(stats)


func on_debug_toggled() -> void:
	_debug.visible = not _debug.visible
