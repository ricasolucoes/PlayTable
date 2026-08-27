extends GutTest

## Resta Um — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestPegSolitaire.

const RulesScript = preload("res://games/solitario/PegSolitaireRules.gd")

const FORA := -1
const VAZIO := 0
const PINO := 1


# ------------------------------------------------------------ PegSolitaireRules

func test_cruz_inglesa_tem_33_casas() -> void:
	var validas := 0
	for r in range(7):
		for c in range(7):
			if RulesScript.is_valid_hole(r, c):
				validas += 1
	assert_eq(validas, 33, "33 furos na cruz")


func test_quinas_ficam_fora_do_tabuleiro() -> void:
	for r in [0, 1, 5, 6]:
		for c in [0, 1, 5, 6]:
			assert_false(RulesScript.is_valid_hole(r, c), "quina (%d,%d) fora" % [r, c])


func test_fora_dos_limites_nao_e_furo() -> void:
	for pos in [[-1, 3], [7, 3], [3, -1], [3, 7]]:
		assert_false(RulesScript.is_valid_hole(pos[0], pos[1]), "%s fora" % str(pos))


func test_tabuleiro_inicial_tem_32_pinos_e_um_furo_no_centro() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	assert_eq(g.count_matching(PINO), 32, "32 pinos")
	assert_eq(g.count_matching(VAZIO), 1, "1 casa vazia")
	assert_eq(g.count_matching(FORA), 16, "16 celulas fora (4 quinas de 4)")
	assert_eq(g.get_cell(3, 3), VAZIO, "o furo vazio e o centro")


func test_posicao_inicial_tem_exatamente_quatro_saltos() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	assert_eq(RulesScript.count_total_moves(g), 4, "4 saltos para o centro")
	assert_true(RulesScript.has_any_valid_moves(g), "ha jogadas")


func test_salto_reduz_um_pino() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	var moves: Array[Dictionary] = RulesScript.get_valid_moves_for_peg(g, Vector2i(1, 3))
	assert_eq(moves.size(), 1, "o pino em (1,3) tem um salto")
	var m := moves[0]
	assert_eq(m["over"], Vector2i(2, 3), "pula por cima de (2,3)")
	assert_eq(m["land"], Vector2i(3, 3), "aterrissa no centro")
	RulesScript.execute_jump(g, m["from"], m["over"], m["land"])
	assert_eq(RulesScript.count_pegs(g), 31, "31 pinos apos o salto")
	assert_eq(g.get_cell(1, 3), VAZIO, "origem esvaziada")
	assert_eq(g.get_cell(2, 3), VAZIO, "pino saltado removido")
	assert_eq(g.get_cell(3, 3), PINO, "destino ocupado")


func test_casa_vazia_nao_gera_salto() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	assert_eq(RulesScript.get_valid_moves_for_peg(g, Vector2i(3, 3)), [] as Array[Dictionary])


func test_salto_precisa_de_pino_no_meio_e_furo_no_destino() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	# (0,2) tem vizinhos ocupados dos dois lados: nenhum destino livre.
	assert_eq(RulesScript.get_valid_moves_for_peg(g, Vector2i(0, 2)), [] as Array[Dictionary])


func test_salto_nao_atravessa_as_quinas() -> void:
	var g := Grid2D.new(7, 7, FORA)
	for r in range(7):
		for c in range(7):
			if RulesScript.is_valid_hole(r, c):
				g.set_cell(r, c, VAZIO)
	# Pino em (1,3) saltando para a esquerda aterrissaria em (1,1), que e
	# quina e nao pertence a cruz.
	g.set_cell(1, 3, PINO)
	g.set_cell(1, 2, PINO)
	assert_eq(RulesScript.get_valid_moves_for_peg(g, Vector2i(1, 3)), [] as Array[Dictionary],
		"(1,1) esta fora da cruz")


func test_saltos_sao_apenas_ortogonais() -> void:
	var g := Grid2D.new(7, 7, FORA)
	for r in range(7):
		for c in range(7):
			if RulesScript.is_valid_hole(r, c):
				g.set_cell(r, c, VAZIO)
	g.set_cell(2, 2, PINO)
	g.set_cell(3, 3, PINO)  # vizinho diagonal
	assert_eq(RulesScript.get_valid_moves_for_peg(g, Vector2i(2, 2)), [] as Array[Dictionary],
		"nao ha salto na diagonal")


func test_fim_de_jogo_quando_nao_sobra_salto() -> void:
	var g := Grid2D.new(7, 7, FORA)
	for r in range(7):
		for c in range(7):
			if RulesScript.is_valid_hole(r, c):
				g.set_cell(r, c, VAZIO)
	g.set_cell(3, 3, PINO)
	assert_eq(RulesScript.count_pegs(g), 1, "sobrou um pino")
	assert_false(RulesScript.has_any_valid_moves(g), "sem saltos")
	assert_eq(RulesScript.count_total_moves(g), 0, "zero saltos")


