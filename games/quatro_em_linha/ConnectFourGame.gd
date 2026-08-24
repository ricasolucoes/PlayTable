extends BaseGame

## Connect Four board game implementation.

const PIECE_SCENE = preload("res://shared/ui/Piece2D.tscn")

## As dimensoes vem das regras: ConnectFourBoard declarava as suas e o jogo
## tambem, tres copias de ROWS/COLS que precisavam concordar por acidente.
const COLS = ConnectFourRules.COLS
const ROWS = ConnectFourRules.ROWS
const CELL_SIZE = ConnectFourLayout.CELL_SIZE
const PIECE_RADIUS = ConnectFourLayout.HOLE_RADIUS

## Estado da partida. As jogadas passam por ConnectFourRules, que e o que a
## suite exercita -- antes havia um ConnectFourBoard com a mesma logica escrita
## de novo sobre um Array de Arrays.
var board: Grid2D = null
var is_player_turn: bool = true
var vs_ai: bool = true
var score_p1: int = 0
var score_p2: int = 0
var piece_instances := {}  ## Vector2i(linha, coluna) -> no da ficha

@onready var pieces_layer = $BoardArea/PiecesLayer
@onready var board_back = $BoardArea/BoardBack
@onready var board_front = $BoardArea/BoardFront
@onready var col_buttons_container = $BoardArea/ColButtons
@onready var p1_panel = $VBoxContainer/ScoreBoard/P1Panel
@onready var p2_panel = $VBoxContainer/ScoreBoard/P2Panel
@onready var p1_score_lbl = $VBoxContainer/ScoreBoard/P1Panel/HBox/Score
@onready var p2_score_lbl = $VBoxContainer/ScoreBoard/P2Panel/HBox/Score
@onready var win_modal = $WinModal
@onready var win_modal_title = $WinModal/Panel/VBox/WinTitle
@onready var win_modal_sub = $WinModal/Panel/VBox/WinSub

## Centro vertical da linha `row` na area de desenho.
##
## `drop_piece` preenche do indice ROWS-1 para o 0, entao a linha ROWS-1 e o
## fundo da coluna. No desenho o y cresce para baixo, ou seja o fundo tambem e o
## maior y: linha logica e linha visual sao a mesma, sem inversao. Havia um
## `(ROWS - 1) - row` aqui, apoiado num comentario que dizia o contrario, e ele
## desenhava a primeira ficha de cada coluna no topo com a pilha crescendo para
## baixo.
func cell_center_y(row: int) -> float:
	return row * CELL_SIZE + (CELL_SIZE * 0.5)


func _ready() -> void:
	status_label = $VBoxContainer/StatusCard/StatusLabel
	board = Grid2D.new(ROWS, COLS, 0)
	
	_setup_board_visuals()
	_setup_column_buttons()
	_update_turn_ui()
	win_modal.visible = false

func _setup_board_visuals() -> void:
	board_back.queue_redraw()
	board_front.queue_redraw()

func _setup_column_buttons() -> void:
	for child in col_buttons_container.get_children():
		child.queue_free()
		
	for c in range(COLS):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(CELL_SIZE - 4.0, ROWS * CELL_SIZE + 40.0)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_col_pressed.bind(c))
		col_buttons_container.add_child(btn)

func _on_col_pressed(col: int):
	if game_over or not is_player_turn:
		return
	if not ConnectFourRules.can_drop(board, col):
		return
		
	_make_move(col, 1)

func _make_move(col: int, player_id: int):
	var row := ConnectFourRules.drop_piece(board, col, player_id)
	if row < 0:
		return
		
	var piece := PIECE_SCENE.instantiate()
	piece.is_red = (player_id == 1)
	piece.radius = PIECE_RADIUS
	pieces_layer.add_child(piece)
	
	var center_x := col * CELL_SIZE + (CELL_SIZE * 0.5)
	var spawn_y := -60.0
	var target_y := cell_center_y(row)
	
	piece.position = Vector2(center_x, spawn_y)
	piece_instances[Vector2i(row, col)] = piece
	
	var win_cells := ConnectFourRules.get_winning_cells(board, row, col, player_id)
	var has_won := win_cells.size() >= 4
	var is_board_full := ConnectFourRules.is_full(board)
	
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
	var ai_col := ConnectFourRules.get_best_move(board, 2)
	if ai_col != -1:
		_make_move(ai_col, 2)
	else:
		is_player_turn = true
		_update_turn_ui()

func _handle_game_won(winner_id: int, win_cells: Array[Vector2i]) -> void:
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
			
	reveal_result_modal(win_modal, 0.8)

func _handle_game_draw() -> void:
	game_over = true
	win_modal_title.text = "Empate!"
	win_modal_sub.text = "O tabuleiro ficou completamente cheio."
	if AudioManager: AudioManager.play_draw()
	reveal_result_modal(win_modal, 0.8)

func _update_turn_ui():
	if game_over:
		return
	if is_player_turn:
		set_status("Sua Vez (Fichas Vermelhas)")
		p1_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
		p2_panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
	else:
		set_status("Vez da IA (Fichas Douradas)...")
		p1_panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
		p2_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _start_new_game() -> void:
	win_modal.visible = false
	board.fill(0)
	for child in pieces_layer.get_children():
		child.queue_free()
	piece_instances.clear()
	game_over = false
	is_player_turn = true
	_update_turn_ui()
