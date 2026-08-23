extends GutTest

## Damas — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestCheckers.
##
## Convencao do tabuleiro: 1 = peca branca (jogador), 2 = dama branca,
## -1 = peca preta (IA), -2 = dama preta, 0 = casa vazia.

const RulesScript = preload("res://games/damas/CheckersRules.gd")

const BRANCA := 1
const DAMA_BRANCA := 2
const PRETA := -1
const DAMA_PRETA := -2


func _vazio() -> Grid2D:
	return Grid2D.new(8, 8, 0)


func _conta(g: Grid2D, valor: int) -> int:
	var total := 0
	for cell in g.cells:
		if cell == valor:
			total += 1
	return total


func test_tabuleiro_inicial_tem_12_pecas_de_cada_lado() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	assert_eq(_conta(g, BRANCA), 12, "12 brancas")
	assert_eq(_conta(g, PRETA), 12, "12 pretas")
	assert_eq(_conta(g, 0), 40, "40 casas vazias")


func test_pecas_ficam_so_nas_casas_escuras() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	for r in range(8):
		for c in range(8):
			if (r + c) % 2 == 0:
				assert_eq(g.get_cell(r, c), 0, "casa clara (%d,%d) vazia" % [r, c])


func test_as_duas_fileiras_do_meio_comecam_vazias() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	for c in range(8):
		assert_eq(g.get_cell(3, c), 0, "linha 3 vazia")
		assert_eq(g.get_cell(4, c), 0, "linha 4 vazia")


func test_captura_simples_e_coroacao() -> void:
	var g := _vazio()
	g.set_cell(2, 2, BRANCA)
	g.set_cell(1, 1, PRETA)
	var caps: Array[Dictionary] = RulesScript.get_piece_captures(g, 2, 2)
	assert_eq(caps.size(), 1, "uma captura possivel")
	assert_eq(caps[0]["to"], Vector2i(0, 0), "aterrissa em (0,0)")
	assert_eq(caps[0]["captures"], [Vector2i(1, 1)], "come a peca de (1,1)")

	var r: Dictionary = RulesScript.execute_move(g, caps[0])
	assert_true(r["captured_any"], "houve captura")
	assert_true(r["promoted"], "chegou na ultima fileira e virou dama")
	assert_eq(g.get_cell(1, 1), 0, "peca capturada saiu do tabuleiro")
	assert_eq(g.get_cell(0, 0), DAMA_BRANCA, "dama branca coroada")
	assert_eq(g.get_cell(2, 2), 0, "casa de origem vazia")


func test_peca_preta_coroa_na_ultima_fileira() -> void:
	var g := _vazio()
	g.set_cell(6, 2, PRETA)
	var r: Dictionary = RulesScript.apply_move(g, Vector2i(6, 2), Vector2i(7, 3))
	assert_true(r["promoted"], "virou dama preta")
	assert_eq(g.get_cell(7, 3), DAMA_PRETA, "dama preta no lugar")


func test_peca_comum_so_anda_para_frente() -> void:
	var g := _vazio()
	g.set_cell(4, 4, BRANCA)
	var destinos: Array = []
	for m in RulesScript.get_piece_moves(g, 4, 4):
		destinos.append(m["to"])
	assert_eq(destinos.size(), 2, "duas diagonais para frente")
	for d in destinos:
		assert_eq(d.x, 3, "branca sobe uma linha")

	g.set_cell(4, 4, 0)
	g.set_cell(4, 4, PRETA)
	destinos.clear()
	for m in RulesScript.get_piece_moves(g, 4, 4):
		destinos.append(m["to"])
	assert_eq(destinos.size(), 2, "duas diagonais para frente")
	for d in destinos:
		assert_eq(d.x, 5, "preta desce uma linha")


func test_dama_anda_nas_quatro_diagonais() -> void:
	var g := _vazio()
	g.set_cell(4, 4, DAMA_BRANCA)
	assert_eq(RulesScript.get_piece_moves(g, 4, 4).size(), 4, "as quatro diagonais")


func test_dama_captura_para_tras() -> void:
	var g := _vazio()
	g.set_cell(2, 2, DAMA_BRANCA)
	g.set_cell(3, 3, PRETA)
	var caps: Array[Dictionary] = RulesScript.get_piece_captures(g, 2, 2)
	assert_eq(caps.size(), 1, "uma captura para tras")
	assert_eq(caps[0]["to"], Vector2i(4, 4), "aterrissa em (4,4)")
	assert_eq(caps[0]["captures"], [Vector2i(3, 3)], "come a peca de (3,3)")


func test_peca_comum_nao_captura_para_tras() -> void:
	var g := _vazio()
	g.set_cell(2, 2, BRANCA)
	g.set_cell(3, 3, PRETA)
	assert_eq(RulesScript.get_piece_captures(g, 2, 2), [] as Array[Dictionary],
		"peca comum branca nao come descendo")


func test_nao_captura_peca_da_propria_cor() -> void:
	var g := _vazio()
	g.set_cell(2, 2, BRANCA)
	g.set_cell(1, 1, BRANCA)
	assert_eq(RulesScript.get_piece_captures(g, 2, 2), [] as Array[Dictionary], "sem fogo amigo")


func test_captura_bloqueada_por_casa_ocupada() -> void:
	var g := _vazio()
	g.set_cell(2, 2, BRANCA)
	g.set_cell(1, 1, PRETA)
	g.set_cell(0, 0, PRETA)
	assert_eq(RulesScript.get_piece_captures(g, 2, 2), [] as Array[Dictionary],
		"nao ha onde aterrissar")


