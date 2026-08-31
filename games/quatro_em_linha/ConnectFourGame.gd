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
var is_animating: bool = false

## Degrau de 1 a 10 do DifficultyManager. Vira orcamento de busca da IA.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL
var score_p1: int = 0
var score_p2: int = 0
var piece_instances := {}  ## Vector2i(linha, coluna) -> no da ficha

## Instante em que a partida comecou, para o tempo entrar no resultado.
var _started_at: float = 0.0

@onready var pieces_layer: Node2D = $BoardArea/PiecesLayer
@onready var board_back: Control = $BoardArea/BoardBack
@onready var board_front: Control = $BoardArea/BoardFront
@onready var col_buttons_container: HBoxContainer = $BoardArea/ColButtons
@onready var win_modal: ColorRect = $WinModal
@onready var win_modal_title: Label = $WinModal/Panel/VBox/WinTitle
@onready var win_modal_sub: Label = $WinModal/Panel/VBox/WinSub
@onready var btn_mode_toggle: Button = $VBoxContainer/TopBar/BtnModeToggle

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
	ai_level = DifficultyManager.get_level(game_id)
	
	_setup_board_visuals()
	_setup_column_buttons()
	btn_mode_toggle.pressed.connect(_on_mode_toggle_pressed)
	_update_mode_button()
	_update_turn_ui()
	win_modal.visible = false
	_started_at = Time.get_ticks_msec() / 1000.0
	begin_match("ai" if vs_ai else "versus")

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

func _on_col_pressed(col: int) -> void:
	if game_over or is_animating or (vs_ai and not is_player_turn):
		return
	if not ConnectFourRules.can_drop(board, col):
		return
		
	# No modo local, os dois jogadores usam as mesmas colunas e o lado ativo
	# define a cor da ficha que cai.
	_make_move(col, 1 if vs_ai or is_player_turn else 2)

func _make_move(col: int, player_id: int) -> void:
	var row := ConnectFourRules.drop_piece(board, col, player_id)
	if row < 0:
		return
	is_animating = true
		
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
		is_animating = false
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

## Pensa fora da linha principal, durante a pausa de encenacao que ja existia.
##
## No degrau 10 a busca chega a meio segundo no computador e mais num telefone.
## A tarefa recebe uma copia plana do tabuleiro, nunca a cena: a cena pode ser
## fechada com a busca ainda rodando.
func _do_ai_turn() -> void:
	if game_over:
		return

	var plano := ConnectFourAI.achatar(board)
	var saida: Array = []
	var tarefa := WorkerThreadPool.add_task(
		ConnectFourAI.pensar_em_tarefa.bind(plano[0], plano[1], 2, ai_level, saida))
	# A arvore fica guardada antes do laco: quando o jogador sai da cena com a
	# busca em andamento, `get_tree()` passa a devolver `null` no quadro
	# seguinte, e `await null.process_frame` estoura. A tarefa nao segura
	# referencia para a cena, entao esperar por ela aqui e seguro.
	var arvore := get_tree()
	while not WorkerThreadPool.is_task_completed(tarefa):
		if arvore == null:
			break
		await arvore.process_frame
	WorkerThreadPool.wait_for_task_completion(tarefa)

	if not is_inside_tree() or game_over:
		return

	var ai_col: int = int(saida[0]) if not saida.is_empty() else -1
	if ai_col != -1:
		_make_move(ai_col, 2)
	else:
		is_player_turn = true
		_update_turn_ui()

func _handle_game_won(winner_id: int, win_cells: Array[Vector2i]) -> void:
	game_over = true

	# O 4 em Linha terminava direto no modal e nunca publicava a partida: nem a
	# vitoria nem a derrota chegavam na gamificacao. `close_call` marca a
	# partida decidida com o tabuleiro quase cheio, que e a conquista "Por um
	# triz".
	report_match_result(winner_id == 1, {
		"time": Time.get_ticks_msec() / 1000.0 - _started_at,
		"close_call": _pecas_no_tabuleiro() >= COLS * ROWS - 3,
		"winner": winner_id,
		"mode": "ai" if vs_ai else "versus",
	})

	if winner_id == 1:
		score_p1 += 1
		_set_score_ui()
		win_modal_title.text = tr("WIN_TITLE") if vs_ai else tr("CONNECT4_WIN_PLAYER") % 1
		win_modal_sub.text = tr("CONNECT4_WIN_DESC") if vs_ai else tr("CONNECT4_WIN_PLAYER_DESC") % 1
		if AudioManager: AudioManager.play_win()
	else:
		score_p2 += 1
		_set_score_ui()
		win_modal_title.text = tr("CONNECT4_LOSE") if vs_ai else tr("CONNECT4_WIN_PLAYER") % 2
		win_modal_sub.text = tr("CONNECT4_LOSE_DESC") if vs_ai else tr("CONNECT4_WIN_PLAYER_DESC") % 2
		if AudioManager: AudioManager.play_win()
		
	# Highlight winning pieces
	for cell in win_cells:
		if piece_instances.has(cell):
			piece_instances[cell].set_winning(true)
			
	reveal_result_modal(win_modal, 0.8)

func _handle_game_draw() -> void:
	game_over = true
	report_match_result(false, {
		"draw": true,
		"time": Time.get_ticks_msec() / 1000.0 - _started_at,
		"mode": "ai" if vs_ai else "versus",
	})
	win_modal_title.text = tr("DRAW_TITLE")
	win_modal_sub.text = tr("CONNECT4_DRAW_DESC")
	if AudioManager: AudioManager.play_draw()
	reveal_result_modal(win_modal, 0.8)

func _update_turn_ui() -> void:
	if game_over:
		return
	_set_score_ui()
	set_active_side(is_player_turn)
	if not vs_ai:
		set_status(tr("CONNECT4_PLAYER_TURN") % (1 if is_player_turn else 2))
	elif is_player_turn:
		set_status(tr("CONNECT4_YOUR_TURN") + difficulty_suffix())
	else:
		set_status(tr("CONNECT4_AI_TURN"))


func _set_score_ui() -> void:
	if vs_ai:
		set_duel_score(score_p1, score_p2)
	else:
		set_duel_score(score_p1, score_p2, "SCORE_PLAYER_1", "SCORE_PLAYER_2")

func _start_new_game() -> void:
	win_modal.visible = false
	board.fill(0)
	for child in pieces_layer.get_children():
		child.queue_free()
	piece_instances.clear()
	game_over = false
	is_animating = false
	is_player_turn = true
	ai_level = DifficultyManager.get_level(game_id)
	_started_at = Time.get_ticks_msec() / 1000.0
	begin_match("ai" if vs_ai else "versus")
	_update_turn_ui()


## Quantas fichas ja cairam. Usado para reconhecer a partida decidida no fim.
func _pecas_no_tabuleiro() -> int:
	return piece_instances.size()


func _on_mode_toggle_pressed() -> void:
	play_click()
	vs_ai = not vs_ai
	_update_mode_button()
	restart_game()


func _update_mode_button() -> void:
	if btn_mode_toggle:
		btn_mode_toggle.text = tr("CONNECT4_BTN_VS_AI") if vs_ai else tr("CONNECT4_BTN_TWO_PLAYERS")
