extends GutTest

## Campo Minado — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestMinesweeper.

const RulesScript = preload("res://games/campo_minado/MinesweeperRules.gd")

const ROWS := 9
const COLS := 9
const MINAS := 10


func _conta_minas(g: Grid2D) -> int:
	var total := 0
	for r in range(ROWS):
		for c in range(COLS):
			if g.get_cell(r, c)["is_mine"]:
				total += 1
	return total


func _minas_em(g: Grid2D, posicoes: Array) -> void:
	for p in posicoes:
		g.get_cell(p[0], p[1])["is_mine"] = true
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = g.get_cell(r, c)
			if cell["is_mine"]:
				continue
			var total := 0
			for n in g.get_all_neighbors(r, c):
				if g.get_cell(n.x, n.y)["is_mine"]:
					total += 1
			cell["adjacent_mines"] = total


func test_grade_vazia_tem_81_casas_limpas() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	assert_eq(g.rows, ROWS, "9 linhas")
	assert_eq(g.cols, COLS, "9 colunas")
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = g.get_cell(r, c)
			assert_false(cell["is_mine"], "sem mina")
			assert_false(cell["is_revealed"], "fechada")
			assert_false(cell["is_flagged"], "sem bandeira")
			assert_eq(cell["adjacent_mines"], 0, "sem vizinhos contados")


func test_geracao_planta_exatamente_dez_minas() -> void:
	for _tentativa in range(20):
		var g: Grid2D = RulesScript.create_empty_grid()
		RulesScript.generate_mines(g, 4, 4)
		assert_eq(_conta_minas(g), MINAS, "10 minas")


func test_primeiro_clique_e_sempre_seguro_com_os_oito_vizinhos() -> void:
	for centro in [[4, 4], [0, 0], [8, 8], [0, 8], [4, 0]]:
		for _tentativa in range(10):
			var g: Grid2D = RulesScript.create_empty_grid()
			RulesScript.generate_mines(g, centro[0], centro[1])
			for dr in [-1, 0, 1]:
				for dc in [-1, 0, 1]:
					var r: int = centro[0] + dr
					var c: int = centro[1] + dc
					if g.is_valid(r, c):
						assert_false(g.get_cell(r, c)["is_mine"],
							"(%d,%d) na caixa segura de %s" % [r, c, str(centro)])


func test_contagem_de_vizinhos_bate_com_o_tabuleiro() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	RulesScript.generate_mines(g, 4, 4)
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = g.get_cell(r, c)
			if cell["is_mine"]:
				continue
			var esperado := 0
			for n in g.get_all_neighbors(r, c):
				if g.get_cell(n.x, n.y)["is_mine"]:
					esperado += 1
			assert_eq(cell["adjacent_mines"], esperado, "vizinhos de (%d,%d)" % [r, c])


func test_numero_maximo_de_vizinhos_e_oito() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	assert_eq(g.get_all_neighbors(4, 4).size(), 8, "casa do meio")
	assert_eq(g.get_all_neighbors(0, 0).size(), 3, "quina")
	assert_eq(g.get_all_neighbors(0, 4).size(), 5, "borda")


func test_flood_fill_abre_a_regiao_vazia_inteira() -> void:
	# Uma unica mina na quina: abrir do lado oposto revela as 80 casas livres.
	var g: Grid2D = RulesScript.create_empty_grid()
	_minas_em(g, [[0, 0]])
	var abertas: Array[Vector2i] = RulesScript.reveal_cell(g, 8, 8)
	assert_eq(abertas.size(), ROWS * COLS - 1, "80 casas abertas de uma vez")
	assert_true(g.get_cell(8, 8)["is_revealed"], "a casa clicada abriu")
	assert_false(g.get_cell(0, 0)["is_revealed"], "a mina continua fechada")


func test_flood_fill_para_nos_numeros() -> void:
	# Parede de minas na linha 4: abrir na linha 8 nao passa para a linha 3.
	var g: Grid2D = RulesScript.create_empty_grid()
	var parede: Array = []
	for c in range(COLS):
		parede.append([4, c])
	_minas_em(g, parede)
	RulesScript.reveal_cell(g, 8, 4)
	for c in range(COLS):
		assert_true(g.get_cell(5, c)["is_revealed"], "(5,%d) e numero e abre" % c)
	for r in range(4):
		for c in range(COLS):
			assert_false(g.get_cell(r, c)["is_revealed"], "(%d,%d) do outro lado da parede" % [r, c])


