class_name NumberPathGenerator
extends RefCounted

## Gerador procedural e solver determinístico para Caminho Numérico (Number Path).
##
## Propriedades e garantias matemáticas:
## 1. Grade bipartida & Invariantes de Paridade:
##    Em qualquer grade livre com obstáculos V_free = V \ O, um caminho hamiltoniano
##    só existe se |V_free,even - V_free,odd| <= 1. O ponto de partida é rigorosamente
##    filtrado para a partição majoritária.
## 2. Pontes e Túneis (Decomposição em Vértice Dual Virtual):
##    Células de ponte suportam dois cruzamentos estritamente ortogonais e retos
##    (horizontal e vertical), incrementando o comprimento efetivo do caminho em 1 por ponte.
## 3. Estrelas Obrigatórias & Pistas Monotônicas:
##    Pistas numéricas 1..K surgem estritamente em ordem crescente ao longo do caminho.
##    Estrelas obrigatórias são posicionadas em células sem números e bloqueiam a vitória
##    caso não sejam todas coletadas antes do checkpoint final.
## 4. Mecânicas Bônus Criativas:
##    - Setas Direcionais (directional): forçam a orientação de saída do passo.
##    - Portais Quânticos (portals): pontos de teleporte instantâneo não-adjacente.
## 5. Hierarquia Fail-Safe de 3 Níveis:
##    - Nível 1: DFS Warnsdorff com poda por menor grau e desempate aleatório (< 8000 nós).
##    - Nível 2: Retry Adaptativo com regeneração de obstáculos e relaxamento de pontes.
##    - Nível 3: Fallback Serpentine Determinístico (0.0 ms, 100% resolúvel).
## 6. Solver por Backtracking Embutido (`solve_puzzle`):
##    Validação autônoma de resolutividade para todas as mecânicas.

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]


# =============================================================================
# 1. API PÚBLICA PRINCIPAL
# =============================================================================

## Gera um caminho hamiltoniano básico em grade retangular limpa.
static func generate_path(w: int, h: int, max_dfs_nodes: int = 8000) -> Array[Vector2i]:
	var res: Dictionary = generate_path_advanced(w, h, [], 0, false, max_dfs_nodes)
	var p: Array[Vector2i] = res.get("path", [] as Array[Vector2i])
	if p.is_empty():
		return _generate_serpentine_path(w, h)
	return p


## Gera um caminho com suporte a obstáculos, pontes e portais quânticos.
static func generate_path_advanced(
	w: int,
	h: int,
	obstacles: Array[Vector2i] = [],
	target_bridges: int = 0,
	allow_portal: bool = false,
	max_dfs_nodes: int = 4000
) -> Dictionary:
	var obs_set: Dictionary = {}
	for o in obstacles:
		obs_set[o] = true

	var walkable_count: int = w * h - obstacles.size()
	if walkable_count <= 0:
		return {"path": [] as Array[Vector2i], "bridges": [] as Array[Vector2i], "portals": {}}
	if walkable_count == 1:
		for y in range(h):
			for x in range(w):
				var c := Vector2i(x, y)
				if not obs_set.has(c):
					return {"path": [c] as Array[Vector2i], "bridges": [] as Array[Vector2i], "portals": {}}

	# Classificação por partição bipartida
	var even_cells: Array[Vector2i] = []
	var odd_cells: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			var c := Vector2i(x, y)
			if not obs_set.has(c):
				if (x + y) % 2 == 0:
					even_cells.append(c)
				else:
					odd_cells.append(c)

	var candidates: Array[Vector2i] = []
	if even_cells.size() > odd_cells.size():
		candidates = even_cells.duplicate()
	elif odd_cells.size() > even_cells.size():
		candidates = odd_cells.duplicate()
	else:
		candidates = even_cells + odd_cells

	candidates.shuffle()

	# Tentativa decrescente do alvo de pontes
	var bridge_targets: Array[int] = [target_bridges]
	if target_bridges > 0:
		for b in range(target_bridges - 1, -1, -1):
			bridge_targets.append(b)

	var budget_per_bridge_target: int = maxi(300, int(max_dfs_nodes / maxi(1, bridge_targets.size())))
	var max_per_candidate: int = mini(150, budget_per_bridge_target)

	for b_count in bridge_targets:
		var target_len: int = walkable_count + b_count
		var b_target_steps: Array[int] = [0]
		for start_pos in candidates:
			if b_target_steps[0] >= budget_per_bridge_target:
				break

			var path: Array[Vector2i] = []
			var bridges: Array[Vector2i] = []
			var portals: Dictionary = {}
			var visit_count: Dictionary = {}
			var straight_axis: Dictionary = {}
			var portal_jump_used: Array[bool] = [false]
			var candidate_steps: Array[int] = [0]

			if _dfs_warnsdorff_advanced(
				start_pos,
				Vector2i.ZERO,
				w,
				h,
				obs_set,
				target_len,
				b_count,
				allow_portal,
				visit_count,
				straight_axis,
				path,
				bridges,
				portals,
				portal_jump_used,
				candidate_steps,
				max_per_candidate,
				b_target_steps,
				budget_per_bridge_target
			):
				return {"path": path, "bridges": bridges, "portals": portals}

	return {"path": [] as Array[Vector2i], "bridges": [] as Array[Vector2i], "portals": {}}


