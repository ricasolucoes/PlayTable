extends Control

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const ReversiRulesScript = preload("res://games/reversi/ReversiRules.gd")

var grid_data: Grid2D
var is_player_turn: bool = true
var game_over: bool = false
var valid_moves: Dictionary = {}

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
	
	for r in range(ReversiRules.ROWS):
		var row_btns = []
		for c in range(ReversiRules.COLS):
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
	
	grid_data = ReversiRules.create_initial_board()
	valid_moves = ReversiRules.find_all_valid_moves(grid_data, 1)
	status_label.text = "Sua Vez! (Peças Pretas ⚫)"
	_update_ui()

func _update_ui():
	var scores = ReversiRules.count_scores(grid_data)
	
	for r in range(ReversiRules.ROWS):
		for c in range(ReversiRules.COLS):
			var btn = cell_buttons[r][c]
			var val = grid_data.get_cell(r, c)
			var pos = Vector2i(r, c)
			
			btn.self_modulate = Color(0.15, 0.45, 0.22)
			
			if val == 1:
				btn.text = "⚫"
			elif val == 2:
				btn.text = "⚪"
			else:
				if is_player_turn and valid_moves.has(pos) and not game_over:
					btn.text = "•"
					btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
					btn.self_modulate = Color(0.2, 0.55, 0.28)
				else:
					btn.text = ""
					
	score_label.text = "Pretas (Você): %d  |  Brancas (IA): %d" % [scores["black"], scores["white"]]

func _on_cell_clicked(r: int, c: int):
	if game_over or not is_player_turn: return
	
	var pos = Vector2i(r, c)
	if not valid_moves.has(pos): return
	
	ReversiRules.apply_move(grid_data, pos, 1, valid_moves[pos])
	_update_ui()
	
	var ai_moves = ReversiRules.find_all_valid_moves(grid_data, 2)
	if not ai_moves.is_empty():
		is_player_turn = false
		status_label.text = "Vez da IA (Brancas ⚪)..."
		await get_tree().create_timer(0.6).timeout
		_play_ai_turn()
	else:
		var p_more = ReversiRules.find_all_valid_moves(grid_data, 1)
		if not p_more.is_empty():
			valid_moves = p_more
			status_label.text = "IA sem movimentos! Sua vez novamente."
			_update_ui()
		else:
			_check_game_end()

func _play_ai_turn():
	if game_over: return
	
	var ai_pos = ReversiRules.get_best_ai_move(grid_data, 2)
	if ai_pos != Vector2i(-1, -1):
		var moves = ReversiRules.find_all_valid_moves(grid_data, 2)
		if moves.has(ai_pos):
			ReversiRules.apply_move(grid_data, ai_pos, 2, moves[ai_pos])
			
	_update_ui()
	
	var p_moves = ReversiRules.find_all_valid_moves(grid_data, 1)
	if not p_moves.is_empty():
		is_player_turn = true
		valid_moves = p_moves
		status_label.text = "Sua Vez! (Pretas ⚫)"
		_update_ui()
	else:
		var ai_more = ReversiRules.find_all_valid_moves(grid_data, 2)
		if not ai_more.is_empty():
			status_label.text = "Você não tem jogadas! Vez da IA novamente."
			await get_tree().create_timer(0.8).timeout
			_play_ai_turn()
		else:
			_check_game_end()

func _check_game_end():
	var scores = ReversiRules.count_scores(grid_data)
	var black = scores["black"]
	var white = scores["white"]
	
	game_over = true
	btn_restart.show()
	
	if black > white:
		status_label.text = "🏆 Parabéns! Você Venceu por %d a %d!" % [black, white]
	elif white > black:
		status_label.text = "IA Venceu por %d a %d!" % [white, black]
	else:
		status_label.text = "Empate Perfeito! %d a %d!" % [black, white]

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
