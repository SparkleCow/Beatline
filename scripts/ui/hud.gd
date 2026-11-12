class_name Hud
extends CanvasLayer
## HUD Y2K: ventanas retro con contador digital de distancia y gemas, barra de meta,
## un "GIF" decorativo y el diálogo de fin de partida (error fatal / nivel superado).
## Solo reacciona a señales y emite intenciones; no conoce el estado interno del juego.

signal retry_requested
signal menu_requested

const MARGIN: float = 36.0
## Deja libre la zona de la cámara/notch del teléfono.
const TOP_OFFSET: float = 84.0
const DISTANCE_DIGITS: int = 5
const GEM_DIGITS: int = 3
const DIGIT_HEIGHT: float = 84.0
const UNIT_FONT_SIZE: int = 44
const GOAL_BAR_HEIGHT: float = 34.0
const GOAL_TOP: float = 322.0
const GIF_SIDE: float = 132.0
const GIF_ALPHA: float = 0.85
const DIALOG_WIDTH: float = 860.0
const DIALOG_HEADLINE_SIZE: int = 50
const DIALOG_DETAIL_SIZE: int = 32
const DIALOG_STATS_SIZE: int = 44
const BUTTON_SIZE: Vector2 = Vector2(360.0, 120.0)
const BUTTON_FONT_SIZE: int = 44
const HINT_FONT_SIZE: int = 28
const SPACING: int = 24
const STATS_TEXT: String = "DISTANCIA  %d m\nMEJOR      %d m\nGEMAS      %d"
const HINT_TEXT: String = "toca para reintentar"
## Título de ventana, titular y detalle por motivo de fin (índice = GameManager.EndReason).
const END_TITLES: Array[String] = ["cubo.exe — error fatal", "cubo.exe — error fatal", "nivel.exe — completado"]
const END_HEADLINES: Array[String] = ["✖ cubo.exe dejó de responder", "✖ cubo.exe se salió del mapa", "✦ NIVEL SUPERADO ✦"]
const END_DETAILS: Array[String] = ["Causa: COLISIÓN", "Causa: CAÍDA AL VACÍO", "El proceso finalizó correctamente"]
const END_COLORS: Array[Color] = [NeonPalette.PINK, NeonPalette.ORANGE, NeonPalette.LIME]

var _top_bar: Control
var _distance: SegmentDisplay
var _gem_display: SegmentDisplay
var _goal_bar: ProgressBar
var _gif_window: RetroWindow
var _dialog: RetroWindow
var _headline: Label
var _detail: Label
var _stats: Label
var _gems: int = 0
var _goal_enabled: bool = false

@onready var _debug: DebugOverlay = $DebugOverlay


func _ready() -> void:
	_build_top_bar()
	_build_goal_bar()
	_build_gif()
	_build_dialog()
	set_in_game(false)


## En el menú solo se ve el mundo; en juego, los contadores.
func set_in_game(in_game: bool) -> void:
	_top_bar.visible = in_game
	_gif_window.visible = in_game
	_goal_bar.visible = in_game and _goal_enabled
	_dialog.visible = false


## Muestra la barra de progreso (niveles con meta).
func set_goal_enabled(on: bool) -> void:
	_goal_enabled = on
	_goal_bar.visible = on and _top_bar.visible


func set_debug_visible(on: bool) -> void:
	_debug.visible = on


func on_run_started(_seed_value: int, _bpm: float) -> void:
	_dialog.visible = false


func on_score_changed(score: int) -> void:
	_distance.value = score


func on_gems_changed(gems: int) -> void:
	_gems = gems
	_gem_display.value = gems


func on_goal_progress_changed(progress: float) -> void:
	_goal_bar.value = progress


func on_run_ended(score: int, best: int, reason: int) -> void:
	var index: int = clampi(reason, 0, END_TITLES.size() - 1)
	_dialog.set_title(END_TITLES[index])
	_dialog.set_accent(END_COLORS[index])
	_headline.text = END_HEADLINES[index]
	_headline.add_theme_color_override(&"font_color", END_COLORS[index])
	_detail.text = END_DETAILS[index]
	_stats.text = STATS_TEXT % [score, best, _gems]
	_dialog.visible = true


func on_debug_stats_changed(stats: Dictionary) -> void:
	_debug.show_stats(stats)