## Gera um quebra-cabeça canônico completo com todas as mecânicas integradas.
static func generate_puzzle(w: int, h: int, config_or_clues = 4) -> Dictionary:
	var total_cells_grid: int = w * h
	if total_cells_grid <= 0:
		return {
			"level": 1,
			"width": maxi(0, w),
			"height": maxi(0, h),
			"total_cells": 0,
			"walkable_count": 0,
			"obstacles": [] as Array[Vector2i],
			"bridges": [] as Array[Vector2i],
			"stars": [] as Array[Vector2i],
			"portals": {},
			"directional": {},
			"path": [] as Array[Vector2i],
			"solution": [] as Array[Vector2i],
			"clues": {},
			"clues_count": 0,
			"start_cell": Vector2i(-1, -1),
			"end_cell": Vector2i(-1, -1),
			"max_number": 0,
			"time_limit": 0.0,
			"par_time": 0.0,
			"difficulty_tier": "Tutorial",
		}

	var clues_target: int = 4
	var obstacles_target: int = 0
	var bridges_target: int = 0
	var stars_target: int = 0
	var directional_target: int = 0
	var portals_target: int = 0
	var time_limit_val: float = 0.0
	var par_time_val: float = 0.0
	var diff_tier: String = "Tutorial"
	var level_num: int = 1

	if typeof(config_or_clues) == TYPE_DICTIONARY:
		var cfg: Dictionary = config_or_clues
		clues_target = int(cfg.get("clues_count", cfg.get("clues", 4)))
		obstacles_target = int(cfg.get("obstacles_count", cfg.get("obstacles", 0)))
		bridges_target = int(cfg.get("bridges_count", cfg.get("bridges", 0)))
		stars_target = int(cfg.get("stars_count", cfg.get("stars", 0)))
		directional_target = int(cfg.get("directional_count", cfg.get("directional", 0)))
		portals_target = int(cfg.get("portals_count", cfg.get("portals", 0)))
		time_limit_val = float(cfg.get("time_limit", 0.0))
		par_time_val = float(cfg.get("par_time", 0.0))
		diff_tier = str(cfg.get("difficulty_tier", "Tutorial"))
		level_num = int(cfg.get("level", 1))
	elif typeof(config_or_clues) == TYPE_INT or typeof(config_or_clues) == TYPE_FLOAT:
		clues_target = int(config_or_clues)

	# --- Tier 1: Constrained Warnsdorff DFS ---
	var obstacles: Array[Vector2i] = place_obstacles_safely(w, h, obstacles_target)
	var allow_portal: bool = (portals_target > 0)
	var adv_res: Dictionary = generate_path_advanced(w, h, obstacles, bridges_target, allow_portal, 1200)
	var path: Array[Vector2i] = adv_res["path"]
	var bridges: Array[Vector2i] = adv_res["bridges"]
	var portals: Dictionary = adv_res["portals"]

	# --- Tier 2: Adaptive Retry ---
	if path.is_empty():
		for retry in range(3):
			var retry_obs_count: int = maxi(0, obstacles_target - (retry + 1))
			obstacles = place_obstacles_safely(w, h, retry_obs_count)
			var retry_bridges: int = maxi(0, bridges_target - (1 if retry > 0 else 0))
			adv_res = generate_path_advanced(w, h, obstacles, retry_bridges, allow_portal and retry == 0, 800)
			path = adv_res["path"]
			bridges = adv_res["bridges"]
			portals = adv_res["portals"]
			if not path.is_empty():
				break

	# --- Tier 3: Deterministic Serpentine Fallback ---
	if path.is_empty():
		path = _generate_serpentine_path(w, h)
		obstacles.clear()
		bridges.clear()
		portals.clear()

	var total_cells: int = path.size()
	var walkable_count: int = (w * h) - obstacles.size()

	# --- Infusão Determinística de Features ---
	# 1. Pistas Numéricas Monotônicas
	var clues: Dictionary = place_clues(path, clues_target, bridges, portals)
	var actual_clues_count: int = clues.size()
	var start_pos: Vector2i = path[0] if not path.is_empty() else Vector2i(-1, -1)
	var end_pos: Vector2i = path.back() if not path.is_empty() else Vector2i(-1, -1)

	# 2. Estrelas Obrigatórias
	var stars: Array[Vector2i] = place_stars(path, clues, stars_target, bridges, portals)

	# 3. Setas Direcionais
	var directional: Dictionary = place_directional(path, clues, stars, directional_target, bridges, portals)

	# 4. Cálculo dinâmico de tempos caso não especificados
	if time_limit_val <= 0.0:
		var step_time: float = maxf(2.0, 4.5 - float(level_num) * 0.08)
		time_limit_val = round(12.0 + float(total_cells) * step_time)
	if par_time_val <= 0.0:
		par_time_val = round(float(total_cells) * 2.0)

	return {
		"level": level_num,
		"width": w,
		"height": h,
		"total_cells": total_cells,
		"walkable_count": walkable_count,
		"obstacles": obstacles,
		"bridges": bridges,
		"stars": stars,
		"portals": portals,
		"directional": directional,
		"path": path,
		"solution": path.duplicate(),
		"clues": clues,
		"clues_count": actual_clues_count,
		"start_cell": start_pos,
		"end_cell": end_pos,
		"max_number": actual_clues_count,
		"time_limit": time_limit_val,
		"par_time": par_time_val,
		"difficulty_tier": diff_tier,
	}


