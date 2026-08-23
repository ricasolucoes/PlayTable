extends GutTest

## Video Poker — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_card_games.py::TestVideoPoker. O
## PokerGame monta o baralho com Deck.create_standard_52(true), entao o As
## vale 14 aqui tambem.

const EvaluatorScript = preload("res://games/poker/PokerEvaluator.gd")

const COPAS := Card.Suit.HEARTS
const OUROS := Card.Suit.DIAMONDS
const PAUS := Card.Suit.CLUBS
const ESPADAS := Card.Suit.SPADES


func _mao(valores: Array, naipes: Array) -> Array:
	var cartas: Array = []
	for i in range(valores.size()):
		cartas.append(Card.new(valores[i], naipes[i]))
	return cartas


func _mesmo_naipe(valores: Array, naipe: Card.Suit) -> Array:
	var naipes: Array = []
	for _v in valores:
		naipes.append(naipe)
	return _mao(valores, naipes)


func test_royal_flush() -> void:
	var r: Dictionary = EvaluatorScript.evaluate_hand(_mesmo_naipe([10, 11, 12, 13, 14], COPAS))
	assert_eq(r["name"], "Royal Flush")
	assert_eq(r["mult"], 800)
	assert_eq(r["rank"], 10)


func test_straight_flush() -> void:
	var r: Dictionary = EvaluatorScript.evaluate_hand(_mesmo_naipe([5, 6, 7, 8, 9], OUROS))
	assert_eq(r["name"], "Straight Flush")
	assert_eq(r["mult"], 50)
	assert_eq(r["rank"], 9)


func test_quadra() -> void:
	var r: Dictionary = EvaluatorScript.evaluate_hand(
		_mao([8, 8, 8, 8, 3], [COPAS, OUROS, PAUS, ESPADAS, COPAS]))
	assert_eq(r["mult"], 25)
	assert_eq(r["rank"], 8)


func test_full_house() -> void:
	var r: Dictionary = EvaluatorScript.evaluate_hand(
		_mao([10, 10, 10, 4, 4], [COPAS, OUROS, PAUS, COPAS, OUROS]))
	assert_eq(r["name"], "Full House")
	assert_eq(r["mult"], 9)
	assert_eq(r["rank"], 7)


func test_flush() -> void:
	var r: Dictionary = EvaluatorScript.evaluate_hand(_mesmo_naipe([2, 5, 7, 9, 13], PAUS))
	assert_eq(r["mult"], 6)
	assert_eq(r["rank"], 6)


func test_straight_comum() -> void:
	var r: Dictionary = EvaluatorScript.evaluate_hand(
		_mao([6, 7, 8, 9, 10], [COPAS, OUROS, PAUS, ESPADAS, COPAS]))
	assert_eq(r["mult"], 4)
	assert_eq(r["rank"], 5)


func test_straight_com_as_baixo() -> void:
	# A-2-3-4-5, a "roda": o As vale 14 no baralho mas fecha a sequencia baixa.
	var r: Dictionary = EvaluatorScript.evaluate_hand(
		_mao([2, 3, 4, 5, 14], [COPAS, OUROS, PAUS, ESPADAS, COPAS]))
	assert_eq(r["mult"], 4)
	assert_eq(r["rank"], 5)


func test_trinca() -> void:
	var r: Dictionary = EvaluatorScript.evaluate_hand(
		_mao([7, 7, 7, 2, 9], [COPAS, OUROS, PAUS, COPAS, OUROS]))
	assert_eq(r["mult"], 3)
	assert_eq(r["rank"], 4)


func test_dois_pares() -> void:
	var r: Dictionary = EvaluatorScript.evaluate_hand(
		_mao([12, 12, 5, 5, 2], [COPAS, OUROS, COPAS, OUROS, PAUS]))
	assert_eq(r["name"], "Dois Pares")
	assert_eq(r["mult"], 2)
	assert_eq(r["rank"], 3)


func test_par_de_valetes_ou_maior_paga() -> void:
	for v in [11, 12, 13, 14]:
		var r: Dictionary = EvaluatorScript.evaluate_hand(
			_mao([v, v, 2, 6, 9], [COPAS, OUROS, PAUS, ESPADAS, COPAS]))
		assert_eq(r["mult"], 1, "par de %d paga" % v)
		assert_eq(r["rank"], 2, "par de %d tem rank 2" % v)


