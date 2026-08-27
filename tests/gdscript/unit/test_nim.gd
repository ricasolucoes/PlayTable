extends GutTest

const Rules = preload("res://games/nim/NimRules.gd")


# ------------------------------------------------------------------- NimRules

func test_inicializacao_de_presets() -> void:
	var c3 := Rules.create_heaps("classic_3")
	assert_eq(c3.size(), 3, "preset 3 pilhas")
	assert_eq(c3, [3, 4, 5], "quantidades [3, 4, 5]")
	
	var p4 := Rules.create_heaps("pyramid_4")
	assert_eq(p4.size(), 4, "preset piramide")
	assert_eq(p4, [1, 3, 5, 7], "quantidades [1, 3, 5, 7]")
	
	var s3 := Rules.create_heaps("simple_3")
	assert_eq(s3, [1, 2, 3], "preset simples [1, 2, 3]")


func test_calculo_do_nim_sum() -> void:
	# 3 ^ 4 ^ 5 = (011) ^ (100) ^ (101) = 010 (2)
	assert_eq(Rules.calculate_nim_sum([3, 4, 5]), 2, "3^4^5 = 2")
	# 1 ^ 2 ^ 3 = (001) ^ (010) ^ (011) = 000 (0 - P-position balanceada)
	assert_eq(Rules.calculate_nim_sum([1, 2, 3]), 0, "1^2^3 = 0")
	# 1 ^ 3 ^ 5 ^ 7 = 0
	assert_eq(Rules.calculate_nim_sum([1, 3, 5, 7]), 0, "1^3^5^7 = 0 (Marienbad inicial)")
	# 0 ^ 0 ^ 0 = 0
	assert_eq(Rules.calculate_nim_sum([0, 0, 0]), 0, "todas vazias = 0")


func test_validacao_de_jogadas_legais_e_ilegais() -> void:
	var heaps: Array[int] = [3, 4, 5]
	
	# Jogadas válidas
	assert_true(Rules.is_valid_move(heaps, 0, 1), "tirar 1 da pilha 0")
	assert_true(Rules.is_valid_move(heaps, 0, 3), "tirar 3 da pilha 0")
	assert_true(Rules.is_valid_move(heaps, 2, 5), "esvaziar pilha 2")
	
	# Jogadas inválidas
	assert_false(Rules.is_valid_move(heaps, 0, 0), "tirar 0 pecas e invalido")
	assert_false(Rules.is_valid_move(heaps, 0, -1), "tirar numero negativo e invalido")
	assert_false(Rules.is_valid_move(heaps, 0, 4), "tirar mais do que a pilha tem (4 > 3)")
	assert_false(Rules.is_valid_move(heaps, -1, 1), "indice de pilha negativo")
	assert_false(Rules.is_valid_move(heaps, 3, 1), "indice de pilha fora do limite")


func test_aplicacao_de_jogadas_e_undo() -> void:
	var heaps: Array[int] = [3, 4, 5]
	
	# apply_move (cópia)
	var next_heaps := Rules.apply_move(heaps, 1, 2)
	assert_eq(heaps, [3, 4, 5], "original inalterado")
	assert_eq(next_heaps, [3, 2, 5], "nova copia com 2 tirados da pilha 1")
	
	# apply_move_inplace & undo_move_inplace
	Rules.apply_move_inplace(heaps, 2, 3)
	assert_eq(heaps, [3, 4, 2], "modificado in-place")
	Rules.undo_move_inplace(heaps, 2, 3)
	assert_eq(heaps, [3, 4, 5], "restaurado com undo")


func test_fim_de_jogo_e_vencedor_modo_normal() -> void:
	assert_false(Rules.is_game_over([0, 1, 0]), "1 peca restante nao e fim")
	assert_true(Rules.is_game_over([0, 0, 0]), "todas zeradas e fim de jogo")
	
	# No modo normal, quem fez a última jogada vence
	assert_eq(Rules.get_winner(1, false), 1, "jogador 1 pegou a ultima e venceu")
	assert_eq(Rules.get_winner(2, false), 2, "jogador 2 pegou a ultima e venceu")


func test_fim_de_jogo_e_vencedor_modo_misere() -> void:
	# No modo misère, quem fez a última jogada perde (o outro vence)
	assert_eq(Rules.get_winner(1, true), 2, "jogador 1 pegou a ultima e perdeu (2 venceu)")
	assert_eq(Rules.get_winner(2, true), 1, "jogador 2 pegou a ultima e perdeu (1 venceu)")


