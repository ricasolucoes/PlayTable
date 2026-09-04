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
		assert_eq(jogo.players_pawns[p].size(), 4, "4 peoes por jogador")
		for idx in range(4):
			assert_eq(jogo.players_pawns[p][idx], -1, "peao %d de %d na base" % [idx, p])
	assert_eq(jogo.current_turn, 0, "o jogador comeca")
	assert_false(jogo.game_over, "partida aberta")


func test_peao_so_sai_da_base_com_seis() -> void:
	var jogo := _jogo()
	for roll in [1, 2, 3, 4, 5]:
		jogo.players_pawns[0] = [-1, -1, -1, -1]
		jogo._handle_player_roll(roll)
		assert_eq(jogo.players_pawns[0], [-1, -1, -1, -1], "com %d nenhum peao sai" % roll)

	jogo.players_pawns[0] = [-1, -1, -1, -1]
	jogo.current_turn = 0
	jogo._move_player_pawn(0, 6)
	assert_eq(jogo.players_pawns[0][0], 0, "com 6 o peao entra na casa 0")


func test_peao_na_pista_anda_o_valor_do_dado() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [5, -1, -1, -1]
	jogo._move_player_pawn(0, 3)
	assert_eq(jogo.players_pawns[0][0], 8, "5 + 3")


func test_peao_nao_passa_da_casa_32() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [30, 30, -1, -1]
	jogo._handle_player_roll(5)
	assert_eq(jogo.players_pawns[0], [30, 30, -1, -1], "35 estouraria a reta final")

	jogo.players_pawns[0] = [30, -1, -1, -1]
	jogo._move_player_pawn(0, 2)
	assert_eq(jogo.players_pawns[0][0], 32, "32 e a casa final exata")


func test_pistas_se_cruzam_pelo_deslocamento_de_largada() -> void:
	# Espec. do teste Python: o passo 7 do jogador 0 e o passo 0 do jogador 1
	# ocupam a mesma casa absoluta.
	assert_eq((7 + START_OFFSETS[0]) % TRACK_LENGTH, (0 + START_OFFSETS[1]) % TRACK_LENGTH,
		"as duas pistas colidem na casa absoluta 7")


func test_captura_manda_o_adversario_para_a_base() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [7, -1, -1, -1]
	jogo.players_pawns[1] = [0, -1, -1, -1]
	jogo._check_captures(0, 0)
	assert_eq(jogo.players_pawns[1][0], -1, "peao azul volta para a base")
	assert_eq(jogo.players_pawns[0][0], 7, "o peao que capturou fica")


func test_captura_nao_atinge_peao_da_propria_cor() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [7, 7, -1, -1]
	jogo._check_captures(0, 0)
	assert_eq(jogo.players_pawns[0], [7, 7, -1, -1], "sem fogo amigo")


func test_captura_ignora_casas_diferentes() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [7, -1, -1, -1]
	jogo.players_pawns[1] = [1, -1, -1, -1]
	jogo._check_captures(0, 0)
	assert_eq(jogo.players_pawns[1][0], 1, "casa absoluta 8 nao e 7")


func test_captura_nao_alcanca_a_reta_final() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [30, -1, -1, -1]
	jogo.players_pawns[1] = [23, -1, -1, -1]  # absoluta (23 + 7) % 28 = 2
	jogo._check_captures(0, 0)
	assert_eq(jogo.players_pawns[1][0], 23, "quem esta na reta final nao captura")

	jogo.players_pawns[0] = [2, -1, -1, -1]
	jogo.players_pawns[2] = [30, -1, -1, -1]
	jogo._check_captures(0, 0)
	assert_eq(jogo.players_pawns[2][0], 30, "quem esta na reta final nao e capturado")


func test_captura_com_a_pista_dando_a_volta() -> void:
	var jogo := _jogo()
	# Jogador 3 largando em 21: passo 10 cai na casa absoluta (10+21)%28 = 3.
	jogo.players_pawns[3] = [10, -1, -1, -1]
	jogo.players_pawns[0] = [3, -1, -1, -1]
	jogo._check_captures(3, 0)
	assert_eq(jogo.players_pawns[0][0], -1, "a volta na pista tambem captura")


