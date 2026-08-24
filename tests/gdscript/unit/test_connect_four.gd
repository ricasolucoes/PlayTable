extends GutTest

## Quatro em Linha — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestConnectFour.
##
## O jogo tem DUAS implementacoes das regras: ConnectFourRules.gd (estatica,
## sobre Grid2D, nao referenciada por ninguem) e ConnectFourBoard.gd +
## ConnectFourAI.gd (as que a cena realmente usa). As duas indexam o
## tabuleiro de formas diferentes — Rules e [linha][coluna], Board e
## [coluna][linha] — e por isso sao testadas separadamente.

const RulesScript = preload("res://games/quatro_em_linha/ConnectFourRules.gd")
const BoardScript = preload("res://games/quatro_em_linha/ConnectFourBoard.gd")
const AIScript = preload("res://games/quatro_em_linha/ConnectFourAI.gd")
const GameScene = preload("res://games/quatro_em_linha/ConnectFourGame.tscn")

const ROWS := 6
const COLS := 7


func _grid() -> Grid2D:
	return Grid2D.new(ROWS, COLS, 0)


func _board() -> Node:
	return autofree(BoardScript.new())


# ------------------------------------------------------------ ConnectFourRules

func test_peca_cai_ate_o_fundo_da_coluna() -> void:
	var g := _grid()
	assert_eq(RulesScript.drop_piece(g, 3, 1), ROWS - 1, "primeira peca no fundo")
	assert_eq(RulesScript.drop_piece(g, 3, 2), ROWS - 2, "segunda empilha em cima")
	assert_eq(RulesScript.drop_piece(g, 3, 1), ROWS - 3, "terceira empilha em cima")


func test_coluna_cheia_e_recusada() -> void:
	var g := _grid()
	for _i in range(ROWS):
		assert_ne(RulesScript.drop_piece(g, 3, 1), -1, "as 6 primeiras entram")
	assert_false(RulesScript.can_drop(g, 3), "coluna cheia")
	assert_eq(RulesScript.drop_piece(g, 3, 1), -1, "a setima e recusada")


func test_coluna_fora_do_tabuleiro_e_recusada() -> void:
	var g := _grid()
	for col in [-1, COLS, 99]:
		assert_false(RulesScript.can_drop(g, col), "coluna %d nao existe" % col)
		assert_eq(RulesScript.drop_piece(g, col, 1), -1, "drop em %d recusado" % col)


func test_sequencia_horizontal_vence() -> void:
	var g := _grid()
	for c in range(4):
		RulesScript.drop_piece(g, c, 1)
	assert_true(RulesScript.check_win(g, ROWS - 1, 3, 1), "4 na linha de baixo")


func test_sequencia_vertical_vence() -> void:
	var g := _grid()
	for _i in range(4):
		RulesScript.drop_piece(g, 6, 2)
	assert_true(RulesScript.check_win(g, 2, 6, 2), "4 empilhadas na coluna 6")


func test_sequencia_diagonal_vence() -> void:
	var g := _grid()
	RulesScript.drop_piece(g, 0, 1)
	RulesScript.drop_piece(g, 1, 2); RulesScript.drop_piece(g, 1, 1)
	RulesScript.drop_piece(g, 2, 2); RulesScript.drop_piece(g, 2, 2); RulesScript.drop_piece(g, 2, 1)
	RulesScript.drop_piece(g, 3, 2); RulesScript.drop_piece(g, 3, 2)
	RulesScript.drop_piece(g, 3, 2); RulesScript.drop_piece(g, 3, 1)
	assert_true(RulesScript.check_win(g, 2, 3, 1), "diagonal ascendente")


func test_tres_seguidas_nao_vencem() -> void:
	var g := _grid()
	for c in range(3):
		RulesScript.drop_piece(g, c, 1)
	assert_false(RulesScript.check_win(g, ROWS - 1, 2, 1), "3 nao bastam")


