extends BaseGame

## Tic-Tac-Toe game implementation.

const PIECE_SCRIPT = preload("res://games/jogo_da_velha/TicTacToePiece.gd")

var board = [0,0,0, 0,0,0, 0,0,0] # 0=empty, 1=X, 2=O
var vs_ai: bool = true
var is_player_turn: bool = true
var score_x: int = 0
var score_o: int = 0
var piece_nodes: Array[Node2D] = []

@onready var grid_container = $BoardContainer/Grid
@onready var x_panel = $VBoxContainer/ScoreBoard/P1Panel
@onready var o_panel = $VBoxContainer/ScoreBoard/P2Panel
@onready var x_score_lbl = $VBoxContainer/ScoreBoard/P1Panel/HBox/Score
@onready var o_score_lbl = $VBoxContainer/ScoreBoard/P2Panel/HBox/Score
@onready var win_modal = $WinModal
@onready var win_modal_title = $WinModal/Panel/VBox/WinTitle
@onready var win_modal_sub = $WinModal/Panel/VBox/WinSub
@onready var strike_line = $BoardContainer/StrikeLine

func _ready() -> void:
	status_label = $VBoxContainer/StatusCard/StatusLabel
	_setup_grid_cells()
	_update_turn_ui()
	win_modal.visible = false
	strike_line.visible = false

func _setup_grid_cells() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	piece_nodes.clear()
	
	for i in range(9):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(150, 150)
		btn.focus_mode = Control.FOCUS_NONE
		btn.flat = true
		
		# Attach piece renderer inside button
		var piece = Node2D.new()
		piece.set_script(PIECE_SCRIPT)
		piece.size = 120.0
		piece.position = Vector2(75, 75)
		btn.add_child(piece)
		piece_nodes.append(piece)
		
		btn.pressed.connect(_on_cell_pressed.bind(i))
		grid_container.add_child(btn)

func _on_cell_pressed(idx: int):
	if game_over or not is_player_turn or board[idx] != 0:
		return
		
	_place_move(idx, 1)

func _place_move(idx: int, player_id: int):
	board[idx] = player_id
	var piece = piece_nodes[idx]
	piece.piece_type = piece.PieceType.X_PIECE if player_id == 1 else piece.PieceType.O_PIECE
	piece.play_spawn_animation()
	
	if AudioManager:
		AudioManager.play_piece_place()
		
	var win_combo = _check_win(player_id)
	if win_combo.size() > 0:
		_handle_game_won(player_id, win_combo)
		return
		
	if _is_draw():
		_handle_game_draw()
		return
		
	if player_id == 1:
		if vs_ai:
			is_player_turn = false
			_update_turn_ui()
			await get_tree().create_timer(0.45).timeout
			_do_ai_turn()
		else:
			is_player_turn = false
			_update_turn_ui()
	else:
		is_player_turn = true
		_update_turn_ui()

func _do_ai_turn():
	if game_over:
		return
		
	var move = _get_ai_move()
	if move != -1:
		_place_move(move, 2)
	else:
		is_player_turn = true
		_update_turn_ui()

func _get_ai_move() -> int:
	# 1. Win if possible
	for i in range(9):
		if board[i] == 0:
			board[i] = 2
			if _check_win(2).size() > 0:
				board[i] = 0
				return i
			board[i] = 0
			
	# 2. Block player win
	for i in range(9):
		if board[i] == 0:
			board[i] = 1
			if _check_win(1).size() > 0:
				board[i] = 0
				return i
			board[i] = 0
			
	# 3. Take center
	if board[4] == 0:
		return 4
		
	# 4. Take corners
	var corners = [0, 2, 6, 8]
	corners.shuffle()
	for c in corners:
		if board[c] == 0:
			return c
			
	# 5. Take sides
	var sides = [1, 3, 5, 7]
	sides.shuffle()
	for s in sides:
		if board[s] == 0:
			return s
			
	return -1

func _check_win(p: int) -> Array[int]:
	var wins = [
		[0,1,2], [3,4,5], [6,7,8], # rows
		[0,3,6], [1,4,7], [2,5,8], # cols
		[0,4,8], [2,4,6]           # diags
	]
	for w in wins:
		if board[w[0]] == p and board[w[1]] == p and board[w[2]] == p:
			var res: Array[int] = []
			res.append_array(w)
			return res
	return []

func _is_draw() -> bool:
	for c in board:
		if c == 0: return false
	return true

func _handle_game_won(winner_id: int, combo: Array[int]) -> void:
	game_over = true
	
	# Highlight winning pieces
	for idx in combo:
		piece_nodes[idx].set_winning(true)
		
	if winner_id == 1:
		score_x += 1
		x_score_lbl.text = str(score_x)
		win_modal_title.text = "🏆 Vitória do X!"
		win_modal_sub.text = "Você alinhou 3 peças com sucesso!"
		if AudioManager: AudioManager.play_win()
	else:
		score_o += 1
		o_score_lbl.text = str(score_o)
		win_modal_title.text = "Vitória do O!"
		win_modal_sub.text = "A IA completou a trinca de ouro."
		if AudioManager: AudioManager.play_draw()
		
	reveal_result_modal(win_modal)

func _handle_game_draw() -> void:
	game_over = true
	win_modal_title.text = "Empate!"
	win_modal_sub.text = "Nenhum jogador conseguiu alinhar 3 peças."
	if AudioManager: AudioManager.play_draw()
	reveal_result_modal(win_modal)

func _update_turn_ui() -> void:
	if game_over: return
	if is_player_turn:
		status_label.text = "Sua Vez (Cruz X Carmesim)"
		x_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
		o_panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
	else:
		status_label.text = "Vez do Computador (Anel O Dourado)..."
		x_panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
		o_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _start_new_game() -> void:
	win_modal.visible = false
	board = [0,0,0, 0,0,0, 0,0,0]
	game_over = false
	is_player_turn = true
	strike_line.visible = false
	for piece in piece_nodes:
		piece.piece_type = piece.PieceType.EMPTY
		piece.set_winning(false)
	_update_turn_ui()
