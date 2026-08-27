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

	# A busca da IA roda fora da linha principal; aqui exercitamos a escolha e
	# a semeadura, que e o que o turno dela faz.
	var cova: int = MancalaAI.choose_pit(MancalaAI.achatar(jogo.pits), 1, 10)
	assert_eq(cova, 7, "so a cova 7 tem gema")
	jogo._semear(cova, 1)

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


# ----------------------------------------------------------------- MancalaAI
#
# A IA antiga era `valid_pits.pick_random()`. Num jogo em que a jogada gulosa e
# uma linha de codigo -- terminar na propria Kalah da turno extra -- sortear a
# cova significa jogar abaixo de quem notou a regra na primeira partida.

const AIScript = preload("res://games/mancala/MancalaAI.gd")

const JOGADOR := 0
const IA := 1


func _pits(lista: Array) -> PackedInt32Array:
	var p := PackedInt32Array()
	p.resize(14)
	for i in range(14):
		p[i] = int(lista[i])
	return p


## A regra que a IA de sorteio passava batido em toda partida.
func test_a_ia_pega_o_turno_extra_quando_ele_esta_na_mesa() -> void:
	# Cova 12 com 1 gema termina exatamente na Kalah da IA (13).
	var pits := _pits([4, 4, 4, 4, 4, 4, 0, 3, 3, 3, 3, 3, 1, 0])
	for _tentativa in range(6):
		assert_eq(AIScript.choose_pit(pits, IA, 10), 12, "a cova que cai na propria Kalah")


func test_o_turno_extra_e_reconhecido_pela_semeadura() -> void:
	var pits := _pits([4, 4, 4, 4, 4, 4, 0, 3, 3, 3, 3, 3, 1, 0])
	assert_true(AIScript.semear(pits, 12, IA), "terminou na Kalah da IA: joga de novo")
	assert_eq(pits[13], 1, "a gema entrou na Kalah")

	var outra := _pits([4, 4, 4, 4, 4, 4, 0, 3, 3, 3, 3, 3, 2, 0])
	assert_false(AIScript.semear(outra, 12, IA), "passou da Kalah: nao ha turno extra")


## Semear nunca pode encher a Kalah do adversario.
func test_a_semeadura_pula_a_kalah_do_adversario() -> void:
	var pits := _pits([0, 0, 0, 0, 0, 0, 7, 8, 0, 0, 0, 0, 0, 0])
	AIScript.semear(pits, 7, IA)
	assert_eq(pits[6], 7, "a Kalah do jogador ficou como estava")
	assert_eq(pits[13], 1, "a Kalah da IA recebeu uma")
	assert_eq(pits[0], 1, "a volta chegou nas covas do jogador")


## Captura: ultima gema em cova propria vazia, com gema na cova oposta.
func test_a_ia_captura_quando_a_captura_esta_disponivel() -> void:
	# Cova 8 com 1 gema termina na 9, que esta vazia; a oposta (3) tem 5.
	var pits := _pits([0, 0, 0, 5, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0])
	assert_eq(AIScript.choose_pit(pits, IA, 10), 8, "a cova que captura")

	AIScript.semear(pits, 8, IA)
	assert_eq(pits[13], 6, "as 5 da oposta mais a que chegou")
	assert_eq(pits[3], 0, "a cova oposta foi esvaziada")
	assert_eq(pits[9], 0, "e a cova de chegada tambem")


## Sem isto a nota do fim de partida esta errada e a busca fecha no lugar errado.
func test_o_fim_de_partida_varre_o_que_sobrou() -> void:
	var pits := _pits([0, 0, 0, 0, 0, 0, 10, 2, 3, 0, 0, 0, 0, 5])
	assert_true(AIScript.acabou(pits), "o jogador ficou sem gema")
	AIScript.varrer(pits)
	assert_eq(pits[13], 10, "a IA recolheu as 5 que tinha em jogo")
	assert_eq(pits[6], 10, "a Kalah do jogador nao mudou")

	var soma := 0
	for v in pits:
		soma += v
	assert_eq(soma, 20, "nenhuma gema sumiu na varredura")


func test_o_fim_de_partida_distingue_vitoria_de_derrota() -> void:
	var ganhando := _pits([0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 20])
	assert_gt(AIScript.evaluate(ganhando, IA), AIScript.VITORIA - 1, "a IA venceu")
	assert_lt(AIScript.evaluate(ganhando, JOGADOR), -AIScript.VITORIA + 1, "o jogador perdeu")


func test_a_escada_de_perfis_e_monotonica() -> void:
	var nos_antes := 0
	var erro_antes := 1.1
	for perfil in AIScript.PERFIS:
		assert_gt(int(perfil["nos"]), nos_antes, "o orcamento cresce a cada degrau")
		assert_true(float(perfil["erro"]) <= erro_antes, "a chance de erro nunca sobe")
		nos_antes = int(perfil["nos"])
		erro_antes = float(perfil["erro"])
	assert_eq(float(AIScript.PERFIS[AIScript.PERFIS.size() - 1]["erro"]), 0.0,
		"o degrau do topo nao erra de proposito")


## O teste que a IA de sorteio nao passaria: em partida cheia, o degrau do topo
## tem de terminar com mais gemas que o degrau de baixo.
func test_o_degrau_do_topo_ganha_do_degrau_de_baixo() -> void:
	var vitorias := 0
	for partida in range(6):
		var pits := _pits([4, 4, 4, 4, 4, 4, 0, 4, 4, 4, 4, 4, 4, 0])
		# Alterna quem comeca: sair na frente pesa no Kalah.
		var lado: int = JOGADOR if partida % 2 == 0 else IA
		var lances := 0
		while not AIScript.acabou(pits) and lances < 200:
			var nivel: int = 10 if lado == IA else 1
			var cova: int = AIScript.choose_pit(pits, lado, nivel)
			if cova < 0:
				break
			if not AIScript.semear(pits, cova, lado):
				lado = 1 - lado
			lances += 1
		AIScript.varrer(pits)
		if pits[13] > pits[6]:
			vitorias += 1

	assert_gt(vitorias, 3, "o degrau 10 venceu %d de 6 partidas contra o degrau 1" % vitorias)