## Escalonamento progressivo de níveis (1 a 30+).
static func generate_level(level: int) -> Dictionary:
	var safe_level: int = maxi(1, level)
	var config: Dictionary = {
		"level": safe_level,
	}

	if safe_level == 1:
		config["width"] = 3; config["height"] = 3
		config["clues_count"] = 4
		config["obstacles_count"] = 0
		config["bridges_count"] = 0
		config["stars_count"] = 0
		config["directional_count"] = 0
		config["portals_count"] = 0
		config["time_limit"] = 25.0
		config["par_time"] = 12.0
		config["difficulty_tier"] = "Tutorial"
	elif safe_level == 2:
		config["width"] = 3; config["height"] = 3
		config["clues_count"] = 3
		config["obstacles_count"] = 0
		config["bridges_count"] = 0
		config["stars_count"] = 0
		config["directional_count"] = 0
		config["portals_count"] = 0
		config["time_limit"] = 25.0
		config["par_time"] = 15.0
		config["difficulty_tier"] = "Tutorial"
	elif safe_level == 3:
		config["width"] = 4; config["height"] = 4
		config["clues_count"] = 5
		config["obstacles_count"] = 0
		config["bridges_count"] = 0
		config["stars_count"] = 1
		config["directional_count"] = 0
		config["portals_count"] = 0
		config["time_limit"] = 35.0
		config["par_time"] = 20.0
		config["difficulty_tier"] = "Iniciante"
	elif safe_level == 4:
		config["width"] = 4; config["height"] = 4
		config["clues_count"] = 4
		config["obstacles_count"] = 1
		config["bridges_count"] = 0
		config["stars_count"] = 1
		config["directional_count"] = 0
		config["portals_count"] = 0
		config["time_limit"] = 40.0
		config["par_time"] = 24.0
		config["difficulty_tier"] = "Iniciante"
	elif safe_level == 5:
		config["width"] = 5; config["height"] = 5
		config["clues_count"] = 7
		config["obstacles_count"] = 1
		config["bridges_count"] = 0
		config["stars_count"] = 2
		config["directional_count"] = 0
		config["portals_count"] = 0
		config["time_limit"] = 45.0
		config["par_time"] = 28.0
		config["difficulty_tier"] = "Iniciante"
	elif safe_level == 6:
		config["width"] = 5; config["height"] = 5
		config["clues_count"] = 6
		config["obstacles_count"] = 1
		config["bridges_count"] = 1
		config["stars_count"] = 1
		config["directional_count"] = 1
		config["portals_count"] = 0
		config["time_limit"] = 50.0
		config["par_time"] = 32.0
		config["difficulty_tier"] = "Médio"
	elif safe_level == 7:
		config["width"] = 5; config["height"] = 5
		config["clues_count"] = 5
		config["obstacles_count"] = 2
		config["bridges_count"] = 1
		config["stars_count"] = 2
		config["directional_count"] = 1
		config["portals_count"] = 0
		config["time_limit"] = 55.0
		config["par_time"] = 36.0
		config["difficulty_tier"] = "Médio"
	elif safe_level == 8:
		config["width"] = 6; config["height"] = 6
		config["clues_count"] = 9
		config["obstacles_count"] = 2
		config["bridges_count"] = 1
		config["stars_count"] = 2
		config["directional_count"] = 1
		config["portals_count"] = 0
		config["time_limit"] = 65.0
		config["par_time"] = 45.0
		config["difficulty_tier"] = "Médio"
	elif safe_level == 9:
		config["width"] = 6; config["height"] = 6
		config["clues_count"] = 7
		config["obstacles_count"] = 3
		config["bridges_count"] = 1
		config["stars_count"] = 2
		config["directional_count"] = 1
		config["portals_count"] = 0
		config["time_limit"] = 70.0
		config["par_time"] = 50.0
		config["difficulty_tier"] = "Difícil"
	elif safe_level == 10:
		config["width"] = 6; config["height"] = 6
		config["clues_count"] = 7
		config["obstacles_count"] = 4
		config["bridges_count"] = 2
		config["stars_count"] = 3
		config["directional_count"] = 2
		config["portals_count"] = 0
		config["time_limit"] = 75.0
		config["par_time"] = 55.0
		config["difficulty_tier"] = "Difícil"
	elif safe_level == 11:
		config["width"] = 6; config["height"] = 6
		config["clues_count"] = 6
		config["obstacles_count"] = 5
		config["bridges_count"] = 2
		config["stars_count"] = 3
		config["directional_count"] = 2
		config["portals_count"] = 0
		config["time_limit"] = 80.0
		config["par_time"] = 60.0
		config["difficulty_tier"] = "Difícil"
	elif safe_level == 12:
		config["width"] = 7; config["height"] = 7
		config["clues_count"] = 9
		config["obstacles_count"] = 4
		config["bridges_count"] = 2
		config["stars_count"] = 3
		config["directional_count"] = 2
		config["portals_count"] = 0
		config["time_limit"] = 85.0
		config["par_time"] = 65.0
		config["difficulty_tier"] = "Especialista"
	elif safe_level == 13:
		config["width"] = 7; config["height"] = 7
		config["clues_count"] = 8
		config["obstacles_count"] = 6
		config["bridges_count"] = 2
		config["stars_count"] = 4
		config["directional_count"] = 2
		config["portals_count"] = 1
		config["time_limit"] = 90.0
		config["par_time"] = 70.0
		config["difficulty_tier"] = "Especialista"
	elif safe_level == 14:
		config["width"] = 7; config["height"] = 7
		config["clues_count"] = 7
		config["obstacles_count"] = 8
		config["bridges_count"] = 3
		config["stars_count"] = 4
		config["directional_count"] = 2
		config["portals_count"] = 1
		config["time_limit"] = 95.0
		config["par_time"] = 75.0
		config["difficulty_tier"] = "Especialista"
	else:
		config["width"] = 7; config["height"] = 7
		var scale_offset: int = safe_level - 15
		config["clues_count"] = maxi(5, 7 - int(scale_offset * 0.12))
		config["obstacles_count"] = clampi(6 + int(scale_offset * 0.4), 6, 11)
		config["bridges_count"] = clampi(2 + int(scale_offset * 0.2), 2, 4)
		config["stars_count"] = clampi(3 + int(scale_offset * 0.2), 3, 5)
		config["directional_count"] = 2
		config["portals_count"] = 1 if safe_level % 2 == 1 else 0
		config["time_limit"] = maxf(50.0, 100.0 - float(scale_offset) * 1.5)
		config["par_time"] = maxf(35.0, 80.0 - float(scale_offset) * 1.2)
		config["difficulty_tier"] = "Mestre"

	var w: int = int(config["width"])
	var h: int = int(config["height"])
	return generate_puzzle(w, h, config)