func test_ia_estrategia_otima_nim_sum_normal() -> void:
	# Posição: [3, 4, 5] -> Nim-Sum = 2 (010).
	# A jogada ótima na pilha 0 (3): 3 ^ 2 = 1 -> tirar 3 - 1 = 2 peças.
	# Novo estado: [1, 4, 5], Nim-Sum = 1 ^ 4 ^ 5 = 0!
	var move := Rules.get_best_ai_move([3, 4, 5], false, "hard")
	assert_eq(move["heap"], 0, "IA escolhe pilha 0")
	assert_eq(move["take"], 2, "IA retira 2 pecas para deixar Nim-Sum = 0")
	
	var resulting_heaps := Rules.apply_move([3, 4, 5], move["heap"], move["take"])
	assert_eq(Rules.calculate_nim_sum(resulting_heaps), 0, "posicao resultante tem Nim-Sum = 0")


func test_ia_estrategia_misere_fase_final_deixa_impar_de_uns() -> void:
	# Posição no Misère: [1, 1, 3] (duas pilhas de 1 e uma grande de 3)
	# Queremos deixar um número ímpar de '1's.
	# Como já temos 2 pilhas de '1', queremos deixar 3 pilhas de '1' (ou seja, reduzir a de 3 para 1, tirando 2).
	# Sobram [1, 1, 1] (total 3 uns). O oponente pega 1, sobram [1, 1], pegamos 1, sobra [1], oponente pega o ultimo e perde!
	var move := Rules.get_best_ai_move([1, 1, 3], true, "hard")
	assert_eq(move["heap"], 2, "IA escolhe a pilha grande")
	assert_eq(move["take"], 2, "IA reduz para 1 peca deixando 3 pilhas de 1")
	
	var res := Rules.apply_move([1, 1, 3], move["heap"], move["take"])
	assert_eq(res, [1, 1, 1], "resultado e [1, 1, 1]")
	
	# Outra posição no Misère: [1, 5] (uma pilha de 1 e uma de 5)
	# Como já temos 1 pilha de '1' (ímpar), queremos esvaziar a de 5 para sobrar apenas 1 pilha de 1!
	var move2 := Rules.get_best_ai_move([1, 5], true, "hard")
	assert_eq(move2["heap"], 1, "IA escolhe a pilha de 5")
	assert_eq(move2["take"], 5, "IA esvazia a pilha de 5 deixando [1, 0]")
	var res2 := Rules.apply_move([1, 5], move2["heap"], move2["take"])
	assert_eq(res2, [1, 0], "resultado e [1, 0]")


func test_partida_completa_ia_contra_si_mesma_termina() -> void:
	var heaps := Rules.create_heaps("classic_3")
	var current_player: int = 1
	var turns: int = 0
	
	while not Rules.is_game_over(heaps) and turns < 50:
		var move := Rules.get_best_ai_move(heaps, true, "hard")
		assert_true(Rules.is_valid_move(heaps, move["heap"], move["take"]), "jogada valida")
		Rules.apply_move_inplace(heaps, move["heap"], move["take"])
		current_player = 3 - current_player
		turns += 1
		
	assert_true(Rules.is_game_over(heaps), "partida terminou com tabuleiro vazio")
	assert_gt(turns, 0, "partida teve jogadas")


# --------------------------------------------------------------------- NimGame
const GameScene = preload("res://games/nim/NimGame.tscn")


func test_cena_inicializa_mesa_3d_e_botoes() -> void:
	var jogo: Node = add_child_autofree(GameScene.instantiate())
	assert_true(jogo is BaseGame, "NimGame herda BaseGame")
	assert_eq(jogo.heaps, [3, 4, 5], "preset padrao [3, 4, 5]")
	assert_eq(jogo.heap_roots.size(), 3, "3 pilhas 3D no tabuleiro")
	assert_eq(jogo.piece_nodes.size(), 3, "3 arrays de pecas 3D")
	assert_eq(jogo.piece_nodes[0].size(), 3, "3 pecas na pilha 0")
	assert_eq(jogo.piece_nodes[1].size(), 4, "4 pecas na pilha 1")
	assert_eq(jogo.piece_nodes[2].size(), 5, "5 pecas na pilha 2")
	assert_false(jogo.game_over, "partida comeca aberta")
	assert_eq(jogo.turn_count, 0, "zero turnos no inicio")


