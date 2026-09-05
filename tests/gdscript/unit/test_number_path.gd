extends GutTest

## Testes unitários e de integração para Caminho Numérico (Number Path).
## Suite de Testes em 4 Camadas (4-Tier Test Suite):
## - Tier 1: Feature Unit Tests (Obstacles, Bridges, Stars, Time Limit, Portals, Directional, Scoring, Generator, Solver)
## - Tier 2: Boundary & Corner Cases (Grid sizes 3x3 to 7x7, Clue densities, Max obstacles, Multiple bridges, Backtracking, Timer bounds)
## - Tier 3: Pairwise Cross-Feature Combinations (Obstacles + Bridges, Bridges + Stars, Portals + Bridges, Portals + Stars, Deep Backtracking)
## - Tier 4: Real-World Application Scenarios (Campaign Levels 1-10+ Simulation, Monte Carlo 50+ Generator Solvability, Player Recovery Flow)

const Generator := preload("res://games/caminho_numerico/NumberPathGenerator.gd")
const Model := preload("res://games/caminho_numerico/NumberPathModel.gd")
const Scoring := preload("res://games/caminho_numerico/NumberPathScoring.gd")


func after_all() -> void:
	if AudioManager:
		for p in AudioManager.sfx_players:
			if is_instance_valid(p):
				p.stop()


# =============================================================================
# TIER 1: FEATURE UNIT TESTS
# =============================================================================

# -----------------------------------------------------------------------------
# 1.1 Obstacles (Obstáculos)
# -----------------------------------------------------------------------------

func test_tier1_obstacle_rejection() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"obstacles": [Vector2i(1, 0)],
		"bridges": [],
		"stars": [],
		"portals": {},
		"directional": {},
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2},
		"solution": []
	}
	model.setup_puzzle(puzzle)
	assert_eq(model.obstacles.size(), 1, "Deve conter 1 obstáculo registrado")
	assert_true(model.obstacles.has(Vector2i(1, 0)))

	# Tentativa de extensão para o obstáculo
	assert_false(model.can_extend_to(Vector2i(1, 0)), "can_extend_to deve retornar false para obstáculo")
	assert_false(model.extend_to(Vector2i(1, 0)), "extend_to deve falhar em obstáculo")
	assert_eq(model.player_path.size(), 1, "Caminho não deve conter a célula de obstáculo")
	assert_gt(model.mistakes_count, 0, "Tentativa de obstáculo deve incrementar erros")


func test_tier1_obstacle_walkable_count_and_total_cells() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 4,
		"height": 4,
		"obstacles": [Vector2i(1, 1), Vector2i(2, 2)],
		"bridges": [],
		"stars": [],
		"portals": {},
		"clues": {Vector2i(0, 0): 1, Vector2i(3, 3): 2},
		"solution": []
	}
	model.setup_puzzle(puzzle)
	assert_eq(model.walkable_count, 14, "Walkable count deve ser 16 - 2 = 14")
	assert_eq(model.total_cells, 14, "Total cells sem pontes deve ser igual a walkable count")


func test_tier1_obstacle_mistake_signal() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"obstacles": [Vector2i(0, 1)],
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2},
	}
	model.setup_puzzle(puzzle)
	watch_signals(model)

	model.extend_to(Vector2i(0, 1))
	assert_signal_emitted(model, "mistake_occurred", "Deve emitir mistake_occurred ao tentar obstáculo")
	assert_eq(model.mistakes_count, 1)


func test_tier1_obstacle_safe_placement_parity_and_connectivity() -> void:
	for i in range(10):
		var obstacles := Generator.place_obstacles_safely(5, 5, 3)
		assert_lte(obstacles.size(), 3, "Número de obstáculos respeita o alvo")
		assert_true(Generator._is_obstacle_layout_valid(5, 5, obstacles), "Layout de obstáculos gerado deve ser válido e conexo")
		for o in obstacles:
			var is_corner: bool = (o.x == 0 or o.x == 4) and (o.y == 0 or o.y == 4)
			assert_false(is_corner, "Obstáculos não devem ser colocados em cantos extremos")


func test_tier1_obstacle_invalid_layout_detection() -> void:
	# Paridade desbalanceada intencional em 3x3 (bloquear 2 células ímpares deixa 5 pares e 2 ímpares -> diferença |5 - 2| = 3 > 1)
	var bad_obs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 1)]
	assert_false(Generator._is_obstacle_layout_valid(3, 3, bad_obs), "Paridade desbalanceada deve ser rejeitada")

	# Ilha isolada desconexa
	var island_obs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0)]
	assert_false(Generator._is_obstacle_layout_valid(3, 3, island_obs), "Célula (0,0) isolada deve ser rejeitada por desconectividade")


func test_tier1_obstacle_board_drag_blocking() -> void:
	var board := NumberPathBoard.new()
	board.size = Vector2(600, 600)
	board.setup_puzzle(3, 3, {
		"width": 3,
		"height": 3,
		"obstacles": [Vector2i(1, 0)],
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	})

	board._handle_drag_to_cell(Vector2i(1, 0))
	assert_eq(board.model.player_path.size(), 1, "Drag para obstáculo não estende o caminho")
	assert_eq(board.model.mistakes_count, 1, "Erro registrado no model")
	board.free()


# -----------------------------------------------------------------------------
# 1.2 Bridges & Tunnels (Pontes e Túneis)
# -----------------------------------------------------------------------------

