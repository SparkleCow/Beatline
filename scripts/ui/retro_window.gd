class_name RetroWindow
extends PanelContainer
## Ventana estilo Windows 98 en clave neón: barra de título de color con botones falsos
## [_][□][×], cuerpo oscuro translúcido, borde marcado y sombra dura.
## Uso: `var w := RetroWindow.create("archivo.exe", color)` y añadir controles a `w.body`.

const BODY_BG: Color = Color(0.04, 0.0, 0.1, 0.86)
const TITLE_TEXT: Color = Color(0.03, 0.0, 0.08)
const TITLE_FONT_SIZE: int = 30
const TITLE_PADDING: int = 10
const BODY_PADDING: int = 18
const BODY_SPACING: int = 14
const CHROME_BUTTONS: Array[String] = ["_", "□", "×"]
const CHROME_SIZE: Vector2 = Vector2(40.0, 40.0)
const CHROME_FONT_SIZE: int = 26
const CHROME_SPACING: int = 6

## Contenedor donde va el contenido de la ventana.
var body: VBoxContainer

var _title_label: Label
var _title_bar: PanelContainer
var _accent: Color = NeonPalette.PINK


## `compact` deja solo el botón [×]: para ventanas pequeñas del HUD.
static func create(title: String, accent: Color = NeonPalette.PINK, compact: bool = false) -> RetroWindow:
	var window := RetroWindow.new()
	window._build(title, accent, compact)
	return window


func set_title(title: String) -> void:
	_title_label.text = title


func set_accent(accent: Color) -> void:
	_accent = accent
	add_theme_stylebox_override(&"panel", NeonTheme.box(BODY_BG, accent))
	var bar := StyleBoxFlat.new()
	bar.bg_color = accent
	bar.set_content_margin_all(TITLE_PADDING)
	_title_bar.add_theme_stylebox_override(&"panel", bar)


func _build(title: String, accent: Color, compact: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_title_bar = PanelContainer.new()
	_title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_title_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", CHROME_SPACING)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_bar.add_child(row)
	_title_label = Label.new()
	_title_label.text = title
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.clip_text = true
	_title_label.add_theme_font_override(&"font", NeonTheme.font())
	_title_label.add_theme_font_size_override(&"font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override(&"font_color", TITLE_TEXT)
	row.add_child(_title_label)
	for glyph: String in CHROME_BUTTONS.slice(CHROME_BUTTONS.size() - 1) if compact else CHROME_BUTTONS:
		row.add_child(_chrome_button(glyph))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, BODY_PADDING)
	column.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override(&"separation", BODY_SPACING)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(body)
	set_accent(accent)


static func _chrome_button(glyph: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CHROME_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = BODY_BG
	style.border_color = TITLE_TEXT
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override(&"panel", style)
	var label := Label.new()
	label.text = glyph
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", CHROME_FONT_SIZE)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	panel.add_child(label)
	return panel
