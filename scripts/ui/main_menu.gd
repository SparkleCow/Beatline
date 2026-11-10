class_name MainMenu
extends Control
## Menú principal Y2K: JUGAR, selector de nivel (hoy / días anteriores / aleatorio),
## dificultad y opciones (volumen, datos de depuración). Se construye por código.
## Solo emite señales; main.gd las conecta con el juego.

signal play_requested(seed_value: int, difficulty: DifficultyConfig)
signal settings_changed

## Cuántos días hacia atrás se pueden jugar.
const MAX_DAYS_BACK: int = 30
## Valor del selector de nivel que significa "aleatorio".
const LEVEL_RANDOM: int = MAX_DAYS_BACK + 1
const MONTHS: Array[String] = ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]
const SCREEN_MARGIN: int = 70
const SPACING: int = 28
const PLAY_HEIGHT: float = 170.0
const BUTTON_HEIGHT: float = 120.0
const ARROW_WIDTH: float = 120.0
const TITLE_SIZE: int = 150
const SUBTITLE_SIZE: int = 36
const OPTIONS_TITLE_SIZE: int = 80
const PLAY_FONT_SIZE: int = 80
const CAPTION_SIZE: int = 30
const INFO_SIZE: int = 26
const DIM_COLOR: Color = Color(0.0, 0.0, 0.05, 0.45)
## Pulso del título al tempo del nivel seleccionado (solo cosmético).
const TITLE_PULSE: float = 0.06
const PULSE_DECAY: float = 5.0
const MSEC_PER_MIN: float = 60000.0

var _settings: SettingsStore
var _difficulties: Array[DifficultyConfig] = []
var _level_choice: int = 0
var _random_seed: int = 0
var _selected_bpm: float = 120.0

var _main_page: VBoxContainer
var _options_page: VBoxContainer
var _title: Label
var _play_button: Button
var _level_label: Label
var _difficulty_label: Label
var _info_label: Label
var _volume_slider: HSlider
var _debug_check: CheckButton


func setup(settings: SettingsStore, difficulties: Array[DifficultyConfig]) -> void:
	_settings = settings
	_difficulties = difficulties
	_settings.difficulty_index = clampi(_settings.difficulty_index, 0, _difficulties.size() - 1)
	theme = NeonTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()
	show_menu()


func show_menu() -> void:
	visible = true
	_main_page.visible = true
	_options_page.visible = false
	_play_button.grab_focus()


func _process(_delta: float) -> void:
	if not visible or _title == null:
		return
	# Late al tempo del nivel elegido usando el reloj absoluto (no gameplay).
	var beats: float = float(Time.get_ticks_msec()) * _selected_bpm / MSEC_PER_MIN
	var pulse: float = exp(-fposmod(beats, 1.0) * PULSE_DECAY)
	_title.scale = Vector2.ONE * (1.0 + pulse * TITLE_PULSE)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_main_page = _page()
	add_child(_main_page)
	_options_page = _page()
	add_child(_options_page)

	# --- Página principal ---
	_title = NeonTheme.title_label("BEATLINE", TITLE_SIZE, NeonPalette.PINK, NeonPalette.CYAN, 20)
	_title.resized.connect(func() -> void: _title.pivot_offset = _title.size * 0.5)
	_main_page.add_child(_title)
	_main_page.add_child(NeonTheme.title_label("✦ un nivel nuevo cada día ✦", SUBTITLE_SIZE,
			NeonPalette.CYAN, NeonPalette.PURPLE, 6))
	_main_page.add_child(_spacer())

	_play_button = _button("▶  JUGAR", PLAY_HEIGHT)
	_play_button.add_theme_font_size_override(&"font_size", PLAY_FONT_SIZE)
	_play_button.pressed.connect(_on_play)
	_main_page.add_child(_play_button)

	_main_page.add_child(_caption("NIVEL"))
	_level_label = _selector(_main_page, _on_level_step)
	_main_page.add_child(_caption("DIFICULTAD"))
	_difficulty_label = _selector(_main_page, _on_difficulty_step)

	var options_button: Button = _button("OPCIONES", BUTTON_HEIGHT)
	options_button.pressed.connect(_show_options)
	_main_page.add_child(options_button)
	_main_page.add_child(_spacer())
	_info_label = NeonTheme.title_label("", INFO_SIZE, NeonPalette.LIME, Color.BLACK, 4)
	_main_page.add_child(_info_label)

	# --- Página de opciones ---
	_options_page.add_child(NeonTheme.title_label("OPCIONES", OPTIONS_TITLE_SIZE, NeonPalette.CYAN, NeonPalette.PINK, 14))
	_options_page.add_child(_spacer())
	_options_page.add_child(_caption("VOLUMEN"))
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT * 0.6)
	_volume_slider.value = _settings.volume
	_volume_slider.value_changed.connect(_on_volume_changed)
	_options_page.add_child(_volume_slider)
	_debug_check = CheckButton.new()
	_debug_check.text = "Datos de depuración (F3)"
	_debug_check.button_pressed = _settings.show_debug
	_debug_check.toggled.connect(_on_debug_toggled)
	_options_page.add_child(_debug_check)
	_options_page.add_child(_spacer())
	var back: Button = _button("◀  VOLVER", BUTTON_HEIGHT)
	back.pressed.connect(show_menu)
	_options_page.add_child(back)


