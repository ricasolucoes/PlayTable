extends GutTest

## Testes Unitários de Regras e Lógica de Gamão (Backgammon).

const Rules := preload("res://games/gamao/BackgammonRules.gd")


func test_estado_inicial_tem_30_pecas() -> void:
	var state := Rules.create_initial_state()
	var board: Array = state["board"]
	assert_eq(board.size(), 25, "tabuleiro tem 25 posicoes (0 a 24)")

	# Brancas
	assert_eq(board[24], 2, "2 brancas no ponto 24")
	assert_eq(board[13], 5, "5 brancas no ponto 13")
	assert_eq(board[8], 3, "3 brancas no ponto 8")
	assert_eq(board[6], 5, "5 brancas no ponto 6")

	# Pretas
	assert_eq(board[1], -2, "2 pretas no ponto 1")
	assert_eq(board[12], -5, "5 pretas no ponto 12")
	assert_eq(board[17], -3, "3 pretas no ponto 17")
	assert_eq(board[19], -5, "5 pretas no ponto 19")

	# Contagem total
	var white_total := 0
	var black_total := 0
	for pt in range(1, 25):
		var v: int = int(board[pt])
		if v > 0:
			white_total += v
		elif v < 0:
			black_total += -v

	assert_eq(white_total, 15, "15 pecas brancas no total")
	assert_eq(black_total, 15, "15 pecas pretas no total")
	assert_eq(state["bar_white"], 0, "barra branca vazia")
	assert_eq(state["bar_black"], 0, "barra preta vazia")
	assert_eq(state["borne_white"], 0, "recolhidas brancas 0")
	assert_eq(state["borne_black"], 0, "recolhidas pretas 0")


func test_rolagem_de_dados_e_duplas() -> void:
	for _i in range(20):
		var roll := Rules.roll_dice()
		var d1: int = roll["d1"]
		var d2: int = roll["d2"]
		assert_true(d1 >= 1 and d1 <= 6, "dado 1 no intervalo 1..6")
		assert_true(d2 >= 1 and d2 <= 6, "dado 2 no intervalo 1..6")
		var moves: Array = roll["moves"]
		if d1 == d2:
			assert_true(roll["is_double"], "marcado como dupla")
			assert_eq(moves.size(), 4, "dupla gera 4 movimentos")
			assert_eq(moves[0], d1, "movimento igual ao dado")
		else:
			assert_false(roll["is_double"], "nao e dupla")
			assert_eq(moves.size(), 2, "diferentes geram 2 movimentos")


func test_valida_movimento_simples() -> void:
	var state := Rules.create_initial_state()
	# Branca move do 24 com dado 3 -> vai para o 21 (vazio)
	var check := Rules.validate_single_move(state, Rules.PLAYER_WHITE, 24, 3)
	assert_true(check["valid"], "movimento 24->21 e valido")
	assert_eq(check["to"], 21, "destino e 21")
	assert_false(check["is_hit"], "nao e captura")
	assert_false(check["is_bear_off"], "nao e bear off")

	var ok := Rules.apply_move_inplace(state, Rules.PLAYER_WHITE, 24, 3)
	assert_true(ok, "lance aplicado com sucesso")
	assert_eq(state["board"][24], 1, "sobra 1 branca no 24")
	assert_eq(state["board"][21], 1, "1 branca no 21")


func test_valida_bloqueio_inimigo() -> void:
	var state := Rules.create_initial_state()
	# Ponto 19 tem 5 pretas (bloqueado para brancas)
	# Branca no ponto 24 com dado 5 -> 24 - 5 = 19 (bloqueado)
	var check := Rules.validate_single_move(state, Rules.PLAYER_WHITE, 24, 5)
	assert_false(check["valid"], "movimento para ponto bloqueado e recusado")


func test_captura_blot_para_a_barra() -> void:
	var state := Rules.create_initial_state()
	# Coloca um blot preto solitário no ponto 20
	state["board"][20] = -1
	# Branca no ponto 24 com dado 4 -> 24 - 4 = 20 (blot preto)
	var check := Rules.validate_single_move(state, Rules.PLAYER_WHITE, 24, 4)
	assert_true(check["valid"], "ataque ao blot e valido")
	assert_true(check["is_hit"], "reconhecido como captura de blot")
	assert_eq(check["to"], 20, "destino e 20")

	Rules.apply_move_inplace(state, Rules.PLAYER_WHITE, 24, 4)
	assert_eq(state["board"][20], 1, "ponto 20 agora tem a peca branca")
	assert_eq(state["bar_black"], 1, "peca preta foi enviada para a barra")


func test_reentrada_obrigatoria_da_barra() -> void:
	var state := Rules.create_initial_state()
	state["bar_white"] = 1 # Branca tem peca na barra

	# Tentativa de mover peca do tabuleiro (ex: ponto 24) deve falhar
	var check_board := Rules.validate_single_move(state, Rules.PLAYER_WHITE, 24, 3)
	assert_false(check_board["valid"], "proibido mover do tabuleiro enquanto houver peca na barra")

	# Mover da barra com dado 3 -> 25 - 3 = 22 (aberto)
	var check_bar := Rules.validate_single_move(state, Rules.PLAYER_WHITE, Rules.BAR_POS, 3)
	assert_true(check_bar["valid"], "reentrada da barra e valida")
	assert_eq(check_bar["to"], 22, "destino no ponto 22")

	Rules.apply_move_inplace(state, Rules.PLAYER_WHITE, Rules.BAR_POS, 3)
	assert_eq(state["bar_white"], 0, "barra branca zerada")
	assert_eq(state["board"][22], 1, "peca branca entrou no ponto 22")


