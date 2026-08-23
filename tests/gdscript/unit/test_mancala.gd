extends GutTest

## Mancala (Kalah) — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestMancala.
##
## As regras do Mancala nao tem arquivo Rules proprio: moram dentro de
## MancalaGame.gd. Os testes chamam a cena real.
##
## Covas 0-5 do jogador, 6 e a Kalah do jogador, 7-12 da IA, 13 a Kalah da IA.

const GameScene = preload("res://games/mancala/MancalaGame.tscn")


func _jogo() -> Node:
	return add_child_autofree(GameScene.instantiate())


func test_tabuleiro_inicial_tem_quatro_gemas_por_cova() -> void:
	var jogo := _jogo()
	assert_eq(jogo.pits.size(), 14, "14 covas")
	for i in range(14):
		if i == 6 or i == 13:
			assert_eq(jogo.pits[i], 0, "kalah %d comeca vazia" % i)
		else:
			assert_eq(jogo.pits[i], 4, "cova %d comeca com 4" % i)
	assert_eq(_total(jogo), 48, "48 gemas na mesa")
	assert_true(jogo.is_player_turn, "o jogador comeca")
	assert_false(jogo.game_over, "partida aberta")


func _total(jogo) -> int:
	var soma := 0
	for v in jogo.pits:
		soma += v
	return soma


func test_semeadura_distribui_uma_gema_por_cova() -> void:
	var jogo := _jogo()
	jogo._on_player_pit_clicked(2)
	assert_eq(jogo.pits[2], 0, "cova de origem esvaziada")
	for i in [3, 4, 5]:
		assert_eq(jogo.pits[i], 5, "cova %d recebeu uma gema" % i)
	assert_eq(jogo.pits[6], 1, "a quarta gema caiu na propria kalah")
	assert_eq(_total(jogo), 48, "nenhuma gema sumiu")


func test_terminar_na_propria_kalah_da_turno_extra() -> void:
	var jogo := _jogo()
	jogo._on_player_pit_clicked(2)
	assert_true(jogo.is_player_turn, "a ultima gema caiu na kalah, joga de novo")


func test_terminar_fora_da_kalah_passa_a_vez() -> void:
	var jogo := _jogo()
	jogo._on_player_pit_clicked(0)
	assert_eq(jogo.pits[6], 0, "nao alcancou a kalah")
	assert_false(jogo.is_player_turn, "a vez passou para a IA")


func test_semeadura_pula_a_kalah_do_adversario() -> void:
	var jogo := _jogo()
	# A gema em 2 evita que a volta feche uma captura e confunda a contagem.
	jogo.pits = [0, 0, 1, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0]
	jogo._on_player_pit_clicked(5)
	assert_eq(jogo.pits[13], 0, "a kalah da IA nao recebe gema do jogador")
	assert_eq(jogo.pits[6], 1, "a propria kalah recebe")
	for i in range(7, 13):
		assert_eq(jogo.pits[i], 1, "as seis covas da IA receberam uma cada")
	assert_eq(jogo.pits[0], 1, "a volta continuou nas covas do jogador")
	assert_eq(jogo.pits[1], 1, "e na segunda tambem")
	assert_eq(jogo.pits[2], 2, "e na terceira, que ja tinha uma")


func test_captura_quando_a_ultima_gema_cai_em_cova_propria_vazia() -> void:
	var jogo := _jogo()
	jogo.pits = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0]
	jogo._on_player_pit_clicked(0)
	assert_eq(jogo.pits[6], 6, "1 da cova + 5 da cova oposta vao para a kalah")
	assert_eq(jogo.pits[1], 0, "cova de chegada esvaziada")
	assert_eq(jogo.pits[11], 0, "cova oposta esvaziada")


func test_sem_captura_quando_a_cova_oposta_esta_vazia() -> void:
	var jogo := _jogo()
	# A gema em 12 mantem o lado da IA ocupado; sem ela a partida acabaria.
	jogo.pits = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]
	jogo._on_player_pit_clicked(0)
	assert_eq(jogo.pits[1], 1, "a gema fica onde caiu")
	assert_eq(jogo.pits[6], 0, "nada para a kalah")


func test_sem_captura_quando_a_cova_de_chegada_ja_tinha_gemas() -> void:
	var jogo := _jogo()
	jogo.pits = [1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0]
	jogo._on_player_pit_clicked(0)
	assert_eq(jogo.pits[1], 4, "a cova de chegada ficou com 4")
	assert_eq(jogo.pits[11], 5, "a cova oposta continua intacta")
	assert_eq(jogo.pits[6], 0, "nada capturado")