func test_partida_completa_nao_trava() -> void:
	# Guarda contra deadlock: substitui test_e2e_peg_solitaire_simulation.
	var g: Grid2D = RulesScript.create_initial_board()
	var saltos := 0
	while RulesScript.has_any_valid_moves(g):
		var escolhido := {}
		for r in range(7):
			for c in range(7):
				if escolhido.is_empty() and g.get_cell(r, c) == PINO:
					var moves: Array[Dictionary] = RulesScript.get_valid_moves_for_peg(g, Vector2i(r, c))
					if not moves.is_empty():
						escolhido = moves[0]
		assert_false(escolhido.is_empty(), "has_any_valid_moves prometeu um salto")
		RulesScript.execute_jump(g, escolhido["from"], escolhido["over"], escolhido["land"])
		saltos += 1
		assert_true(saltos <= 31, "no maximo 31 saltos")
	assert_eq(RulesScript.count_pegs(g), 32 - saltos, "cada salto tira um pino")
	assert_true(RulesScript.count_pegs(g) < 32, "a partida progrediu")


# ------------------------------------------------------------- PegSolitaireGame

const GameScene = preload("res://games/solitario/PegSolitaireGame.tscn")


func test_cena_monta_o_tabuleiro_inicial() -> void:
	var jogo = add_child_autofree(GameScene.instantiate())
	assert_eq(RulesScript.count_pegs(jogo.grid_data), 32, "32 esferas na mesa")
	assert_eq(jogo.marbles_3d.size(), 32, "32 esferas desenhadas")
	assert_false(jogo.game_over, "partida aberta")


func test_cena_executa_o_salto_removendo_a_esfera_saltada() -> void:
	# Duas batidas continuam valendo, agora pelo mesmo caminho do arrasto.
	var jogo = add_child_autofree(GameScene.instantiate())
	await wait_process_frames(2)
	jogo._begin_press(jogo._cell_screen[Vector2i(1, 3)])
	assert_eq(jogo.selected_pos, Vector2i(1, 3), "esfera selecionada")
	assert_eq(jogo.valid_targets.size(), 1, "um destino possivel")
	jogo._end_press(jogo._cell_screen[Vector2i(1, 3)])
	jogo._begin_press(jogo._cell_screen[Vector2i(3, 3)])
	assert_eq(jogo.grid_data.get_cell(1, 3), VAZIO, "origem esvaziada")
	assert_eq(jogo.grid_data.get_cell(2, 3), VAZIO, "esfera saltada removida")
	assert_eq(jogo.grid_data.get_cell(3, 3), PINO, "destino ocupado")
	assert_eq(RulesScript.count_pegs(jogo.grid_data), 31, "31 esferas restantes")


func test_arrastar_a_esfera_ate_o_furo_executa_o_salto() -> void:
	# A grade 7x7 de botoes de 44 px ficava ancorada no centro da tela, longe
	# dos furos projetados: era dificil acertar a esfera, e nao dava para
	# arrastar. Agora o alvo sai da projecao do proprio furo.
	var jogo = add_child_autofree(GameScene.instantiate())
	await wait_process_frames(2)
	var origem: Vector2 = jogo._cell_screen[Vector2i(3, 1)]
	var destino: Vector2 = jogo._cell_screen[Vector2i(3, 3)]
	jogo._begin_press(origem)
	assert_eq(jogo.selected_pos, Vector2i(3, 1), "a esfera foi pega")
	jogo._update_drag(origem.lerp(destino, 0.5))
	jogo._update_drag(destino)
	assert_eq(jogo._hover_target, Vector2i(3, 3), "o furo sob o dedo acende")
	jogo._end_press(destino)
	assert_eq(jogo.grid_data.get_cell(3, 3), PINO, "soltou no furo e saltou")
	assert_eq(RulesScript.count_pegs(jogo.grid_data), 31, "31 esferas restantes")


func test_o_toque_cai_no_furo_mais_proximo() -> void:
	# Exigir o toque exato sobre o furo e o que fazia errar a esfera.
	var jogo = add_child_autofree(GameScene.instantiate())
	await wait_process_frames(2)
	var centro: Vector2 = jogo._cell_screen[Vector2i(3, 1)]
	var desvio: float = jogo._pick_radius * 0.45
	assert_eq(jogo._cell_at(centro + Vector2(desvio, 0.0)), Vector2i(3, 1),
		"errar por meio raio ainda pega a esfera certa")
	assert_eq(jogo._cell_at(centro + Vector2(0.0, -desvio)), Vector2i(3, 1),
		"em qualquer direcao")
	assert_eq(jogo._cell_at(Vector2(4.0, 4.0)), Vector2i(-1, -1),
		"longe do tabuleiro nao pega nada")


func test_so_as_trinta_e_tres_casas_do_tabuleiro_recebem_toque() -> void:
	# O tabuleiro em cruz usa 33 das 49 posicoes da grade 7x7: os quatro blocos
	# 2x2 dos cantos nao existem e nao podem receber toque.
	var jogo = add_child_autofree(GameScene.instantiate())
	await wait_process_frames(2)
	assert_eq(jogo._cell_screen.size(), 33, "33 casas jogaveis projetadas")
	for r in range(7):
		for c in range(7):
			assert_eq(jogo._cell_screen.has(Vector2i(r, c)), RulesScript.is_valid_cell(r, c),
				"celula (%d,%d)" % [r, c])
