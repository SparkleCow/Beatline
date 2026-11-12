class_name MainMenu
extends Control
## Menú principal Y2K: JUGAR, selector de nivel (hoy / días anteriores / aleatorio /
## niveles fijos), dificultad y opciones (volumen, efectos, depuración). Por código.
## Solo emite señales; main.gd las conecta con el juego.

## `goal_beats` > 0 = nivel fijo con meta; 0 = partida sin fin.
signal play_requested(seed_value: int, difficulty: DifficultyConfig, goal_beats: int)
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
const GIF_SIDE: float = 110.0
const FIXED_DIFFICULTY_TEXT: String = "FIJA · DURA"
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
var _sfx_slider: HSlider
var _stages: Array[LevelCatalog.Stage] = []
var _debug_check: CheckButton


func setup(settings: SettingsStore, difficulties: Array[DifficultyConfig]) -> void:
	_settings = settings
	_difficulties = difficulties
	_stages = LevelCatalog.stages()
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
	_main_page.add_child(_gif_row())
	_main_page.add_child(_spacer())

	# Los controles viven dentro de una ventana retro.
	var window: RetroWindow = RetroWindow.create("beatline.exe", NeonPalette.PINK)
	window.mouse_filter = Control.MOUSE_FILTER_PASS
	_main_page.add_child(window)
	var panel: VBoxContainer = window.body
	panel.add_theme_constant_override(&"separation", SPACING)

	_play_button = _button("▶  JUGAR", PLAY_HEIGHT)
	_play_button.add_theme_font_size_override(&"font_size", PLAY_FONT_SIZE)
	_play_button.pressed.connect(_on_play)
	panel.add_child(_play_button)

	panel.add_child(_caption("NIVEL"))
	_level_label = _selector(panel, _on_level_step)
	panel.add_child(_caption("DIFICULTAD"))
	_difficulty_label = _selector(panel, _on_difficulty_step)

	var options_button: Button = _button("OPCIONES", BUTTON_HEIGHT)
	options_button.pressed.connect(_show_options)
	panel.add_child(options_button)
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
	_options_page.add_child(_caption("EFECTOS"))
	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.05
	_sfx_slider.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT * 0.6)
	_sfx_slider.value = _settings.sfx_volume
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_options_page.add_child(_sfx_slider)
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


## Fila decorativa de "GIFs" Y2K. Cada uno se reemplaza con assets/sprites/menu_gif_N.png.
func _gif_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", SPACING * 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kinds: Array[RetroGif.Kind] = [RetroGif.Kind.STAR, RetroGif.Kind.GLOBE, RetroGif.Kind.EQUALIZER]
	var colors: Array[Color] = [NeonPalette.LIME, NeonPalette.CYAN, NeonPalette.PINK]
	for i: int in kinds.size():
		row.add_child(RetroGif.from_asset("menu_gif_%d" % (i + 1), kinds[i], GIF_SIDE,
				colors[i], NeonPalette.PURPLE))
	return row


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


## Los niveles fijos ocupan los índices más altos, en orden inverso: así ▶ desde HOY
## recorre NIVEL 1, 2, 3... y ◀ sigue yendo hacia días anteriores.
func _choice_count() -> int:
	return LEVEL_RANDOM + 1 + _stages.size()


func _selected_stage() -> LevelCatalog.Stage:
	if _level_choice <= LEVEL_RANDOM:
		return null
	return _stages[_choice_count() - 1 - _level_choice]


func _selected_seed() -> int:
	var stage: LevelCatalog.Stage = _selected_stage()
	if stage != null:
		return stage.seed_value
	if _level_choice == LEVEL_RANDOM:
		return _random_seed
	if _level_choice == 0:
		return DailySeed.current_seed()
	return DailySeed.seed_for_days_ago(_level_choice)


func _level_text() -> String:
	var stage: LevelCatalog.Stage = _selected_stage()
	if stage != null:
		return "%d · %s" % [_stages.find(stage) + 1, stage.title]
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
	var stage: LevelCatalog.Stage = _selected_stage()
	_difficulty_label.text = FIXED_DIFFICULTY_TEXT if stage != null \
			else _difficulties[_settings.difficulty_index].display_name.to_upper()
	var seed_value: int = _selected_seed()
	_selected_bpm = GameManager.bpm_for_seed(seed_value, load("res://resources/music_config.tres") as MusicConfig)
	if stage != null:
		_info_label.text = "♪ %d BPM  ·  meta: %d compases" % [_selected_bpm, stage.goal_bars]
	else:
		_info_label.text = "♪ %d BPM  ·  semilla %d" % [_selected_bpm, seed_value]


func _on_level_step(direction: int) -> void:
	_level_choice = posmod(_level_choice - direction, _choice_count())
	if _level_choice == LEVEL_RANDOM:
		_random_seed = randi()
	_refresh()


func _on_difficulty_step(direction: int) -> void:
	if _selected_stage() != null:
		return  # Los niveles fijos traen su propia dificultad.
	_settings.difficulty_index = posmod(_settings.difficulty_index + direction, _difficulties.size())
	settings_changed.emit()
	_refresh()


func _on_play() -> void:
	visible = false
	var stage: LevelCatalog.Stage = _selected_stage()
	if stage != null:
		play_requested.emit(stage.seed_value, stage.difficulty, stage.goal_beats())
	else:
		play_requested.emit(_selected_seed(), _difficulties[_settings.difficulty_index], 0)


func _show_options() -> void:
	_main_page.visible = false
	_options_page.visible = true
	_volume_slider.grab_focus()


func _on_volume_changed(value: float) -> void:
	_settings.volume = value
	settings_changed.emit()


func _on_sfx_volume_changed(value: float) -> void:
	_settings.sfx_volume = value
	settings_changed.emit()


func _on_debug_toggled(on: bool) -> void:
	_settings.show_debug = on
	settings_changed.emit()
