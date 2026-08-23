extends GutTest

## Reversi — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestReversi e da
## simulacao E2E de test_integration_simulations.py.

const RulesScript = preload("res://games/reversi/ReversiRules.gd")

const VAZIO := 0
const PRETO := 1
const BRANCO := 2


func _vazio() -> Grid2D:
	return Grid2D.new(8, 8, VAZIO)


func test_tabuleiro_inicial_tem_as_quatro_pecas_cruzadas() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	assert_eq(g.get_cell(3, 3), BRANCO, "(3,3) branca")
	assert_eq(g.get_cell(3, 4), PRETO, "(3,4) preta")
	assert_eq(g.get_cell(4, 3), PRETO, "(4,3) preta")
	assert_eq(g.get_cell(4, 4), BRANCO, "(4,4) branca")
	assert_eq(RulesScript.count_scores(g), {"black": 2, "white": 2}, "2 a 2")


func test_flanqueio_valido_vira_a_peca_do_meio() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	assert_eq(RulesScript.get_flipped_pieces(g, Vector2i(2, 3), PRETO), [Vector2i(3, 3)] as Array[Vector2i],
		"preta em (2,3) flanqueia a branca em (3,3)")


func test_jogada_sem_flanqueio_e_invalida() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	assert_eq(RulesScript.get_flipped_pieces(g, Vector2i(0, 0), PRETO), [] as Array[Vector2i],
		"(0,0) nao flanqueia nada")


func test_abertura_tem_exatamente_quatro_jogadas_para_cada_lado() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	var pretas: Array[Vector2i] = RulesScript.get_valid_moves(g, PRETO)
	var brancas: Array[Vector2i] = RulesScript.get_valid_moves(g, BRANCO)
	assert_eq(pretas.size(), 4, "4 aberturas para as pretas")
	assert_eq(brancas.size(), 4, "4 aberturas para as brancas")
	for p in [Vector2i(2, 3), Vector2i(3, 2), Vector2i(4, 5), Vector2i(5, 4)]:
		assert_true(p in pretas, "%s e abertura das pretas" % str(p))


func test_casa_ocupada_nunca_e_jogada_valida() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	for pos in [Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3), Vector2i(4, 4)]:
		assert_eq(RulesScript.get_flipped_pieces(g, pos, PRETO), [] as Array[Vector2i],
			"%s ja esta ocupada" % str(pos))


func test_flanqueio_atravessa_varias_pecas() -> void:
	var g := _vazio()
	g.set_cell(0, 0, PRETO)
	for c in range(1, 6):
		g.set_cell(0, c, BRANCO)
	var flips: Array[Vector2i] = RulesScript.get_flipped_pieces(g, Vector2i(0, 6), PRETO)
	assert_eq(flips.size(), 5, "5 brancas viradas de uma vez")


func test_linha_de_pecas_sem_fechamento_nao_vira() -> void:
	# Seis brancas seguidas ate a borda: sem uma preta ancorando do outro
	# lado, jogar em (0,7) nao vira nada.
	var g := _vazio()
	for c in range(1, 7):
		g.set_cell(0, c, BRANCO)
	assert_eq(RulesScript.get_flipped_pieces(g, Vector2i(0, 7), PRETO), [] as Array[Vector2i],
		"sem peca propria ancorando, nao ha flanqueio")


func test_flanqueio_em_oito_direcoes() -> void:
	var g := _vazio()
	# Preta no centro cercada de brancas, com pretas logo atras em todas as
	# oito direcoes: jogar no centro vira as oito.
	var centro := Vector2i(4, 4)
	for d in BoardCoord.ALL_8_DIRECTIONS:
		g.set_cell(centro.x + d.x, centro.y + d.y, BRANCO)
		g.set_cell(centro.x + d.x * 2, centro.y + d.y * 2, PRETO)
	var flips: Array[Vector2i] = RulesScript.get_flipped_pieces(g, centro, PRETO)
	assert_eq(flips.size(), 8, "uma peca virada por direcao")


func test_apply_move_grava_a_jogada_e_as_viradas() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	var pos := Vector2i(2, 3)
	var flips: Array[Vector2i] = RulesScript.get_flipped_pieces(g, pos, PRETO)
	RulesScript.apply_move(g, pos, PRETO, flips)
	assert_eq(g.get_cell(2, 3), PRETO, "jogada gravada")
	assert_eq(g.get_cell(3, 3), PRETO, "branca virada")
	assert_eq(RulesScript.count_scores(g), {"black": 4, "white": 1}, "4 a 1 apos a abertura")


func test_placar_e_vencedor() -> void:
	var g := _vazio()
	for c in range(5):
		g.set_cell(0, c, PRETO)
	for c in range(3):
		g.set_cell(1, c, BRANCO)
	assert_eq(RulesScript.get_winner(g), {"winner": PRETO, "black": 5, "white": 3}, "pretas vencem")

	var empatado := _vazio()
	empatado.set_cell(0, 0, PRETO)
	empatado.set_cell(0, 1, BRANCO)
	assert_eq(RulesScript.get_winner(empatado)["winner"], 0, "empate")

	var brancas := _vazio()
	brancas.set_cell(0, 0, PRETO)
	brancas.set_cell(0, 1, BRANCO)
	brancas.set_cell(0, 2, BRANCO)
	assert_eq(RulesScript.get_winner(brancas)["winner"], BRANCO, "brancas vencem")


func test_ia_escolhe_uma_jogada_valida() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	var escolha: Vector2i = RulesScript.get_best_ai_move(g, BRANCO)
	assert_true(escolha in RulesScript.get_valid_moves(g, BRANCO), "IA joga dentro das regras")


func test_ia_prefere_o_canto() -> void:
	# Pretas em (0,1)..(0,3) com branca em (0,4): (0,0) fecha o canto, que
	# vale 100 na tabela posicional.
	var g := _vazio()
	for c in range(1, 4):
		g.set_cell(0, c, PRETO)
	g.set_cell(0, 4, BRANCO)
	g.set_cell(7, 7, BRANCO)
	var escolha: Vector2i = RulesScript.get_best_ai_move(g, BRANCO)
	assert_eq(escolha, Vector2i(0, 0), "IA pega o canto")


func test_ia_devolve_menos_um_sem_jogada() -> void:
	var g := _vazio()
	g.set_cell(0, 0, BRANCO)
	assert_eq(RulesScript.get_best_ai_move(g, BRANCO), Vector2i(-1, -1), "nada a jogar")


func test_partida_completa_termina_com_o_tabuleiro_resolvido() -> void:
	# Guarda contra deadlock: substitui test_e2e_reversi_simulation. Usa a
	# primeira jogada valida em vez do minimax para nao gastar minutos.
	var g: Grid2D = RulesScript.create_initial_board()
	var vez := PRETO
	var passes := 0
	var jogadas := 0
	while passes < 2 and jogadas < 64:
		var moves: Dictionary = RulesScript.find_all_valid_moves(g, vez)
		if moves.is_empty():
			passes += 1
		else:
			passes = 0
			var pos: Vector2i = moves.keys()[0]
			RulesScript.apply_move(g, pos, vez, moves[pos])
			jogadas += 1
		vez = BRANCO if vez == PRETO else PRETO
	var placar: Dictionary = RulesScript.count_scores(g)
	assert_eq(passes, 2, "a partida acabou por falta de jogadas dos dois lados")
	assert_true(jogadas > 0, "houve jogadas")
	assert_eq(placar["black"] + placar["white"], 4 + jogadas, "cada jogada poe uma peca nova")
	assert_true(placar["black"] + placar["white"] <= 64, "no maximo 64 pecas")