func test_cena_selecao_de_pilha_e_quantidade() -> void:
	var jogo: Node = add_child_autofree(GameScene.instantiate())
	jogo._on_heap_selected(1)
	assert_eq(jogo.selected_heap, 1, "pilha 1 selecionada")
	assert_true(jogo.take_controls_container.visible, "controles de quantidade visiveis")
	
	jogo._set_take_count(3)
	assert_eq(jogo.selected_take_count, 3, "quantidade 3 selecionada")


func test_cena_execucao_de_jogada() -> void:
	var jogo: Node = add_child_autofree(GameScene.instantiate())
	jogo._on_heap_selected(0)
	jogo._set_take_count(2)
	jogo._on_btn_confirm_move_pressed()
	
	assert_eq(jogo.heaps[0], 1, "pilha 0 ficou com 1 peca")
	assert_eq(jogo.turn_count, 1, "1 turno computado")
	assert_eq(jogo.move_history.size(), 1, "1 jogada no historico")


func test_cena_desfazer_jogada() -> void:
	var jogo: Node = add_child_autofree(GameScene.instantiate())
	jogo.is_vs_ai = false # modo 2 jogadores para teste simples de 1 passo de undo
	jogo._on_heap_selected(0)
	jogo._set_take_count(2)
	jogo._on_btn_confirm_move_pressed()
	assert_eq(jogo.heaps[0], 1, "pilha 0 com 1 peca")
	
	jogo.is_animating = false
	jogo._on_btn_undo_pressed()
	assert_eq(jogo.heaps[0], 3, "pilha 0 restaurada para 3 pecas")
	assert_eq(jogo.turn_count, 0, "turnos voltaram a 0")


func test_cena_troca_de_preset() -> void:
	var jogo: Node = add_child_autofree(GameScene.instantiate())
	jogo._on_preset_selected("pyramid_4")
	assert_eq(jogo.preset_name, "pyramid_4", "preset piramide")
	assert_eq(jogo.heaps, [1, 3, 5, 7], "pilhas [1, 3, 5, 7]")
	assert_eq(jogo.heap_roots.size(), 4, "4 pilhas 3D")


func test_cena_troca_de_regra_misere_normal() -> void:
	var jogo: Node = add_child_autofree(GameScene.instantiate())
	assert_true(jogo.is_misere, "comeca no misere por padrao")
	jogo._on_btn_rule_toggle_pressed()
	assert_false(jogo.is_misere, "mudou para regra normal")



# ------------------------------------------------- escada de dificuldade
#
# O Nim andava por tres botoes -- Facil (30%), Medio (75%), Mestre (100%) --
# num campo proprio que nascia sempre em "Mestre" e sumia ao fechar a cena,
# enquanto a escada do DifficultyManager andava em paralelo mexendo so no XP.

func test_a_chance_otima_cresce_a_cada_degrau() -> void:
	assert_eq(Rules.CHANCE_OTIMA.size(), DifficultyManager.MAX_LEVEL,
		"uma chance por degrau da escada")
	var antes := -1.0
	for chance in Rules.CHANCE_OTIMA:
		assert_gt(float(chance), antes, "a chance de acertar cresce a cada degrau")
		antes = float(chance)
	assert_eq(float(Rules.CHANCE_OTIMA[Rules.CHANCE_OTIMA.size() - 1]), 1.0,
		"o degrau do topo joga sempre a jogada perfeita")


func test_o_degrau_do_topo_joga_sempre_a_jogada_de_bouton() -> void:
	# [1, 2, 3] no normal tem Nim-Sum 0; [1, 2, 4] nao, e a jogada otima leva a
	# pilha de 4 para 3.
	var heaps := [1, 2, 4]
	for _tentativa in range(10):
		var m: Dictionary = Rules.get_move(heaps, false, 10)
		assert_eq(int(m["heap"]), 2, "mexe na pilha de 4")
		assert_eq(int(m["take"]), 1, "deixando 3, com Nim-Sum zero")


func test_todo_degrau_devolve_jogada_legal() -> void:
	var heaps := [1, 3, 5, 7]
	for nivel in range(1, DifficultyManager.MAX_LEVEL + 1):
		for _tentativa in range(6):
			var m: Dictionary = Rules.get_move(heaps, true, nivel)
			var h: int = int(m["heap"])
			assert_true(h >= 0 and h < heaps.size(), "degrau %d mira pilha que existe" % nivel)
			assert_true(int(m["take"]) >= 1 and int(m["take"]) <= int(heaps[h]),
				"degrau %d tira entre 1 e o que a pilha tem" % nivel)