# =============================================================================
# 2. SOLVER POR BACKTRACKING COM RESTRIÇÕES
# =============================================================================

## Resolve o quebra-cabeça e retorna até `max_solutions` caminhos válidos.
static func solve_puzzle(puzzle: Dictionary, max_solutions: int = 1) -> Array:
	var w: int = int(puzzle.get("width", 3))
	var h: int = int(puzzle.get("height", 3))
	var clues: Dictionary = puzzle.get("clues", {})
	var raw_obs: Array = puzzle.get("obstacles", [])
	var raw_bridges: Array = puzzle.get("bridges", [])
	var raw_stars: Array = puzzle.get("stars", [])
	var raw_directional: Dictionary = puzzle.get("directional", {})
	var raw_portals: Dictionary = puzzle.get("portals", {})
	var start_cell: Vector2i = puzzle.get("start_cell", Vector2i(-1, -1))
	var total_target: int = int(puzzle.get("total_cells", w * h))

	var obs_set: Dictionary = {}
	for o in raw_obs:
		obs_set[o as Vector2i] = true

	var bridge_set: Dictionary = {}
	for b in raw_bridges:
		bridge_set[b as Vector2i] = true

	var star_set: Dictionary = {}
	for s in raw_stars:
		star_set[s as Vector2i] = true

	var directional: Dictionary = {}
	for k in raw_directional.keys():
		directional[k as Vector2i] = raw_directional[k] as Vector2i

	var portals: Dictionary = {}
	for k in raw_portals.keys():
		portals[k as Vector2i] = raw_portals[k] as Vector2i

	if start_cell == Vector2i(-1, -1):
		for cell in clues.keys():
			if int(clues[cell]) == 1:
				start_cell = cell as Vector2i
				break

	if start_cell == Vector2i(-1, -1):
		return []

	var max_num: int = 0
	for cell in clues.keys():
		var num: int = int(clues[cell])
		if num > max_num:
			max_num = num

	var solutions: Array = []
	var path: Array[Vector2i] = [start_cell]
	var visited_counts: Dictionary = {start_cell: 1}
	var visited_stars: Dictionary = {}
	if star_set.has(start_cell):
		visited_stars[start_cell] = true

	var bridge_axes: Dictionary = {}

	# Se a célula inicial possui portal, auto-teleporta
	if portals.has(start_cell):
		var dest: Vector2i = portals[start_cell]
		path.append(dest)
		visited_counts[dest] = 1
		if star_set.has(dest):
			visited_stars[dest] = true

	_solve_dfs(
		path.back(),
		2,
		max_num,
		w,
		h,
		obs_set,
		bridge_set,
		star_set,
		directional,
		portals,
		clues,
		total_target,
		path,
		visited_counts,
		visited_stars,
		bridge_axes,
		solutions,
		max_solutions
	)

	return solutions


