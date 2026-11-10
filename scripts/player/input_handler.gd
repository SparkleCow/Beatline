class_name InputHandler
extends Node
## Traduce toques/deslizamientos y teclado en señales de intención. No mueve nada.
##
## Táctil: deslizar izq/der = carril (se dispara durante el arrastre, sin esperar a soltar);
##         deslizar arriba o toque corto = saltar.
## PC: flechas / A-D para carril, Espacio / flecha arriba / W para saltar, F3 debug.
## El ratón emula toques (input_devices/pointing/emulate_touch_from_mouse).

signal lane_change_requested(direction: int)
signal jump_requested
signal debug_toggled

const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_JUMP: StringName = &"jump"
const ACTION_DEBUG: StringName = &"toggle_debug"

## Distancia mínima (fracción del ancho visible) para considerar un deslizamiento.
const SWIPE_MIN_FRACTION: float = 0.06
## Movimiento máximo (fracción del ancho) para que cuente como toque.
const TAP_MAX_FRACTION: float = 0.03
## Duración máxima de un toque.
const TAP_MAX_MSEC: int = 250
const NO_TOUCH: int = -1

var _touch_index: int = NO_TOUCH
var _touch_origin: Vector2 = Vector2.ZERO
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_msec: int = 0
var _swiped: bool = false


func _ready() -> void:
	ensure_actions()


## Registra las acciones de teclado si el proyecto no las define.
static func ensure_actions() -> void:
	_ensure_action(ACTION_LEFT, [KEY_LEFT, KEY_A])
	_ensure_action(ACTION_RIGHT, [KEY_RIGHT, KEY_D])
	_ensure_action(ACTION_JUMP, [KEY_SPACE, KEY_UP, KEY_W])
	_ensure_action(ACTION_DEBUG, [KEY_F3])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event.is_action_pressed(ACTION_LEFT):
		lane_change_requested.emit(-1)
	elif event.is_action_pressed(ACTION_RIGHT):
		lane_change_requested.emit(1)
	elif event.is_action_pressed(ACTION_JUMP):
		jump_requested.emit()
	elif event.is_action_pressed(ACTION_DEBUG):
		debug_toggled.emit()


func _handle_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _touch_index != NO_TOUCH:
			return
		_touch_index = touch.index
		_touch_origin = touch.position
		_touch_start_pos = touch.position
		_touch_start_msec = Time.get_ticks_msec()
		_swiped = false
		return
	if touch.index != _touch_index:
		return
	_touch_index = NO_TOUCH
	if _swiped:
		return
	var moved: float = touch.position.distance_to(_touch_start_pos)
	var duration: int = Time.get_ticks_msec() - _touch_start_msec
	if moved <= _screen_width() * TAP_MAX_FRACTION and duration <= TAP_MAX_MSEC:
		jump_requested.emit()


func _handle_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != _touch_index:
		return
	var delta: Vector2 = drag.position - _touch_origin
	var threshold: float = _screen_width() * SWIPE_MIN_FRACTION
	if absf(delta.x) >= threshold and absf(delta.x) > absf(delta.y):
		lane_change_requested.emit(1 if delta.x > 0.0 else -1)
		_swiped = true
		_touch_origin = drag.position  # Re-armar: seguir arrastrando cambia otro carril.
	elif -delta.y >= threshold and -delta.y > absf(delta.x):
		jump_requested.emit()
		_swiped = true
		_touch_origin = drag.position


func _screen_width() -> float:
	var viewport: Viewport = get_viewport()
	return viewport.get_visible_rect().size.x if viewport else 1.0


static func _ensure_action(action: StringName, keys: Array[Key]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
