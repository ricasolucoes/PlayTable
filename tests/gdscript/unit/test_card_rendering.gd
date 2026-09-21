extends GutTest

## Contrato visual das cartas 3D: uma carta precisa existir no primeiro frame
## util, mesmo quando o atlas ainda esta sendo construido em background.

const CARD_SCENE = preload("res://shared/3d/Card3D.tscn")
const ATLAS = preload("res://shared/3d/CardAtlas3D.gd")
const ART = preload("res://shared/3d/CardArt2D.gd")


func test_atlas_rejeita_imagem_transparente_ou_preta_uniforme() -> void:
	var transparente := Image.create(180, 252, false, Image.FORMAT_RGBA8)
	assert_false(ATLAS.is_valid_image(transparente))
	var preta := Image.create(180, 252, false, Image.FORMAT_RGBA8)
	preta.fill(Color.BLACK)
	assert_false(ATLAS.is_valid_image(preta))


func test_atlas_aceita_imagem_com_pixels_de_arte() -> void:
	var imagem := Image.create(180, 252, false, Image.FORMAT_RGBA8)
	imagem.fill(Color.WHITE)
	assert_true(ATLAS.is_valid_image(imagem))


func test_invalid_atlas_keeps_card_fallback() -> void:
	var card: Card3D = CARD_SCENE.instantiate() as Card3D
	add_child_autofree(card)
	card.setup("A", ART.SUIT_SPADE, false)
	await wait_process_frames(1)
	card.apply_fallback_visuals()
	assert_true(card.has_visible_visual(), "carta visivel antes do atlas")
	assert_not_null(card.mesh_instance.mesh)


func test_all_cards_have_fallback_before_atlas_ready() -> void:
	var cards: Array[Card3D] = []
	for suit in ART.SUITS:
		for rank in ART.RANKS:
			var card: Card3D = CARD_SCENE.instantiate() as Card3D
			card.setup(rank, suit, true)
			cards.append(card)
			add_child_autofree(card)

	await wait_process_frames(3)
	for card in cards:
		assert_true(card.has_visible_visual(), "carta %s%s visivel" % [card.rank, card.suit])
