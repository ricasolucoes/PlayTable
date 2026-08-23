extends GutTest

## Paciencia Klondike — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_card_games.py::TestKlondikeSolitaire.

const RulesScript = preload("res://games/paciencia/KlondikeRules.gd")
const GameScene = preload("res://games/paciencia/KlondikeGame.tscn")

const ESPADAS := Card.Suit.SPADES
const COPAS := Card.Suit.HEARTS
const OUROS := Card.Suit.DIAMONDS
const PAUS := Card.Suit.CLUBS

const NAIPES_FUNDACAO := [ESPADAS, COPAS, OUROS, PAUS]


func _carta(valor: int, naipe: Card.Suit, virada := true) -> Card:
	var c := Card.new(valor, naipe)
	c.is_face_up = virada
	return c


func _pilha(cartas: Array) -> CardPile:
	var p := CardPile.new()
	for c in cartas:
		p.push(c)
	return p


# --------------------------------------------------------- Fundacao (can_add_)

func test_as_abre_a_fundacao() -> void:
	assert_true(RulesScript.can_add_to_foundation(_carta(1, ESPADAS), ESPADAS, null), "as de espadas")


func test_fundacao_vazia_so_aceita_as() -> void:
	assert_false(RulesScript.can_add_to_foundation(_carta(2, ESPADAS), ESPADAS, null), "2 nao abre")
	assert_false(RulesScript.can_add_to_foundation(_carta(13, ESPADAS), ESPADAS, null), "rei nao abre")


func test_fundacao_sobe_de_um_em_um() -> void:
	assert_true(RulesScript.can_add_to_foundation(_carta(2, ESPADAS), ESPADAS, _carta(1, ESPADAS)))
	assert_false(RulesScript.can_add_to_foundation(_carta(3, ESPADAS), ESPADAS, _carta(1, ESPADAS)),
		"nao pula degrau")
	assert_false(RulesScript.can_add_to_foundation(_carta(1, ESPADAS), ESPADAS, _carta(2, ESPADAS)),
		"nao desce")


func test_fundacao_exige_o_mesmo_naipe() -> void:
	assert_false(RulesScript.can_add_to_foundation(_carta(2, COPAS), ESPADAS, _carta(1, ESPADAS)),
		"naipe errado")
	assert_false(RulesScript.can_add_to_foundation(_carta(1, COPAS), ESPADAS, null),
		"as de outro naipe nao abre a fundacao de espadas")


func test_carta_nula_nunca_entra_na_fundacao() -> void:
	assert_false(RulesScript.can_add_to_foundation(null, ESPADAS, null))


func test_fundacao_completa_do_as_ao_rei() -> void:
	var topo: Card = null
	for v in range(1, 14):
		var c := _carta(v, OUROS)
		assert_true(RulesScript.can_add_to_foundation(c, OUROS, topo), "carta %d sobe" % v)
		topo = c


# ---------------------------------------------------------- Tableau (can_add_)

func test_coluna_vazia_so_aceita_rei() -> void:
	assert_true(RulesScript.can_add_to_tableau(_carta(13, COPAS), null), "rei entra")
	assert_false(RulesScript.can_add_to_tableau(_carta(12, COPAS), null), "dama nao entra")
	assert_false(RulesScript.can_add_to_tableau(_carta(1, COPAS), null), "as nao entra")


func test_tableau_desce_alternando_cores() -> void:
	assert_true(RulesScript.can_add_to_tableau(_carta(12, COPAS), _carta(13, ESPADAS)),
		"dama vermelha sobre rei preto")
	assert_true(RulesScript.can_add_to_tableau(_carta(9, OUROS), _carta(10, PAUS)),
		"9 vermelho sobre 10 preto")


func test_tableau_recusa_a_mesma_cor() -> void:
	assert_false(RulesScript.can_add_to_tableau(_carta(12, COPAS), _carta(13, OUROS)),
		"dama vermelha sobre rei vermelho")
	assert_false(RulesScript.can_add_to_tableau(_carta(10, PAUS), _carta(11, ESPADAS)),
		"10 preto sobre valete preto")


func test_tableau_recusa_valor_fora_de_sequencia() -> void:
	assert_false(RulesScript.can_add_to_tableau(_carta(10, COPAS), _carta(13, ESPADAS)), "pulou")
	assert_false(RulesScript.can_add_to_tableau(_carta(13, COPAS), _carta(12, ESPADAS)), "subiu")


func test_tableau_recusa_carta_virada_para_baixo() -> void:
	assert_false(RulesScript.can_add_to_tableau(_carta(12, COPAS), _carta(13, ESPADAS, false)),
		"nao empilha sobre carta fechada")


# ----------------------------------------------- Variantes que usam CardPile

