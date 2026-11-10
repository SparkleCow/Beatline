class_name LaneTrack
extends Node3D
## Pista infinita neón con segmentos reciclados (pool fijo): piso con grilla, rieles
## laterales y un arco neón por segmento. Más un suelo synthwave fijo alrededor.
## El desplazamiento se calcula desde el reloj de audio: offset = song_time * velocidad.

const GRID_SHADER: Shader = preload("res://assets/shaders/neon_grid.gdshader")
const GROUND_SHADER: Shader = preload("res://assets/shaders/ground_grid.gdshader")
## Los colores alternan cada 2 segmentos, así el patrón no salta al reciclar.
const STRIPE_PERIOD: int = 2
## Segmentos que quedan detrás del jugador (debajo de la cámara).
const SEGMENTS_BEHIND: int = 1
const RAIL_SIZE: Vector2 = Vector2(0.12, 0.12)
const ARCH_HEIGHT: float = 3.6
const ARCH_THICKNESS: float = 0.14
const ARCH_SIDE_MARGIN: float = 0.5
const RAIL_GLOW: float = 3.0
const ARCH_GLOW: float = 2.2
const GROUND_SIZE: Vector2 = Vector2(220.0, 200.0)
const GROUND_DEPTH: float = 0.35
## Distancia hacia adelante del centro del suelo fijo.
const GROUND_FORWARD: float = 70.0

var _game: GameConfig
var _speed: float = 14.0
var _segments: Array[Node3D] = []


func setup(game: GameConfig, bpm: float) -> void:
	_game = game
	_speed = game.scroll_speed(bpm)
	if _segments.is_empty():
		_build_segments()
		_build_ground()
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
	var length: float = _game.segment_length
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(width, _game.floor_thickness, length)
	var grid := ShaderMaterial.new()
	grid.shader = GRID_SHADER
	grid.set_shader_parameter(&"lane_width", _game.lane_width)
	grid.set_shader_parameter(&"lane_count", float(_game.lane_count))

	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(RAIL_SIZE.x, RAIL_SIZE.y, length)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(ARCH_THICKNESS, ARCH_HEIGHT, ARCH_THICKNESS)
	var arch_half: float = width * 0.5 + ARCH_SIDE_MARGIN
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(arch_half * 2.0 + ARCH_THICKNESS, ARCH_THICKNESS, ARCH_THICKNESS)
	var rail_mat: ShaderMaterial = NeonPalette.solid_material(NeonPalette.CYAN, RAIL_GLOW)
	var arch_mats: Array[ShaderMaterial] = [
		NeonPalette.solid_material(NeonPalette.PINK, ARCH_GLOW),
		NeonPalette.solid_material(NeonPalette.PURPLE, ARCH_GLOW),
	]

	var count: int = ceili(float(_game.segment_count) / STRIPE_PERIOD) * STRIPE_PERIOD
	for i: int in count:
		var segment := Node3D.new()
		segment.name = "Segment%d" % i
		_add_mesh(segment, floor_mesh, grid, Vector3(0.0, -_game.floor_thickness * 0.5, 0.0))
		for side: float in [-1.0, 1.0]:
			_add_mesh(segment, rail_mesh, rail_mat, Vector3(side * width * 0.5, RAIL_SIZE.y * 0.5, 0.0))
			_add_mesh(segment, post_mesh, arch_mats[i % STRIPE_PERIOD],
					Vector3(side * arch_half, ARCH_HEIGHT * 0.5, -length * 0.5))
		_add_mesh(segment, beam_mesh, arch_mats[i % STRIPE_PERIOD], Vector3(0.0, ARCH_HEIGHT, -length * 0.5))
		add_child(segment)
		_segments.append(segment)


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = GROUND_SIZE
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.position = Vector3(0.0, -GROUND_DEPTH, -GROUND_FORWARD)
	add_child(ground)


static func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