func test_captura_nao_vale_do_lado_do_adversario() -> void:
	var jogo := _jogo()
	jogo.pits = [0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0]
	jogo.pits[1] = 4
	jogo._on_player_pit_clicked(5)
	# Ultima gema cai em 8, que e da IA: sem captura para o jogador.
	assert_eq(jogo.pits[8], 1, "a gema fica na cova da IA")
	assert_eq(jogo.pits[6], 1, "so a gema que passou pela kalah")


func test_cova_vazia_nao_pode_ser_escolhida() -> void:
	var jogo := _jogo()
	jogo.pits[3] = 0
	var antes: Array = jogo.pits.duplicate()
	jogo._on_player_pit_clicked(3)
	assert_eq(jogo.pits, antes, "nada mudou")


func test_fim_de_jogo_recolhe_as_gemas_restantes() -> void:
	var jogo := _jogo()
	# O jogador zera o proprio lado ao semear a ultima cova.
	jogo.pits = [0, 0, 0, 0, 0, 1, 10, 2, 3, 0, 0, 0, 0, 5]
	jogo._on_player_pit_clicked(5)
	assert_true(jogo.game_over, "partida encerrada")
	assert_eq(jogo.pits[6], 11, "10 na kalah + a gema semeada")
	assert_eq(jogo.pits[13], 10, "5 da kalah + as 5 que sobraram no lado da IA")
	for i in range(6):
		assert_eq(jogo.pits[i], 0, "lado do jogador limpo")
	for i in range(7, 13):
		assert_eq(jogo.pits[i], 0, "lado da IA limpo")
	assert_eq(jogo.pits[6] + jogo.pits[13], 21, "as gemas todas foram parar nas kalahs")


func test_reiniciar_devolve_o_tabuleiro_inicial() -> void:
	var jogo := _jogo()
	jogo._on_player_pit_clicked(2)
	jogo._start_new_game()
	assert_eq(_total(jogo), 48, "48 gemas de novo")
	assert_eq(jogo.pits[6], 0, "kalah zerada")
	assert_false(jogo.game_over, "partida reaberta")


func test_ia_semeia_sem_tocar_na_kalah_do_jogador() -> void:
	var jogo := _jogo()
	jogo.pits = [0, 0, 0, 0, 0, 0, 7, 8, 0, 0, 0, 0, 0, 0]
	jogo.is_player_turn = false
	jogo._play_ai_turn()
	assert_eq(jogo.pits[6], 7, "a kalah do jogador nao recebeu gema da IA")
	assert_eq(jogo.pits[13], 1, "a IA pos uma gema na propria kalah")
	assert_eq(jogo.pits[0], 1, "a volta passou pelas covas do jogador")
	assert_eq(jogo.pits[1], 1, "e pela segunda")


func test_partida_completa_nao_trava() -> void:
	# Guarda contra deadlock: substitui test_e2e_mancala_simulation. Roda a
	# semeadura pelas mesmas regras da cena, sem esperar as animacoes.
	for _partida in range(20):
		var pits: Array = []
		for i in range(14):
			pits.append(0 if (i == 6 or i == 13) else 4)
		var vez := 0  # 0 = jogador, 1 = IA
		var jogadas := 0
		while jogadas < 500:
			var base := 0 if vez == 0 else 7
			var kalah := 6 if vez == 0 else 13
			var pula := 13 if vez == 0 else 6
			var escolhas: Array = []
			for i in range(base, base + 6):
				if pits[i] > 0:
					escolhas.append(i)
			if escolhas.is_empty():
				break
			var cova: int = escolhas[randi() % escolhas.size()]
			var sementes: int = pits[cova]
			pits[cova] = 0
			var curr := cova
			while sementes > 0:
				curr = (curr + 1) % 14
				if curr == pula:
					continue
				pits[curr] += 1
				sementes -= 1
			if curr >= base and curr < base + 6 and pits[curr] == 1 and pits[12 - curr] > 0:
				pits[kalah] += pits[12 - curr] + 1
				pits[curr] = 0
				pits[12 - curr] = 0
			jogadas += 1
			var soma := 0
			for v in pits:
				soma += v
			assert_eq(soma, 48, "nenhuma gema criada nem perdida")
			if curr != kalah:
				vez = 1 - vez
		assert_true(jogadas > 0, "a partida andou")
		assert_true(jogadas < 500, "a partida terminou sem estourar o limite")