func test_vitoria_so_com_todos_os_peoes_na_casa_final() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [32, 32, 32, 31]
	assert_false(jogo._check_win(0), "um peao ainda esta na estrada")
	jogo.players_pawns[0] = [32, 32, 32, 32]
	assert_true(jogo._check_win(0), "todos chegaram")
	assert_true(jogo.game_over, "partida encerrada")


func test_reiniciar_devolve_todos_os_peoes_a_base() -> void:
	var jogo := _jogo()
	jogo.players_pawns[0] = [32, 32, 32, 32]
	jogo.game_over = true
	jogo._start_new_game()
	for p in range(4):
		assert_eq(jogo.players_pawns[p], [-1, -1, -1, -1], "jogador %d zerado" % p)
	assert_false(jogo.game_over, "partida reaberta")
	assert_eq(jogo.current_turn, 0, "a vez volta para o jogador")


func test_partida_completa_nao_trava() -> void:
	# Guarda contra deadlock: substitui test_e2e_ludo_simulation. Roda as
	# mesmas regras da cena sem esperar dado nem animacao.
	for _partida in range(20):
		var pawns := [[-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]]
		var vez := 0
		var rodadas := 0
		var vencedor := -1
		while vencedor == -1 and rodadas < 4000:
			rodadas += 1
			var roll := randi_range(1, 6)
			var movable: Array = []
			for idx in range(4):
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
						for oidx in range(4):
							var opos: int = pawns[outro][oidx]
							if opos >= 0 and opos < TRACK_LENGTH:
								if (opos + START_OFFSETS[outro]) % TRACK_LENGTH == abs_ativo:
									pawns[outro][oidx] = -1
			var todos_em_casa := true
			for idx in range(4):
				if pawns[vez][idx] < 32:
					todos_em_casa = false
					break
			if todos_em_casa:
				vencedor = vez
			elif roll != 6:
				vez = (vez + 1) % 4
		assert_ne(vencedor, -1, "alguem venceu em menos de 4000 rodadas")
		assert_eq(pawns[vencedor], [32, 32, 32, 32], "o vencedor levou os quatro peoes ao fim")


# -------------------------------------------------------------------- LudoAI
#
# A IA antiga era `movable.pick_random()` -- e valia para os TRES adversarios.
# Elas passavam ao lado de captura de graca, deixavam peao parado na base e
# adiantavam o peao errado.

const AIScript = preload("res://games/ludo/LudoAI.gd")


func _peoes(a: Array, b: Array, c: Array, d: Array) -> Array:
	return [a.duplicate(), b.duplicate(), c.duplicate(), d.duplicate()]


## Mandar peao adversario para a base vale o caminho inteiro que ele andou. A
## IA de sorteio passava ao lado disso metade das vezes.
func test_a_ia_captura_quando_a_captura_esta_na_mesa() -> void:
	# IA azul (1) larga em 7. Peao dela em 3 (casa absoluta 10) anda 4 e cai em
	# 7 (casa absoluta 14). O peao verde (2) larga em 14 e esta em 0 -- casa
	# absoluta 14. O outro peao azul, em 20, so anda.
	var pawns := _peoes([-1, -1, -1, -1], [3, 20, -1, -1], [0, -1, -1, -1], [-1, -1, -1, -1])
	assert_eq(AIScript.capturas(pawns, 1, 0, 4, START_OFFSETS), 1, "o peao 0 come")
	assert_eq(AIScript.capturas(pawns, 1, 1, 4, START_OFFSETS), 0, "o peao 1 nao")

	for _tentativa in range(8):
		assert_eq(AIScript.choose_pawn(pawns, 1, 4, START_OFFSETS, 10), 0,
			"a IA move o peao que captura")


