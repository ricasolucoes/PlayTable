extends GutTest

## Jogo da Memoria — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_card_games.py::TestMemoryGame.

const RulesScript = preload("res://games/memoria/MemoryRules.gd")
const GameScene = preload("res://games/memoria/MemoryGame.tscn")

func before_each() -> void:
	# Cada teste começa na abertura atual, sem depender do save local do jogador.
	DifficultyManager.set_level("memoria", DifficultyManager.DEFAULT_LEVEL)

# ---------------------------------------------------------------- MemoryRules

## MemoryRules falava de Card e de custom_data["pair_id"], um modelo que
## MemoryGame nunca usou -- a cena monta Control com symbol_type: int. A regra
## passou a falar o modelo do jogo, e estes testes batem no que a partida chama.

func test_simbolos_iguais_formam_par() -> void:
	assert_true(RulesScript.symbols_match(3, 3), "mesmo simbolo")
	assert_false(RulesScript.symbols_match(3, 4), "simbolos diferentes")

func test_partida_vence_quando_todos_os_pares_sairam() -> void:
	assert_true(RulesScript.is_game_won(8, 8), "8 de 8 vence")
	assert_false(RulesScript.is_game_won(7, 8), "faltando um par nao vence")

func test_contagem_acima_do_total_ainda_vence() -> void:
	# MemoryGame comparava com ==; um par contado duas vezes deixaria a partida
	# sem fim. A regra usa >=.
	assert_true(RulesScript.is_game_won(9, 8), "passou do total, venceu igual")

func test_total_zero_nao_vence() -> void:
	assert_false(RulesScript.is_game_won(0, 0), "sem pares nao ha partida ganha")

func test_total_padrao_e_o_da_partida() -> void:
	assert_eq(RulesScript.TOTAL_PAIRS, 8, "oito pares por partida")
	assert_true(RulesScript.is_game_won(8), "o total padrao vale sem passar o segundo argumento")

func test_niveis_aumentam_cartas_e_fileiras() -> void:
	var anterior := RulesScript.board_size_for_level(3)
	for nivel in range(4, DifficultyManager.MAX_LEVEL + 1):
		var atual := RulesScript.board_size_for_level(nivel)
		assert_true(atual.x * atual.y > anterior.x * anterior.y, "nivel %d tem mais cartas" % nivel)
		assert_true(atual.y >= anterior.y, "nivel %d nao reduz fileiras" % nivel)
		anterior = atual

func test_baralho_da_proxima_vitoria_fica_maior() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	var nivel: int = int(jogo.difficulty_level)
	var cartas_atuais: int = jogo.cards.size()
	var fileiras_atuais: int = jogo.cards.size() / jogo.grid_container.columns
	jogo._handle_game_won()
	var proximo = add_child_autofree(GameScene.instantiate())
	assert_eq(DifficultyManager.get_level("memoria"), nivel + 1, "vitoria sobe a dificuldade")
	assert_true(proximo.cards.size() > cartas_atuais, "proxima partida tem mais cartas")
	assert_true(proximo.cards.size() / proximo.grid_container.columns >= fileiras_atuais,
		"proxima partida nao reduz fileiras")

func test_nivel_maximo_monta_os_28_pares_e_os_simbolos_novos() -> void:
	DifficultyManager.set_level("memoria", DifficultyManager.MAX_LEVEL)
	var jogo = add_child_autofree(GameScene.instantiate())
	assert_eq(jogo.cards.size(), 56, "nivel maximo tem 56 cartas")
	assert_eq(jogo.TOTAL_PAIRS, 28, "nivel maximo tem 28 pares")
	assert_eq(jogo.grid_container.columns, 7, "nivel maximo tem 7 colunas")
	var simbolos := {}
	for carta in jogo.cards:
		simbolos[carta.symbol_type] = simbolos.get(carta.symbol_type, 0) + 1
	assert_eq(simbolos.size(), 28, "nivel maximo tem 28 simbolos distintos")
	for simbolo in simbolos:
		assert_eq(simbolos[simbolo], 2, "simbolo %s aparece 2 vezes" % str(simbolo))
	# Renderiza um simbolo adicional para cobrir o caminho de desenho dos novos
	# pares, e nao apenas a montagem do baralho.
	for carta in jogo.cards:
		if int(carta.symbol_type) >= 8:
			carta.is_face_up = true
			break
	await wait_process_frames(2)

func test_classificacao_local_compara_os_pares_de_cada_jogador() -> void:
	assert_eq(RulesScript.winner_for_scores(4, 2), 1, "Jogador 1 tem mais pares")
	assert_eq(RulesScript.winner_for_scores(2, 4), 2, "Jogador 2 tem mais pares")
	assert_eq(RulesScript.winner_for_scores(3, 3), 0, "mesmo numero de pares e empate")

# ----------------------------------------------------------------- MemoryGame

func test_baralho_tem_16_cartas_em_8_pares() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	assert_eq(jogo.cards.size(), 16, "16 cartas na mesa")
	assert_eq(jogo.TOTAL_PAIRS, 8, "8 pares")
	var contagem := {}
	for carta in jogo.cards:
		var s: int = carta.symbol_type
		contagem[s] = contagem.get(s, 0) + 1
	assert_eq(contagem.size(), 8, "8 simbolos distintos")
	for simbolo in contagem:
		assert_eq(contagem[simbolo], 2, "simbolo %s aparece 2 vezes" % str(simbolo))