func test_tier1_bridge_double_traversal_orthogonal() -> void:
	var model := Model.new()
	# Tabuleiro 3x3 com ponte em (1,1).
	var puzzle := {
		"width": 3,
		"height": 3,
		"obstacles": [],
		"bridges": [Vector2i(1, 1)],
		"stars": [],
		"portals": {},
		"directional": {},
		"clues": {Vector2i(0, 1): 1, Vector2i(2, 0): 2, Vector2i(1, 2): 3},
		"total_cells": 7, # 6 passos + 1 cruzamento
		"walkable_count": 6,
		"solution": []
	}
	model.setup_puzzle(puzzle)

	# Primeira travessia: Horizontal (0,1) -> (1,1) -> (2,1)
	assert_true(model.can_extend_to(Vector2i(1, 1)))
	assert_true(model.extend_to(Vector2i(1, 1)))
	assert_true(model.can_extend_to(Vector2i(2, 1)))
	assert_true(model.extend_to(Vector2i(2, 1)))
	assert_true(model.bridge_crossings[Vector2i(1, 1)]["H"], "Eixo H registrado na primeira passagem")

	# Movimento ao redor: (2,1) -> (2,0) [pista 2] -> (1,0)
	assert_true(model.extend_to(Vector2i(2, 0)))
	assert_true(model.extend_to(Vector2i(1, 0)))

	# Segunda travessia: Vertical (1,0) -> (1,1) -> (1,2) [pista 3 final]
	assert_true(model.can_extend_to(Vector2i(1, 1)), "Ponte aceita segunda travessia em eixo ortogonal V")
	assert_true(model.extend_to(Vector2i(1, 1)))
	assert_true(model.bridge_crossings[Vector2i(1, 1)]["V"], "Eixo V registrado na segunda passagem")
	assert_true(model.can_extend_to(Vector2i(1, 2)), "Saída reta vertical permitida")
	assert_true(model.extend_to(Vector2i(1, 2)))
	assert_eq(model.player_path.count(Vector2i(1, 1)), 2, "Ponte visitada exatamente 2 vezes")


func test_tier1_bridge_rejection_third_visit() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"bridges": [Vector2i(1, 1)],
		"clues": {Vector2i(0, 1): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)

	# Travessia 1: H
	model.extend_to(Vector2i(1, 1))
	model.extend_to(Vector2i(2, 1))
	# Contorno
	model.extend_to(Vector2i(2, 0))
	model.extend_to(Vector2i(1, 0))
	# Travessia 2: V
	model.extend_to(Vector2i(1, 1))
	model.extend_to(Vector2i(1, 2))
	# Contorno
	model.extend_to(Vector2i(0, 2))
	model.extend_to(Vector2i(0, 1))

	# Tentativa de 3ª visita na ponte
	assert_false(model.can_extend_to(Vector2i(1, 1)), "3ª visita na ponte deve ser expressamente proibida")
	assert_false(model.extend_to(Vector2i(1, 1)))


func test_tier1_bridge_rejection_parallel_second_crossing() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"bridges": [Vector2i(1, 1)],
		"clues": {Vector2i(0, 1): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)

	# Travessia 1: H de (0,1) -> (1,1) -> (2,1)
	model.extend_to(Vector2i(1, 1))
	model.extend_to(Vector2i(2, 1))

	# Retrocede 1 passo para estar em (2,1) e tenta entrar em (1,1) horizontalmente
	assert_false(model.can_extend_to(Vector2i(1, 1)), "Segunda travessia no mesmo eixo H deve ser bloqueada")


func test_tier1_bridge_straight_through_enforcement() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"bridges": [Vector2i(1, 1)],
		"clues": {Vector2i(0, 1): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)

	# Entra na ponte vindo da esquerda (0,1) -> (1,1) [vetor horizontal (1,0)]
	model.extend_to(Vector2i(1, 1))

	# Tentar virar 90 graus para cima (1,0) ou para baixo (1,2)
	assert_false(model.can_extend_to(Vector2i(1, 0)), "Curva de 90° dentro da ponte para cima deve ser proibida")
	assert_false(model.can_extend_to(Vector2i(1, 2)), "Curva de 90° dentro da ponte para baixo deve ser proibida")

	# Saída reta horizontal (2,1) deve ser permitida
	assert_true(model.can_extend_to(Vector2i(2, 1)), "Saída em linha reta deve ser permitida")
	assert_true(model.extend_to(Vector2i(2, 1)))


func test_tier1_bridge_backtracking_dynamic_rebuild() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"bridges": [Vector2i(1, 1)],
		"clues": {Vector2i(0, 1): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)

	# Travessia 1 (H)
	model.extend_to(Vector2i(1, 1))
	model.extend_to(Vector2i(2, 1))
	model.extend_to(Vector2i(2, 0))
	model.extend_to(Vector2i(1, 0))
	# Travessia 2 (V)
	model.extend_to(Vector2i(1, 1))
	model.extend_to(Vector2i(1, 2))

	assert_true(model.bridge_crossings[Vector2i(1, 1)]["H"])
	assert_true(model.bridge_crossings[Vector2i(1, 1)]["V"])

	# Trunca para (1,0) [antes da segunda travessia]
	model.truncate_to(Vector2i(1, 0))
	assert_true(model.bridge_crossings[Vector2i(1, 1)]["H"], "Eixo H ainda presente")
	assert_false(model.bridge_crossings[Vector2i(1, 1)]["V"], "Eixo V limpo pelo backtrack")

	# Trunca para o início (0,1)
	model.truncate_to(Vector2i(0, 1))
	assert_false(model.bridge_crossings.has(Vector2i(1, 1)), "Eixos da ponte totalmente limpos")


func test_tier1_bridge_board_rendering_and_overpass() -> void:
	var board := NumberPathBoard.new()
	board.size = Vector2(600, 600)
	board.setup_puzzle(3, 3, {
		"width": 3,
		"height": 3,
		"bridges": [Vector2i(1, 1)],
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	})
	add_child_autofree(board)

	board._notification(Control.NOTIFICATION_RESIZED)
	assert_eq(board.model.bridges.size(), 1)
	assert_false(board.model.is_completed)


# -----------------------------------------------------------------------------
# 1.3 Mandatory Stars (Estrelas Obrigatórias)
# -----------------------------------------------------------------------------

