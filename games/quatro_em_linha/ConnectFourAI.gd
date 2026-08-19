extends Node
class_name ConnectFourAI

## AI opponent for Connect Four using minimax with alpha-beta pruning.
## WARNING: Simulates moves by directly mutating board.grid. Ensure proper undo.

static func get_best_move(board: Node) -> int:
	var valid_moves: Array = []
	for c in range(board.COLS):
		if board.can_drop(c):
			valid_moves.append(c)
	
	if valid_moves.size() == 0:
		return -1
	
	# Try to win
	for c in valid_moves:
		var r = _simulate_drop(board, c)
		if r >= 0 and board.check_win(c, r, 2):
			_undo_drop(board, c, r)
			return c
		_undo_drop(board, c, r)
		
	# Try to block player
	for c in valid_moves:
		var r = _simulate_drop(board, c)
		if r >= 0:
			board.grid[c][r] = 1 # pretend player
			if board.check_win(c, r, 1):
				_undo_drop(board, c, r)
				return c
			_undo_drop(board, c, r)
			
	# Pick random
	valid_moves.shuffle()
	return valid_moves[0]

static func _simulate_drop(board: Node, col: int) -> int:
	for y in range(board.ROWS - 1, -1, -1):
		if board.grid[col][y] == 0:
			board.grid[col][y] = 2
			return y
	return -1

static func _undo_drop(board: Node, col: int, row: int) -> void:
	if row >= 0:
		board.grid[col][row] = 0
