class_name UnoCardAtlas3D
extends RefCounted

## UnoCardAtlas3D: um unico atlas com as 52 faces do baralho colorido.
##
## Mesma ideia e mesma interface do CardAtlas3D -- uma textura na VRAM, cartas
## diferenciadas so pelo deslocamento de UV do material -- para o Card3D poder
## trocar de baralho sem saber de qual dos dois esta falando. Ver `Card3D.atlas`.
##
## Grade: 13 colunas (0..9, bloquear, inverter, +2) por 5 linhas (as quatro
## cores, mais uma linha de servico com curinga, curinga +4, verso e area lisa).

const COLS := 13
const ROWS := 5
const EXTRA_ROW := 4
const WILD_COL := 0
const WILD4_COL := 1
const BACK_COL := 2
const BLANK_COL := 3

static var _atlas: ImageTexture = null
static var _building: bool = false
static var _face_materials: Dictionary = {}
static var _body_material: StandardMaterial3D = null


static func is_ready() -> bool:
	return _atlas != null


## Garante que o atlas exista. Seguro chamar de varias cartas ao mesmo tempo: a
## primeira constroi e as demais esperam a mesma construcao.
static func ensure_built(context: Node) -> void:
	if _atlas != null:
		return
	if _building:
		while _building and is_instance_valid(context):
			await context.get_tree().process_frame
		return
	_building = true

	var cell := _cell_size()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(cell.x * COLS, cell.y * ROWS)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.disable_3d = true

	var painter := _AtlasPainter.new()
	painter.cell = cell
	painter.size = Vector2(viewport.size)
	viewport.add_child(painter)

	# `call_deferred` pelo mesmo motivo do CardAtlas3D: quem chama isto e o
	# `_ready` de uma Card3D, e enquanto a cena do jogo esta entrando na arvore
	# a raiz recusa novos filhos. Sem adiar, o SubViewport nunca entrava, a
	# textura vinha preta e o baralho inteiro saia como retangulos pretos.
	var tree := context.get_tree()
	tree.root.add_child.call_deferred(viewport)
	while not viewport.is_inside_tree():
		if not is_instance_valid(context) or not is_instance_valid(viewport):
			_building = false
			return
		await tree.process_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	if is_instance_valid(viewport):
		var img := viewport.get_texture().get_image()
		img.generate_mipmaps()
		_atlas = ImageTexture.create_from_image(img)
		viewport.queue_free()

	_building = false


static func _cell_size() -> Vector2i:
	if Quality3D.tier() == Quality3D.Tier.LOW:
		return Vector2i(104, 146)
	return Vector2i(150, 210)


# ---------------------------------------------------------------------------
# Coordenadas no atlas
# ---------------------------------------------------------------------------

static func cell_uv(col: int, row: int) -> Rect2:
	return Rect2(float(col) / float(COLS), float(row) / float(ROWS),
		1.0 / float(COLS), 1.0 / float(ROWS))


## `kind` e "0".."9", "skip", "reverse", "draw2", "wild" ou "wild4";
## `color` e "red", "yellow", "green", "blue" ou "wild".
static func face_uv(kind: String, color: String) -> Rect2:
	if kind == "wild":
		return cell_uv(WILD_COL, EXTRA_ROW)
	if kind == "wild4":
		return cell_uv(WILD4_COL, EXTRA_ROW)
	var col: int = maxi(UnoCardArt2D.KINDS.find(kind), 0)
	var row: int = maxi(UnoCardArt2D.COLOR_KEYS.find(color), 0)
	return cell_uv(col, row)


static func back_uv() -> Rect2:
	return cell_uv(BACK_COL, EXTRA_ROW)


## Area lisa usada pela borda da carta: um retangulo pequeno no meio da celula
## branca, longe das costuras do atlas.
static func rim_uv() -> Rect2:
	var cell := cell_uv(BLANK_COL, EXTRA_ROW)
	return Rect2(cell.position + cell.size * 0.35, cell.size * 0.30)


# ---------------------------------------------------------------------------
# Materiais
# ---------------------------------------------------------------------------

static func face_material(kind: String, color: String) -> StandardMaterial3D:
	var key := kind + "_" + color
	if _face_materials.has(key):
		return _face_materials[key]
	var uv := face_uv(kind, color)
	var mat := _make_card_material()
	mat.uv1_scale = Vector3(uv.size.x, uv.size.y, 1.0)
	mat.uv1_offset = Vector3(uv.position.x, uv.position.y, 0.0)
	_face_materials[key] = mat
	return mat


static func body_material() -> StandardMaterial3D:
	if _body_material != null:
		return _body_material
	_body_material = _make_card_material()
	return _body_material


static func _make_card_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _atlas
	mat.roughness = 0.40
	mat.metallic = 0.0
	mat.metallic_specular = 0.42
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.35
	mat.clearcoat_roughness = 0.30
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


static func clear_cache() -> void:
	_atlas = null
	_face_materials.clear()
	_body_material = null


# ---------------------------------------------------------------------------

## Control interno que pinta o atlas inteiro em um unico _draw.
class _AtlasPainter extends Control:
	var cell: Vector2i = Vector2i(150, 210)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 1), true)
		var cs := Vector2(cell)

		for row in UnoCardArt2D.COLOR_KEYS.size():
			for col in UnoCardArt2D.KINDS.size():
				var r := Rect2(Vector2(float(col) * cs.x, float(row) * cs.y), cs)
				UnoCardArt2D.draw_face(self, r, UnoCardArt2D.KINDS[col],
					UnoCardArt2D.COLOR_KEYS[row])

		var extra := float(UnoCardAtlas3D.EXTRA_ROW) * cs.y
		UnoCardArt2D.draw_face(self,
			Rect2(Vector2(float(UnoCardAtlas3D.WILD_COL) * cs.x, extra), cs),
			"wild", UnoCardArt2D.WILD)
		UnoCardArt2D.draw_face(self,
			Rect2(Vector2(float(UnoCardAtlas3D.WILD4_COL) * cs.x, extra), cs),
			"wild4", UnoCardArt2D.WILD)
		UnoCardArt2D.draw_back(self,
			Rect2(Vector2(float(UnoCardAtlas3D.BACK_COL) * cs.x, extra), cs))

		# Celula lisa: fonte do pixel usado pela borda da carta.
		draw_rect(Rect2(Vector2(float(UnoCardAtlas3D.BLANK_COL) * cs.x, extra), cs),
			Color(0.985, 0.982, 0.975), true)
