class_name RetroGif
extends Control
## "GIF" retro: animación a pocos cuadros por segundo, como los GIFs de las webs Y2K.
##
## Sin assets dibuja una animación procedural (globo de alambre, ecualizador o estrella).
## Si existe res://assets/sprites/<nombre>.png (tira horizontal de cuadros cuadrados),
## reproduce ese sprite en su lugar: es el hueco para GIFs propios (ej. el David).
## Godot no reproduce .gif: hay que convertirlos a una tira PNG.

enum Kind { GLOBE, EQUALIZER, STAR }

const SPRITE_DIR: String = "res://assets/sprites"
## Cuadros por segundo: bajo a propósito (look de GIF).
const FPS: float = 10.0
const MSEC_PER_SEC: float = 1000.0
const LINE_WIDTH: float = 3.0
const ELLIPSE_POINTS: int = 24
const GLOBE_LATITUDES: PackedFloat32Array = [-0.6, -0.3, 0.0, 0.3, 0.6]
const GLOBE_MERIDIANS: int = 4
const GLOBE_TILT: float = 0.22
const GLOBE_SPIN_PER_FRAME: float = 0.16
const EQ_BARS: int = 7
const EQ_BLOCKS: int = 8
const EQ_GAP: float = 0.18
const STAR_FRAMES: int = 8
const STAR_INNER: float = 0.28

var kind: Kind = Kind.GLOBE
var color: Color = NeonPalette.CYAN
var accent: Color = NeonPalette.PINK

var _texture: Texture2D = null
var _sprite_frames: int = 1
var _frame: int = -1


static func create(p_kind: Kind, side: float, p_color: Color, p_accent: Color) -> RetroGif:
	var gif := RetroGif.new()
	gif.kind = p_kind
	gif.color = p_color
	gif.accent = p_accent
	gif.custom_minimum_size = Vector2(side, side)
	gif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gif


## Usa el sprite `res://assets/sprites/<asset_name>.png` si existe; si no, la animación procedural.
static func from_asset(asset_name: String, fallback: Kind, side: float, p_color: Color, p_accent: Color) -> RetroGif:
	var gif: RetroGif = create(fallback, side, p_color, p_accent)
	var path: String = SPRITE_DIR.path_join(asset_name + ".png")
	if ResourceLoader.exists(path):
		gif._texture = load(path) as Texture2D
		if gif._texture != null and gif._texture.get_height() > 0:
			gif._sprite_frames = maxi(1, gif._texture.get_width() / gif._texture.get_height())
	return gif


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	# Reloj absoluto cuantizado: solo redibuja al cambiar de cuadro.
	var frame: int = floori(float(Time.get_ticks_msec()) / MSEC_PER_SEC * FPS)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	if _texture != null:
		var side: float = float(_texture.get_height())
		var source := Rect2(float(_frame % _sprite_frames) * side, 0.0, side, side)
		draw_texture_rect_region(_texture, Rect2(Vector2.ZERO, size), source)
		return
	match kind:
		Kind.GLOBE:
			_draw_globe()
		Kind.EQUALIZER:
			_draw_equalizer()
		Kind.STAR:
			_draw_star()


func _draw_globe() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - LINE_WIDTH
	draw_arc(center, radius, 0.0, TAU, ELLIPSE_POINTS, color, LINE_WIDTH)
	for lat: float in GLOBE_LATITUDES:
		var ring: float = radius * sqrt(1.0 - lat * lat)
		_ellipse(center + Vector2(0.0, lat * radius), ring, ring * GLOBE_TILT, accent)
	for i: int in GLOBE_MERIDIANS:
		var angle: float = float(_frame) * GLOBE_SPIN_PER_FRAME + float(i) * PI / float(GLOBE_MERIDIANS)
		_ellipse(center, radius * absf(cos(angle)), radius, color)


func _ellipse(center: Vector2, rx: float, ry: float, line_color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in ELLIPSE_POINTS + 1:
		var a: float = float(i) / float(ELLIPSE_POINTS) * TAU
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(points, line_color, LINE_WIDTH * 0.6)


func _draw_equalizer() -> void:
	var bar_width: float = size.x / float(EQ_BARS)
	var block_height: float = size.y / float(EQ_BLOCKS)
	for bar: int in EQ_BARS:
		# Altura pseudoaleatoria estable por cuadro y barra.
		var level: int = 1 + hash(Vector2i(_frame, bar)) % EQ_BLOCKS
		for block: int in level:
			var top: bool = block >= EQ_BLOCKS - 2
			var rect := Rect2(float(bar) * bar_width + bar_width * EQ_GAP * 0.5,
					size.y - float(block + 1) * block_height + block_height * EQ_GAP * 0.5,
					bar_width * (1.0 - EQ_GAP), block_height * (1.0 - EQ_GAP))
			draw_rect(rect, accent if top else color)


func _draw_star() -> void:
	var center: Vector2 = size * 0.5
	var phase: float = float(_frame % STAR_FRAMES) / float(STAR_FRAMES)
	var radius: float = minf(size.x, size.y) * 0.5 * (0.55 + 0.45 * absf(sin(phase * PI)))
	var points := PackedVector2Array()
	for i: int in 8:
		var a: float = float(i) * PI / 4.0 + phase * PI * 0.5
		var r: float = radius if i % 2 == 0 else radius * STAR_INNER
		points.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(points, color if _frame % 2 == 0 else accent)
