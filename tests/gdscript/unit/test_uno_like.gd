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


func test_pick_best_color_segue_a_maioria_da_mao() -> void:
	var mao := [_numero(1, VERDE), _numero(5, VERDE), _numero(9, VERDE), _numero(3, AZUL)]
	assert_eq(RulesScript.pick_best_color_for_hand(mao), VERDE,
		"escolhe a cor que a mao tem mais")


func test_pick_best_color_ignora_curinga_na_contagem() -> void:
	var mao := [_numero(2, AMARELO), _numero(4, AMARELO), _acao(13, CURINGA, "wild")]
	assert_eq(RulesScript.pick_best_color_for_hand(mao), AMARELO,
		"o curinga nao conta como cor")


func test_pick_best_color_com_mao_vazia_devolve_uma_cor_valida() -> void:
	var cor = RulesScript.pick_best_color_for_hand([])
	assert_true(cor in [VERMELHO, AZUL, VERDE, AMARELO],
		"mao vazia ainda devolve cor jogavel, nunca curinga")


# --------------------------------------------------------------------- UnoAI
#
# A IA antiga era `playable_indices.pick_random()`. Ela guardava o +2 para o
# fim quando o jogador estava com uma carta so, queimava o curinga tendo carta
# da cor na mao, e descartava as cartas baixas primeiro -- ficando com as caras
# quando o jogador batia.

const AIScript = preload("res://games/unolike/UnoAI.gd")


func _carta(cor: Card.ColorType, valor: int, tipo: String = "number") -> Card:
	return Card.new(valor, Card.Suit.NONE, cor, tipo)


## Carta de acao da cor ativa vem na frente do numero: nesta implementacao os
## quatro efeitos dao turno extra a quem os joga, entao segura-las nao paga.
func test_a_carta_de_acao_sai_antes_do_numero() -> void:
	var topo := _carta(Card.ColorType.RED, 5)
	var mao := [
		_carta(Card.ColorType.RED, 9),
		_carta(Card.ColorType.RED, 0, "draw2"),
	]
	for _tentativa in range(8):
		assert_eq(AIScript.escolher_carta(mao, topo, Card.ColorType.RED, 5, 10), 1,
			"o +2 da turno extra e ainda faz o outro comprar")


## Com o adversario a uma carta de bater, a ordem entre as cartas de acao
## inverte: vale mais a que faz ele comprar.
func test_a_ia_prefere_fazer_comprar_quando_o_adversario_esta_a_uma_carta() -> void:
	var topo := _carta(Card.ColorType.RED, 5)
	var mao := [
		_carta(Card.ColorType.RED, 0, "skip"),
		_carta(Card.ColorType.RED, 0, "draw2"),
	]
	for _tentativa in range(8):
		assert_eq(AIScript.escolher_carta(mao, topo, Card.ColorType.RED, 1, 10), 1,
			"o +2 adia a batida dele; o pular so empurra o turno")

	# Sem urgencia as duas sao cartas de acao da cor: as duas servem.
	var vistas: Dictionary = {}
	for _tentativa in range(12):
		vistas[AIScript.escolher_carta(mao, topo, Card.ColorType.RED, 6, 10)] = true
	assert_true(vistas.size() >= 1, "sem urgencia, qualquer carta de acao serve")


## Curinga e sempre jogavel: queima-lo tendo carta da cor na mao joga fora uma
## jogada legal garantida para quando nada mais encaixar.
func test_a_ia_guarda_o_curinga_enquanto_tem_carta_da_cor() -> void:
	var topo := _carta(Card.ColorType.BLUE, 3)
	var mao := [
		_carta(Card.ColorType.WILD, 0, "wild"),
		_carta(Card.ColorType.BLUE, 7),
	]
	for _tentativa in range(8):
		assert_eq(AIScript.escolher_carta(mao, topo, Card.ColorType.BLUE, 5, 10), 1,
			"a carta da cor sai antes do curinga")


## Quem fica com a mao cara paga o dobro se o outro bater.
func test_entre_cartas_da_cor_a_mais_cara_sai_primeiro() -> void:
	var topo := _carta(Card.ColorType.GREEN, 4)
	var mao := [
		_carta(Card.ColorType.GREEN, 2),
		_carta(Card.ColorType.GREEN, 9),
	]
	for _tentativa in range(8):
		assert_eq(AIScript.escolher_carta(mao, topo, Card.ColorType.GREEN, 5, 10), 1,
			"o 9 sai antes do 2")


## Trocar a cor ativa costuma ajudar o outro lado: seguir na cor que a mao ja
## tem vale mais.
func test_seguir_na_cor_vale_mais_que_trocar_de_cor() -> void:
	var topo := _carta(Card.ColorType.YELLOW, 6)
	var mao := [
		_carta(Card.ColorType.RED, 6),      # encaixa pelo numero, troca a cor
		_carta(Card.ColorType.YELLOW, 1),   # segue na cor
	]
	for _tentativa in range(8):
		assert_eq(AIScript.escolher_carta(mao, topo, Card.ColorType.YELLOW, 5, 10), 1,
			"a carta da cor ativa sai antes da que troca de cor")


func test_a_ia_sem_jogada_devolve_menos_um() -> void:
	var topo := _carta(Card.ColorType.RED, 5)
	var mao := [_carta(Card.ColorType.BLUE, 2), _carta(Card.ColorType.GREEN, 7)]
	assert_eq(AIScript.escolher_carta(mao, topo, Card.ColorType.RED, 5, 10), -1,
		"nada encaixa")


func test_a_ia_so_devolve_carta_jogavel() -> void:
	var topo := _carta(Card.ColorType.RED, 5)
	var mao := [
		_carta(Card.ColorType.BLUE, 2),
		_carta(Card.ColorType.RED, 8),
		_carta(Card.ColorType.GREEN, 7),
	]
	for nivel in range(1, 11):
		for _tentativa in range(6):
			var i: int = AIScript.escolher_carta(mao, topo, Card.ColorType.RED, 4, nivel)
			assert_true(UnoRules.is_valid_play(mao[i], Card.ColorType.RED, topo),
				"degrau %d escolheu carta jogavel" % nivel)


func test_a_escada_de_perfis_e_monotonica() -> void:
	var erro_antes := 1.1
	for perfil in AIScript.PERFIS:
		assert_true(float(perfil["erro"]) <= erro_antes, "a chance de erro nunca sobe")
		erro_antes = float(perfil["erro"])
	assert_eq(float(AIScript.PERFIS[AIScript.PERFIS.size() - 1]["erro"]), 0.0,
		"o degrau do topo nao sorteia a carta")
	assert_gt(float(AIScript.PERFIS[0]["erro"]), 0.5, "o degrau de baixo sorteia quase sempre")