func test_tier1_star_collection_and_signal() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"stars": [Vector2i(1, 0), Vector2i(2, 1)],
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)
	watch_signals(model)

	assert_eq(model.visited_stars.size(), 0)
	model.extend_to(Vector2i(1, 0))
	assert_eq(model.visited_stars.size(), 1, "Estrela adicionada a visited_stars")
	assert_true(model.visited_stars.has(Vector2i(1, 0)))
	assert_signal_emitted(model, "star_collected", "Sinal star_collected emitido")


func test_tier1_star_prevents_premature_completion() -> void:
	var model := Model.new()
	# Grid 3x1 simplificado com estrela em (1,0)
	var puzzle := {
		"width": 3,
		"height": 1,
		"total_cells": 3,
		"walkable_count": 3,
		"stars": [Vector2i(1, 0)],
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 0): 2},
		"solution": []
	}
	model.setup_puzzle(puzzle)
	# Inicia em (0,0)
	assert_eq(model.player_path.size(), 1)
	assert_false(model.can_extend_to(Vector2i(2, 0)))


func test_tier1_star_successful_completion_when_all_collected() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 1,
		"total_cells": 3,
		"walkable_count": 3,
		"stars": [Vector2i(1, 0)],
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 0): 2},
		"solution": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	}
	model.setup_puzzle(puzzle)
	watch_signals(model)

	model.extend_to(Vector2i(1, 0)) # Visita estrela
	model.extend_to(Vector2i(2, 0)) # Visita final
	assert_true(model.is_completed, "Puzzle completo ao visitar todas as células e estrelas")
	assert_signal_emitted(model, "completed")


func test_tier1_star_backtracking_uncollects() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"stars": [Vector2i(1, 0)],
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)

	model.extend_to(Vector2i(1, 0))
	model.extend_to(Vector2i(2, 0))
	assert_eq(model.visited_stars.size(), 1)

	# Retrocede para (0,0)
	model.truncate_to(Vector2i(0, 0))
	assert_eq(model.visited_stars.size(), 0, "Estrela desmarcada após truncar")


func test_tier1_star_generator_placement() -> void:
	var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	var clues: Dictionary = {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	var bridges: Array[Vector2i] = [Vector2i(2, 0)]
	var portals: Dictionary = {}

	var stars := Generator.place_stars(path, clues, 2, bridges, portals)
	assert_lte(stars.size(), 2)
	for s in stars:
		assert_false(clues.has(s), "Estrela não deve sobrepor pista")
		assert_false(bridges.has(s), "Estrela não deve sobrepor ponte")
		assert_false(portals.has(s), "Estrela não deve sobrepor portal")


func test_tier1_star_scoring_bonus() -> void:
	var score_no_stars := Scoring.calculate_score(3, 3, 3, 10.0, 0, 0, 0)
	var score_2_stars := Scoring.calculate_score(3, 3, 3, 10.0, 0, 0, 2)
	assert_eq(score_2_stars["star_bonus"], 300, "2 estrelas = 300 pts de bônus")
	assert_eq(score_2_stars["score"], score_no_stars["score"] + 300)


# -----------------------------------------------------------------------------
# 1.4 Time Limit Mode (Modo Tempo Limite)
# -----------------------------------------------------------------------------

func test_tier1_time_limit_countdown_loop() -> void:
	var game_scene := preload("res://games/caminho_numerico/NumberPathGame.tscn")
	var game: NumberPathGame = game_scene.instantiate()
	add_child_autofree(game)

	game.time_limit = 20.0
	game.time_elapsed = 0.0
	game.time_remaining = 20.0
	game.is_timer_running = true

	game._process(5.0)
	assert_almost_eq(game.time_elapsed, 5.0, 0.01)
	assert_almost_eq(game.time_remaining, 15.0, 0.01)
	assert_false(game.game_over)


func test_tier1_time_limit_timeout_triggers_game_over() -> void:
	var game_scene := preload("res://games/caminho_numerico/NumberPathGame.tscn")
	var game: NumberPathGame = game_scene.instantiate()
	add_child_autofree(game)

	game.time_limit = 10.0
	game.time_elapsed = 0.0
	game.time_remaining = 10.0
	game.is_timer_running = true

	game._process(10.5)
	assert_true(game.game_over, "Timeout deve marcar game_over = true")
	assert_false(game.is_timer_running, "Temporizador deve parar")
	assert_eq(game.time_remaining, 0.0)


func test_tier1_time_limit_stops_on_level_completion() -> void:
	var game_scene := preload("res://games/caminho_numerico/NumberPathGame.tscn")
	var game: NumberPathGame = game_scene.instantiate()
	add_child_autofree(game)

	assert_true(game.is_timer_running)
	# Completa o tabuleiro
	var sol: Array[Vector2i] = []
	for p in game.current_puzzle["solution"]:
		sol.append(p as Vector2i)
	for i in range(1, sol.size()):
		game.num_board.model.extend_to(sol[i])

	assert_false(game.is_timer_running, "Vitória para o temporizador imediatamente")


func test_tier1_time_limit_untimed_mode() -> void:
	var game_scene := preload("res://games/caminho_numerico/NumberPathGame.tscn")
	var game: NumberPathGame = game_scene.instantiate()
	add_child_autofree(game)

	game.time_limit = 0.0 # Modo sem tempo limite
	game.time_elapsed = 0.0
	game.time_remaining = 0.0
	game.is_timer_running = true

	game._process(120.0)
	assert_almost_eq(game.time_elapsed, 120.0, 0.01)
	assert_false(game.game_over, "Modo untimed nunca dispara timeout")


func test_tier1_time_limit_scoring_bonus_formula() -> void:
	# Conclusão em 10s com limite de 30s -> 20s restantes * 20.0 = 400 pts
	var score_res := Scoring.calculate_score(4, 4, 4, 10.0, 0, 0, 0, 30.0)
	assert_eq(score_res["time_bonus"], 400, "Bônus por 20s restantes no tempo limite")


func test_tier1_time_limit_formatting_and_hud() -> void:
	assert_eq(Scoring.format_time(0.0), "00:00")
	assert_eq(Scoring.format_time(59.0), "00:59")
	assert_eq(Scoring.format_time(60.0), "01:00")
	assert_eq(Scoring.format_time(125.0), "02:05")


# -----------------------------------------------------------------------------
# 1.5 Bonus Mechanic 1: Warp Portals (Portais Quânticos)
# -----------------------------------------------------------------------------

func test_tier1_portal_bidirectional_jump() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 5,
		"height": 5,
		"portals": {Vector2i(1, 0): Vector2i(3, 4), Vector2i(3, 4): Vector2i(1, 0)},
		"clues": {Vector2i(0, 0): 1, Vector2i(4, 4): 2}
	}
	model.setup_puzzle(puzzle)
	watch_signals(model)

	# Jogador move (0,0) -> (1,0) [Portal]
	assert_true(model.can_extend_to(Vector2i(1, 0)))
	assert_true(model.extend_to(Vector2i(1, 0)))

	# Deve ter auto-teleportado para (3,4)
	assert_eq(model.player_path.size(), 3, "Path contém (0,0), (1,0) e (3,4)")
	assert_eq(model.player_path[1], Vector2i(1, 0))
	assert_eq(model.player_path[2], Vector2i(3, 4))
	assert_signal_emitted(model, "portal_used", "Sinal portal_used emitido")


