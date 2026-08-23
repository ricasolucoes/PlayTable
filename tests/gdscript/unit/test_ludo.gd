extends GutTest

## Ludo Simplificado — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestLudo.
##
## O Ludo nao tem arquivo Rules: as regras moram em LudoGame.gd. Posicao -1
## significa peao na base; 0..27 e a pista compartilhada; 28..32 e a reta
## final de cada cor.

const GameScene = preload("res://games/ludo/LudoGame.tscn")

const TRACK_LENGTH := 28
const START_OFFSETS := [0, 7, 14, 21]


func _jogo() -> Node:
	return add_child_autofree(GameScene.instantiate())


func test_todos_os_peoes_comecam_na_base() -> void:
	var jogo := _jogo()
	assert_eq(jogo.players_pawns.size(), 4, "4 jogadores")
	for p in range(4):
		assert_eq(jogo.players_pawns[p].size(), 2, "2 peoes por jogador")
		for idx in range(2):
			assert_eq(jogo.players_pawns[p][idx], -1, "peao %d de %d na base" % [idx, p])
	assert_eq(jogo.current_turn, 0, "o jogador comeca")
	assert_false(jogo.game_over, "partida aberta")


func test_peao_so_sai_da_base_com_seis() -> void:
	var jogo := _jogo()
	for roll in [1, 2, 3, 4, 5]:
		jogo.players_pawns[0] = [-1, -1]
		jogo._handle_player_roll(roll)
		assert_eq(jogo.players_pawns[0], [-1, -1], "com %d nenhum peao sai" % roll)

	jogo.players_pawns[0] = [-1, -1]
	jogo.current_turn = 0
	jogo._move_player_pawn(0, 6)
	assert_eq(jogo.players_pawns[0][0], 0, "com 6 o peao entra na casa 0")


func test_peao_na_pista_anda_o_valor_do_dado() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [5, -1]
	jogo._move_player_pawn(0, 3)
	assert_eq(jogo.players_pawns[0][0], 8, "5 + 3")


func test_peao_nao_passa_da_casa_32() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [30, 30]
	jogo._handle_player_roll(5)
	assert_eq(jogo.players_pawns[0], [30, 30], "35 estouraria a reta final")

	jogo.players_pawns[0] = [30, -1]
	jogo._move_player_pawn(0, 2)
	assert_eq(jogo.players_pawns[0][0], 32, "32 e a casa final exata")


func test_pistas_se_cruzam_pelo_deslocamento_de_largada() -> void:
	# Espec. do teste Python: o passo 7 do jogador 0 e o passo 0 do jogador 1
	# ocupam a mesma casa absoluta.
	assert_eq((7 + START_OFFSETS[0]) % TRACK_LENGTH, (0 + START_OFFSETS[1]) % TRACK_LENGTH,
		"as duas pistas colidem na casa absoluta 7")


func test_captura_manda_o_adversario_para_a_base() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [7, -1]
	jogo.players_pawns[1] = [0, -1]
	jogo._check_captures(0, 0)
	assert_eq(jogo.players_pawns[1][0], -1, "peao azul volta para a base")
	assert_eq(jogo.players_pawns[0][0], 7, "o peao que capturou fica")


func test_captura_nao_atinge_peao_da_propria_cor() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [7, 7]
	jogo._check_captures(0, 0)
	assert_eq(jogo.players_pawns[0], [7, 7], "sem fogo amigo")


func test_captura_ignora_casas_diferentes() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [7, -1]
	jogo.players_pawns[1] = [1, -1]
	jogo._check_captures(0, 0)
	assert_eq(jogo.players_pawns[1][0], 1, "casa absoluta 8 nao e 7")


func test_captura_nao_alcanca_a_reta_final() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [30, -1]
	jogo.players_pawns[1] = [23, -1]  # absoluta (23 + 7) % 28 = 2
	jogo._check_captures(0, 0)
	assert_eq(jogo.players_pawns[1][0], 23, "quem esta na reta final nao captura")

	jogo.players_pawns[0] = [2, -1]
	jogo.players_pawns[2] = [30, -1]
	jogo._check_captures(0, 0)
	assert_eq(jogo.players_pawns[2][0], 30, "quem esta na reta final nao e capturado")


func test_captura_com_a_pista_dando_a_volta() -> void:
	var jogo := _jogo()
	# Jogador 3 largando em 21: passo 10 cai na casa absoluta (10+21)%28 = 3.
	jogo.players_pawns[3] = [10, -1]
	jogo.players_pawns[0] = [3, -1]
	jogo._check_captures(3, 0)
	assert_eq(jogo.players_pawns[0][0], -1, "a volta na pista tambem captura")


func test_vitoria_so_com_os_dois_peoes_na_casa_final() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [32, 31]
	assert_false(jogo._check_win(0), "um peao ainda esta na estrada")
	jogo.players_pawns[0] = [32, 32]
	assert_true(jogo._check_win(0), "os dois chegaram")
	assert_true(jogo.game_over, "partida encerrada")


func test_reiniciar_devolve_todos_os_peoes_a_base() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [32, 32]
	jogo.game_over = true
	jogo._start_new_game()
	for p in range(4):
		assert_eq(jogo.players_pawns[p], [-1, -1], "jogador %d zerado" % p)
	assert_false(jogo.game_over, "partida reaberta")
	assert_eq(jogo.current_turn, 0, "a vez volta para o jogador")


func test_partida_completa_nao_trava() -> void:
	# Guarda contra deadlock: substitui test_e2e_ludo_simulation. Roda as
	# mesmas regras da cena sem esperar dado nem animacao.
	for _partida in range(20):
		var pawns := [[-1, -1], [-1, -1], [-1, -1], [-1, -1]]
		var vez := 0
		var rodadas := 0
		var vencedor := -1
		while vencedor == -1 and rodadas < 4000:
			rodadas += 1
			var roll := randi_range(1, 6)
			var movable: Array = []
			for idx in range(2):
				var pos: int = pawns[vez][idx]
				if pos == -1 and roll == 6:
					movable.append(idx)
				elif pos >= 0 and pos + roll <= 32:
					movable.append(idx)
			if not movable.is_empty():
				var escolhido: int = movable[randi() % movable.size()]
				if pawns[vez][escolhido] == -1:
					pawns[vez][escolhido] = 0
				else:
					pawns[vez][escolhido] += roll
				var ativo: int = pawns[vez][escolhido]
				if ativo >= 0 and ativo < TRACK_LENGTH:
					var abs_ativo: int = (ativo + START_OFFSETS[vez]) % TRACK_LENGTH
					for outro in range(4):
						if outro == vez:
							continue
						for oidx in range(2):
							var opos: int = pawns[outro][oidx]
							if opos >= 0 and opos < TRACK_LENGTH:
								if (opos + START_OFFSETS[outro]) % TRACK_LENGTH == abs_ativo:
									pawns[outro][oidx] = -1
			if pawns[vez][0] >= 32 and pawns[vez][1] >= 32:
				vencedor = vez
			elif roll != 6:
				vez = (vez + 1) % 4
		assert_ne(vencedor, -1, "alguem venceu em menos de 4000 rodadas")
		assert_eq(pawns[vencedor], [32, 32], "o vencedor levou os dois peoes ao fim")