func test_can_place_on_foundation_le_o_topo_da_pilha() -> void:
	assert_true(RulesScript.can_place_on_foundation(_carta(1, ESPADAS), _pilha([])), "pilha vazia")
	var pilha := _pilha([_carta(1, ESPADAS)])
	assert_true(RulesScript.can_place_on_foundation(_carta(2, ESPADAS), pilha), "2 sobre o as")
	assert_false(RulesScript.can_place_on_foundation(_carta(2, COPAS), pilha), "naipe errado")
	assert_false(RulesScript.can_place_on_foundation(null, pilha), "carta nula")


func test_can_place_on_tableau_le_o_topo_da_pilha() -> void:
	assert_true(RulesScript.can_place_on_tableau(_carta(13, COPAS), _pilha([])), "rei na coluna vazia")
	var pilha := _pilha([_carta(13, ESPADAS)])
	assert_true(RulesScript.can_place_on_tableau(_carta(12, COPAS), pilha), "dama vermelha")
	assert_false(RulesScript.can_place_on_tableau(_carta(12, ESPADAS), pilha), "dama preta")


func test_auto_fundacao_acha_a_pilha_do_naipe() -> void:
	var pilhas: Array = []
	for _i in range(4):
		pilhas.append(CardPile.new())
	assert_eq(RulesScript.find_auto_foundation_index(_carta(1, OUROS), pilhas, NAIPES_FUNDACAO), 2,
		"ouros e a terceira fundacao")
	assert_eq(RulesScript.find_auto_foundation_index(_carta(5, OUROS), pilhas, NAIPES_FUNDACAO), -1,
		"5 nao abre fundacao")
	assert_eq(RulesScript.find_auto_foundation_index(null, pilhas, NAIPES_FUNDACAO), -1, "carta nula")

	pilhas[2].push(_carta(1, OUROS))
	assert_eq(RulesScript.find_auto_foundation_index(_carta(2, OUROS), pilhas, NAIPES_FUNDACAO), 2,
		"2 de ouros sobe na fundacao aberta")


func test_vitoria_so_com_as_52_cartas_nas_fundacoes() -> void:
	var pilhas: Array = []
	for i in range(4):
		var p := CardPile.new()
		for v in range(1, 14):
			p.push(_carta(v, NAIPES_FUNDACAO[i]))
		pilhas.append(p)
	assert_true(RulesScript.is_game_won(pilhas), "13 x 4 = 52")
	pilhas[0].pop()
	assert_false(RulesScript.is_game_won(pilhas), "51 nao ganha")


# --------------------------------------------------------------- KlondikeGame

func test_distribuicao_inicial_da_cena() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	var total := 0
	for c in range(7):
		assert_eq(jogo.tableau[c].size(), c + 1, "coluna %d tem %d cartas" % [c, c + 1])
		total += jogo.tableau[c].size()
		for i in range(jogo.tableau[c].size()):
			var carta: Card = jogo.tableau[c].get_card(i)
			assert_eq(carta.is_face_up, i == c, "so a ultima carta da coluna %d fica virada" % c)
	assert_eq(total, 28, "28 cartas no tableau")
	assert_eq(jogo.stock.size(), 24, "52 - 28 no monte")
	assert_eq(jogo.waste.size(), 0, "descarte vazio")
	for f in jogo.foundations:
		assert_eq(f.size(), 0, "fundacao vazia")


func test_as_52_cartas_sao_unicas_na_distribuicao() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	var vistas := {}
	var todas: Array = []
	for col in jogo.tableau:
		todas.append_array(col.get_all())
	todas.append_array(jogo.stock.get_all())
	assert_eq(todas.size(), 52, "as 52 cartas na mesa")
	for c in todas:
		assert_false(vistas.has(c.id), "carta %s duplicada" % c.id)
		vistas[c.id] = true


func test_virar_o_monte_move_para_o_descarte() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	var antes: int = jogo.stock.size()
	jogo._on_stock_pressed()
	assert_eq(jogo.stock.size(), antes - 1, "uma carta saiu do monte")
	assert_eq(jogo.waste.size(), 1, "uma carta no descarte")
	assert_true(jogo.waste.peek().is_face_up, "carta do descarte fica virada para cima")


func test_monte_vazio_recicla_o_descarte() -> void:
	# Guarda contra deadlock: substitui test_e2e_klondike_solitaire_simulation.
	var jogo = add_child_autofree(GameScene.instantiate())
	var voltas := 0
	while jogo.stock.size() > 0 and voltas < 60:
		jogo._on_stock_pressed()
		voltas += 1
	assert_eq(jogo.stock.size(), 0, "monte esgotado")
	assert_eq(jogo.waste.size(), 24, "as 24 cartas foram para o descarte")
	jogo._on_stock_pressed()
	assert_eq(jogo.stock.size(), 24, "descarte reciclado de volta para o monte")
	assert_eq(jogo.waste.size(), 0, "descarte esvaziado")
