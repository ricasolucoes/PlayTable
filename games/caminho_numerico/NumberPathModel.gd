class_name NumberPathModel
extends RefCounted

## Modelo de regras e estado do jogo Caminho Numérico.
##
## Totalmente desacoplado de nós de cena e de renderização de interface.
## Gerencia a validação de movimentos, checkpoints de números, histórico
## de passos, retrocesso (backtracking), obstáculos, pontes ortogonais,
## estrelas obrigatórias, portais quânticos, setas direcionais e checagem de vitória.

signal path_changed(path: Array[Vector2i])
signal clue_reached(cell: Vector2i, number: int)
signal star_collected(cell: Vector2i, remaining_count: int)
signal portal_used(from_cell: Vector2i, to_cell: Vector2i)
signal completed
signal mistake_occurred(cell: Vector2i, reason: String)

var grid_w: int = 3
var grid_h: int = 3
var total_cells: int = 9
var walkable_count: int = 9

var obstacles: Array[Vector2i] = []
var bridges: Array[Vector2i] = []
var bridge_crossings: Dictionary = {} # Vector2i -> { "H": bool, "V": bool }
var stars: Array[Vector2i] = []
var visited_stars: Array[Vector2i] = []
var portals: Dictionary = {} # Vector2i -> Vector2i
var directional: Dictionary = {} # Vector2i -> Vector2i
var time_limit: float = 0.0

var clues: Dictionary = {} # Vector2i -> int
var solution_path: Array[Vector2i] = []
var player_path: Array[Vector2i] = []

var max_number: int = 0
var start_cell: Vector2i = Vector2i(-1, -1)
var end_cell: Vector2i = Vector2i(-1, -1)

var is_completed: bool = false
var mistakes_count: int = 0
var moves_count: int = 0
var hints_used: int = 0


func setup_puzzle(puzzle_data: Dictionary) -> void:
	grid_w = int(puzzle_data.get("width", 3))
	grid_h = int(puzzle_data.get("height", 3))

	obstacles.clear()
	for obs in puzzle_data.get("obstacles", []):
		obstacles.append(obs as Vector2i)

	bridges.clear()
	for b in puzzle_data.get("bridges", []):
		bridges.append(b as Vector2i)

	stars.clear()
	for s in puzzle_data.get("stars", []):
		stars.append(s as Vector2i)

	portals.clear()
	var raw_portals: Dictionary = puzzle_data.get("portals", {})
	for k in raw_portals.keys():
		portals[k as Vector2i] = raw_portals[k] as Vector2i

	directional.clear()
	var raw_dir: Dictionary = puzzle_data.get("directional", {})
	for k in raw_dir.keys():
		directional[k as Vector2i] = raw_dir[k] as Vector2i

	time_limit = float(puzzle_data.get("time_limit", 0.0))
	walkable_count = int(puzzle_data.get("walkable_count", (grid_w * grid_h) - obstacles.size()))
	total_cells = int(puzzle_data.get("total_cells", walkable_count + bridges.size()))

	clues = (puzzle_data.get("clues", {}) as Dictionary).duplicate()
	solution_path = []
	var raw_sol: Array = puzzle_data.get("solution", puzzle_data.get("path", []))
	for p in raw_sol:
		solution_path.append(p as Vector2i)

	max_number = 0
	start_cell = Vector2i(-1, -1)
	end_cell = Vector2i(-1, -1)

	for cell in clues.keys():
		var num: int = int(clues[cell])
		if num > max_number:
			max_number = num
			end_cell = cell as Vector2i
		if num == 1:
			start_cell = cell as Vector2i

	if puzzle_data.has("start_cell") and start_cell == Vector2i(-1, -1):
		start_cell = puzzle_data["start_cell"] as Vector2i
	if puzzle_data.has("end_cell") and end_cell == Vector2i(-1, -1):
		end_cell = puzzle_data["end_cell"] as Vector2i
	if puzzle_data.has("max_number") and max_number == 0:
		max_number = int(puzzle_data["max_number"])

	reset()


func reset() -> void:
	player_path.clear()
	visited_stars.clear()
	bridge_crossings.clear()
	is_completed = false
	mistakes_count = 0
	moves_count = 0
	hints_used = 0

	if start_cell != Vector2i(-1, -1):
		player_path.append(start_cell)
		if stars.has(start_cell):
			visited_stars.append(start_cell)

	path_changed.emit(player_path)


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_w and cell.y >= 0 and cell.y < grid_h


func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return (abs(a.x - b.x) + abs(a.y - b.y)) == 1


func get_current_target() -> int:
	var target: int = 1
	for p in player_path:
		if clues.has(p):
			var val: int = int(clues[p])
			if val >= target:
				target = val + 1
	return target


