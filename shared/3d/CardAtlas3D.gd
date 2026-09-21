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
static var _state: String = "cold"
static var _last_error: String = ""
static var _warmup_pending: bool = false
static var _builder_owner: Node = null
static var _face_materials: Dictionary = {}
static var _body_material: StandardMaterial3D = null

static func is_ready() -> bool:
	return _atlas != null and _state == "ready"

static func is_valid_image(image: Image) -> bool:
	var minimum := _cell_size()
	if image == null or image.is_empty() \
		or image.get_width() < minimum.x or image.get_height() < minimum.y:
		return false
	var center := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
	var corner := image.get_pixel(0, 0)
	var edge := image.get_pixel(image.get_width() - 1, image.get_height() - 1)
	var has_alpha := center.a > 0.05 or corner.a > 0.05 or edge.a > 0.05
	var has_ink: bool = center.get_luminance() > 0.02 \
		or corner.get_luminance() > 0.02 \
		or edge.get_luminance() > 0.02 \
		or absf(center.r - corner.r) > 0.01 \
		or absf(center.g - corner.g) > 0.01 \
		or absf(center.b - corner.b) > 0.01
	return has_alpha and has_ink

static func last_error() -> String:
	return _last_error

static func request_warmup() -> void:
	if is_ready() or _state == "building" or _warmup_pending:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		_state = "failed"
		_last_error = "no SceneTree"
		return
	_warmup_pending = true
	var owner := Node.new()
	tree.root.add_child.call_deferred(owner)
	_warmup_and_release(owner, tree)

static func _warmup_and_release(owner: Node, tree: SceneTree) -> void:
	await tree.process_frame
	_warmup_pending = false
	if not is_instance_valid(owner):
		_state = "failed"
		_last_error = "warmup owner was freed"
		return
	await ensure_built(owner)
	if is_instance_valid(owner):
		owner.queue_free()

## Garante que o atlas exista. Seguro chamar de varias cartas ao mesmo tempo:
## a primeira constroi e as demais esperam a mesma construcao.
static func ensure_built(context: Node) -> bool:
	if is_ready():
		return true
	if _state == "failed":
		return false
	if not is_instance_valid(context) or context.get_tree() == null:
		return false
	var tree := context.get_tree()
	if _state == "building":
		while _state == "building":
			await tree.process_frame
		return is_ready()

	_state = "building"
	_last_error = ""
	_start_build(tree)
	while _state == "building":
		await tree.process_frame
	return is_ready()

static func _start_build(tree: SceneTree) -> void:
	var owner := Node.new()
	_builder_owner = owner
	tree.root.add_child.call_deferred(owner)
	_build_in_background(owner, tree)

static func _build_in_background(owner: Node, tree: SceneTree) -> void:
	await tree.process_frame
	if not is_instance_valid(owner):
		_fail("atlas builder owner was freed")
		return

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

	# O owner persistente desacopla o viewport do Card3D que pediu a carta. Isso
	# permite descartar uma mesa durante a distribuicao sem abandonar o atlas.
	owner.add_child(viewport)

	# Dois quadros: um para o SubViewport desenhar, outro para a textura ficar
	# disponivel para leitura.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	if not is_instance_valid(viewport):
		_release_builder(owner)
		_fail("atlas viewport disappeared after rendering")
		return
	var img := viewport.get_texture().get_image()
	viewport.free()
	if not is_valid_image(img):
		_release_builder(owner)
		_fail("atlas image is empty, transparent or uniform")
		return
	img.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(img)
	if _atlas == null:
		_release_builder(owner)
		_fail("could not create atlas texture")
		return
	_state = "ready"
	_release_builder(owner)

static func _release_builder(owner: Node) -> void:
	if _builder_owner == owner:
		_builder_owner = null
	if is_instance_valid(owner):
		owner.free()

static func _fail(message: String) -> bool:
	_state = "failed"
	_last_error = message
	return false

## Celula do atlas. 180x252 fora do tier baixo: o indice de canto ocupa um
## quarto da carta e a 150 px de largura o algarismo saia serrilhado no
## telefone, que mostra a carta com quase o dobro dos pixels do atlas.
static func _cell_size() -> Vector2i:
	if Quality3D.tier() == Quality3D.Tier.LOW:
		return Vector2i(104, 146)
	return Vector2i(180, 252)

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
	_state = "cold"
	_last_error = ""
	_warmup_pending = false
	_face_materials.clear()
	_body_material = null

# ---------------------------------------------------------------------------

## Control interno que pinta o atlas inteiro em um unico _draw.
class _AtlasPainter extends Control:
	var cell: Vector2i = Vector2i(180, 252)

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