static func _solve_dfs(
	curr: Vector2i,
	next_target: int,
	max_num: int,
	w: int,
	h: int,
	obs_set: Dictionary,
	bridge_set: Dictionary,
	star_set: Dictionary,
	directional: Dictionary,
	portals: Dictionary,
	clues: Dictionary,
	total_target: int,
	path: Array[Vector2i],
	visited_counts: Dictionary,
	visited_stars: Dictionary,
	bridge_axes: Dictionary,
	solutions: Array,
	max_solutions: int
) -> void:
	if solutions.size() >= max_solutions:
		return

	if path.size() == total_target:
		var last: Vector2i = path.back()
		if clues.has(last) and int(clues[last]) == max_num:
			if visited_stars.size() >= star_set.size():
				solutions.append(path.duplicate())
		return

	# Determina direções candidatas a partir de curr
	var candidate_dirs: Array[Vector2i] = []

	# 1. Regra de saída reta em pontes
	if bridge_set.has(curr) and path.size() >= 2:
		var prev_cell: Vector2i = path[path.size() - 2]
		if (abs(curr.x - prev_cell.x) + abs(curr.y - prev_cell.y)) == 1:
			var straight_dir: Vector2i = curr - prev_cell
			candidate_dirs = [straight_dir]
	# 2. Seta direcional
	elif directional.has(curr):
		candidate_dirs = [directional[curr] as Vector2i]
	else:
		candidate_dirs = DIRS

	var valid_moves: Array[Dictionary] = []

	for dir in candidate_dirs:
		var nxt: Vector2i = curr + dir
		if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h or obs_set.has(nxt):
			continue

		var visits: int = int(visited_counts.get(nxt, 0))
		var is_bridge: bool = bridge_set.has(nxt)
		var max_allowed_visits: int = 2 if is_bridge else 1
		if visits >= max_allowed_visits:
			continue

		var move_axis: String = "H" if dir.x != 0 else "V"
		if is_bridge:
			var axes: Dictionary = bridge_axes.get(nxt, {})
			if axes.get(move_axis, false):
				continue

		var clue_val: int = int(clues.get(nxt, -1))
		var updated_target: int = next_target
		if clue_val != -1:
			if clue_val != next_target:
				continue
			# Bloqueio de entrada prematura no checkpoint final
			if clue_val == max_num:
				var will_have_stars: int = visited_stars.size() + (1 if (star_set.has(nxt) and not visited_stars.has(nxt)) else 0)
				var projected_len: int = path.size() + (2 if portals.has(nxt) else 1)
				if projected_len < total_target:
					continue
				if will_have_stars < star_set.size():
					continue
			updated_target = next_target + 1

		# Calcula grau Warnsdorff para ordenar busca no solver
		var deg: int = 0
		for d in DIRS:
			var test_c := nxt + d
			if test_c.x >= 0 and test_c.x < w and test_c.y >= 0 and test_c.y < h:
				if not obs_set.has(test_c):
					var tv: int = int(visited_counts.get(test_c, 0))
					var tm: int = 2 if bridge_set.has(test_c) else 1
					if tv < tm:
						deg += 1

		valid_moves.append({
			"nxt": nxt,
			"dir": dir,
			"move_axis": move_axis,
			"is_bridge": is_bridge,
			"visits": visits,
			"updated_target": updated_target,
			"deg": deg
		})

	# Ordena por menor grau (Warnsdorff)
	valid_moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["deg"]) < int(b["deg"])
	)

	for m in valid_moves:
		var nxt: Vector2i = m["nxt"]
		var dir: Vector2i = m["dir"]
		var move_axis: String = m["move_axis"]
		var is_bridge: bool = m["is_bridge"]
		var visits: int = m["visits"]
		var updated_target: int = m["updated_target"]

		# Aplica movimento
		visited_counts[nxt] = visits + 1
		path.append(nxt)
		var star_added: bool = false
		if star_set.has(nxt) and not visited_stars.has(nxt):
			visited_stars[nxt] = true
			star_added = true

		if is_bridge:
			if not bridge_axes.has(nxt):
				bridge_axes[nxt] = {"H": false, "V": false}
			bridge_axes[nxt][move_axis] = true

		# Teleporte de portal
		var took_portal: bool = false
		var portal_dest := Vector2i(-1, -1)
		var p_dest_star_added: bool = false
		var portal_updated_target: int = updated_target

		if portals.has(nxt):
			portal_dest = portals[nxt]
			var p_dest_visits: int = int(visited_counts.get(portal_dest, 0))
			var p_dest_max: int = 2 if bridge_set.has(portal_dest) else 1
			if p_dest_visits < p_dest_max:
				took_portal = true
				visited_counts[portal_dest] = p_dest_visits + 1
				path.append(portal_dest)
				if star_set.has(portal_dest) and not visited_stars.has(portal_dest):
					visited_stars[portal_dest] = true
					p_dest_star_added = true

				var p_clue: int = int(clues.get(portal_dest, -1))
				if p_clue != -1 and p_clue == portal_updated_target:
					portal_updated_target += 1

		# Recursão
		var next_curr: Vector2i = portal_dest if took_portal else nxt
		_solve_dfs(
			next_curr,
			portal_updated_target,
			max_num,
			w,
			h,
			obs_set,
			bridge_set,
			star_set,
			directional,
			portals,
			clues,
			total_target,
			path,
			visited_counts,
			visited_stars,
			bridge_axes,
			solutions,
			max_solutions
		)

		# Backtrack portal
		if took_portal:
			path.pop_back()
			var p_v: int = int(visited_counts[portal_dest]) - 1
			if p_v <= 0:
				visited_counts.erase(portal_dest)
			else:
				visited_counts[portal_dest] = p_v
			if p_dest_star_added:
				visited_stars.erase(portal_dest)

		# Backtrack movimento principal
		path.pop_back()
		if visits == 0:
			visited_counts.erase(nxt)
		else:
			visited_counts[nxt] = visits

		if is_bridge and bridge_axes.has(nxt):
			bridge_axes[nxt][move_axis] = false

		if star_added:
			visited_stars.erase(nxt)

		if solutions.size() >= max_solutions:
			return