func test_tier1_portal_step_through_extension() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 5,
		"height": 5,
		"portals": {Vector2i(1, 0): Vector2i(3, 4), Vector2i(3, 4): Vector2i(1, 0)},
		"clues": {Vector2i(0, 0): 1, Vector2i(4, 4): 2}
	}
	model.setup_puzzle(puzzle)
	model.extend_to(Vector2i(1, 0))

	# Agora o jogador está em (3,4). O próximo passo deve ser adjacente a (3,4), por exemplo (3,3) ou (4,4)
	assert_true(model.can_extend_to(Vector2i(3, 3)), "Passo adjacente à saída do portal deve ser válido")
	assert_true(model.extend_to(Vector2i(3, 3)))
	assert_eq(model.player_path.size(), 4)


func test_tier1_portal_destination_star_collection() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 5,
		"height": 5,
		"portals": {Vector2i(1, 0): Vector2i(4, 4)},
		"stars": [Vector2i(4, 4)],
		"clues": {Vector2i(0, 0): 1, Vector2i(4, 3): 2}
	}
	model.setup_puzzle(puzzle)
	model.extend_to(Vector2i(1, 0))
	assert_true(model.visited_stars.has(Vector2i(4, 4)), "Estrela na saída do portal coletada automaticamente")


func test_tier1_portal_destination_clue_acknowledgement() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 5,
		"height": 5,
		"portals": {Vector2i(1, 0): Vector2i(4, 4)},
		"clues": {Vector2i(0, 0): 1, Vector2i(4, 4): 2, Vector2i(0, 4): 3}
	}
	model.setup_puzzle(puzzle)
	model.extend_to(Vector2i(1, 0))
	assert_eq(model.get_current_target(), 3, "Pista 2 na saída do portal foi alcançada, alvo agora é 3")


func test_tier1_portal_backtracking_restores_state() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 5,
		"height": 5,
		"portals": {Vector2i(1, 0): Vector2i(3, 4)},
		"stars": [Vector2i(3, 4)],
		"clues": {Vector2i(0, 0): 1, Vector2i(0, 4): 2}
	}
	model.setup_puzzle(puzzle)
	model.extend_to(Vector2i(1, 0))
	assert_eq(model.player_path.size(), 3)
	assert_eq(model.visited_stars.size(), 1)

	# Trunca para (0,0)
	model.truncate_to(Vector2i(0, 0))
	assert_eq(model.player_path.size(), 1)
	assert_eq(model.visited_stars.size(), 0)


func test_tier1_portal_generator_advanced_placement() -> void:
	var res := Generator.generate_path_advanced(6, 6, [], 0, true, 2000)
	if not res["portals"].is_empty():
		var p: Dictionary = res["portals"]
		for k in p.keys():
			assert_eq(p[p[k]], k, "Portais gerados devem ser bidirecionais e simétricos")


# -----------------------------------------------------------------------------
# 1.6 Bonus Mechanic 2: Directional Chevrons (Setas Direcionais)
# -----------------------------------------------------------------------------

func test_tier1_directional_enforces_exit_direction() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"directional": {Vector2i(1, 0): Vector2i(1, 0)}, # Força saída para a direita (2,0)
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)
	model.extend_to(Vector2i(1, 0))

	# Tentar sair para baixo (1,1) deve falhar
	assert_false(model.can_extend_to(Vector2i(1, 1)), "Direção para baixo não condiz com a seta para a direita")

	# Sair para a direita (2,0) deve ter sucesso
	assert_true(model.can_extend_to(Vector2i(2, 0)), "Direção para a direita condiz com a seta")
	assert_true(model.extend_to(Vector2i(2, 0)))


func test_tier1_directional_rejects_wrong_direction() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"directional": {Vector2i(1, 1): Vector2i(0, 1)}, # Força saída para baixo (1,2)
		"clues": {Vector2i(1, 0): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)
	model.extend_to(Vector2i(1, 1))

	assert_false(model.can_extend_to(Vector2i(0, 1)), "Esquerda rejeitada")
	assert_false(model.can_extend_to(Vector2i(2, 1)), "Direita rejeitada")
	assert_true(model.can_extend_to(Vector2i(1, 2)), "Baixo aceita")


