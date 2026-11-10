class_name LaneTrack
extends Node3D
## Pista infinita de carriles con segmentos reciclados (pool fijo).
## El desplazamiento se calcula desde el reloj de audio: offset = song_time * velocidad.

const FLOOR_COLOR_A: Color = Color(0.22, 0.22, 0.25)
const FLOOR_COLOR_B: Color = Color(0.27, 0.27, 0.3)
const DIVIDER_COLOR: Color = Color(0.6, 0.6, 0.65)
## Las franjas alternan cada 2 segmentos, así el patrón no salta al reciclar.
const STRIPE_PERIOD: int = 2
## Segmentos que quedan detrás del jugador (debajo de la cámara).
const SEGMENTS_BEHIND: int = 1
const DIVIDER_LIFT: float = 0.01

var _game: GameConfig
var _speed: float = 14.0
var _segments: Array[Node3D] = []


func setup(game: GameConfig, bpm: float) -> void:
	_game = game
	_speed = game.scroll_speed(bpm)
	if _segments.is_empty():
		_build_segments()
	on_tick(0.0)


## Conectado a RhythmClock.tick.
func on_tick(song_time: float) -> void:
	var period: float = _game.segment_length * STRIPE_PERIOD
	var offset: float = fposmod(song_time * _speed, period)
	for i: int in _segments.size():
		var slot: int = i - SEGMENTS_BEHIND * STRIPE_PERIOD
		_segments[i].position.z = -float(slot) * _game.segment_length + offset


func _build_segments() -> void:
	var width: float = _game.lane_width * _game.lane_count
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(width, _game.floor_thickness, _game.segment_length)
	var divider_mesh := BoxMesh.new()
	divider_mesh.size = Vector3(_game.divider_width, _game.floor_thickness, _game.segment_length)
	var mat_a: StandardMaterial3D = _make_material(FLOOR_COLOR_A)
	var mat_b: StandardMaterial3D = _make_material(FLOOR_COLOR_B)
	var mat_div: StandardMaterial3D = _make_material(DIVIDER_COLOR)

	# Redondear a múltiplo del período para que las franjas sean continuas.
	var count: int = ceili(float(_game.segment_count) / STRIPE_PERIOD) * STRIPE_PERIOD
	for i: int in count:
		var segment := Node3D.new()
		segment.name = "Segment%d" % i
		var floor_instance := MeshInstance3D.new()
		floor_instance.mesh = floor_mesh
		floor_instance.material_override = mat_a if i % STRIPE_PERIOD == 0 else mat_b
		floor_instance.position = Vector3(0.0, -_game.floor_thickness * 0.5, 0.0)
		floor_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segment.add_child(floor_instance)
		for lane: int in range(1, _game.lane_count):
			var divider := MeshInstance3D.new()
			divider.mesh = divider_mesh
			divider.material_override = mat_div
			var x: float = (_game.lane_x(lane - 1) + _game.lane_x(lane)) * 0.5
			divider.position = Vector3(x, -_game.floor_thickness * 0.5 + DIVIDER_LIFT, 0.0)
			divider.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			segment.add_child(divider)
		add_child(segment)
		_segments.append(segment)


static func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
