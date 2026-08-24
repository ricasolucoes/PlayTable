class_name CardAtlas3D
extends RefCounted

## CardAtlas3D: Um unico atlas com as 52 faces, o verso e uma area lisa.
##
## Por que atlas: cada carta usaria uma textura propria, e um Klondike na mesa
## chega a 52 cartas. Com o atlas existe UMA textura na VRAM e as cartas se
## diferenciam so pelo deslocamento de UV do material -- que e barato.
##
## O desenho e feito uma vez, num SubViewport, reaproveitando CardArt2D. Depois
## disso o SubViewport e destruido e fica so a ImageTexture.

const COLS := 13
const ROWS := 5
const SUITS_COUNT := 4
const BACK_COL := 0
const BLANK_COL := 1
const EXTRA_ROW := 4

static var _atlas: ImageTexture = null
static var _building: bool = false
static var _face_materials: Dictionary = {}
static var _body_material: StandardMaterial3D = null

static func is_ready() -> bool:
	return _atlas != null

## Garante que o atlas exista. Seguro chamar de varias cartas ao mesmo tempo:
## a primeira constroi e as demais esperam a mesma construcao.
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
	context.get_tree().root.add_child(viewport)

	# Dois quadros: um para o SubViewport desenhar, outro para a textura ficar
	# disponivel para leitura.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

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

static func face_uv(rank: String, suit: String) -> Rect2:
	var col: int = maxi(CardArt2D.RANKS.find(rank), 0)
	var row: int = maxi(CardArt2D.SUITS.find(suit), 0)
	return cell_uv(col, row)

static func back_uv() -> Rect2:
	return cell_uv(BACK_COL, EXTRA_ROW)

## Area lisa usada pela borda da carta -- um retangulo pequeno bem no meio da
## celula branca, longe das costuras do atlas.
static func rim_uv() -> Rect2:
	var cell := cell_uv(BLANK_COL, EXTRA_ROW)
	return Rect2(cell.position + cell.size * 0.35, cell.size * 0.30)

# ---------------------------------------------------------------------------
# Materiais
# ---------------------------------------------------------------------------

## Material da face de uma carta: mesma textura para todas, so muda a UV.
static func face_material(rank: String, suit: String) -> StandardMaterial3D:
	var key := rank + suit
	if _face_materials.has(key):
		return _face_materials[key]
	var uv := face_uv(rank, suit)
	var mat := _make_card_material()
	mat.uv1_scale = Vector3(uv.size.x, uv.size.y, 1.0)
	mat.uv1_offset = Vector3(uv.position.x, uv.position.y, 0.0)
	_face_materials[key] = mat
	return mat

## Material do verso e da borda: um so para o baralho inteiro, porque as UVs
## dessas superficies ja estao gravadas na malha.
static func body_material() -> StandardMaterial3D:
	if _body_material != null:
		return _body_material
	_body_material = _make_card_material()
	return _body_material

static func _make_card_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _atlas
	# Papel plastificado: reflexo curto e difuso, sem virar plastico brilhante.
	mat.roughness = 0.44
	mat.metallic = 0.0
	mat.metallic_specular = 0.38
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.30
	mat.clearcoat_roughness = 0.35
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
		for row in CardAtlas3D.SUITS_COUNT:
			for col in CardArt2D.RANKS.size():
				var r := Rect2(Vector2(float(col) * cs.x, float(row) * cs.y), cs)
				CardArt2D.draw_face(self, r, CardArt2D.RANKS[col], CardArt2D.SUITS[row])

		var back_rect := Rect2(Vector2(float(CardAtlas3D.BACK_COL) * cs.x,
			float(CardAtlas3D.EXTRA_ROW) * cs.y), cs)
		CardArt2D.draw_back(self, back_rect)

		# Celula lisa: fonte do pixel usado pela borda da carta.
		var blank := Rect2(Vector2(float(CardAtlas3D.BLANK_COL) * cs.x,
			float(CardAtlas3D.EXTRA_ROW) * cs.y), cs)
		draw_rect(blank, Color(0.955, 0.945, 0.925), true)
