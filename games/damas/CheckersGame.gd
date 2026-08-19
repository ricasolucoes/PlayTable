extends Control

const ROWS = 8
const COLS = 8

# Piece types:
# 0: Empty
# 1: Player Regular (White)
# 2: Player King (Dama Branca)
# -1: AI Regular (Black)
# -2: AI King (Dama Preta)

var board = []
var selected_pos: Vector2i = Vector2i(-1, -1)
var valid_moves: Array = [] # Array of Dictionary: {"to": Vector2i, "captures": Array of Vector2i}
var is_player_turn: bool = true
var game_over: bool = false
var continuing_capture_pos: Vector2i = Vector2i(-1, -1)

@onready var grid = $VBoxContainer/CenterContainer/BoardContainer/Grid
@onready var status_label = $VBoxContainer/StatusLabel
@onready var score_label = $VBoxContainer/ScoreLabel
@onready var btn_restart = $VBoxContainer/BtnRestart

var cell_buttons = []

func _ready():
	_setup_board_grid()
	_start_new_game()

func _setup_board_grid():
	for c in grid.get_children():
		c.queue_free()
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
	selected_pos = Vector2i(-1, -1)
	continuing_capture_pos = Vector2i(-1, -1)
	valid_moves.clear()
	btn_restart.hide()
	
	# Initialize board
	board.clear()
	for r in range(ROWS):
		var row = []
		for c in range(COLS):
			if (r + c) % 2 == 1:
				if r < 3:
					row.append(-1) # AI piece
				elif r > 4:
					row.append(1) # Player piece
				else:
					row.append(0)
			else:
				row.append(0)
		board.append(row)
		
	_update_ui()
	status_label.text = "Sua Vez! (Brancas)"

func _update_ui():
	var player_count = 0
	var ai_count = 0
	
	for r in range(ROWS):
		for c in range(COLS):
			var btn = cell_buttons[r][c]
			var val = board[r][c]
			var is_dark_square = (r + c) % 2 == 1
			
			# Base color of cell
			var bg_color = Color(0.32, 0.22, 0.16) if is_dark_square else Color(0.85, 0.76, 0.65)
			
			# Highlight selected or valid target
			if selected_pos == Vector2i(r, c):
				bg_color = Color(0.85, 0.7, 0.2) # Gold
			else:
				for vm in valid_moves:
					if vm["to"] == Vector2i(r, c):
						bg_color = Color(0.25, 0.65, 0.35) # Soft Green
						break
			
			btn.self_modulate = bg_color
			
			# Text and color for pieces
			if val == 1:
				btn.text = "⚪"
				player_count += 1
			elif val == 2:
				btn.text = "👑"
				player_count += 1
			elif val == -1:
				btn.text = "⚫"
				ai_count += 1
			elif val == -2:
				btn.text = "👑"
				btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
				ai_count += 1
			else:
				btn.text = ""
				
	score_label.text = "Você: %d peças  |  IA: %d peças" % [player_count, ai_count]

func _on_cell_clicked(r: int, c: int):
	if game_over or not is_player_turn:
		return
		
	var clicked_pos = Vector2i(r, c)
	
	# If player clicked on a valid target move
	for vm in valid_moves:
		if vm["to"] == clicked_pos:
			_execute_player_move(selected_pos, vm)
			return
			
	# If continuing a multi-jump, cannot select other pieces
	if continuing_capture_pos != Vector2i(-1, -1):
		return
		
	# Selecting own piece
	if board[r][c] > 0:
		selected_pos = clicked_pos
		valid_moves = _get_piece_moves(r, c, board)
		_update_ui()
	else:
		selected_pos = Vector2i(-1, -1)
		valid_moves.clear()
		_update_ui()

func _execute_player_move(from_pos: Vector2i, move_data: Dictionary):
	var to_pos = move_data["to"]
	var piece = board[from_pos.x][from_pos.y]
	
	board[from_pos.x][from_pos.y] = 0
	
	# Remove captured pieces
	var captured_any = false
	if move_data.has("captures") and move_data["captures"].size() > 0:
		captured_any = true
		for cap in move_data["captures"]:
			board[cap.x][cap.y] = 0
			
	# Check promotion to King (Dama)
	if piece == 1 and to_pos.x == 0:
		piece = 2
		
	board[to_pos.x][to_pos.y] = piece
	
	# Check multi-jump continuation
	if captured_any:
		var further_captures = _get_piece_captures(to_pos.x, to_pos.y, board)
		if further_captures.size() > 0:
			continuing_capture_pos = to_pos
			selected_pos = to_pos
			valid_moves = further_captures
			_update_ui()
			status_label.text = "Continue a captura!"
			return
			
	continuing_capture_pos = Vector2i(-1, -1)
	selected_pos = Vector2i(-1, -1)
	valid_moves.clear()
	_update_ui()
	
	if _check_game_over():
		return
		
	# AI Turn
	is_player_turn = false
	status_label.text = "Vez da IA..."
	await get_tree().create_timer(0.5).timeout
	_play_ai_turn()