# =============================================================================
# 3. WARNSDORFF DFS ENGINE COM TRAVESSIA ATÔMICA DE PONTES
# =============================================================================

static func _dfs_warnsdorff_advanced(
	curr: Vector2i,
	prev_dir: Vector2i,
	w: int,
	h: int,
	obs_set: Dictionary,
	target_len: int,
	target_bridges: int,
	allow_portal: bool,
	visit_count: Dictionary,
	straight_axis: Dictionary,
	path: Array[Vector2i],
	bridges: Array[Vector2i],
	portals: Dictionary,
	portal_jump_used: Array[bool],
	steps: Array[int],
	max_nodes_candidate: int,
	global_steps: Array[int],
	max_nodes_global: int
) -> bool:
	steps[0] += 1
	global_steps[0] += 1
	if steps[0] > max_nodes_candidate or global_steps[0] > max_nodes_global:
		return false

	visit_count[curr] = int(visit_count.get(curr, 0)) + 1
	path.append(curr)

	if path.size() == target_len:
		return true

	var moves: Array[Dictionary] = []

	for dir in DIRS:
		var nxt := curr + dir
		if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h or obs_set.has(nxt):
			continue

		var n_visits: int = int(visit_count.get(nxt, 0))

		# 1. Célula livre não visitada
		if n_visits == 0:
			var deg: int = _calc_degree(nxt, w, h, obs_set, visit_count)
			moves.append({
				"type": "NORMAL",
				"next": nxt,
				"dir": dir,
				"deg": deg,
				"rand": randf()
			})

		# 2. Candidata a cruzamento de ponte ortogonal (travessia atômica reta de 2 passos)
		elif n_visits == 1 and bridges.size() < target_bridges:
			var first_pass_axis: String = straight_axis.get(nxt, "")
			var cross_axis: String = "H" if dir.x != 0 else "V"
			var is_orthogonal: bool = (first_pass_axis == "H" and cross_axis == "V") or (first_pass_axis == "V" and cross_axis == "H")
			if is_orthogonal:
				var exit_cell: Vector2i = nxt + dir
				if exit_cell.x >= 0 and exit_cell.x < w and exit_cell.y >= 0 and exit_cell.y < h:
					if not obs_set.has(exit_cell) and int(visit_count.get(exit_cell, 0)) == 0:
						var deg_exit: int = _calc_degree(exit_cell, w, h, obs_set, visit_count)
						moves.append({
							"type": "BRIDGE_ATOMIC",
							"bridge_cell": nxt,
							"exit_cell": exit_cell,
							"dir": dir,
							"deg": deg_exit,
							"rand": randf()
						})

	# Ordenação de Warnsdorff (menor grau primeiro, desempate aleatório)
	moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["deg"] != b["deg"]:
			return int(a["deg"]) < int(b["deg"])
		return float(a["rand"]) < float(b["rand"])
	)

	# Tentativa de salto quântico de portal (quando habilitado e na faixa ideal 30%-60% do percurso)
	if allow_portal and not portal_jump_used[0] and path.size() >= int(float(target_len) * 0.3) and path.size() <= int(float(target_len) * 0.6):
		var portal_candidates: Array[Vector2i] = []
		for y in range(h):
			for x in range(w):
				var p_pos := Vector2i(x, y)
				if not obs_set.has(p_pos) and int(visit_count.get(p_pos, 0)) == 0:
					if (abs(p_pos.x - curr.x) + abs(p_pos.y - curr.y)) >= 3:
						portal_candidates.append(p_pos)

		if not portal_candidates.is_empty():
			portal_candidates.shuffle()
			var max_portal_tries: int = mini(3, portal_candidates.size())
			for p_idx in range(max_portal_tries):
				var dest_pos: Vector2i = portal_candidates[p_idx]
				portal_jump_used[0] = true
				portals[curr] = dest_pos
				portals[dest_pos] = curr

				if _dfs_warnsdorff_advanced(
					dest_pos, Vector2i.ZERO, w, h, obs_set, target_len, target_bridges,
					allow_portal, visit_count, straight_axis, path, bridges, portals,
					portal_jump_used, steps, max_nodes_candidate, global_steps, max_nodes_global
				):
					return true

				portals.erase(curr)
				portals.erase(dest_pos)
				portal_jump_used[0] = false

	# Executa os movimentos ordenados
	for m in moves:
		var m_type: String = m["type"]
		if m_type == "NORMAL":
			var nxt_pos: Vector2i = m["next"]
			var nxt_dir: Vector2i = m["dir"]

			var was_straight: bool = (prev_dir != Vector2i.ZERO and prev_dir == nxt_dir)
			if was_straight:
				straight_axis[curr] = "H" if nxt_dir.x != 0 else "V"

			if _dfs_warnsdorff_advanced(
				nxt_pos, nxt_dir, w, h, obs_set, target_len, target_bridges,
				allow_portal, visit_count, straight_axis, path, bridges, portals,
				portal_jump_used, steps, max_nodes_candidate, global_steps, max_nodes_global
			):
				return true

			if was_straight:
				straight_axis.erase(curr)

		elif m_type == "BRIDGE_ATOMIC":
			var b_cell: Vector2i = m["bridge_cell"]
			var e_cell: Vector2i = m["exit_cell"]
			var b_dir: Vector2i = m["dir"]

			path.append(b_cell)
			visit_count[b_cell] = 2
			bridges.append(b_cell)

			var prev_straight: String = straight_axis.get(curr, "")
			var was_straight: bool = (prev_dir != Vector2i.ZERO and prev_dir == b_dir)
			if was_straight:
				straight_axis[curr] = "H" if b_dir.x != 0 else "V"

			if _dfs_warnsdorff_advanced(
				e_cell, b_dir, w, h, obs_set, target_len, target_bridges,
				allow_portal, visit_count, straight_axis, path, bridges, portals,
				portal_jump_used, steps, max_nodes_candidate, global_steps, max_nodes_global
			):
				return true

			if was_straight:
				if prev_straight.is_empty():
					straight_axis.erase(curr)
				else:
					straight_axis[curr] = prev_straight

			bridges.erase(b_cell)
			visit_count[b_cell] = 1
			path.pop_back()

	path.pop_back()
	var c_cnt: int = int(visit_count.get(curr, 1)) - 1
	if c_cnt <= 0:
		visit_count.erase(curr)
		straight_axis.erase(curr)
	else:
		visit_count[curr] = c_cnt

	return false


