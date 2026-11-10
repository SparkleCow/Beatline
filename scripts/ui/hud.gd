class_name Hud
extends CanvasLayer
## HUD: puntaje, pantalla de muerte (Reintentar / Menú) y overlay de depuración.
## Solo reacciona a señales y emite intenciones; no conoce el estado interno del juego.

signal retry_requested
signal menu_requested

const DEATH_TEXT: String = "%d m\nMejor: %d m"
const HINT_TEXT: String = "toca para reintentar"
const BUTTON_SIZE: Vector2 = Vector2(420.0, 130.0)
const BUTTON_FONT_SIZE: int = 52
const HINT_FONT_SIZE: int = 32
const BUTTONS_BOTTOM_OFFSET: float = -420.0
const SPACING: int = 40

var _death_buttons: Control

@onready var _score_label: Label = $ScoreLabel
@onready var _death_label: Label = $DeathLabel
@onready var _debug: DebugOverlay = $DebugOverlay


func _ready() -> void:
	_build_death_buttons()
	set_in_game(false)


## En el menú solo se ve el mundo; en juego, el puntaje.
func set_in_game(in_game: bool) -> void:
	_score_label.visible = in_game
	_death_label.visible = false
	_death_buttons.visible = false


func set_debug_visible(on: bool) -> void:
	_debug.visible = on


func on_run_started(_seed_value: int, _bpm: float) -> void:
	_death_label.visible = false
	_death_buttons.visible = false


func on_score_changed(score: int) -> void:
	_score_label.text = "%d m" % score


func on_run_ended(score: int, best: int) -> void:
	_death_label.text = DEATH_TEXT % [score, best]
	_death_label.visible = true
	_death_buttons.visible = true


func on_debug_stats_changed(stats: Dictionary) -> void:
	_debug.show_stats(stats)


func on_debug_toggled() -> void:
	_debug.visible = not _debug.visible


func _build_death_buttons() -> void:
	var box := VBoxContainer.new()
	box.theme = NeonTheme.build()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", SPACING)
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_top = BUTTONS_BOTTOM_OFFSET
	box.offset_bottom = BUTTONS_BOTTOM_OFFSET * 0.25
	box.add_child(_death_button("↻  REINTENTAR", retry_requested.emit))
	box.add_child(_death_button("MENÚ", menu_requested.emit))
	var hint := NeonTheme.title_label(HINT_TEXT, HINT_FONT_SIZE, NeonPalette.LIME, Color.BLACK, 4)
	box.add_child(hint)
	add_child(box)
	_death_buttons = box


static func _death_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	# Sin foco: Espacio sigue yendo al InputHandler (reintentar rápido).
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override(&"font_size", BUTTON_FONT_SIZE)
	b.pressed.connect(on_pressed)
	return b
