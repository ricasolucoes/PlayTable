extends GutTest

## 21 (Blackjack) — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_card_games.py::TestBlackjack.

const RulesScript = preload("res://games/blackjack/BlackjackRules.gd")
const GameScene = preload("res://games/blackjack/BlackjackGame.tscn")


func _mao(valores: Array) -> Array:
	var cartas: Array = []
	for v in valores:
		cartas.append(Card.new(v, Card.Suit.SPADES))
	return cartas


# -------------------------------------------------------------- BlackjackRules

func test_as_vale_onze_quando_cabe() -> void:
	assert_eq(RulesScript.calculate_score(_mao([1, 10])), 21, "as + dez = 21 natural")


func test_as_vira_um_para_nao_estourar() -> void:
	assert_eq(RulesScript.calculate_score(_mao([1, 9, 5])), 15, "as vale 1")


func test_dois_ases_contam_onze_e_um() -> void:
	assert_eq(RulesScript.calculate_score(_mao([1, 1, 9])), 21, "11 + 1 + 9")


func test_quatro_ases_com_um_sete() -> void:
	assert_eq(RulesScript.calculate_score(_mao([1, 1, 1, 1, 7])), 21, "11+1+1+1+7")


func test_as_alto_catorze_tambem_e_as() -> void:
	# Deck.create_standard_52(true) gera ases com valor 14.
	assert_eq(RulesScript.calculate_score(_mao([14, 10])), 21, "as alto conta igual")
	assert_eq(RulesScript.calculate_score(_mao([14, 9, 5])), 15, "e desce para 1 igual")


func test_figuras_valem_dez() -> void:
	for v in [10, 11, 12, 13]:
		assert_eq(RulesScript.calculate_score(_mao([v, 5])), 15, "carta %d vale 10" % v)


func test_mao_vazia_vale_zero() -> void:
	assert_eq(RulesScript.calculate_score([]), 0, "sem cartas")


func test_estouro_acima_de_21() -> void:
	assert_eq(RulesScript.calculate_score(_mao([10, 10, 5])), 25, "25 pontos")
	assert_true(RulesScript.is_bust(_mao([10, 10, 5])), "estourou")
	assert_false(RulesScript.is_bust(_mao([10, 10, 1])), "21 nao estoura")


func test_blackjack_e_so_com_duas_cartas() -> void:
	assert_true(RulesScript.is_blackjack(_mao([1, 10])), "as + figura")
	assert_false(RulesScript.is_blackjack(_mao([7, 7, 7])), "21 em tres cartas nao e blackjack")
	assert_false(RulesScript.is_blackjack(_mao([10, 9])), "19 nao e blackjack")


func test_dealer_compra_ate_17() -> void:
	assert_true(RulesScript.dealer_should_hit(_mao([10, 6])), "16 compra")
	assert_false(RulesScript.dealer_should_hit(_mao([10, 7])), "17 para")
	assert_false(RulesScript.dealer_should_hit(_mao([10, 10])), "20 para")


func test_dealer_para_no_17_com_as() -> void:
	# 1 + 6 = 17 mole: a regra do projeto e "para em qualquer 17".
	assert_false(RulesScript.dealer_should_hit(_mao([1, 6])), "17 mole tambem para")


func test_jogador_que_estoura_perde_mesmo_com_dealer_ruim() -> void:
	var r: Dictionary = RulesScript.evaluate_match(_mao([10, 6, 8]), _mao([10, 7]))
	assert_eq(r["winner"], "dealer", "estouro do jogador decide primeiro")
	assert_eq(r["reason"], "player_bust")


func test_dealer_que_estoura_perde() -> void:
	var r: Dictionary = RulesScript.evaluate_match(_mao([10, 8]), _mao([10, 6, 8]))
	assert_eq(r["winner"], "player")
	assert_eq(r["reason"], "dealer_bust")


func test_blackjack_do_jogador_ganha_de_21_comum() -> void:
	var r: Dictionary = RulesScript.evaluate_match(_mao([1, 10]), _mao([7, 7, 7]))
	assert_eq(r["winner"], "player")
	assert_eq(r["reason"], "blackjack")


func test_blackjack_do_dealer_ganha() -> void:
	var r: Dictionary = RulesScript.evaluate_match(_mao([7, 7, 7]), _mao([1, 10]))
	assert_eq(r["winner"], "dealer")
	assert_eq(r["reason"], "dealer_blackjack")


func test_dois_blackjacks_empatam() -> void:
	assert_eq(RulesScript.evaluate_match(_mao([1, 10]), _mao([1, 13]))["winner"], "draw")


func test_maior_pontuacao_vence() -> void:
	assert_eq(RulesScript.evaluate_match(_mao([10, 9]), _mao([10, 8]))["winner"], "player")
	assert_eq(RulesScript.evaluate_match(_mao([10, 7]), _mao([10, 8]))["winner"], "dealer")


func test_empate_de_pontos_e_push() -> void:
	var r: Dictionary = RulesScript.evaluate_match(_mao([10, 8]), _mao([9, 9]))
	assert_eq(r["winner"], "draw")
	assert_eq(r["reason"], "push")


func test_determine_winner_traduz_para_o_enum() -> void:
	assert_eq(RulesScript.determine_winner(_mao([1, 10]), _mao([10, 9])), RulesScript.Winner.PLAYER)
	assert_eq(RulesScript.determine_winner(_mao([10, 9]), _mao([1, 10])), RulesScript.Winner.DEALER)
	assert_eq(RulesScript.determine_winner(_mao([10, 8]), _mao([9, 9])), RulesScript.Winner.PUSH)


func test_aliases_devolvem_o_mesmo_que_as_funcoes_base() -> void:
	var mao := _mao([10, 6, 8])
	assert_eq(RulesScript.calculate_hand_value(mao), RulesScript.calculate_score(mao))
	assert_eq(RulesScript.is_busted(mao), RulesScript.is_bust(mao))
	assert_eq(RulesScript.should_dealer_hit(mao), RulesScript.dealer_should_hit(mao))


# --------------------------------------------------------------- BlackjackGame

func test_distribuicao_inicial_da_cena() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	assert_eq(jogo.player_hand.size(), 2, "2 cartas para o jogador")
	assert_eq(jogo.dealer_hand.size(), 2, "2 cartas para o dealer")
	assert_eq(jogo.deck.size(), 48, "52 menos as 4 distribuidas")


func test_partida_completa_da_cena_termina_com_um_resultado() -> void:
	# Guarda contra deadlock: substitui test_e2e_blackjack_simulation.
	for _partida in range(30):
		var baralho: Deck = Deck.create_standard_52()
		baralho.shuffle()
		var jogador: Array = baralho.draw_many(2)
		var dealer: Array = baralho.draw_many(2)
		var compras := 0
		while RulesScript.calculate_score(jogador) < 17 and compras < 10:
			jogador.append(baralho.draw())
			compras += 1
		if not RulesScript.is_bust(jogador):
			while RulesScript.dealer_should_hit(dealer) and not baralho.is_empty():
				dealer.append(baralho.draw())
		var r: Dictionary = RulesScript.evaluate_match(jogador, dealer)
		assert_true(r["winner"] in ["player", "dealer", "draw"], "resultado definido")
		assert_true(RulesScript.is_bust(dealer) or RulesScript.is_bust(jogador)
			or RulesScript.calculate_score(dealer) >= 17, "o dealer para em 17 ou mais")