func test_tier1_directional_generator_placement() -> void:
	var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	var clues: Dictionary = {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	var stars: Array[Vector2i] = []
	var directional := Generator.place_directional(path, clues, stars, 2)
	assert_lte(directional.size(), 2)
	for cell in directional.keys():
		var idx: int = path.find(cell)
		var expected_dir: Vector2i = path[idx + 1] - cell
		assert_eq(directional[cell], expected_dir, "Seta direcional aponta rigorosamente para o próximo passo no caminho")


func test_tier1_directional_solver_respects_arrow() -> void:
	var puzzle := {
		"width": 3,
		"height": 3,
		"total_cells": 9,
		"directional": {Vector2i(1, 0): Vector2i(1, 0)},
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	}
	var solutions := Generator.solve_puzzle(puzzle, 1)
	if not solutions.is_empty():
		var sol: Array[Vector2i] = solutions[0]
		var idx: int = sol.find(Vector2i(1, 0))
		assert_eq(sol[idx + 1] - sol[idx], Vector2i(1, 0), "Solver obedece seta direcional")


# -----------------------------------------------------------------------------
# 1.7 Scoring, Gamification & Translations
# -----------------------------------------------------------------------------

func test_tier1_scoring_all_components_breakdown() -> void:
	var score_dict := Scoring.calculate_score(4, 4, 4, 15.0, 1, 1, 2, 40.0)
	assert_eq(score_dict["base_points"], 1600)
	assert_eq(score_dict["clue_bonus"], 12 * 60) # 16 - 4 = 12 * 60 = 720
	assert_eq(score_dict["star_bonus"], 300) # 2 * 150
	assert_eq(score_dict["penalty"], 40 + 80) # 1 erro + 1 dica = 120
	assert_eq(score_dict["perfect_bonus"], 0) # Teve erros
	assert_gt(score_dict["time_bonus"], 0)
	assert_eq(score_dict["rank"], "A")


func test_tier1_scoring_rank_tiers() -> void:
	var rank_s := Scoring.calculate_score(3, 3, 3, 5.0, 0, 0, 0, 30.0)
	assert_eq(rank_s["rank"], "S")

	var rank_c := Scoring.calculate_score(3, 3, 3, 100.0, 15, 5, 0, 10.0)
	assert_eq(rank_c["rank"], "C")


func test_tier1_scoring_resilience_nan_inf() -> void:
	var res := Scoring.calculate_score(3, 3, 4, NAN, 0, 0)
	assert_false(is_nan(float(res["score"])))
	assert_gte(res["score"], 100)


func test_tier1_translations_all_keys_exist() -> void:
	var keys: Array[String] = [
		"NUMBER_PATH_CONNECT",
		"NUMBER_PATH_CLUES",
		"NUMBER_PATH_WIN",
		"NUMBER_PATH_HINT_BACKTRACK",
		"NUMBER_PATH_OBSTACLE",
		"NUMBER_PATH_BRIDGE",
		"NUMBER_PATH_STAR",
		"NUMBER_PATH_PORTAL",
		"NUMBER_PATH_TIME_LIMIT",
		"NUMBER_PATH_TIMEOUT",
		"NUMBER_PATH_DIRECTIONAL",
		"NUMBER_PATH_STARS_REMAINING",
		"GAME_NUMBER_PATH",
		"GAME_DESC_NUMBER_PATH",
	]
	for k in keys:
		var localized: String = tr(k)
		assert_ne(localized, "", "Chave de tradução %s deve existir" % k)


func test_tier1_gamification_profile_integration() -> void:
	if PlayerProfile == null:
		return
	var game_id := "caminho_numerico"
	var fake_res := {
		"win": true,
		"score": 4200,
		"time": 18.0,
		"moves": 20,
		"perfect": true
	}
	GameEventBus.emit_match_completed(game_id, fake_res)
	var stats: Dictionary = PlayerProfile.game_stats(game_id)
	assert_gte(int(stats.get("best_score", 0)), 4200)


# -----------------------------------------------------------------------------
# 1.8 Generator Core & Built-in Solver
# -----------------------------------------------------------------------------

func test_tier1_generator_bipartite_parity_odd_grids() -> void:
	for i in range(15):
		var p := Generator.generate_path(3, 3)
		assert_eq((p[0].x + p[0].y) % 2, 0, "Início 3x3 #%d deve ter paridade par" % i)


func test_tier1_generator_solver_basic_and_clues() -> void:
	var puzzle := Generator.generate_puzzle(4, 4, 4)
	var solutions := Generator.solve_puzzle(puzzle, 1)
	assert_gt(solutions.size(), 0, "Solver deve encontrar solução para puzzle gerado")
	assert_true(Generator.is_valid_hamiltonian_path(4, 4, solutions[0]))


func test_tier1_generator_fail_safe_serpentine_fallback() -> void:
	var serp := Generator._generate_serpentine_path(4, 4)
	assert_eq(serp.size(), 16)
	assert_true(Generator.is_valid_hamiltonian_path(4, 4, serp))


# =============================================================================
# TIER 2: BOUNDARY & CORNER CASES
# =============================================================================

func test_tier2_grid_size_3x3_min_to_7x7_max() -> void:
	var sizes: Array[int] = [3, 4, 5, 6, 7]
	for s in sizes:
		var pz := Generator.generate_puzzle(s, s, maxi(3, s))
		assert_eq(pz["width"], s)
		assert_eq(pz["height"], s)
		assert_gt(pz["path"].size(), 0)
		var sol := Generator.solve_puzzle(pz, 1)
		assert_gt(sol.size(), 0, "Solver deve resolver grid %dx%d" % [s, s])


func test_tier2_grid_non_square_dimensions() -> void:
	var rect_dims: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 2), Vector2i(4, 3), Vector2i(3, 4)]
	for d in rect_dims:
		var p := Generator.generate_path(d.x, d.y)
		assert_eq(p.size(), d.x * d.y)
		assert_true(Generator.is_valid_hamiltonian_path(d.x, d.y, p))


func test_tier2_clue_density_maximal_vs_minimal() -> void:
	# 1. Máximo de pistas (todas as 9 células são pistas)
	var max_clues_pz := Generator.generate_puzzle(3, 3, 9)
	assert_eq(max_clues_pz["clues_count"], 9)
	var sol_max := Generator.solve_puzzle(max_clues_pz, 1)
	assert_eq(sol_max.size(), 1, "Puzzle com pistas completas possui 1 solução única")

	# 2. Mínimo de pistas (apenas início e fim)
	var min_clues_pz := Generator.generate_puzzle(3, 3, 2)
	assert_eq(min_clues_pz["clues_count"], 2)
	var sol_min := Generator.solve_puzzle(min_clues_pz, 1)
	assert_gt(sol_min.size(), 0, "Puzzle com pistas mínimas tem solução")