func on_debug_toggled() -> void:
	_debug.visible = not _debug.visible


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = MARGIN
	bar.offset_right = -MARGIN
	bar.offset_top = TOP_OFFSET
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_top_bar = bar

	var distance_window: RetroWindow = RetroWindow.create("distancia.exe", NeonPalette.CYAN, true)
	_distance = SegmentDisplay.create(DISTANCE_DIGITS, DIGIT_HEIGHT, NeonPalette.CYAN)
	distance_window.body.add_child(_counter_row(_distance, "m", NeonPalette.CYAN))
	bar.add_child(distance_window)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	var gem_window: RetroWindow = RetroWindow.create("gemas.dat", NeonPalette.PINK, true)
	_gem_display = SegmentDisplay.create(GEM_DIGITS, DIGIT_HEIGHT, ObstacleSpawner.GEM_COLOR)
	gem_window.body.add_child(_counter_row(_gem_display, "◆", ObstacleSpawner.GEM_COLOR))
	bar.add_child(gem_window)


static func _counter_row(display: SegmentDisplay, unit: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", SPACING)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(display)
	var label: Label = NeonTheme.title_label(unit, UNIT_FONT_SIZE, color, Color.BLACK, 6)
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(label)
	return row


func _build_goal_bar() -> void:
	_goal_bar = ProgressBar.new()
	_goal_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_goal_bar.offset_left = MARGIN
	_goal_bar.offset_right = -MARGIN
	_goal_bar.offset_top = GOAL_TOP
	_goal_bar.offset_bottom = GOAL_TOP + GOAL_BAR_HEIGHT
	_goal_bar.min_value = 0.0
	_goal_bar.max_value = 1.0
	_goal_bar.show_percentage = false
	_goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background: StyleBoxFlat = NeonTheme.box(RetroWindow.BODY_BG, NeonPalette.LIME)
	background.shadow_size = 0
	background.set_content_margin_all(0.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = NeonPalette.LIME
	fill.set_border_width_all(NeonTheme.BORDER)
	fill.border_color = Color(0, 0, 0, 0)
	_goal_bar.add_theme_stylebox_override(&"background", background)
	_goal_bar.add_theme_stylebox_override(&"fill", fill)
	add_child(_goal_bar)


## Ventanita decorativa abajo a la izquierda. Si existe assets/sprites/hud_gif.png, lo usa.
func _build_gif() -> void:
	_gif_window = RetroWindow.create("w.gif", NeonPalette.PURPLE, true)
	_gif_window.body.add_child(RetroGif.from_asset("hud_gif", RetroGif.Kind.GLOBE, GIF_SIDE,
			NeonPalette.CYAN, NeonPalette.PINK))
	_gif_window.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_gif_window.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_gif_window.offset_left = MARGIN
	_gif_window.offset_bottom = -MARGIN
	_gif_window.modulate.a = GIF_ALPHA
	add_child(_gif_window)


func _build_dialog() -> void:
	_dialog = RetroWindow.create(END_TITLES[0], NeonPalette.PINK)
	_dialog.theme = NeonTheme.build()
	_dialog.custom_minimum_size.x = DIALOG_WIDTH
	_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dialog.body.add_theme_constant_override(&"separation", SPACING)
	_headline = NeonTheme.title_label("", DIALOG_HEADLINE_SIZE, NeonPalette.PINK, Color.BLACK, 8)
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail = NeonTheme.title_label("", DIALOG_DETAIL_SIZE, NeonTheme.TEXT, Color.BLACK, 4)
	_stats = NeonTheme.title_label("", DIALOG_STATS_SIZE, NeonPalette.CYAN, Color.BLACK, 6)
	_dialog.body.add_child(_headline)
	_dialog.body.add_child(_detail)
	_dialog.body.add_child(_stats)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", SPACING * 2)
	buttons.add_child(_dialog_button("↻ REINTENTAR", retry_requested.emit))
	buttons.add_child(_dialog_button("MENÚ", menu_requested.emit))
	_dialog.body.add_child(buttons)
	_dialog.body.add_child(NeonTheme.title_label(HINT_TEXT, HINT_FONT_SIZE, NeonPalette.LIME, Color.BLACK, 4))
	add_child(_dialog)


static func _dialog_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	# Sin foco: Espacio sigue yendo al InputHandler (reintentar rápido).
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override(&"font_size", BUTTON_FONT_SIZE)
	b.pressed.connect(on_pressed)
	return b
