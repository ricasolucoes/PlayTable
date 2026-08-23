extends GutTest

## Senet Egipcio — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestSenet.
##
## O Senet nao tem arquivo Rules: as regras moram em SenetGame.gd. O
## tabuleiro e um dicionario de 1 a 30, com 0 = vazia, 1 = jogador,
## 2 = adversario.

const GameScene = preload("res://games/senet/SenetGame.tscn")


func _jogo() -> Node:
	return add_child_autofree(GameScene.instantiate())


func _limpa(jogo) -> void:
	for i in range(1, 31):
		jogo.board[i] = 0


func test_tabuleiro_inicial_alterna_dez_pecas() -> void:
	var jogo := _jogo()
	assert_eq(jogo.board.size(), 30, "30 casas")
	for i in range(1, 11):
		assert_eq(jogo.board[i], 1 if i % 2 == 1 else 2, "casa %d alternada" % i)
	for i in range(11, 31):
		assert_eq(jogo.board[i], 0, "casa %d vazia" % i)
	assert_eq(jogo.player_borne_off, 0, "ninguem saiu ainda")
	assert_eq(jogo.ai_borne_off, 0, "ninguem saiu ainda")


func test_caminho_em_serpentina() -> void:
	var jogo := _jogo()
	assert_eq(jogo._get_square_row_col(1), Vector2i(0, 0), "casa 1")
	assert_eq(jogo._get_square_row_col(10), Vector2i(0, 9), "casa 10")
	assert_eq(jogo._get_square_row_col(11), Vector2i(1, 9), "casa 11 volta pela direita")
	assert_eq(jogo._get_square_row_col(20), Vector2i(1, 0), "casa 20")
	assert_eq(jogo._get_square_row_col(21), Vector2i(2, 0), "casa 21 retoma pela esquerda")
	assert_eq(jogo._get_square_row_col(30), Vector2i(2, 9), "casa 30")


func test_varetas_devolvem_valor_entre_um_e_cinco() -> void:
	var jogo := _jogo()
	var vistos := {}
	for _lance in range(400):
		var r: Dictionary = jogo._cast_sticks()
		assert_true(r["value"] in [1, 2, 3, 4, 5], "valor %d fora da tabela" % r["value"])
		assert_eq(r["extra"], r["value"] in [1, 4, 5], "lance extra so em 1, 4 e 5")
		assert_eq(r["display"].length(), 4, "quatro varetas mostradas")
		vistos[r["value"]] = true
	for v in [1, 2, 3, 4]:
		assert_true(vistos.has(v), "o valor %d saiu em 400 lances" % v)


func test_peca_anda_para_casa_vazia() -> void:
	var jogo := _jogo()
	_limpa(jogo)
	jogo.board[5] = 1
	var moves: Array = jogo._get_valid_moves(1, 3)
	assert_eq(moves.size(), 1, "uma jogada")
	assert_eq(moves[0], {"from": 5, "to": 8}, "5 + 3")


func test_peca_nao_pousa_em_casa_da_propria_cor() -> void:
	var jogo := _jogo()
	_limpa(jogo)
	jogo.board[5] = 1
	jogo.board[8] = 1
	assert_eq(jogo._get_valid_moves(1, 3).size(), 1, "so a peca de 8 pode andar")
	assert_eq(jogo._get_valid_moves(1, 3)[0]["from"], 8, "a de 5 esta bloqueada")


func test_troca_de_lugar_ao_cair_sobre_o_adversario() -> void:
	var jogo := _jogo()
	_limpa(jogo)
	jogo.board[5] = 1
	jogo.board[8] = 2
	jogo._execute_move(1, 5, 8)
	assert_eq(jogo.board[8], 1, "o atacante ocupa a casa")
	assert_eq(jogo.board[5], 2, "o defensor vai para a casa de origem")


