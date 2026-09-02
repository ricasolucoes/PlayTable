class_name NumberPathModel
extends RefCounted

## Modelo de regras e estado do jogo Caminho Numérico.
##
## Totalmente desacoplado de nós de cena e de renderização de interface.
## Gerencia a validação de movimentos, checkpoints de números, histórico
## de passos, retrocesso (backtracking) e checagem de vitória.

signal path_changed(path: Array[Vector2i])
signal clue_reached(cell: Vector2i, number: int)
signal completed
signal mistake_occurred(cell: Vector2i, reason: String)

var grid_w: int = 3
var grid_h: int = 3
var total_cells: int = 9
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
	total_cells = grid_w * grid_h
	clues = puzzle_data.get("clues", {}).duplicate()
	solution_path = puzzle_data.get("solution", []).duplicate()

	max_number = 0
	start_cell = Vector2i(-1, -1)
	end_cell = Vector2i(-1, -1)

	for cell in clues.keys():
		var num := int(clues[cell])
		if num > max_number:
			max_number = num
			end_cell = cell
		if num == 1:
			start_cell = cell

	reset()


func reset() -> void:
	player_path.clear()
	is_completed = false
	mistakes_count = 0
	moves_count = 0
	hints_used = 0

	if start_cell != Vector2i(-1, -1):
		player_path.append(start_cell)

	path_changed.emit(player_path)


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_w and cell.y >= 0 and cell.y < grid_h


func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return (abs(a.x - b.x) + abs(a.y - b.y)) == 1


func get_current_target() -> int:
	var target := 1
	for p in player_path:
		if clues.has(p):
			target = int(clues[p]) + 1
	return target


func can_extend_to(cell: Vector2i) -> bool:
	if is_completed:
		return false
	if not is_valid_cell(cell):
		return false
	if player_path.is_empty():
		return cell == start_cell

	var last_cell := player_path.back()
	if not is_adjacent(cell, last_cell):
		return false
	if cell in player_path:
		return false

	var hit_clue := int(clues.get(cell, -1))
	var current_target := get_current_target()

	if current_target > max_number:
		return false

	if hit_clue != -1 and hit_clue != current_target:
		return false

	return true


func extend_to(cell: Vector2i) -> bool:
	if can_extend_to(cell):
		player_path.append(cell)
		moves_count += 1

		var clue_num := int(clues.get(cell, -1))
		if clue_num != -1:
			clue_reached.emit(cell, clue_num)

		path_changed.emit(player_path)
		_check_completion()
		return true
	else:
		if not is_completed and is_valid_cell(cell) and not player_path.is_empty():
			var last_cell := player_path.back()
			if is_adjacent(cell, last_cell) and not (cell in player_path):
				mistakes_count += 1
				mistake_occurred.emit(cell, "wrong_clue_order")
		return false


func truncate_to(cell: Vector2i) -> bool:
	if is_completed:
		return false

	var idx := player_path.find(cell)
	if idx >= 0 and idx < player_path.size() - 1:
		player_path = player_path.slice(0, idx + 1)
		moves_count += 1
		path_changed.emit(player_path)
		return true
	return false


func _check_completion() -> void:
	if player_path.size() == total_cells:
		var last := player_path.back()
		if clues.has(last) and int(clues[last]) == max_number:
			is_completed = true
			completed.emit()


func get_progress_ratio() -> float:
	if total_cells <= 0:
		return 0.0
	return float(player_path.size()) / float(total_cells)


func get_next_clue_info() -> Dictionary:
	var target := get_current_target()
	for cell in clues.keys():
		if int(clues[cell]) == target:
			return {"number": target, "cell": cell}
	return {}


func get_hint_next_step() -> Vector2i:
	if solution_path.is_empty() or is_completed:
		return Vector2i(-1, -1)

	var matches := true
	for i in range(player_path.size()):
		if i >= solution_path.size() or player_path[i] != solution_path[i]:
			matches = false
			break

	hints_used += 1

	if matches and player_path.size() < solution_path.size():
		return solution_path[player_path.size()]

	# Jogador desviou da solução: o hint indica onde voltar ou o primeiro desvio
	return Vector2i(-1, -1)