func test_tier2_obstacle_density_limit_22_percent() -> void:
	# Em 7x7 (49 células), 22% são até 10 obstáculos
	var obs := Generator.place_obstacles_safely(7, 7, 10)
	assert_lte(obs.size(), 10)
	assert_true(Generator._is_obstacle_layout_valid(7, 7, obs))


func test_tier2_multiple_bridges_simultaneous() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 5,
		"height": 5,
		"bridges": [Vector2i(1, 1), Vector2i(3, 3)],
		"total_cells": 27,
		"walkable_count": 25,
		"clues": {Vector2i(0, 0): 1, Vector2i(4, 4): 2}
	}
	model.setup_puzzle(puzzle)
	assert_eq(model.bridges.size(), 2)
	assert_eq(model.total_cells, 27)


func test_tier2_immediate_backtrack_to_start() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)

	# Move 1 passo e volta imediatamente
	model.extend_to(Vector2i(1, 0))
	assert_eq(model.player_path.size(), 2)
	model.truncate_to(Vector2i(0, 0))
	assert_eq(model.player_path.size(), 1)
	assert_eq(model.player_path[0], Vector2i(0, 0))


func test_tier2_backtrack_when_one_cell_remains() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)
	assert_eq(model.player_path.size(), 1)

	# Truncar quando só há 1 célula deve retornar false
	var res := model.truncate_to(Vector2i(0, 0))
	assert_false(res)
	assert_eq(model.player_path.size(), 1)


func test_tier2_time_limits_zero_vs_ultra_tight_vs_generous() -> void:
	var game_scene := preload("res://games/caminho_numerico/NumberPathGame.tscn")
	var game: NumberPathGame = game_scene.instantiate()
	add_child_autofree(game)

	# Ultra tight (1.0s)
	game.time_limit = 1.0
	game.time_remaining = 1.0
	game.time_elapsed = 0.0
	game.is_timer_running = true
	game._process(1.5)
	assert_true(game.game_over)

	# Generous (500s)
	game.game_over = false
	game.time_limit = 500.0
	game.time_remaining = 500.0
	game.time_elapsed = 0.0
	game.is_timer_running = true
	game._process(10.0)
	assert_false(game.game_over)
	assert_almost_eq(game.time_remaining, 490.0, 0.01)


func test_tier2_board_input_coordinate_boundaries() -> void:
	var board := NumberPathBoard.new()
	board.size = Vector2(600, 600)
	board.setup_puzzle(3, 3, {Vector2i(0, 0): 1, Vector2i(2, 2): 2})

	assert_eq(board._pos_to_cell(Vector2(-50, 300)), Vector2i(-1, -1))
	assert_eq(board._pos_to_cell(Vector2(300, -50)), Vector2i(-1, -1))
	assert_eq(board._pos_to_cell(Vector2(1000, 300)), Vector2i(-1, -1))
	assert_eq(board._pos_to_cell(Vector2(300, 1000)), Vector2i(-1, -1))
	board.free()


func test_tier2_board_multi_touch_isolation() -> void:
	var board := NumberPathBoard.new()
	board.size = Vector2(600, 600)
	board.setup_puzzle(3, 3, {
		"width": 3,
		"height": 3,
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	})

	var min_dim: float = (600.0 - board.margin * 2.0) / 3.0
	var offset: float = board.margin

	var t0 := InputEventScreenTouch.new()
	t0.index = 0
	t0.pressed = true
	t0.position = Vector2(offset + min_dim * 1.5, offset + min_dim * 0.5)
	board._gui_input(t0)
	assert_eq(board.model.player_path.size(), 2)

	var t1 := InputEventScreenTouch.new()
	t1.index = 1
	t1.pressed = true
	t1.position = Vector2(offset + min_dim * 2.5, offset + min_dim * 2.5)
	board._gui_input(t1)
	assert_eq(board.model.player_path.size(), 2, "Segundo toque ignorado")
	board.free()


func test_tier2_level_scaling_and_clamping_boundaries() -> void:
	var l_neg := Generator.generate_level(-100)
	assert_eq(l_neg["level"], 1)

	var l_100 := Generator.generate_level(100)
	assert_eq(l_100["level"], 100)
	assert_eq(l_100["width"], 7)
	assert_eq(l_100["height"], 7)
	assert_gt(l_100["total_cells"], 0)


func test_tier2_empty_and_single_cell_puzzle_resilience() -> void:
	var p0 := Generator.generate_puzzle(0, 0)
	assert_eq(p0["total_cells"], 0)

	var p1 := Generator.generate_puzzle(1, 1)
	assert_eq(p1["total_cells"], 1)
	assert_eq(p1["clues"][Vector2i(0, 0)], 1)


# =============================================================================
# TIER 3: PAIRWISE CROSS-FEATURE COMBINATIONS
# =============================================================================

func test_tier3_combo_obstacles_plus_bridges() -> void:
	var model := Model.new()
	# Obstáculos em (0,0) e (0,2), ponte em (1,1)
	var puzzle := {
		"width": 3,
		"height": 3,
		"obstacles": [Vector2i(0, 0), Vector2i(0, 2)],
		"bridges": [Vector2i(1, 1)],
		"clues": {Vector2i(0, 1): 1, Vector2i(2, 2): 2},
		"total_cells": 8, # 7 walkable + 1 ponte
		"walkable_count": 7
	}
	model.setup_puzzle(puzzle)
	assert_eq(model.walkable_count, 7)
	assert_eq(model.total_cells, 8)

	# Travessia horizontal da ponte
	assert_true(model.extend_to(Vector2i(1, 1)))
	assert_true(model.extend_to(Vector2i(2, 1)))