static func _calc_degree(cell: Vector2i, w: int, h: int, obs_set: Dictionary, visit_count: Dictionary) -> int:
	var deg: int = 0
	for d in DIRS:
		var nxt := cell + d
		if nxt.x >= 0 and nxt.x < w and nxt.y >= 0 and nxt.y < h:
			if not obs_set.has(nxt) and int(visit_count.get(nxt, 0)) == 0:
				deg += 1
	return deg


static func _generate_serpentine_path(w: int, h: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(h):
		if y % 2 == 0:
			for x in range(w):
				result.append(Vector2i(x, y))
		else:
			for x in range(w - 1, -1, -1):
				result.append(Vector2i(x, y))
	return result


# =============================================================================
# 4. GERAÇÃO E VALIDAÇÃO DE OBSTÁCULOS
# =============================================================================

static func place_obstacles_safely(w: int, h: int, target_obs: int) -> Array[Vector2i]:
	var obstacles: Array[Vector2i] = []
	if target_obs <= 0 or w < 3 or h < 3:
		return obstacles

	var max_allowed: int = int(float(w * h) * 0.22)
	var desired: int = clampi(target_obs, 0, max_allowed)
	if desired == 0:
		return obstacles

	var candidates: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			var is_corner: bool = (x == 0 or x == w - 1) and (y == 0 or y == h - 1)
			if not is_corner:
				candidates.append(Vector2i(x, y))

	candidates.shuffle()

	for pos in candidates:
		if obstacles.size() >= desired:
			break
		obstacles.append(pos)
		if not _is_obstacle_layout_valid(w, h, obstacles):
			obstacles.pop_back()

	return obstacles


static func _is_obstacle_layout_valid(w: int, h: int, obstacles: Array) -> bool:
	var obs_set: Dictionary = {}
	for o in obstacles:
		obs_set[o as Vector2i] = true

	var total_walkable: int = w * h - obstacles.size()
	if total_walkable <= 0:
		return false

	var start_free := Vector2i(-1, -1)
	var even_count: int = 0
	var odd_count: int = 0

	for y in range(h):
		for x in range(w):
			var c := Vector2i(x, y)
			if not obs_set.has(c):
				if start_free == Vector2i(-1, -1):
					start_free = c
				if (x + y) % 2 == 0:
					even_count += 1
				else:
					odd_count += 1

	# Invariante 1: Equilíbrio de paridade bipartida
	if abs(even_count - odd_count) > 1:
		return false

	# Invariante 2: 1-conectividade via BFS Flood Fill
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_free]
	visited[start_free] = true
	var reached_count: int = 0
	var dead_end_count: int = 0

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		reached_count += 1

		var free_neighbors: int = 0
		for dir in DIRS:
			var nxt := curr + dir
			if nxt.x >= 0 and nxt.x < w and nxt.y >= 0 and nxt.y < h:
				if not obs_set.has(nxt):
					free_neighbors += 1
					if not visited.has(nxt):
						visited[nxt] = true
						queue.append(nxt)

		if free_neighbors == 0:
			return false
		if free_neighbors < 2:
			dead_end_count += 1

	if reached_count != total_walkable:
		return false

	# No máximo 2 células podem ser pontas de grau 1 (extremos do caminho)
	if dead_end_count > 2:
		return false

	return true


# =============================================================================
# 5. INFUSÃO DE ELEMENTOS (PISTAS, ESTRELAS, SETAS, PORTAIS)
# =============================================================================

