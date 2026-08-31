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

## Degrau de 1 a 10 do DifficultyManager, o mesmo dos outros jogos. Quem move
## a escada e o `report_match_result()` do BaseGame; aqui so se le.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

@onready var grid_container: GridContainer = $BoardContainer/Grid
@onready var win_modal: ColorRect = $WinModal
@onready var win_modal_title: Label = $WinModal/Panel/VBox/WinTitle
@onready var win_modal_sub: Label = $WinModal/Panel/VBox/WinSub
@onready var strike_line: Line2D = $BoardContainer/StrikeLine
@onready var level_label: Label = $VBoxContainer/StatusCard/StatusVBox/LevelLabel
@onready var btn_mode_toggle: Button = $VBoxContainer/TopBar/BtnModeToggle

func _ready() -> void:
	status_label = $VBoxContainer/StatusCard/StatusVBox/StatusLabel
	ai_level = DifficultyManager.get_level(game_id)
	_setup_grid_cells()
	btn_mode_toggle.pressed.connect(_on_mode_toggle_pressed)
	_update_mode_button()
	_update_level_label()
	_update_turn_ui()
	win_modal.visible = false
	strike_line.visible = false
	_maybe_ai_opens()
	begin_match("ai" if vs_ai else "versus")


func _update_level_label() -> void:
	if level_label:
		level_label.text = DifficultyManager.label_for(game_id)


## Do degrau 8 em diante quem abre a partida e a IA.
##
## Jogo da velha e resolvido: contra minimax perfeito quem abre no maximo
## empata. Enquanto o jogador abria sempre, ele nao podia perder -- e a escada
## travava no topo para sempre, porque so a derrota faz descer.
func _maybe_ai_opens() -> void:
	if not vs_ai or game_over or not TicTacToeRules.ai_opens(ai_level):
		return
	is_player_turn = false
	_update_turn_ui()
	set_status(tr("DIFF_AI_OPENS"))
	await get_tree().create_timer(0.45).timeout
	if is_inside_tree():
		_do_ai_turn()


## Fecha a partida na escada e avisa na tela quando o degrau andou.
##
## Quem move a escada e `report_match_result()`, no BaseGame -- todo jogo anda
## nela, tenha IA ou nao. Aqui so se le o degrau novo, que so existe depois
## daquela chamada.
func _close_ladder(player_won: bool, was_draw: bool) -> void:
	var antes := DifficultyManager.get_level(game_id)
	report_match_result(player_won, {"ai_level": ai_level, "draw": was_draw})

	var depois := DifficultyManager.get_level(game_id)
	ai_level = depois
	_update_level_label()
	var aviso := DifficultyManager.change_notice(depois, depois - antes)
	if aviso != "":
		win_modal_sub.text += "\n" + aviso

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
	if game_over or (vs_ai and not is_player_turn) or board.cells[idx] != 0:
		return
		
	# No modo local, a mesma mesa recebe os toques dos dois jogadores. O lado
	# ativo é determinado pela vez; contra a IA, o humano continua sendo o X.
	var player_id := 1 if vs_ai or is_player_turn else 2
	_place_move(idx, player_id)

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
		
	var move := TicTacToeRules.get_move(board, 2, ai_level)
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
		set_duel_score(score_x, score_o)
		win_modal_title.text = tr("TICTACTOE_WIN_X") if vs_ai else tr("TICTACTOE_WIN_PLAYER") % 1
		win_modal_sub.text = tr("TICTACTOE_WIN_X_DESC") if vs_ai else tr("TICTACTOE_WIN_PLAYER_DESC") % 1
		if AudioManager: AudioManager.play_win()
	else:
		score_o += 1
		set_duel_score(score_x, score_o)
		win_modal_title.text = tr("TICTACTOE_WIN_O") if vs_ai else tr("TICTACTOE_WIN_PLAYER") % 2
		win_modal_sub.text = tr("TICTACTOE_WIN_O_DESC") if vs_ai else tr("TICTACTOE_WIN_PLAYER_DESC") % 2
		if AudioManager: AudioManager.play_win()

	# O jogo termina por modal, nao por `finish_game()`: a gamificacao precisa
	# ser publicada a mao.
	var venceu := winner_id == 1
	_close_ladder(venceu, false)
	if venceu and env_3d != null:
		env_3d.celebrate_win()
	reveal_result_modal(win_modal)

func _handle_game_draw() -> void:
	game_over = true
	win_modal_title.text = tr("DRAW_TITLE")
	win_modal_sub.text = tr("TICTACTOE_DRAW_DESC")
	if AudioManager: AudioManager.play_draw()
	_close_ladder(false, true)
	reveal_result_modal(win_modal)

func _update_turn_ui() -> void:
	if game_over: return
	if vs_ai:
		set_duel_score(score_x, score_o)
	else:
		set_duel_score(score_x, score_o, "SCORE_PLAYER_1", "SCORE_PLAYER_2")
	set_active_side(is_player_turn)
	if not vs_ai:
		set_status(tr("TICTACTOE_PLAYER_TURN") % (1 if is_player_turn else 2))
	elif is_player_turn:
		set_status(tr("TICTACTOE_YOUR_TURN"))
	else:
		set_status(tr("TICTACTOE_AI_TURN"))

func _start_new_game() -> void:
	win_modal.visible = false
	ai_level = DifficultyManager.get_level(game_id)
	_update_level_label()
	board.fill(0)
	game_over = false
	is_player_turn = true
	strike_line.visible = false
	for piece in piece_nodes:
		piece.piece_type = piece.PieceType.EMPTY
		piece.set_winning(false)
	_update_turn_ui()
	_maybe_ai_opens()
	begin_match("ai" if vs_ai else "versus")


func _on_mode_toggle_pressed() -> void:
	play_click()
	vs_ai = not vs_ai
	_update_mode_button()
	restart_game()


func _update_mode_button() -> void:
	if btn_mode_toggle:
		btn_mode_toggle.text = tr("TICTACTOE_BTN_VS_AI") if vs_ai else tr("TICTACTOE_BTN_TWO_PLAYERS")
