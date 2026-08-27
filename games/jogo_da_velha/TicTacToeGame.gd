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

## Nivel da IA. Sobe um degrau a cada vitoria do jogador e so desce depois de
## duas derrotas seguidas -- perder uma vez nao tira o degrau conquistado.
##
## Fica gravado: sem isso a IA voltava ao nivel 1 toda vez que a tela era
## reaberta, e a mesma abertura de forquilha ganhava de novo, para sempre.
const DIFFICULTY_KEY := "ttt_ai_level"
const LOSSES_KEY := "ttt_losses_streak"

var ai_level: int = TicTacToeRules.Level.HARD
var losses_streak: int = 0

@onready var grid_container: GridContainer = $BoardContainer/Grid
@onready var x_panel: PanelContainer = $VBoxContainer/ScoreBoard/P1Panel
@onready var o_panel: PanelContainer = $VBoxContainer/ScoreBoard/P2Panel
@onready var x_score_lbl: Label = $VBoxContainer/ScoreBoard/P1Panel/HBox/Score
@onready var o_score_lbl: Label = $VBoxContainer/ScoreBoard/P2Panel/HBox/Score
@onready var win_modal: ColorRect = $WinModal
@onready var win_modal_title: Label = $WinModal/Panel/VBox/WinTitle
@onready var win_modal_sub: Label = $WinModal/Panel/VBox/WinSub
@onready var strike_line: Line2D = $BoardContainer/StrikeLine
@onready var level_label: Label = $VBoxContainer/StatusCard/StatusVBox/LevelLabel

func _ready() -> void:
	status_label = $VBoxContainer/StatusCard/StatusVBox/StatusLabel
	ai_level = clampi(int(SaveManager.get_setting(DIFFICULTY_KEY, TicTacToeRules.Level.HARD)),
		TicTacToeRules.Level.EASY, TicTacToeRules.MAX_LEVEL)
	losses_streak = int(SaveManager.get_setting(LOSSES_KEY, 0))
	_setup_grid_cells()
	_update_level_label()
	_update_turn_ui()
	win_modal.visible = false
	strike_line.visible = false


func _update_level_label() -> void:
	if level_label:
		level_label.text = tr("TTT_LEVEL_LABEL") % tr(TicTacToeRules.level_name(ai_level))


## Ajusta o degrau depois da partida e grava.
func _tune_difficulty(player_won: bool, was_draw: bool) -> void:
	var subiu := false
	if player_won:
		losses_streak = 0
		if ai_level < TicTacToeRules.MAX_LEVEL:
			ai_level += 1
			subiu = true
	elif was_draw:
		losses_streak = 0
	else:
		losses_streak += 1
		if losses_streak >= 2 and ai_level > TicTacToeRules.Level.EASY:
			ai_level -= 1
			losses_streak = 0

	SaveManager.set_setting(DIFFICULTY_KEY, ai_level)
	SaveManager.set_setting(LOSSES_KEY, losses_streak)
	_update_level_label()

	if subiu:
		win_modal_sub.text += "\n" + (tr("TTT_LEVEL_UP") % tr(TicTacToeRules.level_name(ai_level)))

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

	# O jogo termina por modal, nao por `finish_game()`: a gamificacao precisa
	# ser publicada a mao.
	var venceu := winner_id == 1
	_tune_difficulty(venceu, false)
	report_match_result(venceu, {"ai_level": ai_level})
	if venceu and env_3d != null:
		env_3d.celebrate_win()
	reveal_result_modal(win_modal)

func _handle_game_draw() -> void:
	game_over = true
	win_modal_title.text = "Empate!"
	win_modal_sub.text = "Nenhum jogador conseguiu alinhar 3 peças."
	if AudioManager: AudioManager.play_draw()
	_tune_difficulty(false, true)
	report_match_result(false, {"ai_level": ai_level, "draw": true})
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
	_update_level_label()
	board.fill(0)
	game_over = false
	is_player_turn = true
	strike_line.visible = false
	for piece in piece_nodes:
		piece.piece_type = piece.PieceType.EMPTY
		piece.set_winning(false)
	_update_turn_ui()
