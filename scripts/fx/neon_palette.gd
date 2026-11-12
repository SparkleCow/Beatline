class_name NeonPalette
extends RefCounted
## Paleta neón Y2K y fábrica de materiales compartidos (crear una vez, reutilizar siempre).

const PINK: Color = Color(1.0, 0.16, 0.72)
const CYAN: Color = Color(0.1, 0.95, 1.0)
const PURPLE: Color = Color(0.62, 0.25, 1.0)
const LIME: Color = Color(0.65, 1.0, 0.15)
const ORANGE: Color = Color(1.0, 0.55, 0.1)
const WHITE: Color = Color(1.0, 1.0, 1.0)
## Orden de colores por compás: cada compás de obstáculos tiene su color.
const COLORS: Array[Color] = [PINK, CYAN, PURPLE, LIME, ORANGE]

const SHADER_EDGES: Shader = preload("res://assets/shaders/neon_edges.gdshader")
const SHADER_SOLID: Shader = preload("res://assets/shaders/neon_solid.gdshader")


static func color_for_bar(bar: int) -> Color:
	return COLORS[posmod(bar, COLORS.size())]


## Caja con aristas brillantes. `size` debe coincidir con el BoxMesh.
static func edges_material(edge: Color, size: Vector3, striped: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_EDGES
	mat.set_shader_parameter(&"edge_color", edge)
	mat.set_shader_parameter(&"half_size", size * 0.5)
	mat.set_shader_parameter(&"stripes", 1.0 if striped else 0.0)
	return mat


static func solid_material(color: Color, glow: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_SOLID
	mat.set_shader_parameter(&"color", color)
	mat.set_shader_parameter(&"glow", glow)
	return mat
