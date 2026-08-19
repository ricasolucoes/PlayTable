extends Control

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const CheckersRulesScript = preload("res://games/damas/CheckersRules.gd")

var grid_data: Grid2D
var selected_pos: Vector2i = Vector2i(-1, -1)
var valid_moves: Array[Dictionary] = []
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
	for c in grid.get_children(): c.queue_free()
	cell_buttons.clear()
	
	for r in range(CheckersRules.ROWS):
		var row_btns = []
		for c in range(CheckersRules.COLS):
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
	
	grid_data = CheckersRules.create_initial_board()
	_update_ui()
	status_label.text = "Sua Vez! (Brancas)"

func _update_ui():
	var player_count = 0
	var ai_count = 0
	
	for r in range(CheckersRules.ROWS):
		for c in range(CheckersRules.COLS):
			var btn = cell_buttons[r][c]
			var val = grid_data.get_cell(r, c)
			var is_dark_square = (r + c) % 2 == 1
			
			var bg_color = Color(0.32, 0.22, 0.16) if is_dark_square else Color(0.85, 0.76, 0.65)
			
			if selected_pos == Vector2i(r, c):
				bg_color = Color(0.85, 0.7, 0.2)
			else:
				for vm in valid_moves:
					if vm["to"] == Vector2i(r, c):
						bg_color = Color(0.25, 0.65, 0.35)
						break
			
			btn.self_modulate = bg_color
			
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
	if game_over or not is_player_turn: return
	
	var clicked_pos = Vector2i(r, c)
	
	for vm in valid_moves:
		if vm["to"] == clicked_pos:
			_execute_player_move(selected_pos, vm)
			return
			
	if continuing_capture_pos != Vector2i(-1, -1):
		return
		
	var cell_val = grid_data.get_cell(r, c)
	if cell_val != null and cell_val > 0:
		selected_pos = clicked_pos
		valid_moves = CheckersRules.get_piece_moves(grid_data, r, c)
		_update_ui()
	else:
		selected_pos = Vector2i(-1, -1)
		valid_moves.clear()
		_update_ui()

func _execute_player_move(from_pos: Vector2i, move_data: Dictionary):
	var move_result = CheckersRules.execute_move(grid_data, move_data)
	var further_caps = move_result["further_captures"]
	
	if move_result["captured_any"] and not further_caps.is_empty():
		continuing_capture_pos = move_data["to"]
		selected_pos = move_data["to"]
		valid_moves = further_caps
		_update_ui()
		status_label.text = "Continue a captura!"
		return
		
	continuing_capture_pos = Vector2i(-1, -1)
	selected_pos = Vector2i(-1, -1)
	valid_moves.clear()
	_update_ui()
	
	if _check_game_over(): return
	
	# IA
	is_player_turn = false
	status_label.text = "Vez da IA..."
	await get_tree().create_timer(0.5).timeout
	_play_ai_turn()

func _play_ai_turn():
	if game_over: return
	
	var all_ai_moves = CheckersRules.get_all_valid_moves(grid_data, -1)
	if all_ai_moves.is_empty():
		_end_game("Você Venceu! A IA não tem movimentos.")
		return
		
	var captures = []
	for m in all_ai_moves:
		if m["captures"].size() > 0:
			captures.append(m)
			
	var chosen_move: Dictionary
	if not captures.is_empty():
		captures.shuffle()
		chosen_move = captures[0]
	else:
		all_ai_moves.shuffle()
		chosen_move = all_ai_moves[0]
		
	var res = CheckersRules.execute_move(grid_data, chosen_move)
	
	# Multi-jumps da IA
	while res["captured_any"] and not res["further_captures"].is_empty():
		var next_caps = res["further_captures"]
		next_caps.shuffle()
		res = CheckersRules.execute_move(grid_data, next_caps[0])
		
	_update_ui()
	
	if _check_game_over(): return
	
	is_player_turn = true
	status_label.text = "Sua Vez! (Brancas)"

func _check_game_over() -> bool:
	var p_count = 0
	var ai_count = 0
	for r in range(CheckersRules.ROWS):
		for c in range(CheckersRules.COLS):
			var val = grid_data.get_cell(r, c)
			if val > 0: p_count += 1
			elif val < 0: ai_count += 1
			
	if p_count == 0:
		_end_game("A IA Venceu!")
		return true
	if ai_count == 0:
		_end_game("🏆 Você Venceu!")
		return true
		
	var p_moves = CheckersRules.get_all_valid_moves(grid_data, 1)
	if is_player_turn and p_moves.is_empty():
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
