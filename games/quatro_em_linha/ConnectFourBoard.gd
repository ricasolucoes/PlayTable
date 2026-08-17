extends Node

const COLS = 7
const ROWS = 6

var grid = []

func _init():
	reset_board()

func reset_board():
	grid.clear()
	for x in range(COLS):
		var column = []
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
	var directions = [
		Vector2(1, 0), # Horizontal
		Vector2(0, 1), # Vertical
		Vector2(1, 1), # Diagonal \
		Vector2(1, -1) # Diagonal /
	]
	
	for dir in directions:
		var count = 1
		count += _count_direction(col, row, dir.x, dir.y, player_id)
		count += _count_direction(col, row, -dir.x, -dir.y, player_id)
		if count >= 4:
			return true
	return false

func _count_direction(col: int, row: int, dx: int, dy: int, player_id: int) -> int:
	var count = 0
	var c = col + dx
	var r = row + dy
	while c >= 0 and c < COLS and r >= 0 and r < ROWS and grid[c][r] == player_id:
		count += 1
		c += dx
		r += dy
	return count

func is_full() -> bool:
	for c in range(COLS):
		if grid[c][0] == 0:
			return false
	return true
