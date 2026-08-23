extends GutTest

## Cartas das Cores (Uno-like) — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_card_games.py::TestUnoLike.

const RulesScript = preload("res://games/unolike/UnoRules.gd")
const GameScene = preload("res://games/unolike/UnoLikeGame.tscn")

const VERMELHO := Card.ColorType.RED
const AZUL := Card.ColorType.BLUE
const VERDE := Card.ColorType.GREEN
const AMARELO := Card.ColorType.YELLOW
const CURINGA := Card.ColorType.WILD


func _numero(valor: int, cor: Card.ColorType) -> Card:
	return Card.new(valor, Card.Suit.NONE, cor, "number")


func _acao(valor: int, cor: Card.ColorType, tipo: String) -> Card:
	return Card.new(valor, Card.Suit.NONE, cor, tipo)


# -------------------------------------------------------------------- UnoRules

func test_carta_da_mesma_cor_e_valida() -> void:
	var topo := _numero(7, VERMELHO)
	assert_true(RulesScript.is_valid_play(_numero(3, VERMELHO), VERMELHO, topo), "vermelho sobre vermelho")


func test_carta_do_mesmo_valor_e_valida() -> void:
	var topo := _numero(7, VERMELHO)
	assert_true(RulesScript.is_valid_play(_numero(7, AZUL), VERMELHO, topo), "7 sobre 7")


func test_curinga_e_sempre_valido() -> void:
	var topo := _numero(7, VERMELHO)
	assert_true(RulesScript.is_valid_play(_acao(50, CURINGA, "wild"), VERMELHO, topo), "curinga")
	assert_true(RulesScript.is_valid_play(_acao(54, CURINGA, "wild4"), AZUL, topo), "curinga +4")


func test_cor_e_valor_diferentes_e_invalido() -> void:
	var topo := _numero(7, VERMELHO)
	assert_false(RulesScript.is_valid_play(_numero(2, VERDE), VERMELHO, topo), "verde 2 sobre vermelho 7")


func test_carta_nula_nunca_e_valida() -> void:
	assert_false(RulesScript.is_valid_play(null, VERMELHO, _numero(7, VERMELHO)))


func test_a_cor_ativa_manda_e_nao_a_cor_do_topo() -> void:
	# Depois de um curinga o topo e WILD, mas a cor ativa e a escolhida.
	var topo := _acao(50, CURINGA, "wild")
	assert_true(RulesScript.is_valid_play(_numero(3, VERDE), VERDE, topo), "verde com cor ativa verde")
	assert_false(RulesScript.is_valid_play(_numero(3, AZUL), VERDE, topo), "azul nao entra")


func test_acao_casa_por_tipo_e_valor() -> void:
	var topo := _acao(10, VERMELHO, "skip")
	assert_true(RulesScript.is_valid_play(_acao(10, AZUL, "skip"), VERMELHO, topo), "skip sobre skip")
	assert_false(RulesScript.is_valid_play(_acao(11, AZUL, "reverse"), VERMELHO, topo),
		"reverse nao casa com skip")


func test_numero_nao_casa_com_acao_de_mesmo_valor() -> void:
	# O +2 vale 12 e a Dama do baralho frances tambem, mas o tipo difere.
	var topo := _acao(12, VERMELHO, "draw2")
	assert_false(RulesScript.is_valid_play(_numero(12, AZUL), VERMELHO, topo), "tipos diferentes")


func test_sem_topo_so_a_cor_ativa_decide() -> void:
	assert_true(RulesScript.is_valid_play(_numero(3, VERMELHO), VERMELHO, null), "cor bate")
	assert_false(RulesScript.is_valid_play(_numero(3, AZUL), VERMELHO, null), "cor nao bate")


func test_can_play_card_e_apelido_com_os_argumentos_trocados() -> void:
	var topo := _numero(7, VERMELHO)
	var carta := _numero(7, AZUL)
	assert_eq(RulesScript.can_play_card(carta, topo, VERMELHO),
		RulesScript.is_valid_play(carta, VERMELHO, topo), "mesmo resultado")


func test_get_playable_cards_lista_os_indices() -> void:
	var topo := _numero(7, VERMELHO)
	var mao := [_numero(2, VERDE), _numero(7, AZUL), _numero(3, VERMELHO), _acao(50, CURINGA, "wild")]
	assert_eq(RulesScript.get_playable_cards(mao, VERMELHO, topo), [1, 2, 3] as Array[int])
	assert_eq(RulesScript.get_playable_cards([], VERMELHO, topo), [] as Array[int], "mao vazia")