func test_bear_off_recolhimento_exato() -> void:
	var state := {
		"board": [0, 2, 3, 2, 3, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		"bar_white": 0,
		"bar_black": 0,
		"borne_white": 0,
		"borne_black": 0
	}
	# Todas as 15 brancas estao em 1..6 (2+3+2+3+2+3 = 15)
	assert_true(Rules.can_bear_off(state, Rules.PLAYER_WHITE), "apto a recolher pecas")

	# Recolhe do ponto 6 com dado 6
	var check := Rules.validate_single_move(state, Rules.PLAYER_WHITE, 6, 6)
	assert_true(check["valid"], "recolhimento exato valido")
	assert_true(check["is_bear_off"], "marcado como bear off")
	assert_eq(check["to"], Rules.BEAR_OFF_POS, "destino e bear off tray")

	Rules.apply_move_inplace(state, Rules.PLAYER_WHITE, 6, 6)
	assert_eq(state["board"][6], 2, "sobraram 2 no ponto 6")
	assert_eq(state["borne_white"], 1, "1 peca recolhida")


func test_bear_off_recusa_com_peca_fora_do_home() -> void:
	var state := {
		"board": [0, 2, 3, 2, 3, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		"bar_white": 0,
		"bar_black": 0,
		"borne_white": 0,
		"borne_black": 0
	}
	# Ha 1 peca no ponto 7 (fora do home 1..6)
	assert_false(Rules.can_bear_off(state, Rules.PLAYER_WHITE), "nao pode recolher com peca fora")
	var check := Rules.validate_single_move(state, Rules.PLAYER_WHITE, 6, 6)
	assert_false(check["valid"], "movimento de bear-off e recusado")


func test_bear_off_dado_maior_recolhe_do_ponto_mais_distante() -> void:
	var state := {
		"board": [0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		"bar_white": 0,
		"bar_black": 0,
		"borne_white": 0,
		"borne_black": 0
	}
	# Ponto 6 esta vazio; o ponto mais alto ocupado e o 5
	# Com dado 6, deve poder recolher do ponto 5
	var check := Rules.validate_single_move(state, Rules.PLAYER_WHITE, 5, 6)
	assert_true(check["valid"], "dado 6 recolhe do ponto 5 porque o 6 esta vazio")

	# Mas nao pode recolher do ponto 2 com dado 6, pois o ponto 5 ainda tem pecas!
	var check_invalid := Rules.validate_single_move(state, Rules.PLAYER_WHITE, 2, 6)
	assert_false(check_invalid["valid"], "nao pode recolher do ponto 2 com dado 6 enquanto houver pecas no 5")


func test_pip_count_inicial() -> void:
	var state := Rules.create_initial_state()
	var white_pip := Rules.calculate_pip_count(state, Rules.PLAYER_WHITE)
	var black_pip := Rules.calculate_pip_count(state, Rules.PLAYER_BLACK)
	# 2*24 + 5*13 + 3*8 + 5*6 = 48 + 65 + 24 + 30 = 167
	assert_eq(white_pip, 167, "pip count inicial das brancas e 167")
	assert_eq(black_pip, 167, "pip count inicial das pretas e 167")


func test_vitoria_normal_gammon_e_backgammon() -> void:
	var state := Rules.create_initial_state()
	state["borne_white"] = 15
	state["borne_black"] = 1 # Pretas ja recolheram 1
	assert_true(Rules.is_game_over(state), "jogo finalizado")
	assert_eq(Rules.get_winner(state), Rules.PLAYER_WHITE, "brancas venceram")
	assert_eq(Rules.get_win_type(state, Rules.PLAYER_WHITE), "single", "vitoria simples")

	# Gammon: pretas com 0 recolhidas e sem pecas no home das brancas
	state["borne_black"] = 0
	# Limpa pontos 1..6 de pecas pretas
	for pt in range(1, 7):
		if state["board"][pt] < 0:
			state["board"][pt] = 0
	assert_eq(Rules.get_win_type(state, Rules.PLAYER_WHITE), "gammon", "vitoria por Gammon (2x)")

	# Backgammon: pretas na barra ou no home das brancas com 0 recolhidas
	state["bar_black"] = 1
	assert_eq(Rules.get_win_type(state, Rules.PLAYER_WHITE), "backgammon", "vitoria por Backgammon (3x)")


func test_ia_gera_jogadas_validas() -> void:
	var state := Rules.create_initial_state()
	var turn := Rules.get_best_ai_turn(state, Rules.PLAYER_BLACK, [3, 5], "hard")
	assert_false(turn.is_empty(), "IA encontrou sequencia de jogadas")
	for mv in turn:
		assert_true(mv.has("from"), "jogada tem from")
		assert_true(mv.has("die"), "jogada tem die")
		assert_true(mv.has("to"), "jogada tem to")


func test_partida_completa_ia_vs_ia_termina() -> void:
	# Simula 3 partidas completas entre IAs para garantir ausencia de deadlocks
	for _partida in range(3):
		var state := Rules.create_initial_state()
		var current_player: int = Rules.PLAYER_WHITE
		var turns: int = 0

		while not Rules.is_game_over(state) and turns < 600:
			turns += 1
			var roll := Rules.roll_dice()
			var moves_left: Array = roll["moves"]
			var ai_turn := Rules.get_best_ai_turn(state, current_player, moves_left, "hard")
			for mv in ai_turn:
				Rules.apply_move_inplace(state, current_player, mv["from"], mv["die"])
			current_player = 3 - current_player

		assert_true(Rules.is_game_over(state), "partida terminou em menos de 600 turnos")
		assert_ne(Rules.get_winner(state), Rules.PLAYER_NONE, "houve vencedor definido")
