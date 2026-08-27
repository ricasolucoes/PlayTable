extends GutTest

## Jogo da Velha — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestTicTacToe, que
## reimplementava estas regras em Python. Aqui os mesmos casos apontam para
## TicTacToeRules.gd e para TicTacToeGame.gd.

const RulesScript = preload("res://games/jogo_da_velha/TicTacToeRules.gd")
const GameScene = preload("res://games/jogo_da_velha/TicTacToeGame.tscn")

const VAZIO := 0
const X := 1
const O := 2


func _grid(celulas: Array) -> Grid2D:
	var g := Grid2D.new(3, 3, VAZIO)
	for i in range(9):
		g.cells[i] = celulas[i]
	return g


# ---------------------------------------------------------------- TicTacToeRules

func test_vitoria_em_qualquer_linha() -> void:
	assert_true(RulesScript.check_win(_grid([1,1,1, 0,0,0, 0,0,0]), X), "linha do topo")
	assert_true(RulesScript.check_win(_grid([0,0,0, 2,2,2, 0,0,0]), O), "linha do meio")
	assert_true(RulesScript.check_win(_grid([0,0,0, 0,0,0, 1,1,1]), X), "linha de baixo")


func test_vitoria_em_qualquer_coluna() -> void:
	assert_true(RulesScript.check_win(_grid([1,0,0, 1,0,0, 1,0,0]), X), "coluna esquerda")
	assert_true(RulesScript.check_win(_grid([0,2,0, 0,2,0, 0,2,0]), O), "coluna do meio")
	assert_true(RulesScript.check_win(_grid([0,0,1, 0,0,1, 0,0,1]), X), "coluna direita")


func test_vitoria_nas_duas_diagonais() -> void:
	assert_true(RulesScript.check_win(_grid([1,0,0, 0,1,0, 0,0,1]), X), "diagonal principal")
	assert_true(RulesScript.check_win(_grid([0,0,2, 0,2,0, 2,0,0]), O), "diagonal secundaria")


func test_as_oito_combinacoes_vencedoras_e_so_elas() -> void:
	# Forca bruta: das 9 celulas, so as 8 trincas listadas vencem.
	var combos_esperados := [
		[0,1,2], [3,4,5], [6,7,8],
		[0,3,6], [1,4,7], [2,5,8],
		[0,4,8], [2,4,6],
	]
	var vencedoras: Array = []
	for a in range(9):
		for b in range(a + 1, 9):
			for c in range(b + 1, 9):
				var celulas := [0,0,0, 0,0,0, 0,0,0]
				celulas[a] = X
				celulas[b] = X
				celulas[c] = X
				if RulesScript.check_win(_grid(celulas), X):
					vencedoras.append([a, b, c])
	assert_eq(vencedoras.size(), 8, "exatamente 8 trincas vencedoras")
	for combo in combos_esperados:
		assert_true(combo in vencedoras, "trinca %s deveria vencer" % str(combo))


func test_tabuleiro_sem_trinca_nao_e_vitoria() -> void:
	var empate := _grid([1,2,1, 1,2,2, 2,1,1])
	assert_false(RulesScript.check_win(empate, X), "X nao venceu")
	assert_false(RulesScript.check_win(empate, O), "O nao venceu")


func test_empate_com_tabuleiro_cheio_e_sem_vencedor() -> void:
	assert_true(RulesScript.is_draw(_grid([1,2,1, 1,2,2, 2,1,1])), "tabuleiro cheio sem trinca")


func test_tabuleiro_incompleto_nao_e_empate() -> void:
	assert_false(RulesScript.is_draw(_grid([1,2,1, 1,2,2, 2,1,0])), "ainda ha casa livre")


func test_tabuleiro_cheio_com_vencedor_nao_e_empate() -> void:
	assert_false(RulesScript.is_draw(_grid([1,1,1, 2,2,1, 2,1,2])), "X venceu, nao e empate")


func test_get_empty_indices_lista_as_casas_livres() -> void:
	assert_eq(RulesScript.get_empty_indices(_grid([1,0,2, 0,1,0, 2,0,1])), [1, 3, 5, 7] as Array[int])
	assert_eq(RulesScript.get_empty_indices(_grid([1,2,1, 1,2,2, 2,1,1])), [] as Array[int])


# ------------------------------------------------------------------- IA (Rules)

func test_ia_fecha_a_propria_vitoria() -> void:
	assert_eq(RulesScript.get_best_move(_grid([2,2,0, 1,1,0, 0,0,0]), O), 2, "O fecha em 2")


func test_ia_bloqueia_a_vitoria_do_oponente() -> void:
	assert_eq(RulesScript.get_best_move(_grid([1,1,0, 2,0,0, 0,0,0]), O), 2, "O bloqueia em 2")


func test_vencer_tem_prioridade_sobre_bloquear() -> void:
	# X ameaca em 5 (linha 3-4-5); O ameaca em 2 (linha 0-1-2).
	var g := _grid([2,2,0, 1,1,0, 0,0,0])
	assert_eq(RulesScript.get_best_move(g, O), 2, "vencer vem antes de bloquear")


