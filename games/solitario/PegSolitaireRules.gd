class_name PegSolitaireRules
extends RefCounted

## Rules and logic for Solitario.

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")

const SIZE = 7

static func is_valid_hole(r: int, c: int) -> bool:
	if r < 0 or r >= SIZE or c < 0 or c >= SIZE:
		return false
	# Padrão inglês em cruz
	if (r < 2 or r > 4) and (c < 2 or c > 4):
		return false
	return true

static func is_valid_cell(r: int, c: int) -> bool:
	return is_valid_hole(r, c)

static func has_any_valid_moves(grid: Grid2D) -> bool:
	return count_total_moves(grid) > 0

static func create_initial_board() -> Grid2D:
	var grid = Grid2D.new(SIZE, SIZE, -1)
	for r in range(SIZE):
		for c in range(SIZE):
			if is_valid_hole(r, c):
				if r == 3 and c == 3:
					grid.set_cell(r, c, 0) # Centro vazio
				else:
					grid.set_cell(r, c, 1) # Pino
			else:
				grid.set_cell(r, c, -1)    # Fora do tabuleiro
	return grid

static func get_valid_moves_for_peg(grid: Grid2D, pos: Vector2i) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	if grid.get_cell_pos(pos) != 1: return moves
	
	var directions = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for d in directions:
		var over = pos + d
		var land = pos + (d * 2)
		if is_valid_hole(over.x, over.y) and is_valid_hole(land.x, land.y):
			if grid.get_cell_pos(over) == 1 and grid.get_cell_pos(land) == 0:
				moves.append({"from": pos, "over": over, "land": land})
				
	return moves

static func count_pegs(grid: Grid2D) -> int:
	return grid.count_matching(1)

static func count_total_moves(grid: Grid2D) -> int:
	var total: int = 0
	for r in range(SIZE):
		for c in range(SIZE):
			if grid.get_cell(r, c) == 1:
				total += get_valid_moves_for_peg(grid, Vector2i(r, c)).size()
	return total

static func execute_jump(grid: Grid2D, from_pos: Vector2i, over_pos: Vector2i, land_pos: Vector2i) -> void:
	grid.set_cell_pos(from_pos, 0)
	grid.set_cell_pos(over_pos, 0)
	grid.set_cell_pos(land_pos, 1)
