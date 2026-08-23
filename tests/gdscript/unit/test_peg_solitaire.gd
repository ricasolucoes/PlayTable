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