func test_peca_protegida_por_vizinha_nao_pode_ser_trocada() -> void:
	var jogo := _jogo()
	_limpa(jogo)
	jogo.board[5] = 1
	jogo.board[8] = 2
	jogo.board[9] = 2
	assert_eq(jogo._get_valid_moves(1, 3), [], "vizinha a direita protege")

	_limpa(jogo)
	jogo.board[5] = 1
	jogo.board[8] = 2
	jogo.board[7] = 2
	assert_eq(jogo._get_valid_moves(1, 3), [], "vizinha a esquerda protege")


func test_casa_da_agua_afoga_e_manda_para_o_renascimento() -> void:
	var jogo := _jogo()
	_limpa(jogo)
	jogo.board[24] = 1
	jogo._execute_move(1, 24, 27)
	assert_eq(jogo.board[27], 0, "a casa da agua fica vazia")
	assert_eq(jogo.board[15], 1, "a peca renasce na casa 15")


func test_renascimento_ocupado_recua_ate_achar_casa_livre() -> void:
	var jogo := _jogo()
	_limpa(jogo)
	jogo.board[24] = 1
	jogo.board[15] = 2
	jogo.board[14] = 2
	jogo._execute_move(1, 24, 27)
	assert_eq(jogo.board[13], 1, "desceu ate a primeira casa livre")
	assert_eq(jogo.board[15], 2, "as ocupadas continuam ocupadas")
	assert_eq(jogo.board[14], 2, "as ocupadas continuam ocupadas")


func test_retirada_do_tabuleiro_na_casa_31() -> void:
	var jogo := _jogo()
	_limpa(jogo)
	jogo.board[29] = 1
	var moves: Array = jogo._get_valid_moves(1, 2)
	assert_eq(moves[0]["to"], 31, "29 + 2 sai do tabuleiro")
	jogo._execute_move(1, 29, 31)
	assert_eq(jogo.board[29], 0, "casa esvaziada")
	assert_eq(jogo.player_borne_off, 1, "uma peca retirada")


func test_lance_que_passa_de_31_nao_gera_jogada() -> void:
	var jogo := _jogo()
	_limpa(jogo)
	jogo.board[29] = 1
	assert_eq(jogo._get_valid_moves(1, 5), [], "34 estoura o tabuleiro")


func test_vitoria_com_as_cinco_pecas_retiradas() -> void:
	var jogo := _jogo()
	_limpa(jogo)
	jogo.player_borne_off = 4
	jogo.board[29] = 1
	jogo._execute_move(1, 29, 31)
	assert_eq(jogo.player_borne_off, 5, "as 5 pecas sairam")
	assert_true(jogo.game_over, "partida encerrada")


func test_reiniciar_devolve_o_tabuleiro_inicial() -> void:
	var jogo := _jogo()
	_limpa(jogo)
	jogo.player_borne_off = 3
	jogo.game_over = true
	jogo._start_new_game()
	assert_eq(jogo.player_borne_off, 0, "contador zerado")
	assert_false(jogo.game_over, "partida reaberta")
	for i in range(1, 11):
		assert_ne(jogo.board[i], 0, "as 10 pecas voltaram")


func test_partida_completa_nao_trava() -> void:
	# Guarda contra deadlock: substitui test_e2e_senet_simulation.
	for _partida in range(10):
		var jogo := _jogo()
		var rodadas := 0
		var lado := 1
		while not jogo.game_over and rodadas < 3000:
			rodadas += 1
			var lance: Dictionary = jogo._cast_sticks()
			var moves: Array = jogo._get_valid_moves(lado, lance["value"])
			if not moves.is_empty():
				var m: Dictionary = moves[randi() % moves.size()]
				jogo._execute_move(lado, m["from"], m["to"])
			if not lance["extra"]:
				lado = 2 if lado == 1 else 1
		assert_true(jogo.game_over, "a partida terminou em menos de 3000 rodadas")
		assert_true(jogo.player_borne_off >= 5 or jogo.ai_borne_off >= 5, "houve vencedor")
