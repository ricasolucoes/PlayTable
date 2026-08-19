class_name ReversiRules
extends RefCounted

## Rules and logic for Reversi.

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const BoardCoordScript = preload("res://shared/core_engine/board/BoardCoord.gd")

const ROWS = 8
const COLS = 8

const POSITIONAL_WEIGHTS = [
	[ 100, -20,  10,   5,   5,  10, -20, 100],
	[ -20, -50,  -2,  -2,  -2,  -2, -50, -20],
	[  10,  -2,   5,   1,   1,   5,  -2,  10],
	[   5,  -2,   1,   0,   0,   1,  -2,   5],
	[   5,  -2,   1,   0,   0,   1,  -2,   5],
	[  10,  -2,   5,   1,   1,   5,  -2,  10],
	[ -20, -50,  -2,  -2,  -2,  -2, -50, -20],
	[ 100, -20,  10,   5,   5,  10, -20, 100]
]

static func create_initial_board() -> Grid2D:
	var grid = Grid2D.new(ROWS, COLS, 0)
	grid.set_cell(3, 3, 2) # White
	grid.set_cell(3, 4, 1) # Black
	grid.set_cell(4, 3, 1) # Black
	grid.set_cell(4, 4, 2) # White
	return grid

static func find_all_valid_moves(grid: Grid2D, piece: int) -> Dictionary:
	var moves: Dictionary = {}
	var opponent = 2 if piece == 1 else 1
	var directions = BoardCoord.ALL_8_DIRECTIONS
	
	for r in range(ROWS):
		for c in range(COLS):
			if grid.get_cell(r, c) != 0: continue
			var all_flips: Array[Vector2i] = []
			
			for d in directions:
				var current_flips: Array[Vector2i] = []
				var nr = r + d.x
				var nc = c + d.y
				
				while grid.is_valid(nr, nc) and grid.get_cell(nr, nc) == opponent:
					current_flips.append(Vector2i(nr, nc))
					nr += d.x
					nc += d.y
					
				if grid.is_valid(nr, nc) and grid.get_cell(nr, nc) == piece:
					if not current_flips.is_empty():
						all_flips.append_array(current_flips)
						
			if not all_flips.is_empty():
				moves[Vector2i(r, c)] = all_flips
				
	return moves

static func get_valid_moves(grid: Grid2D, piece: int) -> Array[Vector2i]:
	var moves = find_all_valid_moves(grid, piece)
	var list: Array[Vector2i] = []
	for p in moves.keys():
		list.append(p)
	return list

static func get_flipped_pieces(grid: Grid2D, pos: Vector2i, piece: int) -> Array[Vector2i]:
	var moves = find_all_valid_moves(grid, piece)
	if moves.has(pos):
		return moves[pos]
	return []

static func get_best_move(grid: Grid2D, ai_piece: int) -> Vector2i:
	return get_best_ai_move(grid, ai_piece)

static func get_winner(grid: Grid2D) -> Dictionary:
	var scores = count_scores(grid)
	if scores["black"] > scores["white"]:
		return {"winner": 1, "black": scores["black"], "white": scores["white"]}
	elif scores["white"] > scores["black"]:
		return {"winner": 2, "black": scores["black"], "white": scores["white"]}
	else:
		return {"winner": 0, "black": scores["black"], "white": scores["white"]}

static func apply_move(grid: Grid2D, pos: Vector2i, piece: int, flips: Array) -> void:
	grid.set_cell_pos(pos, piece)
	for f in flips:
		grid.set_cell_pos(f, piece)

static func count_scores(grid: Grid2D) -> Dictionary:
	var black = grid.count_matching(1)
	var white = grid.count_matching(2)
	return {"black": black, "white": white}

static func get_best_ai_move(grid: Grid2D, ai_piece: int) -> Vector2i:
	var moves = find_all_valid_moves(grid, ai_piece)
	if moves.is_empty(): return Vector2i(-1, -1)
	
	var best_pos = Vector2i(-1, -1)
	var best_score = -999999
	
	for pos in moves:
		var flips = moves[pos]
		var cloned_grid = grid.clone()
		apply_move(cloned_grid, pos, ai_piece, flips)
		
		# Depth 3 is a good balance for GDScript performance
		var score = minimax(cloned_grid, 3, -999999, 999999, false, ai_piece)
		
		if score > best_score:
			best_score = score
			best_pos = pos
			
	if best_pos == Vector2i(-1, -1):
		# Fallback if all moves somehow returned the lowest score
		return moves.keys()[0]
	return best_pos

static func minimax(grid: Grid2D, depth: int, alpha: int, beta: int, maximizing: bool, ai_piece: int) -> int:
	if depth == 0:
		return evaluate_board(grid, ai_piece)
		
	var current_piece = ai_piece if maximizing else (2 if ai_piece == 1 else 1)
	var moves = find_all_valid_moves(grid, current_piece)
	
	if moves.is_empty():
		# If neither side has moves, game over
		var opponent = 2 if ai_piece == 1 else 1
		var opp_moves = find_all_valid_moves(grid, opponent)
		if opp_moves.is_empty():
			var scores = count_scores(grid)
			var ai_score = scores["black"] if ai_piece == 1 else scores["white"]
			var opp_score = scores["white"] if ai_piece == 1 else scores["black"]
			if ai_score > opp_score: return 99999
			elif ai_score < opp_score: return -99999
			else: return 0
		# Pass turn
		return minimax(grid, depth - 1, alpha, beta, not maximizing, ai_piece)
		
	if maximizing:
		var max_eval = -999999
		for pos in moves:
			var flips = moves[pos]
			var cloned = grid.clone()
			apply_move(cloned, pos, current_piece, flips)
			var ev = minimax(cloned, depth - 1, alpha, beta, false, ai_piece)
			max_eval = max(max_eval, ev)
			alpha = max(alpha, ev)
			if beta <= alpha: break
		return max_eval
	else:
		var min_eval = 999999
		for pos in moves:
			var flips = moves[pos]
			var cloned = grid.clone()
			apply_move(cloned, pos, current_piece, flips)
			var ev = minimax(cloned, depth - 1, alpha, beta, true, ai_piece)
			min_eval = min(min_eval, ev)
			beta = min(beta, ev)
			if beta <= alpha: break
		return min_eval

static func evaluate_board(grid: Grid2D, ai_piece: int) -> int:
	var score: int = 0
	var opponent = 2 if ai_piece == 1 else 1
	for r in range(ROWS):
		for c in range(COLS):
			var cell = grid.get_cell(r, c)
			if cell == ai_piece:
				score += POSITIONAL_WEIGHTS[r][c]
			elif cell == opponent:
				score -= POSITIONAL_WEIGHTS[r][c]
	return score