func _page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.offset_left = SCREEN_MARGIN
	page.offset_right = -SCREEN_MARGIN
	page.offset_top = SCREEN_MARGIN
	page.offset_bottom = -SCREEN_MARGIN
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override(&"separation", SPACING)
	return page


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _caption(text: String) -> Label:
	return NeonTheme.title_label(text, CAPTION_SIZE, NeonPalette.PINK, Color.BLACK, 6)


func _button(text: String, height: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, height)
	return b


## Fila [◀] etiqueta [▶]. Devuelve la etiqueta; `on_step` recibe -1 o +1.
func _selector(parent: Container, on_step: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", SPACING)
	var left: Button = _button("◀", BUTTON_HEIGHT)
	left.custom_minimum_size.x = ARROW_WIDTH
	left.pressed.connect(on_step.bind(-1))
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override(&"font_color", NeonPalette.CYAN)
	var right: Button = _button("▶", BUTTON_HEIGHT)
	right.custom_minimum_size.x = ARROW_WIDTH
	right.pressed.connect(on_step.bind(1))
	row.add_child(left)
	row.add_child(label)
	row.add_child(right)
	parent.add_child(row)
	return label


func _selected_seed() -> int:
	if _level_choice == LEVEL_RANDOM:
		return _random_seed
	if _level_choice == 0:
		return DailySeed.current_seed()
	return DailySeed.seed_for_days_ago(_level_choice)


func _level_text() -> String:
	if _level_choice == LEVEL_RANDOM:
		return "ALEATORIO"
	var d: Dictionary = DailySeed.utc_date_days_ago(_level_choice)
	var date: String = "%02d %s" % [int(d["day"]), MONTHS[int(d["month"]) - 1]]
	if _level_choice == 0:
		return "HOY · " + date
	if _level_choice == 1:
		return "AYER · " + date
	return date


func _refresh() -> void:
	_level_label.text = _level_text()
	_difficulty_label.text = _difficulties[_settings.difficulty_index].display_name.to_upper()
	var seed_value: int = _selected_seed()
	var rng := RandomNumberGenerator.new()
	rng.seed = DailySeed.derive(seed_value, DailySeed.SALT_MUSIC)
	_selected_bpm = MusicGenerator.choose_bpm(rng, load("res://resources/music_config.tres") as MusicConfig)
	_info_label.text = "♪ %d BPM  ·  semilla %d" % [_selected_bpm, seed_value]


func _on_level_step(direction: int) -> void:
	_level_choice = posmod(_level_choice - direction, LEVEL_RANDOM + 1)
	if _level_choice == LEVEL_RANDOM:
		_random_seed = randi()
	_refresh()


func _on_difficulty_step(direction: int) -> void:
	_settings.difficulty_index = posmod(_settings.difficulty_index + direction, _difficulties.size())
	settings_changed.emit()
	_refresh()


func _on_play() -> void:
	visible = false
	play_requested.emit(_selected_seed(), _difficulties[_settings.difficulty_index])


func _show_options() -> void:
	_main_page.visible = false
	_options_page.visible = true
	_volume_slider.grab_focus()


func _on_volume_changed(value: float) -> void:
	_settings.volume = value
	settings_changed.emit()


func _on_debug_toggled(on: bool) -> void:
	_settings.show_debug = on
	settings_changed.emit()
