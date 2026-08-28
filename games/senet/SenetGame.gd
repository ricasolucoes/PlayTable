extends GridGame

## SenetGame: Senet 3D do Antigo Egito com Tabuleiro Entalhado 3x10 e Peças Conoidais em Ouro/Obsidiana

const SPECIAL_SQUARES = {
	15: {"name": "Renascimento", "symbol": "☥"},
	26: {"name": "Beleza", "symbol": "𓄤"},
	27: {"name": "Água (Nilo)", "symbol": "𓈗"},
	28: {"name": "Três Juízes", "symbol": "𓊹"},
	29: {"name": "Hórus", "symbol": "𓁹"},
	30: {"name": "Rá", "symbol": "𓇳"}
}

var board = {} # Map int (1..30) -> int (0, 1, 2)
var player_borne_off: int = 0
var ai_borne_off: int = 0
var current_throw: int = 0
var has_extra_throw: bool = false
var can_throw: bool = true
var is_player_turn: bool = true
var valid_moves: Array = []
var pieces_3d: Dictionary = {}

## Degrau de 1 a 10 do DifficultyManager. Vira a chance de a IA largar a
## avaliacao e sortear a jogada.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

@onready var board_3d: Board3D = $Board3D
@onready var pieces_root: Node3D = $PiecesRoot
@onready var level_label: Label = $UI/VBoxContainer/LevelLabel
@onready var btn_cast_sticks: Button = $UI/SticksArea/BtnCastSticks
@onready var sticks_label: Label = $UI/SticksArea/SticksLabel

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/Actions/BtnRestart
	ai_level = DifficultyManager.get_level(game_id)
	board_3d.setup_board(3, 10, 0.65, "wood_checkered")
	# O toque entra pelo proprio tabuleiro: a casa tocada e a casa desenhada.
	board_3d.cell_clicked.connect(_on_cell_clicked)
	fit_table(board_3d.content_size())
	_start_new_game()

## A grade compartilhada entrega (linha, coluna); o tabuleiro do Senet numera as
## 30 casas em serpentina, e e por numero que o resto do jogo raciocina.
func _on_cell_clicked(r: int, c: int) -> void:
	_on_square_clicked(_get_square_number(r, c))

func _get_square_number(r: int, c: int) -> int:
	if r == 0:
		return c + 1
	elif r == 1:
		return 20 - c
	return 21 + c

func _get_square_row_col(sq_num: int) -> Vector2i:
	if sq_num <= 10:
		return Vector2i(0, sq_num - 1)
	elif sq_num <= 20:
		return Vector2i(1, 20 - sq_num)
	else:
		return Vector2i(2, sq_num - 21)

func _start_new_game() -> void:
	game_over = false
	is_player_turn = true
	can_throw = true
	current_throw = 0
	has_extra_throw = false
	player_borne_off = 0
	ai_borne_off = 0
	valid_moves.clear()
	ai_level = DifficultyManager.get_level(game_id)
	btn_restart.hide()
	
	board.clear()
	for i in range(1, 31):
		board[i] = 0
		
	# Peças iniciais intercaladas (5 peças cada)
	for i in range(1, 11):
		board[i] = 1 if i % 2 == 1 else 2
		
	sticks_label.text = tr("SENET_CAST_HINT")
	set_status(tr("SENET_YOUR_TURN"))
	btn_cast_sticks.disabled = false
	_sync_pieces_3d()

func _sync_pieces_3d() -> void:
	for p in pieces_root.get_children(): p.queue_free()
	pieces_3d.clear()
	
	for sq in range(1, 31):
		var val = board[sq]
		var rc := _get_square_row_col(sq)
		board_3d.reset_cell_material(rc.x, rc.y)
		
		if val != 0:
			var piece := preload("res://shared/3d/Token3D.tscn").instantiate()
			piece.token_type = "pawn"
			piece.material_name = "gold" if val == 1 else "obsidian"
			piece.position = board_3d.get_cell_position_3d(rc.x, rc.y, 0.12)
			pieces_root.add_child(piece)
			pieces_3d[sq] = piece
			
	set_duel_score("%d/5" % player_borne_off, "%d/5" % ai_borne_off)
	level_label.text = DifficultyManager.label_for(game_id)

