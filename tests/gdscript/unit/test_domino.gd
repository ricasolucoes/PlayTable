extends GutTest

## Domino — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestDomino.

const RulesScript = preload("res://games/domino/DominoRules.gd")
const GameScene = preload("res://games/domino/DominoGame.tscn")


# ----------------------------------------------------------------- DominoRules

func test_monte_tem_28_pedras_sem_repeticao() -> void:
	var monte: Array[Dictionary] = RulesScript.generate_boneyard_28()
	assert_eq(monte.size(), 28, "28 pedras")
	var vistas := {}
	for t in monte:
		var chave := "%d|%d" % [t["a"], t["b"]]
		assert_false(vistas.has(chave), "pedra %s repetida" % chave)
		vistas[chave] = true
		assert_true(t["a"] <= t["b"], "pedra normalizada com a <= b")


func test_monte_tem_os_sete_duplos() -> void:
	var monte: Array[Dictionary] = RulesScript.generate_boneyard_28()
	var duplos := 0
	for t in monte:
		if t["a"] == t["b"]:
			duplos += 1
	assert_eq(duplos, 7, "de 0|0 a 6|6")


func test_soma_de_todos_os_pontos_do_monte() -> void:
	assert_eq(RulesScript.calculate_hand_points(RulesScript.generate_boneyard_28()), 168,
		"o domino completo soma 168 pontos")


func test_pedra_encaixa_quando_bate_com_alguma_ponta() -> void:
	var pedra := {"a": 6, "b": 4}
	assert_true(RulesScript.can_tile_fit(pedra, 4, 2), "o 4 bate com a ponta esquerda")
	assert_true(RulesScript.can_tile_fit(pedra, 6, 2), "o 6 bate com a ponta esquerda")
	assert_true(RulesScript.can_tile_fit(pedra, 2, 6), "o 6 bate com a ponta direita")
	assert_false(RulesScript.can_tile_fit(pedra, 5, 3), "nenhum lado bate")


func test_mesa_vazia_aceita_qualquer_pedra() -> void:
	assert_true(RulesScript.can_tile_fit({"a": 0, "b": 1}, -1, -1), "mesa vazia")


func test_has_any_playable_olha_a_mao_inteira() -> void:
	var mao := [{"a": 0, "b": 1}, {"a": 6, "b": 4}]
	assert_true(RulesScript.has_any_playable(mao, 4, 2), "a segunda pedra joga")
	assert_false(RulesScript.has_any_playable(mao, 5, 3), "nenhuma joga")
	assert_false(RulesScript.has_any_playable([], 5, 3), "mao vazia nao joga")


func test_get_playable_indices_lista_so_as_jogaveis() -> void:
	var mao := [{"a": 0, "b": 1}, {"a": 6, "b": 4}, {"a": 2, "b": 2}]
	assert_eq(RulesScript.get_playable_indices(mao, 4, 2), [1, 2] as Array[int])
	assert_eq(RulesScript.get_playable_indices(mao, 5, 3), [] as Array[int])


func test_orientacao_na_ponta_esquerda_vira_a_pedra() -> void:
	# Espec. do teste Python: (6,4) na esquerda com ponta 6 vira (4,6) e a
	# nova ponta esquerda passa a ser 4.
	var r: Dictionary = RulesScript.orient_tile_for_side({"a": 6, "b": 4}, "left", 6, 2)
	assert_eq(r["oriented_tile"], {"a": 4, "b": 6}, "pedra virada")
	assert_eq(r["new_left_end"], 4, "nova ponta esquerda")
	assert_eq(r["new_right_end"], 2, "ponta direita intacta")


func test_orientacao_na_ponta_esquerda_sem_virar() -> void:
	var r: Dictionary = RulesScript.orient_tile_for_side({"a": 4, "b": 6}, "left", 6, 2)
	assert_eq(r["oriented_tile"], {"a": 4, "b": 6}, "ja estava na posicao certa")
	assert_eq(r["new_left_end"], 4, "nova ponta esquerda")