func test_par_baixo_nao_paga() -> void:
	for v in [2, 5, 9, 10]:
		var r: Dictionary = EvaluatorScript.evaluate_hand(
			_mao([v, v, 3, 6, 8], [COPAS, OUROS, PAUS, ESPADAS, COPAS]))
		assert_eq(r["mult"], 0, "par de %d nao paga" % v)
		assert_eq(r["rank"], 1, "par de %d tem rank 1" % v)


func test_carta_alta_nao_paga() -> void:
	var r: Dictionary = EvaluatorScript.evaluate_hand(
		_mao([2, 4, 6, 8, 14], [COPAS, OUROS, PAUS, ESPADAS, COPAS]))
	assert_eq(r["mult"], 0)
	assert_eq(r["rank"], 0)


func test_mao_incompleta() -> void:
	var r: Dictionary = EvaluatorScript.evaluate_hand(_mao([2, 4], [COPAS, OUROS]))
	assert_eq(r["name"], "Mão Incompleta")
	assert_eq(r["mult"], 0)
	assert_eq(r["rank"], 0)
	assert_eq(EvaluatorScript.evaluate_hand([])["rank"], 0, "mao vazia")


func test_ranks_estao_ordenados_do_pior_para_o_melhor() -> void:
	var esperado := [
		[_mao([2, 4, 6, 8, 14], [COPAS, OUROS, PAUS, ESPADAS, COPAS]), 0],
		[_mao([9, 9, 3, 6, 8], [COPAS, OUROS, PAUS, ESPADAS, COPAS]), 1],
		[_mao([12, 12, 3, 6, 8], [COPAS, OUROS, PAUS, ESPADAS, COPAS]), 2],
		[_mao([12, 12, 5, 5, 2], [COPAS, OUROS, COPAS, OUROS, PAUS]), 3],
		[_mao([7, 7, 7, 2, 9], [COPAS, OUROS, PAUS, COPAS, OUROS]), 4],
		[_mao([6, 7, 8, 9, 10], [COPAS, OUROS, PAUS, ESPADAS, COPAS]), 5],
		[_mesmo_naipe([2, 5, 7, 9, 13], PAUS), 6],
		[_mao([10, 10, 10, 4, 4], [COPAS, OUROS, PAUS, COPAS, OUROS]), 7],
		[_mao([8, 8, 8, 8, 3], [COPAS, OUROS, PAUS, ESPADAS, COPAS]), 8],
		[_mesmo_naipe([5, 6, 7, 8, 9], OUROS), 9],
		[_mesmo_naipe([10, 11, 12, 13, 14], COPAS), 10],
	]
	var anterior := -1
	for par in esperado:
		var r: Dictionary = EvaluatorScript.evaluate_hand(par[0])
		assert_eq(r["rank"], par[1], "rank de %s" % r["name"])
		assert_true(r["rank"] > anterior, "ranks sobem monotonicamente")
		anterior = r["rank"]


func test_evaluate_e_apelido_de_evaluate_hand() -> void:
	var mao := _mesmo_naipe([10, 11, 12, 13, 14], COPAS)
	assert_eq(EvaluatorScript.evaluate(mao), EvaluatorScript.evaluate_hand(mao))


func test_ordem_das_cartas_nao_muda_o_resultado() -> void:
	var mao := _mao([4, 10, 10, 4, 10], [COPAS, COPAS, OUROS, OUROS, PAUS])
	assert_eq(EvaluatorScript.evaluate_hand(mao)["name"], "Full House",
		"avaliador ordena antes de decidir")


func test_qualquer_mao_de_um_baralho_real_recebe_um_rank() -> void:
	# Guarda contra deadlock/crash: substitui test_e2e_video_poker_simulation.
	for _rodada in range(50):
		var baralho: Deck = Deck.create_standard_52(true)
		baralho.shuffle()
		var mao: Array = baralho.draw_many(5)
		var r: Dictionary = EvaluatorScript.evaluate_hand(mao)
		assert_between(r["rank"], 0, 10, "rank dentro da tabela")
		assert_true(r["mult"] >= 0, "multiplicador nao negativo")
		assert_ne(r["name"], "Mão Incompleta", "5 cartas nunca sao mao incompleta")
		# Descarte e nova compra, como o jogo faz na segunda fase.
		mao[0] = baralho.draw()
		mao[1] = baralho.draw()
		assert_between(EvaluatorScript.evaluate_hand(mao)["rank"], 0, 10, "rank apos a troca")