func test_clique_numa_casa_com_numero_abre_so_ela() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	_minas_em(g, [[0, 0]])
	var abertas: Array[Vector2i] = RulesScript.reveal_cell(g, 0, 1)
	assert_eq(abertas, [Vector2i(0, 1)] as Array[Vector2i], "so a casa clicada")
	assert_eq(g.get_cell(0, 1)["adjacent_mines"], 1, "1 mina vizinha")


func test_casa_com_bandeira_nao_abre() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	_minas_em(g, [[0, 0]])
	g.get_cell(8, 8)["is_flagged"] = true
	assert_eq(RulesScript.reveal_cell(g, 8, 8), [] as Array[Vector2i], "bandeira bloqueia")
	assert_false(g.get_cell(8, 8)["is_revealed"], "continua fechada")


func test_flood_fill_nao_atravessa_bandeira() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	_minas_em(g, [[0, 0]])
	g.get_cell(4, 4)["is_flagged"] = true
	RulesScript.reveal_cell(g, 8, 8)
	assert_false(g.get_cell(4, 4)["is_revealed"], "a casa marcada fica fechada")


func test_mina_nunca_e_revelada_pelo_flood_fill() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	RulesScript.generate_mines(g, 4, 4)
	RulesScript.reveal_cell(g, 4, 4)
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = g.get_cell(r, c)
			if cell["is_mine"]:
				assert_false(cell["is_revealed"], "mina em (%d,%d) segue escondida" % [r, c])


func test_abrir_de_novo_nao_soma_casas() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	_minas_em(g, [[0, 0]])
	RulesScript.reveal_cell(g, 8, 8)
	assert_eq(RulesScript.reveal_cell(g, 8, 8), [] as Array[Vector2i], "nada a revelar")


func test_contagem_de_bandeiras() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	assert_eq(RulesScript.count_flagged(g), 0, "nenhuma bandeira")
	g.get_cell(0, 0)["is_flagged"] = true
	g.get_cell(5, 5)["is_flagged"] = true
	assert_eq(RulesScript.count_flagged(g), 2, "duas bandeiras")


func test_vitoria_quando_todas_as_casas_livres_abrem() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	_minas_em(g, [[0, 0]])
	assert_false(RulesScript.check_win(g), "nada aberto ainda")
	RulesScript.reveal_cell(g, 8, 8)
	assert_true(RulesScript.check_win(g), "80 casas livres abertas, mina intacta")


func test_bandeira_esquecida_nao_impede_a_vitoria() -> void:
	# check_win olha so as casas livres reveladas — a mina marcada nao conta.
	var g: Grid2D = RulesScript.create_empty_grid()
	_minas_em(g, [[0, 0]])
	g.get_cell(0, 0)["is_flagged"] = true
	RulesScript.reveal_cell(g, 8, 8)
	assert_true(RulesScript.check_win(g), "vitoria com a mina sinalizada")


func test_partida_completa_nao_trava() -> void:
	# Guarda contra deadlock: substitui test_e2e_minesweeper_simulation.
	var g: Grid2D = RulesScript.create_empty_grid()
	RulesScript.generate_mines(g, 4, 4)
	RulesScript.reveal_cell(g, 4, 4)
	var passos := 0
	while not RulesScript.check_win(g) and passos < ROWS * COLS:
		passos += 1
		var achou := false
		for r in range(ROWS):
			for c in range(COLS):
				var cell: Dictionary = g.get_cell(r, c)
				if not achou and not cell["is_mine"] and not cell["is_revealed"]:
					RulesScript.reveal_cell(g, r, c)
					achou = true
		assert_true(achou, "sobrou casa livre fechada mas check_win negou a vitoria")
	assert_true(RulesScript.check_win(g), "partida vencida abrindo todas as casas livres")
	assert_eq(_conta_minas(g), MINAS, "as 10 minas continuam la")


# ----------------------------------------------------------- MinesweeperGame

const GameScene = preload("res://games/campo_minado/MinesweeperGame.tscn")


func test_vitoria_anuncia_o_tempo_no_rotulo() -> void:
	# "100%" dentro da string de formato precisa ser escapado: com um unico %
	# o operador falha e o rotulo da vitoria fica vazio.
	var jogo = add_child_autofree(GameScene.instantiate())
	_minas_em(jogo.grid_data, [[0, 0]])
	RulesScript.reveal_cell(jogo.grid_data, 8, 8)
	jogo.game_timer.elapsed_time = 42.0
	jogo._check_win_condition()
	assert_true(jogo.game_won, "partida vencida")
	assert_string_contains(jogo.status_label.text, "100%", "o texto sobreviveu a formatacao")
	assert_string_contains(jogo.status_label.text, "42 segundos", "o tempo entrou no texto")