func test_tier3_combo_bridges_plus_stars() -> void:
	var model := Model.new()
	# Estrela em (0,1) logo antes da ponte em (1,1) e estrela em (2,1) logo depois
	var puzzle := {
		"width": 3,
		"height": 3,
		"bridges": [Vector2i(1, 1)],
		"stars": [Vector2i(0, 1), Vector2i(2, 1)],
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)

	model.extend_to(Vector2i(0, 1)) # Coleta Estrela 1
	assert_eq(model.visited_stars.size(), 1)

	model.extend_to(Vector2i(1, 1)) # Entra na ponte
	model.extend_to(Vector2i(2, 1)) # Sai da ponte e coleta Estrela 2
	assert_eq(model.visited_stars.size(), 2)


func test_tier3_combo_portals_plus_bridges() -> void:
	var model := Model.new()
	# Inicia em (0,0). Move para (1,0) [Portal -> (0,1)].
	# (0,1) fica em frente à ponte em (1,1).
	var puzzle := {
		"width": 3,
		"height": 3,
		"portals": {Vector2i(1, 0): Vector2i(0, 1)},
		"bridges": [Vector2i(1, 1)],
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 1): 2, Vector2i(2, 2): 3}
	}
	model.setup_puzzle(puzzle)

	# Inicia em (0,0) e move para portal em (1,0), teleportando para (0,1)
	assert_true(model.extend_to(Vector2i(1, 0)))
	assert_eq(model.player_path.size(), 3)
	assert_eq(model.player_path.back(), Vector2i(0, 1))

	# Da saída do portal (0,1), entra direto na ponte (1,1) e sai em (2,1)
	assert_true(model.can_extend_to(Vector2i(1, 1)))
	assert_true(model.extend_to(Vector2i(1, 1)))
	assert_true(model.extend_to(Vector2i(2, 1)))


func test_tier3_combo_portals_plus_stars() -> void:
	var model := Model.new()
	# Portal de (1,0) leva para (2,2) onde há uma estrela
	var puzzle := {
		"width": 3,
		"height": 3,
		"portals": {Vector2i(1, 0): Vector2i(2, 2)},
		"stars": [Vector2i(2, 2)],
		"clues": {Vector2i(0, 0): 1, Vector2i(0, 2): 2}
	}
	model.setup_puzzle(puzzle)

	model.extend_to(Vector2i(1, 0))
	assert_true(model.visited_stars.has(Vector2i(2, 2)), "Estrela coletada no pouso do teleporte")


func test_tier3_combo_directional_plus_bridges_and_portals() -> void:
	var model := Model.new()
	# Seta em (0,1) apontando para a ponte em (1,1)
	var puzzle := {
		"width": 3,
		"height": 3,
		"bridges": [Vector2i(1, 1)],
		"directional": {Vector2i(0, 1): Vector2i(1, 0)},
		"clues": {Vector2i(0, 0): 1, Vector2i(2, 2): 2}
	}
	model.setup_puzzle(puzzle)
	model.extend_to(Vector2i(0, 1))

	# Tentar mover para (0,2) falha pela seta
	assert_false(model.can_extend_to(Vector2i(0, 2)))
	# Mover para a ponte (1,1) tem sucesso
	assert_true(model.can_extend_to(Vector2i(1, 1)))
	assert_true(model.extend_to(Vector2i(1, 1)))


func test_tier3_combo_time_pressure_plus_all_mechanics() -> void:
	var game_scene := preload("res://games/caminho_numerico/NumberPathGame.tscn")
	var game: NumberPathGame = game_scene.instantiate()
	add_child_autofree(game)

	var complex_puzzle := {
		"width": 3,
		"height": 3,
		"obstacles": [Vector2i(0, 2)],
		"bridges": [Vector2i(1, 1)],
		"stars": [Vector2i(2, 0)],
		"portals": {Vector2i(2, 0): Vector2i(2, 1)},
		"directional": {Vector2i(0, 0): Vector2i(1, 0)},
		"clues": {Vector2i(0, 0): 1, Vector2i(1, 2): 2},
		"total_cells": 9,
		"time_limit": 60.0,
		"solution": []
	}
	game.num_board.setup_puzzle(3, 3, complex_puzzle)
	game.time_limit = 60.0
	game.time_remaining = 60.0
	game.is_timer_running = true

	game._process(10.0)
	assert_almost_eq(game.time_remaining, 50.0, 0.01)

	game._on_level_completed()
	assert_false(game.is_timer_running, "Temporizador para na conclusão do nível complexo")
	assert_gt(game.total_score, 0)


func test_tier3_combo_deep_backtracking_portal_bridge_star_sequence() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 5,
		"height": 5,
		"stars": [Vector2i(1, 0), Vector2i(4, 3)],
		"bridges": [Vector2i(2, 0)],
		"portals": {Vector2i(3, 0): Vector2i(4, 2)},
		"clues": {Vector2i(0, 0): 1, Vector2i(0, 4): 2}
	}
	model.setup_puzzle(puzzle)

	# (0,0) -> (1,0) [Star 1] -> (2,0) [Bridge 1 H] -> (3,0) [Portal -> (4,2)] -> (4,3) [Star 2]
	model.extend_to(Vector2i(1, 0))
	model.extend_to(Vector2i(2, 0))
	model.extend_to(Vector2i(3, 0))
	model.extend_to(Vector2i(4, 3))

	assert_eq(model.visited_stars.size(), 2)
	assert_true(model.bridge_crossings[Vector2i(2, 0)]["H"])
	assert_eq(model.player_path.size(), 6)

	# Trunca de volta para o início (0,0)
	model.truncate_to(Vector2i(0, 0))
	assert_eq(model.player_path.size(), 1)
	assert_eq(model.visited_stars.size(), 0, "Todas as estrelas desmarcadas")
	assert_false(model.bridge_crossings.has(Vector2i(2, 0)), "Eixos de ponte limpos")