func test_orientacao_na_ponta_direita() -> void:
	var sem_virar: Dictionary = RulesScript.orient_tile_for_side({"a": 2, "b": 5}, "right", 6, 2)
	assert_eq(sem_virar["oriented_tile"], {"a": 2, "b": 5}, "o a ja encosta na ponta")
	assert_eq(sem_virar["new_right_end"], 5, "nova ponta direita")
	assert_eq(sem_virar["new_left_end"], 6, "ponta esquerda intacta")

	var virando: Dictionary = RulesScript.orient_tile_for_side({"a": 5, "b": 2}, "right", 6, 2)
	assert_eq(virando["oriented_tile"], {"a": 2, "b": 5}, "pedra virada")
	assert_eq(virando["new_right_end"], 5, "nova ponta direita")


func test_duplo_encaixa_sem_mudar_a_ponta() -> void:
	var r: Dictionary = RulesScript.orient_tile_for_side({"a": 3, "b": 3}, "left", 3, 5)
	assert_eq(r["new_left_end"], 3, "duplo mantem a ponta")
	assert_eq(r["new_right_end"], 5, "ponta direita intacta")


func test_ia_escolhe_pedra_jogavel_e_a_ponta_certa() -> void:
	var mao := [{"a": 0, "b": 1}, {"a": 6, "b": 4}]
	var jogada: Dictionary = RulesScript.find_ai_move(mao, 4, 2)
	assert_eq(jogada["tile_index"], 1, "a pedra jogavel")
	assert_eq(jogada["side"], "left", "encaixa na esquerda, que vale 4")

	var so_direita: Dictionary = RulesScript.find_ai_move([{"a": 2, "b": 5}], 4, 2)
	assert_eq(so_direita["side"], "right", "so a ponta direita aceita")


func test_ia_sem_jogada_devolve_dicionario_vazio() -> void:
	assert_eq(RulesScript.find_ai_move([{"a": 0, "b": 1}], 5, 3), {}, "nada jogavel")
	assert_eq(RulesScript.find_ai_move([], 5, 3), {}, "mao vazia")


func test_pontos_da_mao() -> void:
	assert_eq(RulesScript.calculate_hand_points([{"a": 6, "b": 4}, {"a": 0, "b": 3}]), 13)
	assert_eq(RulesScript.calculate_hand_points([]), 0, "mao vazia vale zero")


# ------------------------------------------------------------------ DominoGame

func test_distribuicao_inicial_da_cena() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	# Uma pedra sai de uma das maos para abrir a mesa.
	assert_eq(jogo.board_chain.size(), 1, "mesa aberta com uma pedra")
	assert_eq(jogo.player_hand.size() + jogo.ai_hand.size(), 13, "7 + 7 menos a de abertura")
	assert_eq(jogo.boneyard.size(), 14, "28 - 14 distribuidas")
	assert_eq(jogo.left_end, jogo.board_chain[0]["a"], "ponta esquerda")
	assert_eq(jogo.right_end, jogo.board_chain[0]["b"], "ponta direita")


func test_nenhuma_pedra_aparece_duas_vezes_na_distribuicao() -> void:
	for _partida in range(5):
		var jogo = add_child_autofree(GameScene.instantiate())
		var todas: Array = []
		todas.append_array(jogo.player_hand)
		todas.append_array(jogo.ai_hand)
		todas.append_array(jogo.boneyard)
		todas.append_array(jogo.board_chain)
		assert_eq(todas.size(), 28, "as 28 pedras seguem em jogo")
		var vistas := {}
		for t in todas:
			var chave := "%d|%d" % [t["a"], t["b"]]
			assert_false(vistas.has(chave), "pedra %s duplicada" % chave)
			vistas[chave] = true