func test_ia_prefere_o_centro_no_tabuleiro_vazio() -> void:
	assert_eq(RulesScript.get_best_move(_grid([0,0,0, 0,0,0, 0,0,0]), O), 4, "centro livre")


func test_ia_vai_para_um_canto_quando_o_centro_esta_ocupado() -> void:
	# A implementacao embaralha os cantos: o contrato e "algum canto", nao um fixo.
	for _i in range(20):
		var escolha := RulesScript.get_best_move(_grid([0,0,0, 0,1,0, 0,0,0]), O)
		assert_true(escolha in [0, 2, 6, 8], "escolheu %d, esperado um canto" % escolha)


func test_ia_devolve_menos_um_com_o_tabuleiro_cheio() -> void:
	assert_eq(RulesScript.get_best_move(_grid([1,2,1, 1,2,2, 2,1,1]), O), -1, "sem jogada possivel")


func test_get_best_move_nao_suja_o_tabuleiro() -> void:
	# A busca escreve nas celulas para simular jogadas; precisa desfazer tudo.
	var antes := [1,0,2, 0,1,0, 2,0,0]
	var g := _grid(antes)
	RulesScript.get_best_move(g, O)
	assert_eq(Array(g.cells), antes, "grid restaurado apos a busca")


func test_ia_nunca_perde_contra_jogo_perfeito() -> void:
	# Jogo da velha e empate com jogo perfeito dos dois lados. Com a IA nas
	# duas cadeiras, X nunca pode vencer.
	for _partida in range(30):
		var g := _grid([0,0,0, 0,0,0, 0,0,0])
		var vez := X
		var vencedor := 0
		while true:
			var idx := RulesScript.get_best_move(g, vez)
			if idx == -1:
				break
			g.cells[idx] = vez
			if RulesScript.check_win(g, vez):
				vencedor = vez
				break
			vez = O if vez == X else X
		assert_eq(vencedor, 0, "IA contra IA tem de empatar, venceu %d" % vencedor)


# -------------------------------------------------------------- TicTacToeGame

func _novo_jogo() -> Node:
	var jogo = add_child_autofree(GameScene.instantiate())
	jogo.vs_ai = false  # evita o await do turno da IA dentro de _place_move
	return jogo


func test_cena_monta_nove_casas() -> void:
	var jogo := _novo_jogo()
	assert_eq(jogo.board.cells.size(), 9, "9 casas no modelo")
	assert_eq(jogo.piece_nodes.size(), 9, "9 pecas desenhadas")
	assert_false(jogo.game_over, "partida comeca aberta")


func test_clique_em_casa_ocupada_e_ignorado() -> void:
	var jogo := _novo_jogo()
	jogo._on_cell_pressed(0)
	assert_eq(jogo.board.cells[0], X, "primeira jogada aceita")
	jogo.is_player_turn = true
	jogo._on_cell_pressed(0)
	assert_eq(jogo.board.cells[0], X, "casa ocupada nao muda de dono")


func test_clique_apos_o_fim_da_partida_e_ignorado() -> void:
	var jogo := _novo_jogo()
	jogo.board.cells.assign([1,1,1, 0,0,0, 0,0,0])
	jogo.game_over = true
	jogo._on_cell_pressed(3)
	assert_eq(jogo.board.cells[3], VAZIO, "tabuleiro congelado depois do fim")


func test_trinca_vencedora_sai_das_regras() -> void:
	var jogo := _novo_jogo()
	jogo.board.cells.assign([1,0,0, 0,1,0, 0,0,1])
	assert_eq(RulesScript.get_winning_combo(jogo.board, X), [0, 4, 8] as Array[int],
		"diagonal principal")
	assert_eq(RulesScript.get_winning_combo(jogo.board, O), [] as Array[int],
		"O nao venceu")


func test_ia_da_cena_fecha_e_bloqueia() -> void:
	# A cena chama TicTacToeRules.get_best_move(board, 2); estes casos passam a
	# bater na mesma funcao que a partida usa.
	var jogo := _novo_jogo()
	jogo.board.cells.assign([2,2,0, 1,1,0, 0,0,0])
	assert_eq(RulesScript.get_best_move(jogo.board, 2), 2, "fecha a propria vitoria")
	jogo.board.cells.assign([1,1,0, 2,0,0, 0,0,0])
	assert_eq(RulesScript.get_best_move(jogo.board, 2), 2, "bloqueia a vitoria de X")
	jogo.board.cells.assign([0,0,0, 0,0,0, 0,0,0])
	assert_eq(RulesScript.get_best_move(jogo.board, 2), 4, "prefere o centro")
	jogo.board.cells.assign([1,2,1, 1,2,2, 2,1,1])
	assert_eq(RulesScript.get_best_move(jogo.board, 2), -1, "sem jogada possivel")


func test_reiniciar_limpa_o_tabuleiro_e_preserva_o_placar() -> void:
	var jogo := _novo_jogo()
	jogo.board.cells.assign([1,1,1, 2,2,0, 0,0,0])
	jogo.game_over = true
	jogo.score_x = 3
	jogo._on_restart_pressed()
	assert_eq(Array(jogo.board.cells), [0,0,0, 0,0,0, 0,0,0], "tabuleiro zerado")
	assert_false(jogo.game_over, "partida reaberta")
	assert_true(jogo.is_player_turn, "vez volta para o jogador")
	assert_eq(jogo.score_x, 3, "placar acumulado sobrevive ao reinicio")


