extends Control

const ROWS = 8
const COLS = 8

# Cell: 0 = Empty, 1 = Black (Player), 2 = White (AI)
var board = []
var is_player_turn: bool = true
var game_over: bool = false
var valid_moves: Dictionary = {} # Key: Vector2i, Value: Array of flipped Vector2i

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

@onready var grid = $VBoxContainer/CenterContainer/BoardContainer/Grid
@onready var status_label = $VBoxContainer/StatusLabel
@onready var score_label = $VBoxContainer/ScoreLabel
@onready var btn_restart = $VBoxContainer/BtnRestart

var cell_buttons = []

func _ready():
	_setup_grid()
	_start_new_game()

func _setup_grid():
	for c in grid.get_children(): c.queue_free()
	cell_buttons.clear()
	
	for r in range(ROWS):
		var row_btns = []
		for c in range(COLS):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(65, 65)
			btn.add_theme_font_size_override("font_size", 34)
			btn.pressed.connect(_on_cell_clicked.bind(r, c))
			grid.add_child(btn)
			row_btns.append(btn)
		cell_buttons.append(row_btns)

func _start_new_game():
	game_over = false
	is_player_turn = true
	btn_restart.hide()
	
	board.clear()
	for r in range(ROWS):
		var row = []
		for c in range(COLS): row.append(0)
		board.append(row)
		
	# Starting 4 pieces
	board[3][3] = 2 # White
	board[3][4] = 1 # Black
	board[4][3] = 1 # Black
	board[4][4] = 2 # White
	
	valid_moves = _find_all_valid_moves(1, board)
	status_label.text = "Sua Vez! (Peças Pretas ⚫)"
	_update_ui()

func _update_ui():
	var black_count = 0
	var white_count = 0
	
	for r in range(ROWS):
		for c in range(COLS):
			var btn = cell_buttons[r][c]
			var val = board[r][c]
			var pos = Vector2i(r, c)
			
			btn.self_modulate = Color(0.15, 0.45, 0.22) # Green felt
			
			if val == 1:
				btn.text = "⚫"
				black_count += 1
			elif val == 2:
				btn.text = "⚪"
				white_count += 1
			else:
				if is_player_turn and valid_moves.has(pos) and not game_over:
					btn.text = "•"
					btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
					btn.self_modulate = Color(0.2, 0.55, 0.28)
				else:
					btn.text = ""
					
	score_label.text = "Pretas (Você): %d  |  Brancas (IA): %d" % [black_count, white_count]

func _on_cell_clicked(r: int, c: int):
	if game_over or not is_player_turn: return
	
	var pos = Vector2i(r, c)
	if not valid_moves.has(pos):
		return
		
	# Execute Player Move
	_apply_move(pos, 1, valid_moves[pos])
	_update_ui()
	
	# Check next turn
	var ai_moves = _find_all_valid_moves(2, board)
	if ai_moves.size() > 0:
		is_player_turn = false
		status_label.text = "Vez da IA (Brancas ⚪)..."
		await get_tree().create_timer(0.6).timeout
		_play_ai_turn(ai_moves)
	else:
		# AI has no moves, player gets another turn or game over
		var player_more_moves = _find_all_valid_moves(1, board)
		if player_more_moves.size() > 0:
			valid_moves = player_more_moves
			status_label.text = "IA sem movimentos! Sua vez novamente."
			_update_ui()
		else:
			_check_game_end()

func _apply_move(pos: Vector2i, piece: int, flips: Array):
	board[pos.x][pos.y] = piece
	for f in flips:
		board[f.x][f.y] = piece

func _play_ai_turn(ai_moves: Dictionary):
	if game_over: return
	
	# Pick best move based on positional weights and flips count
	var best_pos = Vector2i(-1, -1)
	var best_score = -999999
	
	for pos in ai_moves:
		var flips = ai_moves[pos]
		var score = POSITIONAL_WEIGHTS[pos.x][pos.y] * 10 + flips.size()
		if score > best_score:
			best_score = score
			best_pos = pos
			
	if best_pos != Vector2i(-1, -1):
		_apply_move(best_pos, 2, ai_moves[best_pos])
		
	_update_ui()
	
	# Check player moves
	var p_moves = _find_all_valid_moves(1, board)
	if p_moves.size() > 0:
		is_player_turn = true
		valid_moves = p_moves
		status_label.text = "Sua Vez! (Pretas ⚫)"
		_update_ui()
	else:
		# Player has no moves, AI continues or game over
		var ai_more_moves = _find_all_valid_moves(2, board)
		if ai_more_moves.size() > 0:
			status_label.text = "Você não tem jogadas! Vez da IA novamente."
			await get_tree().create_timer(0.8).timeout
			_play_ai_turn(ai_more_moves)
		else:
			_check_game_end()

func _find_all_valid_moves(piece: int, b: Array) -> Dictionary:
	var moves = {}
	var opponent = 2 if piece == 1 else 1
	var directions = [
		Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1),
		Vector2i(0, -1),                   Vector2i(0, 1),
		Vector2i(1, -1),  Vector2i(1, 0),  Vector2i(1, 1)
	]
	
	for r in range(ROWS):
		for c in range(COLS):
			if b[r][c] != 0: continue
			var all_flips = []
			
			for d in directions:
				var current_flips = []
				var nr = r + d.x
				var nc = c + d.y
				
				while nr >= 0 and nr < ROWS and nc >= 0 and nc < COLS and b[nr][nc] == opponent:
					current_flips.append(Vector2i(nr, nc))
					nr += d.x
					nc += d.y
					
				if nr >= 0 and nr < ROWS and nc >= 0 and nc < COLS and b[nr][nc] == piece:
					if current_flips.size() > 0:
						all_flips.append_array(current_flips)
						
			if all_flips.size() > 0:
				moves[Vector2i(r, c)] = all_flips
				
	return moves

func _check_game_end():
	var black_count = 0
	var white_count = 0
	for r in range(ROWS):
		for c in range(COLS):
			if board[r][c] == 1: black_count += 1
			elif board[r][c] == 2: white_count += 1
			
	game_over = true
	btn_restart.show()
	
	if black_count > white_count:
		status_label.text = "🏆 Parabéns! Você Venceu por %d a %d!" % [black_count, white_count]
	elif white_count > black_count:
		status_label.text = "IA Venceu por %d a %d!" % [white_count, black_count]
	else:
		status_label.text = "Empate Perfeito! %d a %d!" % [black_count, white_count]

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
