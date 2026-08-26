extends GutTest

## Testes unitários para as regras e algoritmos de Torres de Hanói (HanoiRules)

const Rules = preload("res://games/hanoi/HanoiRules.gd")


func test_inicializacao_de_pinos_com_3_a_8_discos() -> void:
	for count in range(3, 9):
		var pegs := Rules.create_initial_pegs(count)
		assert_eq(pegs.size(), 3, "3 pinos no total")
		assert_eq(pegs[0].size(), count, "%d discos no pino de origem" % count)
		assert_eq(pegs[1].size(), 0, "pino auxiliar vazio")
		assert_eq(pegs[2].size(), 0, "pino destino vazio")
		
		# Verifica ordem decrescente (base maior, topo menor)
		assert_eq(pegs[0][0], count, "base e o disco maior (%d)" % count)
		assert_eq(pegs[0][pegs[0].size() - 1], 1, "topo e o disco menor (1)")


func test_topo_de_pino_vazio_e_ocupado() -> void:
	var pegs := Rules.create_initial_pegs(3)
	assert_eq(Rules.get_top_disk(pegs[0]), 1, "topo do pino 0 e 1")
	assert_eq(Rules.get_top_disk(pegs[1]), 0, "pino 1 vazio retorna 0")
	assert_eq(Rules.get_top_disk(pegs[2]), 0, "pino 2 vazio retorna 0")


func test_valida_movimento_permitido_e_rejeita_movimento_invalido() -> void:
	var pegs := Rules.create_initial_pegs(3)
	# Mover disco 1 (menor) do pino 0 para pino 1 vazio -> PERMITIDO
	assert_true(Rules.can_move_disk(pegs, 0, 1), "mover disco 1 para pino vazio e valido")
	# Mover de pino 1 vazio para pino 2 -> INVÁLIDO
	assert_false(Rules.can_move_disk(pegs, 1, 2), "pino origem vazio e invalido")
	# Mover de pino 0 para pino 0 (mesmo pino) -> INVÁLIDO
	assert_false(Rules.can_move_disk(pegs, 0, 0), "mesmo pino e invalido")
	# Índice fora dos limites -> INVÁLIDO
	assert_false(Rules.can_move_disk(pegs, -1, 2), "indice negativo e invalido")
	assert_false(Rules.can_move_disk(pegs, 0, 3), "indice 3 e invalido")


func test_rejeita_disco_maior_sobre_disco_menor() -> void:
	var pegs := Rules.create_initial_pegs(3)
	# Move disco 1 de 0 para 1
	var res1 := Rules.execute_move(pegs, 0, 1)
	assert_true(res1["success"], "moveu disco 1 para pino 1")
	
	# Agora o topo do pino 0 e o disco 2, e o topo do pino 1 e o disco 1
	# Tentar mover disco 2 sobre disco 1 -> DEVE SER REJEITADO
	assert_false(Rules.can_move_disk(pegs, 0, 1), "disco 2 nao pode ficar sobre disco 1")
	var res2 := Rules.execute_move(pegs, 0, 1)
	assert_false(res2["success"], "execucao rejeitada")


func test_execucao_de_movimento_e_desfazer() -> void:
	var pegs := Rules.create_initial_pegs(4)
	var res := Rules.execute_move(pegs, 0, 2)
	assert_true(res["success"], "movimento executado")
	assert_eq(res["disk"], 1, "disco 1 movido")
	assert_eq(pegs[0].size(), 3, "pino 0 ficou com 3 discos")
	assert_eq(pegs[2].size(), 1, "pino 2 ficou com 1 disco")
	assert_eq(Rules.get_top_disk(pegs[2]), 1, "topo do pino 2 e 1")
	
	# Desfazer movimento
	var undo_res := Rules.undo_move(pegs, res)
	assert_true(undo_res, "undo bem sucedido")
	assert_eq(pegs[0].size(), 4, "pino 0 restaurado com 4 discos")
	assert_eq(pegs[2].size(), 0, "pino 2 restaurado vazio")
	assert_eq(Rules.get_top_disk(pegs[0]), 1, "topo do pino 0 e 1 novamente")


func test_calculo_de_movimentos_otimos() -> void:
	assert_eq(Rules.get_optimal_moves(3), 7, "3 discos -> 7 jogadas")
	assert_eq(Rules.get_optimal_moves(4), 15, "4 discos -> 15 jogadas")
	assert_eq(Rules.get_optimal_moves(5), 31, "5 discos -> 31 jogadas")
	assert_eq(Rules.get_optimal_moves(6), 63, "6 discos -> 63 jogadas")
	assert_eq(Rules.get_optimal_moves(7), 127, "7 discos -> 127 jogadas")
	assert_eq(Rules.get_optimal_moves(8), 255, "8 discos -> 255 jogadas")


func test_estrelas_calculo() -> void:
	# Para 3 discos (otimo = 7)
	assert_eq(Rules.calculate_stars(7, 3), 3, "7 jogadas com 3 discos = 3 estrelas")
	assert_eq(Rules.calculate_stars(9, 3), 2, "9 jogadas com 3 discos = 2 estrelas")
	assert_eq(Rules.calculate_stars(20, 3), 1, "20 jogadas com 3 discos = 1 estrela")


