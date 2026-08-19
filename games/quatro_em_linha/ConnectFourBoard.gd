extends Node

## Helper class for Quatro Em Linha.

const COLS = 7
const ROWS = 6

var grid: Array = []
func _init() -> void:
	reset_board()

func reset_board() -> void:
	grid.clear()
	for x in range(COLS):
		var column: Array = []
		for y in range(ROWS):
			column.append(0) # 0 = empty, 1 = player 1 (red), 2 = player 2 (yellow)
		grid.append(column)

func can_drop(col: int) -> bool:
	if col < 0 or col >= COLS: return false
	return grid[col][0] == 0

func drop_piece(col: int, player_id: int) -> int:
	if not can_drop(col): return -1
	# Find lowest empty row
	for y in range(ROWS - 1, -1, -1):
		if grid[col][y] == 0:
			grid[col][y] = player_id
			return y
	return -1

func check_win(col: int, row: int, player_id: int) -> bool:
	return get_winning_cells(col, row, player_id).size() >= 4

func get_winning_cells(col: int, row: int, player_id: int) -> Array[Vector2i]:
	var directions = [
		Vector2i(1, 0),  # Horizontal
		Vector2i(0, 1),  # Vertical
		Vector2i(1, 1),  # Diagonal \
		Vector2i(1, -1)  # Diagonal /
	]
	
	for dir in directions:
		var cells: Array[Vector2i] = [Vector2i(col, row)]
		
		# Forward
		var c = col + dir.x
		var r = row + dir.y
		while c >= 0 and c < COLS and r >= 0 and r < ROWS and grid[c][r] == player_id:
			cells.append(Vector2i(c, r))
			c += dir.x
			r += dir.y
			
		# Backward
		c = col - dir.x
		r = row - dir.y
		while c >= 0 and c < COLS and r >= 0 and r < ROWS and grid[c][r] == player_id:
			cells.append(Vector2i(c, r))
			c -= dir.x
			r -= dir.y
			
		if cells.size() >= 4:
			return cells
			
	return []

func is_full() -> bool:
	for c in range(COLS):
		if grid[c][0] == 0:
			return false
	return true