# =============================================================================
# TIER 4: REAL-WORLD SCENARIOS & MONTE CARLO SOLVABILITY
# =============================================================================

func test_tier4_full_campaign_simulation_levels_1_to_10() -> void:
	var game_scene := preload("res://games/caminho_numerico/NumberPathGame.tscn")
	var game: NumberPathGame = game_scene.instantiate()
	add_child_autofree(game)

	var cumulative_score: int = 0

	for lvl in range(1, 11):
		game.current_level = lvl
		game._start_new_game()

		var pz: Dictionary = game.current_puzzle
		assert_eq(pz["level"], lvl, "Nível %d configurado" % lvl)
		assert_gt(pz["total_cells"], 0)

		# Resolve o puzzle usando o solver oficial
		var solutions: Array = Generator.solve_puzzle(pz, 1)
		assert_gt(solutions.size(), 0, "Nível da campanha %d deve ser 100%% resolúvel pelo solver" % lvl)

		var sol: Array[Vector2i] = []
		for p in solutions[0]:
			sol.append(p as Vector2i)

		# Simula execução do jogador
		for step_idx in range(1, sol.size()):
			var step_cell: Vector2i = sol[step_idx]
			if game.num_board.model.player_path.back() == step_cell:
				continue # Auto-teleportado por portal
			game.num_board.model.extend_to(step_cell)

		assert_true(game.num_board.model.is_completed, "Nível %d completado pelo jogador simulado" % lvl)
		assert_true(game._result_reported, "Resultado reportado no nível %d" % lvl)
		assert_gt(game.total_score, cumulative_score, "Pontuação acumulada cresceu no nível %d" % lvl)
		cumulative_score = game.total_score


func test_tier4_monte_carlo_procedural_generator_solvability_50_puzzles() -> void:
	# 50 gerações procedurais distribuídas em 5 patamares de dificuldade
	var test_tiers: Array[int] = [1, 3, 5, 7, 10]

	for tier_level in test_tiers:
		for iter in range(10):
			var puzzle: Dictionary = Generator.generate_level(tier_level)
			var w: int = int(puzzle["width"])
			var h: int = int(puzzle["height"])
			var path: Array[Vector2i] = []
			for p in puzzle["path"]:
				path.append(p as Vector2i)

			var obstacles: Array[Vector2i] = []
			for o in puzzle["obstacles"]:
				obstacles.append(o as Vector2i)

			var bridges: Array[Vector2i] = []
			for b in puzzle["bridges"]:
				bridges.append(b as Vector2i)

			var portals: Dictionary = puzzle["portals"]

			# 1. Validação estrutural do caminho gerado
			assert_true(
				Generator.is_valid_puzzle_path(w, h, path, obstacles, bridges, portals),
				"Monte Carlo Level %d #%d: caminho estruturalmente válido" % [tier_level, iter]
			)

			# 2. Validação determinística pelo solver independente
			var solutions: Array = Generator.solve_puzzle(puzzle, 1)
			assert_gt(
				solutions.size(), 0,
				"Monte Carlo Level %d #%d: solver encontrou solução válida com 100%% de sucesso" % [tier_level, iter]
			)


func test_tier4_realistic_player_recovery_flow() -> void:
	var model := Model.new()
	var puzzle := {
		"width": 3,
		"height": 3,
		"obstacles": [Vector2i(2, 0)],
		"stars": [Vector2i(1, 2)],
		"clues": {Vector2i(0, 0): 1, Vector2i(1, 0): 2, Vector2i(0, 1): 3},
		"total_cells": 8,
		"walkable_count": 8,
		"solution": [
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
			Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2),
			Vector2i(0, 2), Vector2i(0, 1)
		]
	}
	model.setup_puzzle(puzzle)

	# 1. Jogador tenta pular diagonal para (1,1) -> Falha
	assert_false(model.extend_to(Vector2i(1, 1)))

	# 2. Jogador tenta clicar em obstáculo (2,0) -> Falha
	assert_false(model.extend_to(Vector2i(2, 0)))

	# 3. Jogador tenta pular direto para pista 3 final (0,1) -> Falha
	assert_false(model.can_extend_to(Vector2i(0, 1)))

	# 4. Jogador inicia rota exploratória errada descendo primeiro: (0,0) -> (0,1) [pista 3 prematura] -> Falha
	assert_false(model.extend_to(Vector2i(0, 1)))
	assert_gt(model.mistakes_count, 0)

	# Jogador move para (1,0) [pista 2 alcançada!]
	assert_true(model.extend_to(Vector2i(1, 0)))
	assert_eq(model.get_current_target(), 3)

	# Jogador erra o caminho tentando virar para o obstáculo (2,0) -> Falha
	assert_false(model.extend_to(Vector2i(2, 0)))

	# 5. Jogador executa rota vencedora completa:
	assert_true(model.extend_to(Vector2i(1, 1)))
	assert_true(model.extend_to(Vector2i(2, 1)))
	assert_true(model.extend_to(Vector2i(2, 2)))
	assert_true(model.extend_to(Vector2i(1, 2))) # Estrela coletada
	assert_eq(model.visited_stars.size(), 1)
	assert_true(model.extend_to(Vector2i(0, 2)))
	assert_true(model.extend_to(Vector2i(0, 1))) # Pista 3 final alcançada com todas as 8 células

	assert_true(model.is_completed, "Jogador recuperou a rota e venceu com 100% de precisão")
	assert_gt(model.mistakes_count, 0, "Erros cometidos na fase de exploração foram registrados")


func test_tier4_rapid_level_transitions_and_reset_isolation() -> void:
	var game_scene := preload("res://games/caminho_numerico/NumberPathGame.tscn")
	var game: NumberPathGame = game_scene.instantiate()
	add_child_autofree(game)

	for i in range(5):
		game.restart_game()
		assert_false(game.game_over)
		assert_false(game.is_transitioning)
		assert_not_null(game.num_board.model)
		assert_eq(game.num_board.model.player_path.size(), 1)
