extends Control

var board = [0, 0, 0,  0, 0, 0,  0, 0, 0]
var game_over = false
var is_player_turn = true

var player_wins = 0
var ai_wins = 0
var draws = 0

@onready var grid = $VBoxContainer/CenterContainer/Grid
@onready var status = $VBoxContainer/Status
@onready var score_label = $VBoxContainer/ScoreLabel
@onready var btn_restart = $VBoxContainer/BtnRestart

var cell_buttons = []

func _ready():
	_setup_grid()
	_start_new_game()

func _setup_grid():
	for c in grid.get_children(): c.queue_free()
	cell_buttons.clear()
	
	for i in range(9):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(110, 110)
		btn.add_theme_font_size_override("font_size", 64)
		btn.pivot_offset = Vector2(55, 55)
		btn.pressed.connect(_on_cell_pressed.bind(i, btn))
		grid.add_child(btn)
		cell_buttons.append(btn)

func _start_new_game():
	board = [0, 0, 0,  0, 0, 0,  0, 0, 0]
	game_over = false
	is_player_turn = true
	btn_restart.hide()
	status.text = "Sua Vez (X)"
	_update_score_ui()
	
	for btn in cell_buttons:
		btn.text = ""
		btn.self_modulate = Color(0.2, 0.25, 0.3)

func _update_score_ui():
	score_label.text = "Você: %d  |  IA: %d  |  Empates: %d" % [player_wins, ai_wins, draws]

func _animate_move(btn: Button, text: String, color: Color):
	btn.text = text
	btn.add_theme_color_override("font_color", color)
	var tween = get_tree().create_tween()
	btn.scale = Vector2(0.5, 0.5)
	tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)

func _on_cell_pressed(idx: int, btn: Button):
	if game_over or not is_player_turn or board[idx] != 0: return
	
	# Player move
	board[idx] = 1
	_animate_move(btn, "X", Color(0.9, 0.25, 0.3))
	
	if _check_win(1):
		player_wins += 1
		_end_game("🏆 Você Venceu!")
		return
	if _is_draw():
		draws += 1
		_end_game("🤝 Empate!")
		return
		
	status.text = "Vez da IA (O)..."
	is_player_turn = false
	await get_tree().create_timer(0.4).timeout
	
	# AI move with Minimax
	var ai_move = _get_best_ai_move()
	if ai_move != -1:
		board[ai_move] = 2
		_animate_move(cell_buttons[ai_move], "O", Color(0.2, 0.65, 0.95))
		
		if _check_win(2):
			ai_wins += 1
			_end_game("IA Venceu!")
			return
		if _is_draw():
			draws += 1
			_end_game("🤝 Empate!")
			return
			
	is_player_turn = true
	status.text = "Sua Vez (X)"

func _get_best_ai_move() -> int:
	# 1. Check if AI can win in 1 move
	for i in range(9):
		if board[i] == 0:
			board[i] = 2
			if _check_win(2):
				board[i] = 0
				return i
			board[i] = 0
			
	# 2. Block player immediate win
	for i in range(9):
		if board[i] == 0:
			board[i] = 1
			if _check_win(1):
				board[i] = 0
				return i
			board[i] = 0
			
	# 3. Take Center
	if board[4] == 0: return 4
	
	# 4. Take corners or edges
	var empty = []
	for i in range(9):
		if board[i] == 0: empty.append(i)
	if empty.size() > 0:
		empty.shuffle()
		return empty[0]
	return -1

func _check_win(p: int) -> bool:
	var wins = [
		[0, 1, 2], [3, 4, 5], [6, 7, 8],
		[0, 3, 6], [1, 4, 7], [2, 5, 8],
		[0, 4, 8], [2, 4, 6]
	]
	for w in wins:
		if board[w[0]] == p and board[w[1]] == p and board[w[2]] == p:
			return true
	return false

func _is_draw() -> bool:
	for c in board:
		if c == 0: return false
	return true

func _end_game(msg: String):
	game_over = true
	status.text = msg
	_update_score_ui()
	btn_restart.show()

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