func test_tabuleiro_cheio_e_reconhecido() -> void:
	var g := _grid()
	assert_false(RulesScript.is_full(g), "tabuleiro vazio")
	for c in range(COLS):
		for r in range(ROWS):
			RulesScript.drop_piece(g, c, 1 + (r + c) % 2)
	assert_true(RulesScript.is_full(g), "42 pecas colocadas")
	assert_eq(RulesScript.get_valid_cols(g), [] as Array[int], "nenhuma coluna livre")


func test_get_valid_cols_ignora_as_colunas_cheias() -> void:
	var g := _grid()
	for _i in range(ROWS):
		RulesScript.drop_piece(g, 0, 1)
	assert_eq(RulesScript.get_valid_cols(g), [1, 2, 3, 4, 5, 6] as Array[int])


func test_ia_fecha_a_propria_vitoria() -> void:
	var g := _grid()
	for c in range(3):
		RulesScript.drop_piece(g, c, 2)
	assert_eq(RulesScript.get_best_move(g, 2), 3, "fecha em 3")


func test_ia_bloqueia_a_vitoria_do_oponente() -> void:
	var g := _grid()
	for c in range(3):
		RulesScript.drop_piece(g, c, 1)
	# A IA (2) nao tem vitoria disponivel, entao precisa bloquear.
	assert_eq(RulesScript.get_best_move(g, 2), 3, "bloqueia em 3")


func test_ia_prefere_a_coluna_central_no_tabuleiro_vazio() -> void:
	assert_eq(RulesScript.get_best_move(_grid(), 2), 3, "coluna do meio")


func test_ia_devolve_menos_um_com_o_tabuleiro_cheio() -> void:
	var g := _grid()
	for c in range(COLS):
		for r in range(ROWS):
			RulesScript.drop_piece(g, c, 1 + (r + c) % 2)
	assert_eq(RulesScript.get_best_move(g, 2), -1, "sem jogada possivel")


func test_get_best_move_nao_suja_o_tabuleiro() -> void:
	var g := _grid()
	for c in range(3):
		RulesScript.drop_piece(g, c, 1)
	var antes := Array(g.cells).duplicate()
	RulesScript.get_best_move(g, 2)
	assert_eq(Array(g.cells), antes, "grid restaurado apos a busca")


# ------------------------------------- ConnectFourBoard / AI (usados pela cena)

func test_board_comeca_com_42_casas_vazias() -> void:
	var b := _board()
	assert_eq(b.grid.size(), COLS, "7 colunas")
	for col in b.grid:
		assert_eq(col.size(), ROWS, "6 linhas por coluna")
		for v in col:
			assert_eq(v, 0, "casa vazia")


func test_board_empilha_e_recusa_coluna_cheia() -> void:
	var b := _board()
	assert_eq(b.drop_piece(2, 1), ROWS - 1, "primeira no fundo")
	for _i in range(ROWS - 1):
		assert_ne(b.drop_piece(2, 1), -1, "resto da coluna")
	assert_false(b.can_drop(2), "coluna cheia")
	assert_eq(b.drop_piece(2, 1), -1, "recusada")


func test_board_devolve_as_casas_vencedoras() -> void:
	var b := _board()
	for c in range(4):
		b.drop_piece(c, 1)
	var cells: Array[Vector2i] = b.get_winning_cells(3, ROWS - 1, 1)
	assert_eq(cells.size(), 4, "4 casas na linha vencedora")
	assert_true(b.check_win(3, ROWS - 1, 1), "vitoria horizontal")


func test_board_reconhece_vitoria_vertical_e_diagonal() -> void:
	var vertical := _board()
	for _i in range(4):
		vertical.drop_piece(6, 2)
	assert_true(vertical.check_win(6, ROWS - 4, 2), "vitoria vertical")

	var diagonal := _board()
	diagonal.drop_piece(0, 1)
	diagonal.drop_piece(1, 2); diagonal.drop_piece(1, 1)
	diagonal.drop_piece(2, 2); diagonal.drop_piece(2, 2); diagonal.drop_piece(2, 1)
	diagonal.drop_piece(3, 2); diagonal.drop_piece(3, 2)
	diagonal.drop_piece(3, 2); diagonal.drop_piece(3, 1)
	assert_true(diagonal.check_win(3, ROWS - 4, 1), "vitoria diagonal")


