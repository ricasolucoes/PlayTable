extends BaseGame

## Tic-Tac-Toe game implementation.

const PIECE_SCRIPT = preload("res://games/jogo_da_velha/TicTacToePiece.gd")

## Estado da partida. As regras moram em TicTacToeRules, que a suite ja
## exercitava enquanto a cena rodava a propria copia delas.
var board: Grid2D = Grid2D.new(3, 3, 0)
var vs_ai: bool = true
var is_player_turn: bool = true

## Partida em rede: X e quem abriu a sala, O e quem entrou. A mesma mesa que
## os dois jogadores locais usam, so que cada aparelho toca so na propria vez
## e a jogada do outro chega por `_on_net_move`.
var em_rede: bool = false
var score_x: int = 0
var score_o: int = 0
var piece_nodes: Array[Node2D] = []

## Degrau de 1 a 10 do DifficultyManager, o mesmo dos outros jogos. Quem move
## a escada e o `report_match_result()` do BaseGame; aqui so se le.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

@onready var grid_container: GridContainer = $BoardContainer/Grid
@onready var strike_line: Line2D = $BoardContainer/StrikeLine
@onready var btn_mode_toggle: Button = $UI/TopActions/BtnModeToggle
@onready var shell: GameShell = $GameShell

func _ready() -> void:
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	shell.restart_requested.connect(_on_restart_pressed)
	ai_level = DifficultyManager.get_level(game_id)
	_ler_modo_de_rede()
	_setup_grid_cells()
	_update_mode_button()
	_update_level_label()
	_update_turn_ui()
	strike_line.visible = false
	_maybe_ai_opens()
	begin_match(_modo())


## Entra em rede quando o NetworkManager ja esta em partida deste jogo. Sai da
## rede -- e volta ao duelo local -- quando o outro lado se foi.
func _ler_modo_de_rede() -> void:
	em_rede = net_active()
	if em_rede:
		vs_ai = false
	if btn_mode_toggle:
		btn_mode_toggle.visible = not em_rede


func _modo() -> String:
	if em_rede:
		return "online"
	return "ai" if vs_ai else "versus"


## O lado que joga agora, 1 (X) ou 2 (O).
func _lado_da_vez() -> int:
	return 1 if is_player_turn else 2


func _update_level_label() -> void:
	pass


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
	# Em rede, este aparelho so joga pelo proprio assento.
	if em_rede and not NetworkManager.is_my_turn(player_id):
		return
	if em_rede:
		net_send({"idx": idx})
	_place_move(idx, player_id)


## A jogada do outro aparelho. So vale se for a vez dele e a casa estiver livre.
func _on_net_move(payload: Dictionary) -> void:
	if not em_rede or game_over:
		return
	var idx := int(payload.get("idx", -1))
	if idx < 0 or idx >= 9 or board.cells[idx] != 0:
		return
	var lado := _lado_da_vez()
	if lado != NetworkManager.remote_seat():
		return
	_place_move(idx, lado)

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
		
	var msg := ""
	if winner_id == 1:
		score_x += 1
		msg = tr("TICTACTOE_WIN_X") if vs_ai else tr("TICTACTOE_WIN_PLAYER") % 1
	else:
		score_o += 1
		msg = tr("TICTACTOE_WIN_O") if vs_ai else tr("TICTACTOE_WIN_PLAYER") % 2
	_pintar_placar()

	var venceu := winner_id == 1
	if em_rede:
		venceu = NetworkManager.is_my_turn(winner_id)
		msg = tr("RESULT_YOU_WIN") if venceu else tr("NET_OPPONENT_WINS") % net_opponent_name()
	if AudioManager and (venceu or not em_rede):
		AudioManager.play_win()
	finish_game(msg, venceu, {"ai_level": ai_level, "draw": false, "mode": _modo()})

func _handle_game_draw() -> void:
	game_over = true
	if AudioManager: AudioManager.play_draw()
	finish_game(tr("DRAW_TITLE"), false, {"ai_level": ai_level, "draw": true})

## O placar da barra: em rede, o meu numero e o do meu assento.
func _pintar_placar() -> void:
	if em_rede:
		var meu := score_x if NetworkManager.local_seat == 1 else score_o
		var dele := score_o if NetworkManager.local_seat == 1 else score_x
		set_duel_score(meu, dele, "NET_YOU", "NET_OPPONENT")
	elif vs_ai:
		set_duel_score(score_x, score_o)
	else:
		set_duel_score(score_x, score_o, "SCORE_PLAYER_1", "SCORE_PLAYER_2")


func _update_turn_ui() -> void:
	if game_over: return
	_pintar_placar()
	
	if em_rede:
		var minha := NetworkManager.is_my_turn(_lado_da_vez())
		set_active_side(minha)
		shell.set_level(tr("NET_MODE_LABEL") % net_opponent_name())
		set_status(tr("NET_YOUR_TURN") if minha else tr("NET_THEIR_TURN") % net_opponent_name())
		return

	set_active_side(is_player_turn)
	shell.set_level(DifficultyManager.label_for(game_id))
	
	if not vs_ai:
		set_status(tr("TICTACTOE_PLAYER_TURN") % (1 if is_player_turn else 2))
	elif is_player_turn:
		set_status(tr("TICTACTOE_YOUR_TURN"))
	else:
		set_status(tr("TICTACTOE_AI_TURN"))

func _start_new_game() -> void:
	ai_level = DifficultyManager.get_level(game_id)
	_ler_modo_de_rede()
	_update_level_label()
	_update_mode_button()
	board.fill(0)
	game_over = false
	is_player_turn = true
	strike_line.visible = false
	for piece in piece_nodes:
		piece.piece_type = piece.PieceType.EMPTY
		piece.set_winning(false)
	_update_turn_ui()
	_maybe_ai_opens()
	begin_match(_modo())


func _on_mode_toggle_pressed() -> void:
	play_click()
	vs_ai = not vs_ai
	_update_mode_button()
	restart_game()


func _update_mode_button() -> void:
	if btn_mode_toggle:
		btn_mode_toggle.text = tr("TICTACTOE_BTN_VS_AI") if vs_ai else tr("TICTACTOE_BTN_TWO_PLAYERS")