static func place_clues(
	path: Array[Vector2i],
	clues_count: int,
	bridges: Array[Vector2i] = [],
	portals: Dictionary = {}
) -> Dictionary:
	var total_cells: int = path.size()
	var clues: Dictionary = {}
	if total_cells <= 0:
		return clues
	if total_cells == 1:
		clues[path[0]] = 1
		return clues

	var safe_clues: int = clampi(clues_count, 2, total_cells)
	clues[path[0]] = 1
	clues[path[total_cells - 1]] = safe_clues

	if safe_clues > 2:
		var bridge_set: Dictionary = {}
		for b in bridges:
			bridge_set[b] = true

		var available_indices: Array[int] = []
		for i in range(1, total_cells - 1):
			var cell: Vector2i = path[i]
			if not bridge_set.has(cell) and not portals.has(cell):
				available_indices.append(i)

		if available_indices.size() < safe_clues - 2:
			available_indices.clear()
			for i in range(1, total_cells - 1):
				var cell: Vector2i = path[i]
				if not portals.has(cell):
					available_indices.append(i)

		available_indices.shuffle()
		var chosen: Array = available_indices.slice(0, mini(safe_clues - 2, available_indices.size()))
		chosen.sort()

		for i in range(chosen.size()):
			var idx: int = int(chosen[i])
			clues[path[idx]] = i + 2

	return clues


static func place_stars(
	path: Array[Vector2i],
	clues: Dictionary,
	target_stars: int,
	bridges: Array[Vector2i] = [],
	portals: Dictionary = {}
) -> Array[Vector2i]:
	var stars: Array[Vector2i] = []
	if target_stars <= 0 or path.size() < 3:
		return stars

	var bridge_set: Dictionary = {}
	for b in bridges:
		bridge_set[b] = true

	var candidates: Array[Vector2i] = []
	for i in range(1, path.size() - 1):
		var c: Vector2i = path[i]
		if not clues.has(c) and not bridge_set.has(c) and not portals.has(c) and not candidates.has(c):
			candidates.append(c)

	candidates.shuffle()
	var count: int = mini(target_stars, candidates.size())
	for i in range(count):
		stars.append(candidates[i])

	return stars


static func place_directional(
	path: Array[Vector2i],
	clues: Dictionary,
	stars: Array[Vector2i],
	target_dir: int,
	bridges: Array[Vector2i] = [],
	portals: Dictionary = {}
) -> Dictionary:
	var directional: Dictionary = {}
	if target_dir <= 0 or path.size() < 4:
		return directional

	var star_set: Dictionary = {}
	for s in stars:
		star_set[s] = true
	var bridge_set: Dictionary = {}
	for b in bridges:
		bridge_set[b] = true

	var candidates: Array[int] = []
	for i in range(1, path.size() - 1):
		var c: Vector2i = path[i]
		var nxt: Vector2i = path[i + 1]
		var step_dir: Vector2i = nxt - c
		if not clues.has(c) and not star_set.has(c) and not bridge_set.has(c) and not portals.has(c) and not portals.has(nxt) and step_dir in DIRS:
			candidates.append(i)

	candidates.shuffle()
	var count: int = mini(target_dir, candidates.size())
	for i in range(count):
		var idx: int = candidates[i]
		var c: Vector2i = path[idx]
		var dir: Vector2i = path[idx + 1] - c
		directional[c] = dir

	return directional


# =============================================================================
# 6. VALIDADORES E TESTES DE INTEGRIDADE
# =============================================================================

static func is_valid_hamiltonian_path(w: int, h: int, path: Array[Vector2i]) -> bool:
	var total: int = w * h
	if total <= 0:
		return path.is_empty()
	if path.size() != total:
		return false

	var seen: Dictionary = {}
	for i in range(path.size()):
		var cell: Vector2i = path[i]
		if cell.x < 0 or cell.x >= w or cell.y < 0 or cell.y >= h:
			return false
		if seen.has(cell):
			return false
		seen[cell] = true

		if i > 0:
			var prev: Vector2i = path[i - 1]
			var dist: int = abs(cell.x - prev.x) + abs(cell.y - prev.y)
			if dist != 1:
				return false

	return true


static func is_valid_puzzle_path(
	w: int,
	h: int,
	path: Array[Vector2i],
	obstacles: Array[Vector2i] = [],
	bridges: Array[Vector2i] = [],
	portals: Dictionary = {}
) -> bool:
	var obs_set: Dictionary = {}
	for o in obstacles:
		obs_set[o] = true

	var bridge_set: Dictionary = {}
	for b in bridges:
		bridge_set[b] = true

	var total_expected: int = (w * h - obstacles.size()) + bridges.size()
	if path.size() != total_expected:
		return false

	var visit_counts: Dictionary = {}
	for i in range(path.size()):
		var cell: Vector2i = path[i]
		if cell.x < 0 or cell.x >= w or cell.y < 0 or cell.y >= h:
			return false
		if obs_set.has(cell):
			return false

		var count: int = int(visit_counts.get(cell, 0)) + 1
		visit_counts[cell] = count
		var max_allowed: int = 2 if bridge_set.has(cell) else 1
		if count > max_allowed:
			return false

		if i > 0:
			var prev: Vector2i = path[i - 1]
			var is_adj: bool = (abs(cell.x - prev.x) + abs(cell.y - prev.y)) == 1
			var is_portal: bool = (portals.has(prev) and portals[prev] == cell)
			if not is_adj and not is_portal:
				return false

	return true