func test_todas_as_cartas_comecam_viradas_para_baixo() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	for carta in jogo.cards:
		assert_false(carta.is_face_up, "carta fechada")
		assert_false(carta.is_matched, "carta ainda nao casada")

func test_partida_comeca_zerada() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	assert_eq(jogo.pairs_found, 0, "nenhum par")
	assert_eq(jogo.moves_count, 0, "nenhuma jogada")
	assert_false(jogo.game_over, "partida aberta")
	assert_null(jogo.first_card, "nenhuma carta selecionada")

func test_primeira_carta_clicada_vira_a_selecionada() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	jogo._on_card_clicked(jogo.cards[0])
	assert_eq(jogo.first_card, jogo.cards[0], "primeira carta guardada")
	assert_eq(jogo.moves_count, 0, "jogada so conta no par")

func test_modo_local_mostra_placar_dos_dois_jogadores() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	jogo.is_local_multiplayer = true
	jogo._start_new_game()
	assert_eq(jogo.current_player, 1, "Jogador 1 começa")
	assert_eq(jogo.player_one_pairs, 0, "placar do Jogador 1 zerado")
	assert_eq(jogo.player_two_pairs, 0, "placar do Jogador 2 zerado")


func test_modo_local_passa_a_vez_depois_de_um_par_errado() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	jogo.is_local_multiplayer = true
	jogo._start_new_game()
	var duas := _diferentes_de(jogo)
	jogo._on_card_clicked(duas[0])
	jogo._on_card_clicked(duas[1])
	await wait_seconds(1.2)
	assert_eq(jogo.current_player, 2, "erro passa a vez ao Jogador 2")
	assert_eq(jogo.player_one_pairs, 0, "erro não pontua")

func test_clicar_duas_vezes_na_mesma_carta_e_ignorado() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	jogo._on_card_clicked(jogo.cards[0])
	jogo._on_card_clicked(jogo.cards[0])
	assert_null(jogo.second_card, "nao virou par consigo mesma")
	assert_eq(jogo.moves_count, 0, "nenhuma jogada contada")

func _par_de(jogo) -> Array:
	# Devolve duas cartas com o mesmo simbolo.
	for i in range(jogo.cards.size()):
		for j in range(i + 1, jogo.cards.size()):
			if jogo.cards[i].symbol_type == jogo.cards[j].symbol_type:
				return [jogo.cards[i], jogo.cards[j]]
	return []

func _diferentes_de(jogo) -> Array:
	for i in range(jogo.cards.size()):
		for j in range(i + 1, jogo.cards.size()):
			if jogo.cards[i].symbol_type != jogo.cards[j].symbol_type:
				return [jogo.cards[i], jogo.cards[j]]
	return []

func test_par_correto_conta_ponto() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	var par := _par_de(jogo)
	assert_eq(par.size(), 2, "achou um par no baralho")
	jogo._on_card_clicked(par[0])
	jogo._on_card_clicked(par[1])
	assert_eq(jogo.pairs_found, 1, "1 par encontrado")
	assert_eq(jogo.moves_count, 1, "1 jogada contada")

func test_par_errado_nao_conta_ponto() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	var duas := _diferentes_de(jogo)
	assert_eq(duas.size(), 2, "achou duas cartas diferentes")
	jogo._on_card_clicked(duas[0])
	jogo._on_card_clicked(duas[1])
	assert_eq(jogo.pairs_found, 0, "nenhum par")
	assert_eq(jogo.moves_count, 1, "a jogada conta mesmo errando")
	assert_true(jogo.is_checking, "o jogo trava a mesa enquanto mostra o erro")

func test_reiniciar_zera_a_partida() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	var par := _par_de(jogo)
	jogo._on_card_clicked(par[0])
	jogo._on_card_clicked(par[1])
	jogo._start_new_game()
	assert_eq(jogo.pairs_found, 0, "pares zerados")
	assert_eq(jogo.moves_count, 0, "jogadas zeradas")
	assert_false(jogo.game_over, "partida reaberta")

func test_partida_completa_encontra_os_oito_pares() -> void:
	# Guarda contra deadlock: substitui test_e2e_memory_game_simulation.
	var jogo = add_child_autofree(GameScene.instantiate())
	var por_simbolo := {}
	for carta in jogo.cards:
		var s: int = carta.symbol_type
		if not por_simbolo.has(s):
			por_simbolo[s] = []
		por_simbolo[s].append(carta)
	for simbolo in por_simbolo:
		var duas: Array = por_simbolo[simbolo]
		jogo._on_card_clicked(duas[0])
		jogo._on_card_clicked(duas[1])
		# _check_match espera a animacao antes de liberar a mesa; sem esperar
		# junto, o clique seguinte cai no guarda is_checking.
		await wait_seconds(0.3)
	assert_eq(jogo.pairs_found, jogo.TOTAL_PAIRS, "todos os pares encontrados")
	assert_eq(jogo.moves_count, 8, "8 jogadas, uma por par")
	assert_true(RulesScript.is_game_won(jogo.pairs_found, jogo.TOTAL_PAIRS), "condicao de vitoria")