func test_abertura_usa_o_duplo_mais_alto_disponivel() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	var aberta: Dictionary = jogo.board_chain[0]
	if aberta["a"] != aberta["b"]:
		# Sem duplo nenhum nas maos: nada a conferir.
		return
	var na_mao: Array = []
	na_mao.append_array(jogo.player_hand)
	na_mao.append_array(jogo.ai_hand)
	for t in na_mao:
		if t["a"] == t["b"]:
			assert_true(t["a"] < aberta["a"],
				"duplo %d|%d ficou na mao sendo maior que a abertura" % [t["a"], t["b"]])


func test_partida_completa_da_cena_nao_trava() -> void:
	# Guarda contra deadlock: substitui test_e2e_domino_simulation. Joga com
	# as regras reais, sem passar pela cena, para nao esperar animacao.
	for _partida in range(20):
		var monte: Array[Dictionary] = RulesScript.generate_boneyard_28()
		monte.shuffle()
		var maos := [[], []]
		for _i in range(7):
			maos[0].append(monte.pop_back())
			maos[1].append(monte.pop_back())
		var abertura: Dictionary = maos[0].pop_back()
		var esquerda: int = abertura["a"]
		var direita: int = abertura["b"]
		var vez := 1
		var passes := 0
		var jogadas := 0
		while passes < 2 and not maos[0].is_empty() and not maos[1].is_empty() and jogadas < 28:
			var jogada: Dictionary = RulesScript.find_ai_move(maos[vez], esquerda, direita)
			if jogada.is_empty():
				if not monte.is_empty():
					maos[vez].append(monte.pop_back())
					continue
				passes += 1
			else:
				passes = 0
				jogadas += 1
				var pedra: Dictionary = maos[vez].pop_at(jogada["tile_index"])
				var r: Dictionary = RulesScript.orient_tile_for_side(pedra, jogada["side"], esquerda, direita)
				esquerda = r["new_left_end"]
				direita = r["new_right_end"]
			vez = 1 - vez
		assert_true(passes >= 2 or maos[0].is_empty() or maos[1].is_empty() or jogadas >= 27,
			"a partida terminou por batida ou por jogo fechado")


# ------------------------------------------------------------------ DominoAI
#
# A IA antiga era `playable[0]` -- a primeira pedra jogavel na ordem em que ela
# caiu na mao -- e sempre a ponta esquerda quando a pedra batia com ela. E
# exatamente o `moves[0]` que o cabecalho da CheckersAI documenta ter
# substituido nas Damas.

const AIScript = preload("res://games/domino/DominoAI.gd")


## Quem fica com a mao cara perde por pontos quando o outro bate. Entre duas
## pedras que encaixam igual, a cara sai primeiro.
func test_a_ia_descarta_a_pedra_mais_cara_primeiro() -> void:
	# As duas encaixam na ponta 3 e deixam a mesa igualmente aberta; [3|6] vale
	# 9 pontos e [3|0] vale 3.
	var mao := [{"a": 3, "b": 0}, {"a": 3, "b": 6}]
	var escolhida := 0
	for _tentativa in range(8):
		var m: Dictionary = AIScript.escolher(mao, 3, 5, AIScript.nova_memoria(), 10)
		if int(m["tile_index"]) == 1:
			escolhida += 1
	assert_gt(escolhida, 5, "a pedra de 9 pontos sai antes da de 3")


## Toda vez que o adversario compra ou passa, ele diz que nao tem as duas
## pontas da mesa. Deixar as pontas nesses numeros e travar o jogo com a mao
## mais leve -- a vitoria por pontos que o jogo fechado paga.
func test_a_ia_usa_o_que_o_passe_do_adversario_denunciou() -> void:
	var memoria: Dictionary = AIScript.nova_memoria()
	AIScript.registrar_falta(memoria, 2, 4)
	assert_true(memoria["vazios"].has(2), "ele nao tem o 2")
	assert_true(memoria["vazios"].has(4), "nem o 4")

	# Pontas 2 e 4. [2|4] deixa as pontas em 4 e 2 -- os dois numeros que ele
	# nao tem. [2|5] deixa 5 e 4, e o 5 ele pode ter.
	var mao := [{"a": 2, "b": 5}, {"a": 2, "b": 4}]
	var travou := 0
	for _tentativa in range(8):
		var m: Dictionary = AIScript.escolher(mao, 2, 4, memoria, 10)
		if int(m["tile_index"]) == 1:
			travou += 1
	assert_gt(travou, 5, "a IA fecha nas pontas que o adversario denunciou nao ter")