func test_ia_escolhe_a_cor_majoritaria() -> void:
	var mao := [
		_numero(1, AZUL), _numero(4, AZUL), _numero(9, AZUL),
		_numero(5, VERMELHO), _numero(3, VERDE),
	]
	assert_eq(RulesScript.pick_best_color_for_hand(mao), AZUL, "3 azuis contra 1 e 1")


func test_curinga_nao_conta_na_escolha_de_cor() -> void:
	var mao := [_acao(50, CURINGA, "wild"), _acao(54, CURINGA, "wild4"), _numero(2, AMARELO)]
	assert_eq(RulesScript.pick_best_color_for_hand(mao), AMARELO, "so a carta colorida conta")


func test_empate_de_cores_devolve_a_primeira() -> void:
	var mao := [_numero(1, VERDE), _numero(2, VERMELHO)]
	assert_eq(RulesScript.pick_best_color_for_hand(mao), VERMELHO, "vermelho abre a contagem")
	assert_eq(RulesScript.pick_best_color_for_hand([]), VERMELHO, "mao vazia tambem")


func test_simbolo_de_cada_cor() -> void:
	assert_eq(RulesScript.get_color_symbol(VERMELHO), "🔴")
	assert_eq(RulesScript.get_color_symbol(AZUL), "🔵")
	assert_eq(RulesScript.get_color_symbol(VERDE), "🟢")
	assert_eq(RulesScript.get_color_symbol(AMARELO), "🟡")
	assert_eq(RulesScript.get_color_symbol(CURINGA), "🌈")
	assert_eq(RulesScript.get_color_symbol(Card.ColorType.NONE), "⚪")


# ---------------------------------------------------------- Baralho e distribuicao

func test_baralho_uno_tem_108_cartas() -> void:
	var baralho: Deck = Deck.create_uno_deck()
	assert_eq(baralho.size(), 108, "76 numeros + 24 acoes + 8 curingas")
	var curingas := 0
	var por_cor := {VERMELHO: 0, AZUL: 0, VERDE: 0, AMARELO: 0}
	for c in baralho.cards:
		if c.color_type == CURINGA:
			curingas += 1
		elif por_cor.has(c.color_type):
			por_cor[c.color_type] += 1
	assert_eq(curingas, 8, "4 curingas + 4 curingas +4")
	for cor in por_cor:
		assert_eq(por_cor[cor], 25, "25 cartas por cor")


func test_distribuicao_inicial_da_cena() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	assert_eq(jogo.player_hand.size(), 7, "7 cartas para o jogador")
	assert_eq(jogo.ai_hand.size(), 7, "7 cartas para a IA")
	assert_eq(jogo.discard_pile.size(), 1, "uma carta virada na mesa")
	assert_eq(jogo.draw_pile.size(), 108 - 15, "o resto no monte")


func test_primeira_carta_da_mesa_nunca_e_curinga() -> void:
	for _partida in range(10):
		var jogo = add_child_autofree(GameScene.instantiate())
		var topo: Card = jogo.discard_pile.peek()
		assert_ne(topo.color_type, CURINGA, "a mesa abre com uma cor definida")
		assert_eq(jogo.active_color, topo.color_type, "a cor ativa comeca igual a do topo")


func test_partida_completa_nao_trava() -> void:
	# Guarda contra deadlock: substitui test_e2e_unolike_simulation.
	for _partida in range(10):
		var baralho: Deck = Deck.create_uno_deck()
		baralho.shuffle()
		var maos := [[], []]
		for _i in range(7):
			maos[0].append(baralho.draw())
			maos[1].append(baralho.draw())
		var topo: Card = baralho.draw()
		while topo != null and topo.color_type == CURINGA:
			topo = baralho.draw()
		var cor_ativa: Card.ColorType = topo.color_type
		var vez := 0
		var rodadas := 0
		while not maos[0].is_empty() and not maos[1].is_empty() and rodadas < 400:
			rodadas += 1
			var jogaveis: Array[int] = RulesScript.get_playable_cards(maos[vez], cor_ativa, topo)
			if jogaveis.is_empty():
				var comprada: Card = baralho.draw()
				if comprada == null:
					break
				maos[vez].append(comprada)
			else:
				var carta: Card = maos[vez].pop_at(jogaveis[0])
				topo = carta
				cor_ativa = RulesScript.pick_best_color_for_hand(maos[vez]) if carta.color_type == CURINGA else carta.color_type
				vez = 1 - vez
		assert_true(maos[0].is_empty() or maos[1].is_empty() or baralho.is_empty(),
			"a partida termina por batida ou por monte esgotado")
