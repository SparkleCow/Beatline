class_name NeonTheme
extends RefCounted
## Tema de interfaz Y2K / cyber-retro generado por código: esquinas rectas, borde neón y
## sombra dura desplazada (estilo ventana de Windows 98 pasada por neón).
## Fuente: usa res://assets/fonts/pixel.ttf si existe; si no, una monoespaciada del sistema.

const BG: Color = Color(0.05, 0.0, 0.12, 0.88)
const BG_HOVER: Color = Color(0.14, 0.0, 0.26, 0.92)
const BG_PRESSED: Color = Color(0.55, 0.05, 0.4, 0.95)
const BORDER: int = 4
const RADIUS: int = 0
## Sombra dura: casi sin difuminar y desplazada abajo-derecha.
const SHADOW: int = 2
const SHADOW_OFFSET: Vector2 = Vector2(10.0, 10.0)
const PIXEL_FONT_PATH: String = "res://assets/fonts/pixel.ttf"
const SYSTEM_FONT_NAMES: PackedStringArray = ["VT323", "Fixedsys", "Consolas", "DejaVu Sans Mono",
		"Droid Sans Mono", "Courier New", "monospace"]
const PADDING: float = 18.0
const FONT_SIZE: int = 48
const TEXT: Color = Color(1.0, 0.92, 1.0)


static var _font: Font = null


## Fuente retro compartida (pixel si el proyecto trae una; si no, monoespaciada del sistema).
static func font() -> Font:
	if _font != null:
		return _font
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		_font = load(PIXEL_FONT_PATH) as Font
	if _font == null:
		var system := SystemFont.new()
		system.font_names = SYSTEM_FONT_NAMES
		system.font_weight = 700
		system.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font = system
	return _font


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = font()
	theme.default_font_size = FONT_SIZE
	theme.set_stylebox(&"normal", &"Button", _box(BG, NeonPalette.PINK))
	theme.set_stylebox(&"hover", &"Button", _box(BG_HOVER, NeonPalette.CYAN))
	theme.set_stylebox(&"pressed", &"Button", _box(BG_PRESSED, NeonPalette.CYAN))
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), NeonPalette.LIME)
	focus.shadow_size = 0
	focus.draw_center = false
	theme.set_stylebox(&"focus", &"Button", focus)
	theme.set_color(&"font_color", &"Button", TEXT)
	theme.set_color(&"font_hover_color", &"Button", NeonPalette.CYAN)
	theme.set_color(&"font_pressed_color", &"Button", Color.WHITE)
	theme.set_color(&"font_focus_color", &"Button", NeonPalette.LIME)
	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_color(&"font_color", &"CheckButton", TEXT)
	theme.set_stylebox(&"slider", &"HSlider", _box(BG, NeonPalette.PURPLE))
	theme.set_stylebox(&"grabber_area", &"HSlider", _box(NeonPalette.PINK, NeonPalette.PINK))
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", _box(NeonPalette.CYAN, NeonPalette.CYAN))
	return theme


## Caja plana con borde y sombra dura. Pública: la reutilizan las ventanas retro.
static func box(bg: Color, border: Color) -> StyleBoxFlat:
	return _box(bg, border)


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(BORDER)
	box.set_corner_radius_all(RADIUS)
	box.shadow_color = Color(border, 0.6)
	box.shadow_size = SHADOW
	box.shadow_offset = SHADOW_OFFSET
	box.set_content_margin_all(PADDING)
	return box


## Etiqueta grande con contorno neón.
static func title_label(text: String, size: int, color: Color, outline: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font())
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", outline)
	label.add_theme_constant_override(&"outline_size", outline_size)
	return label