func test_solucao_recursiva_otima_resolve_com_exatamente_2n_menos_1_passos() -> void:
	for count in range(3, 7):
		var solution := Rules.generate_optimal_solution(count, 0, 2, 1)
		var optimal := Rules.get_optimal_moves(count)
		assert_eq(solution.size(), optimal, "solucao para %d discos tem exatamente %d passos" % [count, optimal])
		
		# Simula a aplicacao passo a passo
		var pegs := Rules.create_initial_pegs(count)
		for step in solution:
			var f: int = step["from"]
			var t: int = step["to"]
			assert_true(Rules.can_move_disk(pegs, f, t), "passo valido na solucao: %d -> %d" % [f, t])
			Rules.execute_move(pegs, f, t)
			
		assert_true(Rules.is_won(pegs, count, 2), "tabuleiro final e vitorioso")
		assert_eq(pegs[0].size(), 0, "pino origem vazio no final")
		assert_eq(pegs[1].size(), 0, "pino auxiliar vazio no final")
		assert_eq(pegs[2].size(), count, "todos os discos no pino destino")


func test_dica_encontra_o_proximo_passo_valido() -> void:
	var pegs := Rules.create_initial_pegs(3)
	var hint := Rules.get_next_hint(pegs, 3, 2)
	assert_false(hint.is_empty(), "dica encontrada")
	assert_true(Rules.can_move_disk(pegs, hint["from"], hint["to"]), "dica e uma jogada valida")


# ------------------------------------------------------------------- HanoiGame
const GameScene = preload("res://games/hanoi/HanoiGame.tscn")


func test_cena_monta_estrutura_3d_inicial() -> void:
	var jogo: Node = add_child_autofree(GameScene.instantiate())
	assert_true(jogo is BaseGame, "HanoiGame herda BaseGame")
	assert_eq(jogo.pegs.size(), 3, "3 pinos no tabuleiro")
	assert_eq(jogo.pegs[0].size(), 3, "3 discos no pino A por padrao")
	assert_eq(jogo.disk_nodes.size(), 3, "3 malhas 3D de discos criadas")
	assert_false(jogo.game_over, "partida comeca aberta")
	assert_eq(jogo.move_count, 0, "zero jogadas no inicio")


func test_cena_selecao_e_movimento_de_disco() -> void:
	var jogo: Node = add_child_autofree(GameScene.instantiate())
	# Toque no pino 0 (Origem) -> Ergue disco
	jogo._on_peg_pressed(0)
	assert_eq(jogo.selected_peg, 0, "pino 0 selecionado")
	assert_not_null(jogo.selected_disk_node, "no 3D do disco erguido")
	
	# Toque no pino 2 (Destino) -> Move disco
	jogo._on_peg_pressed(2)
	assert_eq(jogo.selected_peg, -1, "selecao limpa apos jogada")
	assert_eq(jogo.pegs[0].size(), 2, "pino 0 ficou com 2 discos")
	assert_eq(jogo.pegs[2].size(), 1, "pino 2 recebeu 1 disco")
	assert_eq(jogo.move_count, 1, "1 jogada contabilizada")


func test_cena_rejeita_movimento_invalido() -> void:
	var jogo: Node = add_child_autofree(GameScene.instantiate())
	# Move disco 1 para pino 1
	jogo._on_peg_pressed(0)
	jogo._on_peg_pressed(1)
	assert_eq(jogo.pegs[1].size(), 1, "disco 1 no pino 1")
	
	# Tenta mover disco 2 para pino 1 (sobre disco 1) -> Rejeitado
	jogo._on_peg_pressed(0)
	jogo._on_peg_pressed(1)
	assert_eq(jogo.pegs[0].size(), 2, "disco 2 permaneceu no pino 0")
	assert_eq(jogo.pegs[1].size(), 1, "pino 1 inalterado")


func test_cena_desfazer_movimento() -> void:
	var jogo: Node = add_child_autofree(GameScene.instantiate())
	jogo._on_peg_pressed(0)
	jogo._on_peg_pressed(2)
	assert_eq(jogo.move_count, 1, "1 jogada feita")
	
	jogo.is_animating = false
	jogo._on_btn_undo_pressed()
	assert_eq(jogo.move_count, 0, "jogadas voltaram a 0")
	assert_eq(jogo.pegs[0].size(), 3, "3 discos restaurados no pino 0")
	assert_eq(jogo.pegs[2].size(), 0, "pino 2 esvaziado")


func test_cena_troca_de_dificuldade() -> void:
	var jogo: Node = add_child_autofree(GameScene.instantiate())
	jogo._on_difficulty_selected(5)
	assert_eq(jogo.disk_count, 5, "5 discos configurados")
	assert_eq(jogo.pegs[0].size(), 5, "5 discos no pino 0")
	assert_eq(jogo.disk_nodes.size(), 5, "5 malhas 3D criadas")

