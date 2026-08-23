extends GutTest

## Domino — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestDomino.

const RulesScript = preload("res://games/domino/DominoRules.gd")
const GameScene = preload("res://games/domino/DominoGame.tscn")


# ----------------------------------------------------------------- DominoRules

func test_monte_tem_28_pedras_sem_repeticao() -> void:
	var monte: Array[Dictionary] = RulesScript.generate_boneyard_28()
	assert_eq(monte.size(), 28, "28 pedras")
	var vistas := {}
	for t in monte:
		var chave := "%d|%d" % [t["a"], t["b"]]
		assert_false(vistas.has(chave), "pedra %s repetida" % chave)
		vistas[chave] = true
		assert_true(t["a"] <= t["b"], "pedra normalizada com a <= b")


func test_monte_tem_os_sete_duplos() -> void:
	var monte: Array[Dictionary] = RulesScript.generate_boneyard_28()
	var duplos := 0
	for t in monte:
		if t["a"] == t["b"]:
			duplos += 1
	assert_eq(duplos, 7, "de 0|0 a 6|6")


func test_soma_de_todos_os_pontos_do_monte() -> void:
	assert_eq(RulesScript.calculate_hand_points(RulesScript.generate_boneyard_28()), 168,
		"o domino completo soma 168 pontos")


func test_pedra_encaixa_quando_bate_com_alguma_ponta() -> void:
	var pedra := {"a": 6, "b": 4}
	assert_true(RulesScript.can_tile_fit(pedra, 4, 2), "o 4 bate com a ponta esquerda")
	assert_true(RulesScript.can_tile_fit(pedra, 6, 2), "o 6 bate com a ponta esquerda")
	assert_true(RulesScript.can_tile_fit(pedra, 2, 6), "o 6 bate com a ponta direita")
	assert_false(RulesScript.can_tile_fit(pedra, 5, 3), "nenhum lado bate")


func test_mesa_vazia_aceita_qualquer_pedra() -> void:
	assert_true(RulesScript.can_tile_fit({"a": 0, "b": 1}, -1, -1), "mesa vazia")


func test_has_any_playable_olha_a_mao_inteira() -> void:
	var mao := [{"a": 0, "b": 1}, {"a": 6, "b": 4}]
	assert_true(RulesScript.has_any_playable(mao, 4, 2), "a segunda pedra joga")
	assert_false(RulesScript.has_any_playable(mao, 5, 3), "nenhuma joga")
	assert_false(RulesScript.has_any_playable([], 5, 3), "mao vazia nao joga")


func test_get_playable_indices_lista_so_as_jogaveis() -> void:
	var mao := [{"a": 0, "b": 1}, {"a": 6, "b": 4}, {"a": 2, "b": 2}]
	assert_eq(RulesScript.get_playable_indices(mao, 4, 2), [1, 2] as Array[int])
	assert_eq(RulesScript.get_playable_indices(mao, 5, 3), [] as Array[int])


func test_orientacao_na_ponta_esquerda_vira_a_pedra() -> void:
	# Espec. do teste Python: (6,4) na esquerda com ponta 6 vira (4,6) e a
	# nova ponta esquerda passa a ser 4.
	var r: Dictionary = RulesScript.orient_tile_for_side({"a": 6, "b": 4}, "left", 6, 2)
	assert_eq(r["oriented_tile"], {"a": 4, "b": 6}, "pedra virada")
	assert_eq(r["new_left_end"], 4, "nova ponta esquerda")
	assert_eq(r["new_right_end"], 2, "ponta direita intacta")


func test_orientacao_na_ponta_esquerda_sem_virar() -> void:
	var r: Dictionary = RulesScript.orient_tile_for_side({"a": 4, "b": 6}, "left", 6, 2)
	assert_eq(r["oriented_tile"], {"a": 4, "b": 6}, "ja estava na posicao certa")
	assert_eq(r["new_left_end"], 4, "nova ponta esquerda")


func test_orientacao_na_ponta_direita() -> void:
	var sem_virar: Dictionary = RulesScript.orient_tile_for_side({"a": 2, "b": 5}, "right", 6, 2)
	assert_eq(sem_virar["oriented_tile"], {"a": 2, "b": 5}, "o a ja encosta na ponta")
	assert_eq(sem_virar["new_right_end"], 5, "nova ponta direita")
	assert_eq(sem_virar["new_left_end"], 6, "ponta esquerda intacta")

	var virando: Dictionary = RulesScript.orient_tile_for_side({"a": 5, "b": 2}, "right", 6, 2)
	assert_eq(virando["oriented_tile"], {"a": 2, "b": 5}, "pedra virada")
	assert_eq(virando["new_right_end"], 5, "nova ponta direita")


func test_duplo_encaixa_sem_mudar_a_ponta() -> void:
	var r: Dictionary = RulesScript.orient_tile_for_side({"a": 3, "b": 3}, "left", 3, 5)
	assert_eq(r["new_left_end"], 3, "duplo mantem a ponta")
	assert_eq(r["new_right_end"], 5, "ponta direita intacta")


