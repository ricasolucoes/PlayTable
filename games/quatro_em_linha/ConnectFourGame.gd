extends Control

const BOARD_SCRIPT = preload("res://games/quatro_em_linha/ConnectFourBoard.gd")
const AI_SCRIPT = preload("res://games/quatro_em_linha/ConnectFourAI.gd")
const PIECE_SCENE = preload("res://shared/pecas/Piece.tscn")

const COLS = 7
const ROWS = 6
const CELL_SIZE = 86.0
const PIECE_RADIUS = 34.0

var board = null
var is_player_turn = true
var game_over = false
var vs_ai = true

var score_p1 = 0
var score_p2 = 0

var piece_instances = {} # Vector2i -> Piece node

@onready var pieces_layer = $BoardArea/PiecesLayer
@onready var board_back = $BoardArea/BoardBack
@onready var board_front = $BoardArea/BoardFront
@onready var col_buttons_container = $BoardArea/ColButtons
@onready var status_label = $VBoxContainer/StatusCard/StatusLabel
@onready var p1_panel = $VBoxContainer/ScoreBoard/P1Panel
@onready var p2_panel = $VBoxContainer/ScoreBoard/P2Panel
@onready var p1_score_lbl = $VBoxContainer/ScoreBoard/P1Panel/HBox/Score
@onready var p2_score_lbl = $VBoxContainer/ScoreBoard/P2Panel/HBox/Score
@onready var win_modal = $WinModal
@onready var win_modal_title = $WinModal/Panel/VBox/WinTitle
@onready var win_modal_sub = $WinModal/Panel/VBox/WinSub

func _ready():
	board = BOARD_SCRIPT.new()
	add_child(board)
	
	_setup_board_visuals()
	_setup_column_buttons()
	_update_turn_ui()
	win_modal.visible = false

func _setup_board_visuals():
	board_back.queue_redraw()
	board_front.queue_redraw()

func _setup_column_buttons():
	for child in col_buttons_container.get_children():
		child.queue_free()
		
	for c in range(COLS):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(CELL_SIZE - 4.0, ROWS * CELL_SIZE + 40.0)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_col_pressed.bind(c))
		col_buttons_container.add_child(btn)

func _on_col_pressed(col: int):
	if game_over or not is_player_turn:
		return
	if not board.can_drop(col):
		return
		
	_make_move(col, 1)

func _make_move(col: int, player_id: int):
	var row = board.drop_piece(col, player_id)
	if row < 0:
		return
		
	var piece = PIECE_SCENE.instantiate()
	piece.is_red = (player_id == 1)
	piece.radius = PIECE_RADIUS
	pieces_layer.add_child(piece)
	
	var center_x = col * CELL_SIZE + (CELL_SIZE * 0.5)
	var spawn_y = -60.0
	# In logic row 0 is bottom, row 5 is top. Visual row 0 is top, visual row 5 is bottom
	var visual_row = (ROWS - 1) - row
	var target_y = visual_row * CELL_SIZE + (CELL_SIZE * 0.5)
	
	piece.position = Vector2(center_x, spawn_y)
	piece_instances[Vector2i(col, row)] = piece
	
	var win_cells = board.get_winning_cells(col, row, player_id)
	var has_won = win_cells.size() >= 4
	var is_board_full = board.is_full()
	
	piece.drop_to(target_y, func():
		if has_won:
			_handle_game_won(player_id, win_cells)
		elif is_board_full:
			_handle_game_draw()
		else:
			if player_id == 1:
				if vs_ai:
					is_player_turn = false
					_update_turn_ui()
					await get_tree().create_timer(0.4).timeout
					_do_ai_turn()
				else:
					is_player_turn = false
					_update_turn_ui()
			else:
				is_player_turn = true
				_update_turn_ui()
	)

func _do_ai_turn():
	if game_over:
		return
	var ai_col = AI_SCRIPT.get_best_move(board)
	if ai_col != -1:
		_make_move(ai_col, 2)
	else:
		is_player_turn = true
		_update_turn_ui()

func _handle_game_won(winner_id: int, win_cells: Array[Vector2i]):
	game_over = true
	if winner_id == 1:
		score_p1 += 1
		p1_score_lbl.text = str(score_p1)
		win_modal_title.text = "🏆 Vitória!"
		win_modal_sub.text = "Você conectou 4 fichas vermelhas!"
		if AudioManager: AudioManager.play_win()
	else:
		score_p2 += 1
		p2_score_lbl.text = str(score_p2)
		win_modal_title.text = "Computador Venceu!"
		win_modal_sub.text = "A inteligência artificial completou a linha."
		if AudioManager: AudioManager.play_draw()
		
	# Highlight winning pieces
	for cell in win_cells:
		if piece_instances.has(cell):
			piece_instances[cell].set_winning(true)
			
	await get_tree().create_timer(0.8).timeout
	win_modal.visible = true
	win_modal.modulate.a = 0.0
	var tw = get_tree().create_tween()
	tw.tween_property(win_modal, "modulate:a", 1.0, 0.3)

func _handle_game_draw():
	game_over = true
	win_modal_title.text = "Empate!"
	win_modal_sub.text = "O tabuleiro ficou completamente cheio."
	if AudioManager: AudioManager.play_draw()
	await get_tree().create_timer(0.8).timeout
	win_modal.visible = true

func _update_turn_ui():
	if game_over:
		return
	if is_player_turn:
		status_label.text = "Sua Vez (Fichas Vermelhas)"
		p1_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
		p2_panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
	else:
		status_label.text = "Vez da IA (Fichas Douradas)..."
		p1_panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
		p2_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_restart_pressed():
	if AudioManager: AudioManager.play_click()
	win_modal.visible = false
	board.reset_board()
	for child in pieces_layer.get_children():
		child.queue_free()
	piece_instances.clear()
	game_over = false
	is_player_turn = true
	_update_turn_ui()

func _on_back_pressed():
	if AudioManager: AudioManager.play_click()
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