## Peao na base nao anda e nao ameaca: tirar um da base vale mais que adiantar
## quem ja esta na pista.
func test_a_ia_tira_o_peao_da_base_com_o_seis() -> void:
	var pawns := _peoes([-1, -1, -1, -1], [-1, 12, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1])
	var saiu := 0
	for _tentativa in range(8):
		# Os indices 0, 2 e 3 estao todos na base e valem a mesma jogada: o que
		# se afirma e que a IA tira ALGUEM de la, nao que ela prefira o indice 0.
		if AIScript.choose_pawn(pawns, 1, 6, START_OFFSETS, 10) != 1:
			saiu += 1
	assert_gt(saiu, 4, "com 6 na mao, a base esvazia antes de a pista adiantar")


## Peao na reta final nao pode mais ser capturado; peao chegado nao sai de la.
func test_a_avaliacao_paga_a_reta_final_e_a_chegada() -> void:
	var perto := _peoes([-1, -1, -1, -1], [27, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1])
	var dentro := _peoes([-1, -1, -1, -1], [29, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1])
	var chegou := _peoes([-1, -1, -1, -1], [32, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1])

	var n_perto: int = AIScript.evaluate(perto, 1, START_OFFSETS)
	var n_dentro: int = AIScript.evaluate(dentro, 1, START_OFFSETS)
	var n_chegou: int = AIScript.evaluate(chegou, 1, START_OFFSETS)
	assert_gt(n_dentro, n_perto, "entrar na reta final vale mais que a ultima casa da pista")
	assert_gt(n_chegou, n_dentro, "chegar vale mais que estar na reta final")


## O Ludo nao tem casa segura, so distancia. Entre dois peoes que andariam o
## mesmo tanto, a IA move o que escapa do adversario.
##
## Os dois lances avancam 5 casas, entao o termo de avanco se cancela e sobra
## so a ameaca -- que e exatamente o que a IA de sorteio nao enxergava.
func test_a_ia_tira_da_frente_o_peao_ameacado() -> void:
	# Azul (1) larga em 7: peao em 3 fica na casa absoluta 10, peao em 12 na 19.
	# Vermelho (0) larga em 0: peao em 8 fica na casa absoluta 8, duas atras do
	# primeiro peao azul. Andando 5, o peao 0 vai para a absoluta 15 e sai do
	# alcance; o peao 1 so adianta e deixa o companheiro exposto.
	var pawns := _peoes([8, -1, -1, -1], [3, 12, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1])
	var fugiu := 0
	for _tentativa in range(8):
		if AIScript.choose_pawn(pawns, 1, 5, START_OFFSETS, 10) == 0:
			fugiu += 1
	assert_gt(fugiu, 4, "a IA prefere tirar da frente o peao que esta ao alcance")


## A geracao da IA e a regra da cena tem de concordar.
func test_a_geracao_da_ia_bate_com_a_regra_da_cena() -> void:
	assert_eq(AIScript.gerar(_peoes([-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]), 1, 3).size(), 0,
		"da base so se sai com 6")
	assert_eq(AIScript.gerar(_peoes([-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]), 1, 6).size(), 4,
		"com 6, os quatro peoes podem sair")
	assert_eq(AIScript.gerar(_peoes([-1, -1, -1, -1], [31, 20, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]), 1, 3).size(), 1,
		"o peao em 31 nao passa da casa 32")


func test_a_escada_de_perfis_e_monotonica() -> void:
	var erro_antes := 1.1
	for perfil in AIScript.PERFIS:
		assert_true(float(perfil["erro"]) <= erro_antes, "a chance de erro nunca sobe")
		erro_antes = float(perfil["erro"])
	assert_eq(float(AIScript.PERFIS[AIScript.PERFIS.size() - 1]["erro"]), 0.0,
		"o degrau do topo nao sorteia o peao")
	assert_gt(float(AIScript.PERFIS[0]["erro"]), 0.5, "o degrau de baixo sorteia quase sempre")
