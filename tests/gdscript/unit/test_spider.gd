extends GutTest

## Regras e invariantes da Paciência Spider.

const RulesScript = preload("res://games/paciencia_spider/SpiderRules.gd")
const GameScene = preload("res://games/paciencia_spider/SpiderGame.tscn")

func _card(value: int, suit: Card.Suit, face_up := true) -> Card:
	var card := Card.new(value, suit)
	card.is_face_up = face_up
	return card


func _pile(cards: Array) -> CardPile:
	var pile := CardPile.new()
	for card in cards:
		pile.push(card)
	return pile


func test_sequencia_do_mesmo_naipe_desce() -> void:
	assert_true(RulesScript.can_move_sequence([_card(9, Card.Suit.SPADES), _card(8, Card.Suit.SPADES)]))
	assert_false(RulesScript.can_move_sequence([_card(9, Card.Suit.SPADES), _card(8, Card.Suit.HEARTS)]))
	assert_false(RulesScript.can_move_sequence([_card(9, Card.Suit.SPADES), _card(7, Card.Suit.SPADES)]))


func test_coluna_vazia_so_recebe_rei() -> void:
	var vazia := CardPile.new()
	assert_true(RulesScript.can_place_sequence_on_tableau([_card(13, Card.Suit.CLUBS)], vazia))
	assert_false(RulesScript.can_place_sequence_on_tableau([_card(12, Card.Suit.CLUBS)], vazia))


func test_destino_aceita_qualquer_naipe_uma_abaixo() -> void:
	var destino := _pile([_card(10, Card.Suit.HEARTS)])
	assert_true(RulesScript.can_place_sequence_on_tableau([_card(9, Card.Suit.SPADES)], destino))
	assert_false(RulesScript.can_place_sequence_on_tableau([_card(8, Card.Suit.SPADES)], destino))


func test_sequencia_completa_e_rei_ate_as() -> void:
	var cartas: Array = []
	for value in range(13, 0, -1):
		cartas.append(_card(value, Card.Suit.DIAMONDS))
	assert_true(RulesScript.is_complete_run(cartas))
	cartas[5] = _card(8, Card.Suit.CLUBS)
	assert_false(RulesScript.is_complete_run(cartas))


func test_distribuicao_tem_104_cartas_em_10_colunas_e_50_no_monte() -> void:
	var game = add_child_autofree(GameScene.instantiate())
	var total: int = game.stock.size()
	for col in game.tableau:
		total += col.size()
	assert_eq(total, 104)
	assert_eq(game.stock.size(), 50)
	assert_eq(game.tableau.size(), 10)
	assert_eq(game.tableau[0].size(), 6)
	assert_eq(game.tableau[9].size(), 5)


func test_distribuicao_de_estoque_exige_colunas_preenchidas() -> void:
	var game = add_child_autofree(GameScene.instantiate())
	var antes: int = game.stock.size()
	game.tableau[0].clear()
	game._on_stock_pressed()
	assert_eq(game.stock.size(), antes)