func _play_ai_turn():
	if game_over: return
	
	var all_ai_moves = _get_all_valid_moves(-1, board)
	if all_ai_moves.size() == 0:
		_end_game("Você Venceu! A IA não tem movimentos.")
		return
		
	# AI move selection: prefer captures, then best position score
	var captures = []
	for m in all_ai_moves:
		if m["captures"].size() > 0:
			captures.append(m)
			
	var chosen_move: Dictionary
	if captures.size() > 0:
		captures.shuffle()
		chosen_move = captures[0]
	else:
		all_ai_moves.shuffle()
		chosen_move = all_ai_moves[0]
		
	var from_p = chosen_move["from"]
	var to_p = chosen_move["to"]
	var piece = board[from_p.x][from_p.y]
	
	board[from_p.x][from_p.y] = 0
	
	var captured_any = false
	if chosen_move["captures"].size() > 0:
		captured_any = true
		for cap in chosen_move["captures"]:
			board[cap.x][cap.y] = 0
			
	# AI Promotion
	if piece == -1 and to_p.x == ROWS - 1:
		piece = -2
		
	board[to_p.x][to_p.y] = piece
	
	# Multi-jumps for AI
	var current_ai_pos = to_p
	while captured_any:
		var more_caps = _get_piece_captures(current_ai_pos.x, current_ai_pos.y, board)
		if more_caps.size() == 0:
			break
		more_caps.shuffle()
		var next_cap = more_caps[0]
		var next_to = next_cap["to"]
		
		board[current_ai_pos.x][current_ai_pos.y] = 0
		for cap in next_cap["captures"]:
			board[cap.x][cap.y] = 0
			
		if piece == -1 and next_to.x == ROWS - 1:
			piece = -2
			
		board[next_to.x][next_to.y] = piece
		current_ai_pos = next_to
		
	_update_ui()
	
	if _check_game_over():
		return
		
	is_player_turn = true
	status_label.text = "Sua Vez! (Brancas)"

func _get_piece_moves(r: int, c: int, b: Array) -> Array:
	var moves = _get_piece_captures(r, c, b)
	if moves.size() > 0:
		return moves
		
	var piece = b[r][c]
	if piece == 0: return []
	
	var is_player = piece > 0
	var is_king = abs(piece) == 2
	var directions = []
	
	if is_player or is_king:
		directions.append(Vector2i(-1, -1))
		directions.append(Vector2i(-1, 1))
	if not is_player or is_king:
		directions.append(Vector2i(1, -1))
		directions.append(Vector2i(1, 1))
		
	for d in directions:
		var nr = r + d.x
		var nc = c + d.y
		if _is_valid_coord(nr, nc) and b[nr][nc] == 0:
			moves.append({"to": Vector2i(nr, nc), "captures": []})
			
	return moves

func _get_piece_captures(r: int, c: int, b: Array) -> Array:
	var captures = []
	var piece = b[r][c]
	if piece == 0: return []
	
	var is_player = piece > 0
	var is_king = abs(piece) == 2
	var directions = [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]
	
	for d in directions:
		# Check forward/backward for captures
		if not is_king:
			if is_player and d.x > 0: continue
			if not is_player and d.x < 0: continue
			
		var over_r = r + d.x
		var over_c = c + d.y
		var land_r = r + d.x * 2
		var land_c = c + d.y * 2
		
		if _is_valid_coord(land_r, land_c) and _is_valid_coord(over_r, over_c):
			var target_piece = b[over_r][over_c]
			if target_piece != 0 and (target_piece > 0) != is_player:
				if b[land_r][land_c] == 0:
					captures.append({
						"to": Vector2i(land_r, land_c),
						"captures": [Vector2i(over_r, over_c)]
					})
	return captures

func _get_all_valid_moves(side: int, b: Array) -> Array:
	var is_player = side > 0
	var all_moves = []
	var has_captures = false
	
	for r in range(ROWS):
		for c in range(COLS):
			var p = b[r][c]
			if p != 0 and (p > 0) == is_player:
				var caps = _get_piece_captures(r, c, b)
				if caps.size() > 0:
					has_captures = true
					for cap in caps:
						cap["from"] = Vector2i(r, c)
						all_moves.append(cap)
						
	if has_captures:
		return all_moves
		
	for r in range(ROWS):
		for c in range(COLS):
			var p = b[r][c]
			if p != 0 and (p > 0) == is_player:
				var mvs = _get_piece_moves(r, c, b)
				for m in mvs:
					m["from"] = Vector2i(r, c)
					all_moves.append(m)
					
	return all_moves

func _is_valid_coord(r: int, c: int) -> bool:
	return r >= 0 and r < ROWS and c >= 0 and c < COLS

func _check_game_over() -> bool:
	var player_pieces = 0
	var ai_pieces = 0
	for r in range(ROWS):
		for c in range(COLS):
			if board[r][c] > 0: player_pieces += 1
			elif board[r][c] < 0: ai_pieces += 1
			
	if player_pieces == 0:
		_end_game("A IA Venceu!")
		return true
	if ai_pieces == 0:
		_end_game("🏆 Você Venceu!")
		return true
		
	var player_moves = _get_all_valid_moves(1, board)
	if is_player_turn and player_moves.size() == 0:
		_end_game("Empate! Sem movimentos válidos.")
		return true
		
	return false

func _end_game(msg: String):
	game_over = true
	status_label.text = msg
	btn_restart.show()

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
