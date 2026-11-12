class_name SegmentDisplay
extends Control
## Contador digital de 7 segmentos dibujado por código (estilo reloj LCD / marcador retro).
## No usa fuentes ni texturas: cada dígito son hasta 7 rectángulos.

## Segmentos encendidos por dígito, bits: a=1 (arriba), b=2, c=4, d=8 (abajo), e=16, f=32, g=64 (medio).
const DIGIT_MASKS: PackedInt32Array = [63, 6, 91, 79, 102, 109, 125, 7, 127, 111]
const SEG_A: int = 1
const SEG_B: int = 2
const SEG_C: int = 4
const SEG_D: int = 8
const SEG_E: int = 16
const SEG_F: int = 32
const SEG_G: int = 64
## Proporciones respecto a la altura del dígito.
const WIDTH_RATIO: float = 0.55
const THICKNESS_RATIO: float = 0.13
const SPACING_RATIO: float = 0.2
## Brillo de los segmentos apagados (efecto LCD).
const OFF_ALPHA: float = 0.13

var digits: int = 5
var digit_height: float = 90.0
var on_color: Color = NeonPalette.CYAN

var value: int = 0:
	set(new_value):
		var clamped: int = clampi(new_value, 0, int(pow(10.0, float(digits))) - 1)
		if clamped != value:
			value = clamped
			queue_redraw()


static func create(p_digits: int, p_height: float, color: Color) -> SegmentDisplay:
	var display := SegmentDisplay.new()
	display.digits = p_digits
	display.digit_height = p_height
	display.on_color = color
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width: float = p_height * WIDTH_RATIO
	display.custom_minimum_size = Vector2(
			float(p_digits) * width + float(p_digits - 1) * p_height * SPACING_RATIO, p_height)
	return display


func _draw() -> void:
	var width: float = digit_height * WIDTH_RATIO
	var step: float = width + digit_height * SPACING_RATIO
	var text: String = str(value)
	for i: int in digits:
		# Alineado a la derecha; las posiciones sin dígito quedan "apagadas".
		var char_index: int = i - (digits - text.length())
		var mask: int = DIGIT_MASKS[text.unicode_at(char_index) - 48] if char_index >= 0 else 0
		_draw_digit(Vector2(float(i) * step, 0.0), width, mask)


func _draw_digit(origin: Vector2, width: float, mask: int) -> void:
	var h: float = digit_height
	var t: float = h * THICKNESS_RATIO
	var bar: Vector2 = Vector2(width - 2.0 * t, t)
	var post: Vector2 = Vector2(t, h * 0.5 - 1.5 * t)
	var lower: float = h * 0.5 + t * 0.5
	_segment(origin + Vector2(t, 0.0), bar, mask & SEG_A)
	_segment(origin + Vector2(width - t, t), post, mask & SEG_B)
	_segment(origin + Vector2(width - t, lower), post, mask & SEG_C)
	_segment(origin + Vector2(t, h - t), bar, mask & SEG_D)
	_segment(origin + Vector2(0.0, lower), post, mask & SEG_E)
	_segment(origin + Vector2(0.0, t), post, mask & SEG_F)
	_segment(origin + Vector2(t, h * 0.5 - t * 0.5), bar, mask & SEG_G)


func _segment(pos: Vector2, size_px: Vector2, lit: int) -> void:
	draw_rect(Rect2(pos, size_px), on_color if lit != 0 else Color(on_color, OFF_ALPHA))
