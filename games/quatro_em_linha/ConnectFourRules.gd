class_name ConnectFourRules
extends RefCounted

## Rules and logic for Quatro Em Linha.

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const BoardCoordScript = preload("res://shared/core_engine/board/BoardCoord.gd")

const ROWS = 6
const COLS = 7

static func can_drop(grid: Grid2D, col: int) -> bool:
	if col < 0 or col >= COLS: return false
	return grid.get_cell(0, col) == 0

static func drop_piece(grid: Grid2D, col: int, player_id: int) -> int:
	if not can_drop(grid, col): return -1
	for r in range(ROWS - 1, -1, -1):
		if grid.get_cell(r, col) == 0:
			grid.set_cell(r, col, player_id)
			return r
	return -1

static func check_win(grid: Grid2D, row: int, col: int, player_id: int) -> bool:
	var pos = Vector2i(row, col)
	for dir in BoardCoord.CONNECT_4_DIRECTIONS:
		if grid.count_streak_bidirectional(pos, dir, player_id) >= 4:
			return true
	return false

## As casas que formam a sequencia vencedora passando por (row, col).
##
## Devolve (linha, coluna), a convencao do Grid2D e do resto desta classe. Vazio
## quando a jogada nao fecha quatro. Vivia so em ConnectFourBoard.
static func get_winning_cells(grid: Grid2D, row: int, col: int, player_id: int) -> Array[Vector2i]:
	var origem := Vector2i(row, col)
	for dir in BoardCoordScript.CONNECT_4_DIRECTIONS:
		var celulas: Array[Vector2i] = [origem]
		for sentido in [1, -1]:
			var passo: Vector2i = dir * sentido
			var p: Vector2i = origem + passo
			while grid.is_valid_pos(p) and grid.get_cell_pos(p) == player_id:
				celulas.append(p)
				p += passo
		if celulas.size() >= 4:
			return celulas
	return [] as Array[Vector2i]


static func is_full(grid: Grid2D) -> bool:
	for c in range(COLS):
		if grid.get_cell(0, c) == 0:
			return false
	return true

static func get_valid_cols(grid: Grid2D) -> Array[int]:
	var list: Array[int] = []
	for c in range(COLS):
		if can_drop(grid, c):
			list.append(c)
	return list

static func get_best_move(grid: Grid2D, ai_player_id: int) -> int:
	var opponent_id = 1 if ai_player_id == 2 else 2
	var valid_moves = get_valid_cols(grid)
	if valid_moves.is_empty(): return -1
	
	# 1. Ganhar na rodada
	for c in valid_moves:
		var sim_grid = grid.clone()
		var r = drop_piece(sim_grid, c, ai_player_id)
		if r >= 0 and check_win(sim_grid, r, c, ai_player_id):
			return c
			
	# 2. Bloquear oponente de ganhar
	for c in valid_moves:
		var sim_grid = grid.clone()
		var r = drop_piece(sim_grid, c, opponent_id)
		if r >= 0 and check_win(sim_grid, r, c, opponent_id):
			return c
			
	# 3. Preferência pela coluna central (3) e adjacentes (2, 4)
	var preferred_order = [3, 2, 4, 1, 5, 0, 6]
	for c in preferred_order:
		if c in valid_moves:
			return c
			
	valid_moves.shuffle()
	return valid_moves[0]
