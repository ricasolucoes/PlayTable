extends BaseGame

## Tic-Tac-Toe game implementation.

const PIECE_SCRIPT = preload("res://games/jogo_da_velha/TicTacToePiece.gd")

## Estado da partida. As regras moram em TicTacToeRules, que a suite ja
## exercitava enquanto a cena rodava a propria copia delas.
var board: Grid2D = Grid2D.new(3, 3, 0)
var vs_ai: bool = true
var is_player_turn: bool = true
var score_x: int = 0
var score_o: int = 0
var piece_nodes: Array[Node2D] = []

@onready var grid_container: GridContainer = $BoardContainer/Grid
@onready var x_panel: PanelContainer = $VBoxContainer/ScoreBoard/P1Panel
@onready var o_panel: PanelContainer = $VBoxContainer/ScoreBoard/P2Panel
@onready var x_score_lbl: Label = $VBoxContainer/ScoreBoard/P1Panel/HBox/Score
@onready var o_score_lbl: Label = $VBoxContainer/ScoreBoard/P2Panel/HBox/Score
@onready var win_modal: ColorRect = $WinModal
@onready var win_modal_title: Label = $WinModal/Panel/VBox/WinTitle
@onready var win_modal_sub: Label = $WinModal/Panel/VBox/WinSub
@onready var strike_line: Line2D = $BoardContainer/StrikeLine

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
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 150)
		btn.focus_mode = Control.FOCUS_NONE
		btn.flat = true
		
		# Attach piece renderer inside button
		var piece := Node2D.new()
		piece.set_script(PIECE_SCRIPT)
		piece.size = 120.0
		piece.position = Vector2(75, 75)
		btn.add_child(piece)
		piece_nodes.append(piece)
		
		btn.pressed.connect(_on_cell_pressed.bind(i))
		grid_container.add_child(btn)

func _on_cell_pressed(idx: int) -> void:
	if game_over or not is_player_turn or board.cells[idx] != 0:
		return
		
	_place_move(idx, 1)

func _place_move(idx: int, player_id: int) -> void:
	board.cells[idx] = player_id
	var piece := piece_nodes[idx]
	piece.piece_type = piece.PieceType.X_PIECE if player_id == 1 else piece.PieceType.O_PIECE
	piece.play_spawn_animation()
	
	if AudioManager:
		AudioManager.play_piece_place()
		
	var win_combo := TicTacToeRules.get_winning_combo(board, player_id)
	if win_combo.size() > 0:
		_handle_game_won(player_id, win_combo)
		return
		
	if TicTacToeRules.is_draw(board):
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

func _do_ai_turn() -> void:
	if game_over:
		return
		
	var move := TicTacToeRules.get_best_move(board, 2)
	if move != -1:
		_place_move(move, 2)
	else:
		is_player_turn = true
		_update_turn_ui()

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
		set_status("Sua Vez (Cruz X Carmesim)")
		x_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
		o_panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
	else:
		set_status("Vez do Computador (Anel O Dourado)...")
		x_panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
		o_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _start_new_game() -> void:
	win_modal.visible = false
	board.fill(0)
	game_over = false
	is_player_turn = true
	strike_line.visible = false
	for piece in piece_nodes:
		piece.piece_type = piece.PieceType.EMPTY
		piece.set_winning(false)
	_update_turn_ui()
