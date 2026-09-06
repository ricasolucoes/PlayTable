class_name DecalGrid3D
extends MultiMeshInstance3D

## Decalques planos sobre a mesa, todos de um atlas so, numa chamada de desenho.
##
## Nasceu para os algarismos do Campo Minado: ate 81 casas abertas, cada uma
## com um numero de 1 a 8. Um `Label3D` por casa funciona e e legivel, mas sao
## ate 81 nos, 81 malhas e 81 chamadas; aqui e um `MultiMesh` de quadrados
## deitados e a tira `numeros.png` (oito celulas encostadas), com o indice da
## celula viajando em `INSTANCE_CUSTOM` ate o fragmento, que desloca o UV.
##
## Serve a qualquer tira de icones do mesmo tamanho: a bandeira e a mina do
## Campo Minado tambem poderiam morar aqui num atlas 1x2.
##
## Uso:
##
##     var grade := DecalGrid3D.new()
##     add_child(grade)
##     grade.setup(atlas, 8, 1, 0.6, 81)      # 8 colunas, 1 linha, 0,6 un. de lado
##     grade.place(Vector2i(3, 4), pos, 2)     # celula 2 do atlas (o "3")
##     grade.remove(Vector2i(3, 4))
##     grade.clear()

const CODIGO := """
shader_type spatial;
// Sinal de interface, nao objeto da mesa: sem luz, sem sombra, e o recorte
// por alpha da PNG e o contorno do algarismo.
render_mode unshaded, cull_back, shadows_disabled, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform vec2 cell_uv = vec2(0.125, 1.0);

varying vec2 offset;

void vertex() {
	// INSTANCE_CUSTOM.xy = (coluna, linha) da celula desta instancia.
	offset = INSTANCE_CUSTOM.xy;
}

void fragment() {
	vec4 c = texture(atlas, (UV + offset) * cell_uv);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

## Altura sobre o ponto do alvo: a mesma folga do `CellHalo3D`, para os dois
## pousarem na superficie sem brigar em z com ela.
const ALTURA := 0.02

static var _shader: Shader = null

var _cols: int = 1
var _rows: int = 1
var _positions: Dictionary = {}   # id -> Vector3
var _cells: Dictionary = {}       # id -> int (indice na tira)
var _order: Array = []            # ids na ordem das instancias


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Prepara ate `capacity` decalques de `size` unidades de lado, tirados de um
## atlas com `cols` x `rows` celulas iguais.
func setup(atlas: Texture2D, cols: int, rows: int, size: float, capacity: int) -> void:
	_cols = maxi(cols, 1)
	_rows = maxi(rows, 1)

	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	# QuadMesh nasce de pe no plano XY; deitado, o topo da imagem aponta para
	# -Z, que e o "longe" da camera -- o algarismo fica de pe para quem joga.
	quad.orientation = PlaneMesh.FACE_Y

	var mat := ShaderMaterial.new()
	mat.shader = _get_shader()
	mat.set_shader_parameter("atlas", atlas)
	mat.set_shader_parameter("cell_uv", Vector2(1.0 / float(_cols), 1.0 / float(_rows)))
	material_override = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = maxi(capacity, 0)
	mm.visible_instance_count = 0
	multimesh = mm

	_positions.clear()
	_cells.clear()
	_order.clear()


## Poe (ou troca) o decalque `id` em `position_3d`, com a celula `cell` do
## atlas contada da esquerda para a direita, linha a linha, a partir de zero.
func place(id: Variant, position_3d: Vector3, cell: int) -> void:
	if multimesh == null:
		return
	if not _positions.has(id):
		if _order.size() >= multimesh.instance_count:
			push_warning("DecalGrid3D: capacidade de %d esgotada" % multimesh.instance_count)
			return
		_order.append(id)
	_positions[id] = position_3d
	_cells[id] = clampi(cell, 0, _cols * _rows - 1)
	_refresh()


func remove(id: Variant) -> void:
	if not _positions.has(id):
		return
	_positions.erase(id)
	_cells.erase(id)
	_order.erase(id)
	_refresh()


func has(id: Variant) -> bool:
	return _positions.has(id)


## A celula do atlas de um decalque, ou -1. Registro deste no, nao do
## RenderingServer: em modo headless o MultiMesh nao devolve o que recebeu.
func cell_of(id: Variant) -> int:
	return int(_cells.get(id, -1))


func position_of(id: Variant) -> Vector3:
	return _positions.get(id, Vector3.INF)


## Em que instancia o decalque esta desenhado: as vivas ficam compactadas do
## zero em diante, na ordem em que entraram.
func slot_of(id: Variant) -> int:
	return _order.find(id)


func count() -> int:
	return _order.size()


func clear() -> void:
	_positions.clear()
	_cells.clear()
	_order.clear()
	_refresh()


func _refresh() -> void:
	if multimesh == null:
		return
	var n := 0
	for id in _order:
		var celula: int = _cells[id]
		var pos: Vector3 = _positions[id]
		multimesh.set_instance_transform(n,
			Transform3D(Basis.IDENTITY, pos + Vector3(0.0, ALTURA, 0.0)))
		multimesh.set_instance_custom_data(n,
			Color(float(celula % _cols), float(celula / _cols), 0.0, 0.0))
		n += 1
	multimesh.visible_instance_count = n


static func _get_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODIGO
	return _shader