func test_board_reset_esvazia_o_tabuleiro() -> void:
	var b := _board()
	for c in range(COLS):
		b.drop_piece(c, 1)
	b.reset_board()
	assert_eq(b.grid.size(), COLS, "continua com 7 colunas apos o reset")
	for col in b.grid:
		for v in col:
			assert_eq(v, 0, "casa limpa")


func test_ia_da_cena_fecha_a_propria_vitoria() -> void:
	var b := _board()
	for c in range(3):
		b.drop_piece(c, 2)
	assert_eq(AIScript.get_best_move(b), 3, "IA (2) fecha em 3")


func test_ia_da_cena_bloqueia_a_vitoria_do_jogador() -> void:
	var b := _board()
	for c in range(3):
		b.drop_piece(c, 1)
	assert_eq(AIScript.get_best_move(b), 3, "IA bloqueia em 3")


func test_ia_da_cena_nao_deixa_lixo_no_tabuleiro() -> void:
	# _simulate_drop escreve direto em board.grid; o undo tem de cobrir tudo.
	var b := _board()
	b.drop_piece(0, 1)
	b.drop_piece(1, 2)
	var antes: Array = b.grid.duplicate(true)
	var escolha: int = AIScript.get_best_move(b)
	assert_true(escolha >= 0 and escolha < COLS, "coluna valida")
	assert_eq(b.grid, antes, "tabuleiro restaurado apos a busca")


func test_ia_da_cena_so_escolhe_coluna_jogavel() -> void:
	var b := _board()
	# Enche todas as colunas menos a 5, alternando para nao formar 4 seguidas.
	for c in range(COLS):
		if c == 5:
			continue
		for r in range(ROWS):
			b.drop_piece(c, 1 + (r + c) % 2)
	assert_eq(AIScript.get_best_move(b), 5, "unica coluna livre")


func test_partida_completa_da_ia_contra_ela_mesma_termina() -> void:
	# Guarda contra deadlock: substitui test_e2e_connect_four_simulation.
	for _partida in range(10):
		var b := _board()
		var vez := 1
		var jogadas := 0
		var vencedor := 0
		while jogadas < ROWS * COLS:
			var col: int = AIScript.get_best_move(b)
			if col == -1:
				break
			var row: int = b.drop_piece(col, vez)
			assert_true(row >= 0, "IA escolheu coluna jogavel")
			jogadas += 1
			if b.check_win(col, row, vez):
				vencedor = vez
				break
			vez = 1 if vez == 2 else 2
		assert_true(vencedor != 0 or b.is_full(), "partida acaba com vitoria ou tabuleiro cheio")


# ------------------------------------------------- Orientacao do desenho

## A primeira ficha de uma coluna tem de ser desenhada no fundo.
##
## drop_piece devolve ROWS-1 na primeira jogada, e no desenho o y cresce para
## baixo. Havia um (ROWS - 1) - row invertendo isso: a pilha nascia no topo e
## crescia para baixo.
func test_a_linha_do_fundo_e_desenhada_embaixo() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	var y_fundo: float = jogo.cell_center_y(ROWS - 1)
	var y_topo: float = jogo.cell_center_y(0)
	assert_gt(y_fundo, y_topo, "a linha ROWS-1 fica abaixo da linha 0 na tela")


func test_a_pilha_cresce_do_fundo_para_o_topo() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	var grid := _grid()
	var primeira := RulesScript.drop_piece(grid, 3, 1)
	var segunda := RulesScript.drop_piece(grid, 3, 2)
	assert_gt(jogo.cell_center_y(primeira), jogo.cell_center_y(segunda),
		"a segunda ficha da coluna e desenhada acima da primeira")