func _on_btn_cast_sticks_pressed() -> void:
	if not can_throw or game_over: return
	can_throw = false
	btn_cast_sticks.disabled = true
	
	var throw_res := _cast_sticks()
	current_throw = throw_res["value"]
	has_extra_throw = throw_res["extra"]
	
	sticks_label.text = tr("SENET_STICKS") % [throw_res["display"], current_throw]
	
	if is_player_turn:
		valid_moves = _get_valid_moves(1, current_throw)
		if valid_moves.is_empty():
			set_status(tr("NO_MOVES_WITH") % current_throw)
			await get_tree().create_timer(0.9).timeout
			_handle_end_of_turn()
		else:
			set_status(tr("SENET_PICK_PIECE") % current_throw)
			for m in valid_moves:
				var rc := _get_square_row_col(m["from"])
				board_3d.highlight_cell(rc.x, rc.y, Color(0.2, 0.85, 0.4))
	else:
		_play_ai_move()

func _cast_sticks() -> Dictionary:
	var white_count: int = 0
	var disp: String = ""
	for i in range(4):
		if randf() > 0.5:
			white_count += 1
			disp += "⚪"
		else:
			disp += "⚫"
	var val := 5 if white_count == 0 else white_count
	var extra := (val == 1 or val == 4 or val == 5)
	return {"value": val, "extra": extra, "display": disp}

func _get_valid_moves(player_id: int, steps: int) -> Array:
	var opponent := 2 if player_id == 1 else 1
	var moves: Array = []
	for sq in range(1, 31):
		if board[sq] == player_id:
			var target := sq + steps
			if target == 31: # Retirada do tabuleiro
				moves.append({"from": sq, "to": 31})
			elif target < 31:
				if board[target] == 0:
					moves.append({"from": sq, "to": target})
				elif board[target] == opponent:
					# Não pode capturar se protegido por peça adjacente
					var protected: bool = false
					if target > 1 and board[target - 1] == opponent: protected = true
					if target < 30 and board[target + 1] == opponent: protected = true
					if not protected:
						moves.append({"from": sq, "to": target})
	return moves

func _on_square_clicked(sq_num: int) -> void:
	if game_over or not is_player_turn or can_throw: return
	
	for m in valid_moves:
		if m["from"] == sq_num:
			_execute_move(1, m["from"], m["to"])
			return

func _execute_move(player_id: int, from_sq: int, to_sq: int) -> void:
	var opponent := 2 if player_id == 1 else 1
	
	if to_sq == 31:
		board[from_sq] = 0
		if player_id == 1: player_borne_off += 1
		else: ai_borne_off += 1
	else:
		if board[to_sq] == opponent:
			board[from_sq] = opponent
			board[to_sq] = player_id
		else:
			board[from_sq] = 0
			board[to_sq] = player_id
			
		# Casa da Água (27) afoga e manda para o Renascimento (15)
		if to_sq == 27:
			board[to_sq] = 0
			var rebirth := 15
			while board[rebirth] != 0 and rebirth > 1:
				rebirth -= 1
			board[rebirth] = player_id
			
	_sync_pieces_3d()
	
	if player_borne_off >= 5:
		_end_game(1)
		return
	elif ai_borne_off >= 5:
		_end_game(2)
		return
		
	_handle_end_of_turn()

func _handle_end_of_turn() -> void:
	if has_extra_throw:
		status_label.text += " Jogada extra concedida!"
		can_throw = true
		if is_player_turn:
			btn_cast_sticks.disabled = false
		else:
			await get_tree().create_timer(0.7).timeout
			_on_btn_cast_sticks_pressed()
	else:
		is_player_turn = not is_player_turn
		can_throw = true
		if is_player_turn:
			set_status(tr("SENET_YOUR_TURN"))
			btn_cast_sticks.disabled = false
		else:
			set_status(tr("AI_TURN_SHORT"))
			btn_cast_sticks.disabled = true
			await get_tree().create_timer(0.7).timeout
			_on_btn_cast_sticks_pressed()

func _play_ai_move() -> void:
	var chosen := SenetAI.choose_move(SenetAI.achatar(board), 2, current_throw,
		ai_borne_off, player_borne_off, ai_level)
	if chosen.is_empty():
		set_status(tr("SENET_AI_NO_MOVES"))
		await get_tree().create_timer(0.8).timeout
		_handle_end_of_turn()
		return

	_execute_move(2, chosen["from"], chosen["to"])

func _end_game(winner: int) -> void:
	if winner == 1:
		finish_game(tr("SENET_WIN"), true)
	else:
		finish_game(tr("SENET_LOSE"))