func can_extend_to(cell: Vector2i) -> bool:
	if is_completed:
		return false
	if not is_valid_cell(cell):
		return false
	if obstacles.has(cell):
		return false
	if player_path.is_empty():
		return cell == start_cell

	var last_cell: Vector2i = player_path.back()
	var is_adj: bool = is_adjacent(cell, last_cell)
	var is_portal_jump: bool = (portals.has(last_cell) and portals[last_cell] == cell)

	if not is_adj and not is_portal_jump:
		return false

	# Validação de setas direcionais na última célula
	if is_adj and directional.has(last_cell):
		var req_dir: Vector2i = directional[last_cell]
		if (cell - last_cell) != req_dir:
			return false

	# Validação de saída em linha reta para pontes
	if is_adj and bridges.has(last_cell) and player_path.size() >= 2:
		var prev_cell: Vector2i = player_path[player_path.size() - 2]
		if is_adjacent(last_cell, prev_cell):
			var entry_dir: Vector2i = last_cell - prev_cell
			if (cell - last_cell) != entry_dir:
				return false

	# Validação de visitas e cruzamento de pontes
	if player_path.has(cell):
		if not bridges.has(cell):
			return false
		var visit_count: int = player_path.count(cell)
		if visit_count >= 2:
			return false
		if is_adj:
			var move_dir: Vector2i = cell - last_cell
			var move_axis: String = "H" if move_dir.x != 0 else "V"
			if bridge_crossings.get(cell, {}).get(move_axis, false):
				return false

	if is_adj and bridges.has(cell) and not player_path.has(cell):
		var move_dir: Vector2i = cell - last_cell
		var move_axis: String = "H" if move_dir.x != 0 else "V"
		if bridge_crossings.get(cell, {}).get(move_axis, false):
			return false

	# Validação de pistas numéricas
	var hit_clue: int = int(clues.get(cell, -1))
	var current_target: int = get_current_target()

	if current_target > max_number and hit_clue != -1:
		return false

	if hit_clue != -1 and hit_clue != current_target:
		return false

	# Célula final só pode ser visitada como última etapa com todas as casas e estrelas preenchidas
	if hit_clue == max_number:
		if player_path.size() < total_cells - 1:
			return false
		var stars_collected_so_far: int = visited_stars.size()
		if stars.has(cell) and not visited_stars.has(cell):
			stars_collected_so_far += 1
		if stars_collected_so_far < stars.size():
			return false

	return true


func extend_to(cell: Vector2i) -> bool:
	if can_extend_to(cell):
		var last_cell: Vector2i = player_path.back() if not player_path.is_empty() else Vector2i(-1, -1)
		player_path.append(cell)
		moves_count += 1

		# Registrar travessia na ponte
		if bridges.has(cell) and last_cell != Vector2i(-1, -1) and is_adjacent(cell, last_cell):
			var move_dir: Vector2i = cell - last_cell
			var move_axis: String = "H" if move_dir.x != 0 else "V"
			if not bridge_crossings.has(cell):
				bridge_crossings[cell] = {"H": false, "V": false}
			bridge_crossings[cell][move_axis] = true

		# Coletar estrela
		if stars.has(cell) and not visited_stars.has(cell):
			visited_stars.append(cell)
			var remaining: int = stars.size() - visited_stars.size()
			star_collected.emit(cell, remaining)

		# Notificar pista numérica
		var clue_num: int = int(clues.get(cell, -1))
		if clue_num != -1:
			clue_reached.emit(cell, clue_num)

		# Teleporte de portal
		if portals.has(cell):
			var dest_cell: Vector2i = portals[cell]
			if last_cell != dest_cell and not player_path.has(dest_cell):
				player_path.append(dest_cell)
				moves_count += 1
				portal_used.emit(cell, dest_cell)

				if stars.has(dest_cell) and not visited_stars.has(dest_cell):
					visited_stars.append(dest_cell)
					var rem_stars: int = stars.size() - visited_stars.size()
					star_collected.emit(dest_cell, rem_stars)

				var dest_clue: int = int(clues.get(dest_cell, -1))
				if dest_clue != -1:
					clue_reached.emit(dest_cell, dest_clue)

		path_changed.emit(player_path)
		_check_completion()
		return true
	else:
		if not is_completed:
			if obstacles.has(cell):
				mistakes_count += 1
				mistake_occurred.emit(cell, "obstacle")
			elif is_valid_cell(cell) and not player_path.is_empty():
				var last_cell: Vector2i = player_path.back()
				if is_adjacent(cell, last_cell) and not player_path.has(cell):
					mistakes_count += 1
					mistake_occurred.emit(cell, "wrong_clue_order")
		return false


func truncate_to(cell: Vector2i) -> bool:
	if is_completed:
		return false

	var idx: int = player_path.rfind(cell)
	if idx >= 0 and idx < player_path.size() - 1:
		player_path = player_path.slice(0, idx + 1)
		moves_count += 1
		_rebuild_dynamic_state()
		path_changed.emit(player_path)
		return true
	return false


func _rebuild_dynamic_state() -> void:
	visited_stars.clear()
	for c in player_path:
		if stars.has(c) and not visited_stars.has(c):
			visited_stars.append(c)

	bridge_crossings.clear()
	for i in range(1, player_path.size()):
		var c: Vector2i = player_path[i]
		if bridges.has(c):
			var prev: Vector2i = player_path[i - 1]
			if is_adjacent(c, prev):
				var d: Vector2i = c - prev
				var ax: String = "H" if d.x != 0 else "V"
				if not bridge_crossings.has(c):
					bridge_crossings[c] = {"H": false, "V": false}
				bridge_crossings[c][ax] = true


func _check_completion() -> void:
	if player_path.size() == total_cells:
		var last: Vector2i = player_path.back()
		if clues.has(last) and int(clues[last]) == max_number:
			if visited_stars.size() >= stars.size():
				is_completed = true
				completed.emit()


func get_progress_ratio() -> float:
	if total_cells <= 0:
		return 0.0
	return clampf(float(player_path.size()) / float(total_cells), 0.0, 1.0)


func get_next_clue_info() -> Dictionary:
	var target: int = get_current_target()
	for cell in clues.keys():
		if int(clues[cell]) == target:
			return {"number": target, "cell": cell as Vector2i}
	return {}


func get_hint_next_step() -> Vector2i:
	if solution_path.is_empty() or is_completed:
		return Vector2i(-1, -1)

	var matches: bool = true
	for i in range(player_path.size()):
		if i >= solution_path.size() or player_path[i] != solution_path[i]:
			matches = false
			break

	hints_used += 1

	if matches and player_path.size() < solution_path.size():
		return solution_path[player_path.size()]

	return Vector2i(-1, -1)
