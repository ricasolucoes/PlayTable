extends Control

const BOARD_SCRIPT = preload("res://games/quatro_em_linha/ConnectFourBoard.gd")
const AI_SCRIPT = preload("res://games/quatro_em_linha/ConnectFourAI.gd")
const PIECE_SCENE = preload("res://shared/pecas/Piece.tscn")

var board = null
var is_player_turn = true
var game_over = false

@onready var grid_container = $VBoxContainer/CenterContainer/Grid
@onready var status_label = $VBoxContainer/StatusLabel
@onready var pieces_layer = $PiecesLayer

func _ready():
	board = BOARD_SCRIPT.new()
	add_child(board)
	_draw_grid_buttons()
	status_label.text = "Sua Vez! (Vermelho)"

func _draw_grid_buttons():
	for c in range(board.COLS):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(60, 400) # Entire column click area
		btn.flat = true
		btn.pressed.connect(_on_col_pressed.bind(c))
		grid_container.add_child(btn)

func _on_col_pressed(col: int):
	if game_over or not is_player_turn: return
	
	if board.can_drop(col):
		_do_move(col, 1) # Player is 1 (Red)
		
		if not game_over:
			is_player_turn = false
			status_label.text = "Vez do Computador..."
			# Simulate thinking
			await get_tree().create_timer(0.5).timeout
			var ai_col = AI_SCRIPT.get_best_move(board)
			if ai_col != -1:
				_do_move(ai_col, 2) # AI is 2 (Yellow)
			is_player_turn = true
			if not game_over:
				status_label.text = "Sua Vez! (Vermelho)"

func _do_move(col: int, player_id: int):
	var row = board.drop_piece(col, player_id)
	if row >= 0:
		_spawn_piece_visual(col, row, player_id)
		if board.check_win(col, row, player_id):
			game_over = true
			if player_id == 1:
				status_label.text = "Você Venceu!"
			else:
				status_label.text = "Computador Venceu!"
		elif board.is_full():
			game_over = true
			status_label.text = "Empate!"

func _spawn_piece_visual(col: int, row: int, player_id: int):
	var piece = PIECE_SCENE.instantiate()
	piece.is_red = (player_id == 1)
	pieces_layer.add_child(piece)
	
	var start_x = 100 + (col * 65)
	var start_y = -50
	var target_y = 100 + ((5 - row) * 65) # Visual inversion since row 0 is bottom in logic
	
	piece.position = Vector2(start_x, start_y)
	piece.drop_to(target_y)

func _on_back_pressed():
	SceneManager.goto_scene("res://core/telas/MainMenu.tscn")
