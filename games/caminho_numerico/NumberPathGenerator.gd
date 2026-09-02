class_name NumberPathGenerator
extends RefCounted

## Gerador procedural de caminhos hamiltonianos em grade 2D (Caminho Numérico / Number Path).
##
## Propriedades e garantias matemáticas:
## 1. Grade bipartida: Em uma grade W x H com N = W * H ímpar, qualquer caminho
##    hamiltoniano DEVE começar em uma casa de paridade par (onde (x+y)%2 == 0),
##    pois há (N+1)/2 casas pares e (N-1)/2 casas ímpares.
## 2. Heurística de Warnsdorff: A cada passo da busca em profundidade (DFS),
##    os vizinhos são ordenados pelo menor grau de vizinhos livres disponíveis,
##    com desempate aleatório para variedade.
## 3. Fallback determinístico: Em caso de esgotamento de iterações, fallback
##    serpentine garante 100% de resolutividade.

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]


static func generate_path(w: int, h: int, max_dfs_nodes: int = 5000) -> Array[Vector2i]:
	var total_cells := w * h
	if total_cells <= 0:
		return []
	if total_cells == 1:
		return [Vector2i(0, 0)]

	var is_odd_grid := (total_cells % 2 != 0)
	var candidates: Array[Vector2i] = []

	for y in range(h):
		for x in range(w):
			if is_odd_grid:
				# Em grids ímpares, o início TEM que ser par (maioria na bipartição)
				if (x + y) % 2 == 0:
					candidates.append(Vector2i(x, y))
			else:
				candidates.append(Vector2i(x, y))

	candidates.shuffle()

	# Tenta gerar usando Warnsdorff DFS a partir dos candidatos
	for start_pos in candidates:
		var path: Array[Vector2i] = []
		var visited: Array[bool] = []
		visited.resize(total_cells)
		visited.fill(false)

		var steps_counter = [0] # Array como referência mutável
		if _dfs_warnsdorff(start_pos.x, start_pos.y, w, h, visited, path, max_dfs_nodes, steps_counter):
			return path

	# Fallback garantido: caminho serpentine
	return _generate_serpentine_path(w, h)


static func _dfs_warnsdorff(
	x: int,
	y: int,
	w: int,
	h: int,
	visited: Array[bool],
	path: Array[Vector2i],
	max_nodes: int,
	steps: Array
) -> bool:
	steps[0] += 1
	if steps[0] > max_nodes:
		return false

	var total_cells := w * h
	var cell_idx := y * w + x
	visited[cell_idx] = true
	path.append(Vector2i(x, y))

	if path.size() == total_cells:
		return true

	# Coleta vizinhos livres e calcula seus graus (Warnsdorff)
	var neighbors: Array[Dictionary] = []
	for dir in DIRS:
		var nx := x + dir.x
		var ny := y + dir.y
		if nx >= 0 and nx < w and ny >= 0 and ny < h:
			var n_idx := ny * w + nx
			if not visited[n_idx]:
				var deg := 0
				for d2 in DIRS:
					var nnx := nx + d2.x
					var nny := ny + d2.y
					if nnx >= 0 and nnx < w and nny >= 0 and nny < h:
						if not visited[nny * w + nnx]:
							deg += 1
				neighbors.append({"pos": Vector2i(nx, ny), "deg": deg, "rand": randf()})

	# Ordena pelo menor grau (menos saídas livres primeiro); desempate aleatório
	neighbors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["deg"] != b["deg"]:
			return a["deg"] < b["deg"]
		return a["rand"] < b["rand"]
	)

	for n in neighbors:
		var n_pos: Vector2i = n["pos"]
		if _dfs_warnsdorff(n_pos.x, n_pos.y, w, h, visited, path, max_nodes, steps):
			return true

	visited[cell_idx] = false
	path.pop_back()
	return false


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


static func generate_puzzle(w: int, h: int, clues_count: int = 4) -> Dictionary:
	var total_cells := w * h
	var safe_clues := clampi(clues_count, 2, total_cells)
	var path := generate_path(w, h)

	var clues: Dictionary = {}
	clues[path[0]] = 1
	clues[path[total_cells - 1]] = safe_clues

	if safe_clues > 2:
		var available_indices: Array[int] = []
		for i in range(1, total_cells - 1):
			available_indices.append(i)
		available_indices.shuffle()

		var chosen_indices := available_indices.slice(0, safe_clues - 2)
		chosen_indices.sort()

		for i in range(chosen_indices.size()):
			var idx: int = chosen_indices[i]
			clues[path[idx]] = i + 2

	return {
		"width": w,
		"height": h,
		"total_cells": total_cells,
		"path": path,
		"solution": path.duplicate(),
		"clues": clues,
		"clues_count": safe_clues,
		"start_cell": path[0],
		"end_cell": path[total_cells - 1],
		"max_number": safe_clues,
	}


static func generate_level(level: int) -> Dictionary:
	var w := 3
	var h := 3
	var clues := 4

	if level == 1:
		w = 3; h = 3; clues = 4
	elif level == 2:
		w = 3; h = 3; clues = 3
	elif level == 3:
		w = 4; h = 4; clues = 5
	elif level == 4:
		w = 4; h = 4; clues = 4
	elif level == 5:
		w = 5; h = 5; clues = 7
	elif level == 6:
		w = 5; h = 5; clues = 6
	elif level == 7:
		w = 5; h = 5; clues = 5
	elif level == 8:
		w = 6; h = 6; clues = 9
	elif level == 9:
		w = 6; h = 6; clues = 7
	else:
		# Nível 10+: 6x6 com número reduzido de pistas
		w = 6; h = 6
		clues = maxi(5, 8 - (level - 10) / 3)

	var puzzle := generate_puzzle(w, h, clues)
	puzzle["level"] = level
	return puzzle


static func is_valid_hamiltonian_path(w: int, h: int, path: Array[Vector2i]) -> bool:
	var total := w * h
	if path.size() != total:
		return false

	var seen := {}
	for i in range(path.size()):
		var cell := path[i]
		if cell.x < 0 or cell.x >= w or cell.y < 0 or cell.y >= h:
			return false
		if seen.has(cell):
			return false
		seen[cell] = true

		if i > 0:
			var prev := path[i - 1]
			var dist := abs(cell.x - prev.x) + abs(cell.y - prev.y)
			if dist != 1:
				return false

	return true
