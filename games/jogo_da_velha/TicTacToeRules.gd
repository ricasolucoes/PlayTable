class_name TicTacToeRules
extends RefCounted

## Rules and logic for Jogo Da Velha.

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")

const WIN_COMBOS = [
	[0, 1, 2], [3, 4, 5], [6, 7, 8], # Linhas
	[0, 3, 6], [1, 4, 7], [2, 5, 8], # Colunas
	[0, 4, 8], [2, 4, 6]             # Diagonais
]

static func check_win(grid: Grid2D, player_id: int) -> bool:
	for combo in WIN_COMBOS:
		if grid.cells[combo[0]] == player_id and grid.cells[combo[1]] == player_id and grid.cells[combo[2]] == player_id:
			return true
	return false

static func is_draw(grid: Grid2D) -> bool:
	for c in grid.cells:
		if c == 0: return false
	return not check_win(grid, 1) and not check_win(grid, 2)

static func get_empty_indices(grid: Grid2D) -> Array[int]:
	var list: Array[int] = []
	for i in range(grid.cells.size()):
		if grid.cells[i] == 0:
			list.append(i)
	return list

static func get_best_move(grid: Grid2D, ai_player_id: int) -> int:
	var human_id = 1 if ai_player_id == 2 else 2
	var empty = get_empty_indices(grid)
	if empty.is_empty(): return -1
	
	# 1. Tenta vencer na próxima jogada
	for idx in empty:
		grid.cells[idx] = ai_player_id
		if check_win(grid, ai_player_id):
			grid.cells[idx] = 0
			return idx
		grid.cells[idx] = 0
		
	# 2. Tenta bloquear a vitória do oponente
	for idx in empty:
		grid.cells[idx] = human_id
		if check_win(grid, human_id):
			grid.cells[idx] = 0
			return idx
		grid.cells[idx] = 0
		
	# 3. Prefere o centro (4)
	if 4 in empty:
		return 4
		
	# 4. Cantos (0, 2, 6, 8)
	var corners: Array = []
	for c in [0, 2, 6, 8]:
		if c in empty: corners.append(c)
	if not corners.is_empty():
		corners.shuffle()
		return corners[0]
		
	# 5. Aleatório
	empty.shuffle()
	return empty[0]
