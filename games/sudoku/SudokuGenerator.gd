class_name SudokuGenerator
extends RefCounted

const SIZE := 9
const BOX_SIZE := 3

## Gerador de Sudoku com backtracking
## level: 1 (Fácil), 2 (Médio), 3 (Difícil), 4 (Especialista)
static func generate_board(level: int) -> Dictionary:
	var grid := _create_empty_grid()
	_fill_diagonal_boxes(grid)
	_solve(grid)
	
	var solution := []
	for r in range(SIZE):
		solution.append(grid[r].duplicate())
		
	var clues_to_keep := 40
	match level:
		1: clues_to_keep = randi_range(36, 45) # Fácil
		2: clues_to_keep = randi_range(30, 35) # Médio
		3: clues_to_keep = randi_range(26, 29) # Difícil
		4: clues_to_keep = randi_range(17, 25) # Especialista
		_: clues_to_keep = 40
		
	var cells_to_try := []
	for r in range(SIZE):
		for c in range(SIZE):
			cells_to_try.append(Vector2i(r, c))
			
	cells_to_try.shuffle()
	
	var current_clues = SIZE * SIZE
	
	for cell in cells_to_try:
		if current_clues <= clues_to_keep:
			break
			
		var r = cell.x
		var c = cell.y
		
		var backup = grid[r][c]
		grid[r][c] = 0
		
		var solutions_count = _count_solutions(grid, 2)
		if solutions_count != 1:
			# Se quebrou a unicidade da solução, desfaz a remoção
			grid[r][c] = backup
		else:
			current_clues -= 1
			
	return {
		"puzzle": grid,
		"solution": solution,
		"clues": current_clues
	}

static func _create_empty_grid() -> Array:
	var grid := []
	for r in range(SIZE):
		var row := []
		for c in range(SIZE):
			row.append(0)
		grid.append(row)
	return grid

static func _fill_diagonal_boxes(grid: Array) -> void:
	for box_idx in range(0, SIZE, BOX_SIZE):
		_fill_box(grid, box_idx, box_idx)

static func _fill_box(grid: Array, row_start: int, col_start: int) -> void:
	var nums := [1, 2, 3, 4, 5, 6, 7, 8, 9]
	nums.shuffle()
	var i = 0
	for r in range(BOX_SIZE):
		for c in range(BOX_SIZE):
			grid[row_start + r][col_start + c] = nums[i]
			i += 1

static func _is_safe(grid: Array, row: int, col: int, num: int) -> bool:
	for i in range(SIZE):
		if grid[row][i] == num:
			return false
		if grid[i][col] == num:
			return false
			
	var box_r_start = row - (row % BOX_SIZE)
	var box_c_start = col - (col % BOX_SIZE)
	for r in range(BOX_SIZE):
		for c in range(BOX_SIZE):
			if grid[box_r_start + r][box_c_start + c] == num:
				return false
				
	return true

static func _solve(grid: Array) -> bool:
	var empty_cell = _find_empty(grid)
	if empty_cell == Vector2i(-1, -1):
		return true
		
	var r = empty_cell.x
	var c = empty_cell.y
	
	var nums = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	nums.shuffle()
	
	for num in nums:
		if _is_safe(grid, r, c, num):
			grid[r][c] = num
			if _solve(grid):
				return true
			grid[r][c] = 0
			
	return false

static func _count_solutions(grid: Array, limit: int) -> int:
	var empty_cell = _find_empty(grid)
	if empty_cell == Vector2i(-1, -1):
		return 1
		
	var r = empty_cell.x
	var c = empty_cell.y
	
	var count = 0
	for num in range(1, 10):
		if _is_safe(grid, r, c, num):
			grid[r][c] = num
			count += _count_solutions(grid, limit - count)
			grid[r][c] = 0
			if count >= limit:
				break
				
	return count

static func _find_empty(grid: Array) -> Vector2i:
	var best_r = -1
	var best_c = -1
	var min_candidates = 10
	
	for r in range(SIZE):
		for c in range(SIZE):
			if grid[r][c] == 0:
				var candidates = 0
				for num in range(1, 10):
					if _is_safe(grid, r, c, num):
						candidates += 1
				if candidates < min_candidates:
					min_candidates = candidates
					best_r = r
					best_c = c
					if candidates <= 1:
						return Vector2i(r, c)
						
	return Vector2i(best_r, best_c)
