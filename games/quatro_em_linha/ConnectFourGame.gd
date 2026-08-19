extends Control

const BOARD_SCRIPT = preload("res://games/quatro_em_linha/ConnectFourBoard.gd")
const AI_SCRIPT = preload("res://games/quatro_em_linha/ConnectFourAI.gd")
const PIECE_SCENE = preload("res://shared/pecas/Piece.tscn")

var board = null
var is_player_turn = true
var game_over = false

var player_wins = 0
var ai_wins = 0

@onready var grid_container = $VBoxContainer/CenterContainer/Grid
@onready var status_label = $VBoxContainer/StatusLabel
@onready var score_label = $VBoxContainer/ScoreLabel
@onready var pieces_layer = $PiecesLayer
@onready var btn_restart = $VBoxContainer/BtnRestart

func _ready():
	board = BOARD_SCRIPT.new()
	add_child(board)
	_draw_grid_buttons()
	_start_new_game()

func _draw_grid_buttons():
	for c in grid_container.get_children(): c.queue_free()
	for c in range(board.COLS):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(65, 400) # Column click area
		btn.flat = true
		btn.pressed.connect(_on_col_pressed.bind(c))
		grid_container.add_child(btn)

func _start_new_game():
	board.reset_board()
	game_over = false
	is_player_turn = true
	btn_restart.hide()
	status_label.text = "Sua Vez! (Vermelho 🔴)"
	_update_score_ui()
	
	for p in pieces_layer.get_children():
		p.queue_free()

func _update_score_ui():
	score_label.text = "Você: %d vitórias  |  IA: %d vitórias" % [player_wins, ai_wins]

func _on_col_pressed(col: int):
	if game_over or not is_player_turn: return
	
	if board.can_drop(col):
		_do_move(col, 1) # Player is 1 (Red)
		
		if not game_over:
			is_player_turn = false
			status_label.text = "Vez do Computador (Amarelo 🟡)..."
			await get_tree().create_timer(0.5).timeout
			var ai_col = AI_SCRIPT.get_best_move(board)
			if ai_col != -1:
				_do_move(ai_col, 2) # AI is 2 (Yellow)
			is_player_turn = true
			if not game_over:
				status_label.text = "Sua Vez! (Vermelho 🔴)"

func _do_move(col: int, player_id: int):
	var row = board.drop_piece(col, player_id)
	if row >= 0:
		_spawn_piece_visual(col, row, player_id)
		if board.check_win(col, row, player_id):
			game_over = true
			btn_restart.show()
			if player_id == 1:
				player_wins += 1
				status_label.text = "🏆 Você Venceu!"
			else:
				ai_wins += 1
				status_label.text = "Computador Venceu!"
			_update_score_ui()
		elif board.is_full():
			game_over = true
			btn_restart.show()
			status_label.text = "🤝 Empate!"

func _spawn_piece_visual(col: int, row: int, player_id: int):
	var piece = PIECE_SCENE.instantiate()
	piece.is_red = (player_id == 1)
	pieces_layer.add_child(piece)
	
	var start_x = 125 + (col * 70)
	var start_y = -50
	var target_y = 120 + ((5 - row) * 70)
	
	piece.position = Vector2(start_x, start_y)
	piece.drop_to(target_y)

func _on_btn_restart_pressed():
	_start_new_game()

func _on_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