func test_captura_para_fora_do_tabuleiro_nao_conta() -> void:
	var g := _vazio()
	g.set_cell(1, 1, BRANCA)
	g.set_cell(0, 0, PRETA)
	assert_eq(RulesScript.get_piece_captures(g, 1, 1), [] as Array[Dictionary],
		"a casa de destino cairia fora")


func test_casa_vazia_nao_gera_jogada() -> void:
	var g := _vazio()
	assert_eq(RulesScript.get_piece_captures(g, 4, 4), [] as Array[Dictionary])
	assert_eq(RulesScript.get_piece_moves(g, 4, 4), [] as Array[Dictionary])


func test_captura_e_obrigatoria() -> void:
	var g := _vazio()
	g.set_cell(4, 4, BRANCA)   # tem captura
	g.set_cell(3, 3, PRETA)
	g.set_cell(6, 0, BRANCA)   # so tem passeio
	var moves: Array[Dictionary] = RulesScript.get_all_valid_moves(g, 1)
	assert_eq(moves.size(), 1, "com captura disponivel, so ela e oferecida")
	assert_eq(moves[0]["from"], Vector2i(4, 4), "a peca que come")


func test_captura_em_cadeia_e_sinalizada() -> void:
	var g := _vazio()
	g.set_cell(4, 4, BRANCA)
	g.set_cell(3, 3, PRETA)
	g.set_cell(1, 3, PRETA)
	var r: Dictionary = RulesScript.apply_move(g, Vector2i(4, 4), Vector2i(2, 2), Vector2i(3, 3))
	assert_true(r["captured_any"], "primeira captura feita")
	assert_eq(r["further_captures"].size(), 1, "ha uma segunda captura encadeada")
	assert_false(r["promoted"], "ainda nao coroou")


func test_movimento_simples_nao_procura_cadeia() -> void:
	var g := _vazio()
	g.set_cell(4, 4, BRANCA)
	var r: Dictionary = RulesScript.apply_move(g, Vector2i(4, 4), Vector2i(3, 3))
	assert_false(r["captured_any"], "sem captura")
	assert_eq(r["further_captures"], [] as Array[Dictionary], "nao ha cadeia depois de passeio")


func test_abertura_tem_sete_movimentos_para_cada_lado() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	assert_eq(RulesScript.get_all_valid_moves(g, 1).size(), 7, "brancas")
	assert_eq(RulesScript.get_all_valid_moves(g, -1).size(), 7, "pretas")


func test_variantes_formatadas_devolvem_captured_singular() -> void:
	var g := _vazio()
	g.set_cell(2, 2, BRANCA)
	g.set_cell(1, 1, PRETA)
	var caps: Array[Dictionary] = RulesScript.get_captures_for_piece(g, Vector2i(2, 2))
	assert_eq(caps.size(), 1)
	assert_eq(caps[0]["captured"], Vector2i(1, 1), "chave captured no singular")

	var g2 := _vazio()
	g2.set_cell(4, 4, BRANCA)
	var moves: Array[Dictionary] = RulesScript.get_valid_moves_for_piece(g2, Vector2i(4, 4))
	assert_eq(moves[0]["captured"], Vector2i(-1, -1), "passeio marca captured invalido")


func test_fim_de_jogo_quando_um_lado_fica_sem_pecas() -> void:
	assert_eq(RulesScript.check_game_over(RulesScript.create_initial_board()), 0, "abertura segue")

	var so_brancas := _vazio()
	so_brancas.set_cell(4, 4, BRANCA)
	assert_eq(RulesScript.check_game_over(so_brancas), 1, "brancas vencem")

	var so_pretas := _vazio()
	so_pretas.set_cell(4, 4, PRETA)
	assert_eq(RulesScript.check_game_over(so_pretas), -1, "pretas vencem")


func test_fim_de_jogo_quando_um_lado_fica_sem_jogada() -> void:
	# Branca encurralada na quina de cima: sem movimento, perde.
	var g := _vazio()
	g.set_cell(0, 0, BRANCA)
	g.set_cell(5, 5, PRETA)
	assert_eq(RulesScript.check_game_over(g), -1, "brancas travadas perdem")


func test_ia_escolhe_jogada_valida() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	var jogada: Dictionary = RulesScript.get_best_ai_move(g)
	assert_false(jogada.is_empty(), "IA tem jogada na abertura")
	assert_eq(g.get_cell(jogada["from"].x, jogada["from"].y), PRETA, "move uma peca preta")
	assert_eq(g.get_cell(jogada["to"].x, jogada["to"].y), 0, "para uma casa vazia")


func test_ia_sem_pecas_devolve_dicionario_vazio() -> void:
	var g := _vazio()
	g.set_cell(4, 4, BRANCA)
	assert_eq(RulesScript.get_best_ai_move(g), {}, "sem pretas nao ha jogada")


func test_partida_completa_termina() -> void:
	# Guarda contra deadlock: substitui test_e2e_checkers_simulation.
	for _partida in range(5):
		var g: Grid2D = RulesScript.create_initial_board()
		var lado := 1
		var jogadas := 0
		while RulesScript.check_game_over(g) == 0 and jogadas < 400:
			var moves: Array[Dictionary] = RulesScript.get_all_valid_moves(g, lado)
			assert_false(moves.is_empty(), "check_game_over prometeu jogada para o lado %d" % lado)
			moves.shuffle()
			RulesScript.execute_move(g, moves[0])
			jogadas += 1
			lado = -lado
		assert_true(jogadas > 0, "a partida andou")
		assert_true(jogadas < 400, "a partida terminou sem estourar o limite")
		assert_ne(RulesScript.check_game_over(g), 0, "houve um vencedor")