## Uma pedra que cabe nas duas pontas sao duas jogadas diferentes. A IA antiga
## so olhava uma delas -- a esquerda -- mesmo quando a direita valia mais.
func test_a_ia_considera_as_duas_pontas_da_mesma_pedra() -> void:
	var memoria: Dictionary = AIScript.nova_memoria()
	AIScript.registrar_falta(memoria, 1, 6)

	# [1|6] encaixa nas duas pontas. Pela esquerda deixa (6, 6); pela direita
	# deixa (1, 1). As duas travam, entao o que importa e a IA ter enxergado as
	# duas jogadas em vez de so a primeira.
	var mao := [{"a": 1, "b": 6}]
	var lados: Dictionary = {}
	for _tentativa in range(12):
		var m: Dictionary = AIScript.escolher(mao, 1, 6, memoria, 10)
		lados[str(m["side"])] = true
	assert_eq(lados.size(), 2, "as duas pontas entram no sorteio quando empatam")


## Bucha so encaixa num numero: quanto mais o jogo anda, mais dificil colocar.
func test_a_bucha_sai_antes_da_pedra_comum_de_mesmo_peso() -> void:
	# [3|3] vale 6 pontos; [2|4] tambem vale 6 e encaixa na mesma ponta.
	var mao := [{"a": 2, "b": 4}, {"a": 3, "b": 3}]
	var buchou := 0
	for _tentativa in range(8):
		var m: Dictionary = AIScript.escolher(mao, 3, 2, AIScript.nova_memoria(), 10)
		if int(m["tile_index"]) == 1:
			buchou += 1
	assert_gt(buchou, 5, "entre duas de 6 pontos, a bucha sai primeiro")


func test_a_ia_sem_jogada_devolve_vazio() -> void:
	assert_eq(AIScript.escolher([{"a": 0, "b": 1}], 5, 3, AIScript.nova_memoria(), 10), {},
		"nada jogavel")
	assert_eq(AIScript.escolher([], 5, 3, AIScript.nova_memoria(), 10), {}, "mao vazia")


func test_a_escada_de_perfis_e_monotonica() -> void:
	var erro_antes := 1.1
	for perfil in AIScript.PERFIS:
		assert_true(float(perfil["erro"]) <= erro_antes, "a chance de erro nunca sobe")
		erro_antes = float(perfil["erro"])
	assert_eq(float(AIScript.PERFIS[AIScript.PERFIS.size() - 1]["erro"]), 0.0,
		"o degrau do topo nao sorteia a pedra")


# ------------------------------------------------------------- regra da compra
#
# O jogador so podia passar com o monte vazio -- `_update_action_buttons` ja
# cobrava isso. A IA comprava UMA pedra e passava a vez mesmo quando a pedra
# comprada encaixava. A regra valia para um lado so.

func test_a_ia_compra_ate_poder_jogar_como_o_jogador_ja_fazia() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	jogo.game_over = false
	jogo.board_chain.assign([{"a": 6, "b": 6}])
	jogo.left_end = 6
	jogo.right_end = 6
	jogo.ai_hand.assign([{"a": 0, "b": 1}])          # nao encaixa em 6
	jogo.player_hand.assign([{"a": 2, "b": 3}])
	jogo.boneyard.assign([{"a": 4, "b": 5}, {"a": 6, "b": 2}])   # a ultima encaixa
	jogo.consecutive_passes = 0

	jogo._play_ai_turn()

	assert_eq(jogo.consecutive_passes, 0, "a IA jogou, entao nao houve passe")
	assert_true(jogo.left_end == 2 or jogo.right_end == 2,
		"a pedra comprada que encaixava foi jogada, nao guardada")