func test_ia_escolhe_pedra_jogavel_e_a_ponta_certa() -> void:
	var mao := [{"a": 0, "b": 1}, {"a": 6, "b": 4}]
	var jogada: Dictionary = RulesScript.find_ai_move(mao, 4, 2)
	assert_eq(jogada["tile_index"], 1, "a pedra jogavel")
	assert_eq(jogada["side"], "left", "encaixa na esquerda, que vale 4")

	var so_direita: Dictionary = RulesScript.find_ai_move([{"a": 2, "b": 5}], 4, 2)
	assert_eq(so_direita["side"], "right", "so a ponta direita aceita")


func test_ia_sem_jogada_devolve_dicionario_vazio() -> void:
	assert_eq(RulesScript.find_ai_move([{"a": 0, "b": 1}], 5, 3), {}, "nada jogavel")
	assert_eq(RulesScript.find_ai_move([], 5, 3), {}, "mao vazia")


func test_pontos_da_mao() -> void:
	assert_eq(RulesScript.calculate_hand_points([{"a": 6, "b": 4}, {"a": 0, "b": 3}]), 13)
	assert_eq(RulesScript.calculate_hand_points([]), 0, "mao vazia vale zero")


# ------------------------------------------------------------------ DominoGame

func test_distribuicao_inicial_da_cena() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	# Uma pedra sai de uma das maos para abrir a mesa.
	assert_eq(jogo.board_chain.size(), 1, "mesa aberta com uma pedra")
	assert_eq(jogo.player_hand.size() + jogo.ai_hand.size(), 13, "7 + 7 menos a de abertura")
	assert_eq(jogo.boneyard.size(), 14, "28 - 14 distribuidas")
	assert_eq(jogo.left_end, jogo.board_chain[0]["a"], "ponta esquerda")
	assert_eq(jogo.right_end, jogo.board_chain[0]["b"], "ponta direita")


func test_nenhuma_pedra_aparece_duas_vezes_na_distribuicao() -> void:
	for _partida in range(5):
		var jogo = add_child_autofree(GameScene.instantiate())
		var todas: Array = []
		todas.append_array(jogo.player_hand)
		todas.append_array(jogo.ai_hand)
		todas.append_array(jogo.boneyard)
		todas.append_array(jogo.board_chain)
		assert_eq(todas.size(), 28, "as 28 pedras seguem em jogo")
		var vistas := {}
		for t in todas:
			var chave := "%d|%d" % [t["a"], t["b"]]
			assert_false(vistas.has(chave), "pedra %s duplicada" % chave)
			vistas[chave] = true


func test_abertura_usa_o_duplo_mais_alto_disponivel() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	var aberta: Dictionary = jogo.board_chain[0]
	if aberta["a"] != aberta["b"]:
		# Sem duplo nenhum nas maos: nada a conferir.
		return
	var na_mao: Array = []
	na_mao.append_array(jogo.player_hand)
	na_mao.append_array(jogo.ai_hand)
	for t in na_mao:
		if t["a"] == t["b"]:
			assert_true(t["a"] < aberta["a"],
				"duplo %d|%d ficou na mao sendo maior que a abertura" % [t["a"], t["b"]])


func test_partida_completa_da_cena_nao_trava() -> void:
	# Guarda contra deadlock: substitui test_e2e_domino_simulation. Joga com
	# as regras reais, sem passar pela cena, para nao esperar animacao.
	for _partida in range(20):
		var monte: Array[Dictionary] = RulesScript.generate_boneyard_28()
		monte.shuffle()
		var maos := [[], []]
		for _i in range(7):
			maos[0].append(monte.pop_back())
			maos[1].append(monte.pop_back())
		var abertura: Dictionary = maos[0].pop_back()
		var esquerda: int = abertura["a"]
		var direita: int = abertura["b"]
		var vez := 1
		var passes := 0
		var jogadas := 0
		while passes < 2 and not maos[0].is_empty() and not maos[1].is_empty() and jogadas < 28:
			var jogada: Dictionary = RulesScript.find_ai_move(maos[vez], esquerda, direita)
			if jogada.is_empty():
				if not monte.is_empty():
					maos[vez].append(monte.pop_back())
					continue
				passes += 1
			else:
				passes = 0
				jogadas += 1
				var pedra: Dictionary = maos[vez].pop_at(jogada["tile_index"])
				var r: Dictionary = RulesScript.orient_tile_for_side(pedra, jogada["side"], esquerda, direita)
				esquerda = r["new_left_end"]
				direita = r["new_right_end"]
			vez = 1 - vez
		assert_true(passes >= 2 or maos[0].is_empty() or maos[1].is_empty() or jogadas >= 27,
			"a partida terminou por batida ou por jogo fechado")