## A cena tinha a propria copia das regras e este teste varria as 6.561
## posicoes possiveis para travar a divergencia entre as duas. Agora
## TicTacToeGame chama TicTacToeRules, entao a varredura passou a conferir o que
## de fato importa: que get_winning_combo e check_win nunca discordem entre si.
func test_combo_e_check_win_nunca_discordam() -> void:
	var divergencias: Array[String] = []
	for mascara in range(6561):  # 3^8, varrendo tabuleiros de 8 casas
		var celulas := []
		var resto := mascara
		for _i in range(8):
			celulas.append(resto % 3)
			resto /= 3
		celulas.append(0)
		var grid := _grid(celulas)
		for jogador in [X, O]:
			var tem_combo: bool = not RulesScript.get_winning_combo(grid, jogador).is_empty()
			var venceu: bool = RulesScript.check_win(grid, jogador)
			if tem_combo != venceu:
				divergencias.append("%s / %d" % [str(celulas), jogador])
	assert_eq(divergencias, [] as Array[String], "combo e check_win divergem")


# ------------------------------------------------------- escada de dificuldade

## Jogo da velha e resolvido: quem abre, contra minimax perfeito, no maximo
## empata. Enquanto o jogador abria sempre, ele nao podia perder -- e a escada,
## que so desce na derrota, travava no topo para sempre.
func test_a_ia_abre_a_partida_nos_degraus_de_cima() -> void:
	for nivel in range(1, RulesScript.NIVEL_IA_ABRE):
		assert_false(RulesScript.ai_opens(nivel), "degrau %d: quem abre e o jogador" % nivel)
	for nivel in range(RulesScript.NIVEL_IA_ABRE, RulesScript.MAX_LEVEL + 1):
		assert_true(RulesScript.ai_opens(nivel), "degrau %d: quem abre e a IA" % nivel)


func test_todo_degrau_devolve_jogada_valida() -> void:
	for nivel in range(1, RulesScript.MAX_LEVEL + 1):
		var g := _grid([1,0,0, 0,2,0, 0,0,0])
		var jogada: int = RulesScript.get_move(g, O, nivel)
		assert_between(jogada, 0, 8, "degrau %d joga dentro do tabuleiro" % nivel)
		assert_eq(g.cells[jogada], VAZIO, "degrau %d joga em casa vazia" % nivel)


func test_degrau_fora_da_faixa_e_puxado_para_dentro() -> void:
	assert_eq(RulesScript.clamp_level(0), RulesScript.MIN_LEVEL, "abaixo do fundo")
	assert_eq(RulesScript.clamp_level(99), RulesScript.MAX_LEVEL, "acima do topo")


## O minimax devolvia sempre a primeira da lista de preferencia, entao a partida
## inteira era decorada depois de vista uma vez. Sortear entre jogadas de mesma
## nota nao enfraquece nada: elas valem o mesmo para a busca.
func test_o_minimax_varia_entre_jogadas_igualmente_boas() -> void:
	var vistas := {}
	for _tentativa in range(60):
		vistas[RulesScript.minimax_move(_grid([0,0,0, 0,0,0, 0,0,0]), O)] = true
	assert_gt(vistas.size(), 1, "o tabuleiro vazio nao abre sempre na mesma casa")


## Variar entre iguais nao pode custar forca: no tabuleiro vazio o minimax so
## considera jogadas que garantem o empate contra jogo perfeito.
func test_variar_nao_enfraquece_o_minimax() -> void:
	for _tentativa in range(30):
		var g := _grid([0,0,0, 0,0,0, 0,0,0])
		var lado := O
		while true:
			var jogada: int = RulesScript.minimax_move(g, lado)
			if jogada == -1:
				break
			g.cells[jogada] = lado
			if RulesScript.check_win(g, lado) or RulesScript.is_draw(g):
				break
			lado = X if lado == O else O
		assert_true(RulesScript.is_draw(g), "minimax contra minimax da empate")
		assert_false(RulesScript.check_win(g, X), "X nao venceu")
		assert_false(RulesScript.check_win(g, O), "O nao venceu")


## O minimax da nota 0 as nove aberturas, entao "sortear entre iguais" abria em
## lateral -- casa que nao ameaca nada e deixa o outro lado empatar sem pensar.
## Variar e bom; variar para uma casa passiva e jogar de graca.
func test_a_abertura_da_ia_nunca_cai_numa_lateral() -> void:
	var vistas := {}
	for _i in range(60):
		var idx := RulesScript.minimax_move(_grid([0,0,0, 0,0,0, 0,0,0]), O)
		assert_true(idx in RulesScript.CASAS_FORTES,
			"abriu em %d, uma lateral que nao monta forquilha" % idx)
		vistas[idx] = true
	assert_true(vistas.size() > 1, "e ainda assim a abertura varia entre partidas")
