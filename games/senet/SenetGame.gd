extends Control

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
var player_borne_off = 0
var ai_borne_off = 0

var current_throw = 0
var has_extra_throw = false
var can_throw = true
var is_player_turn = true
var game_over = false
var valid_moves = []
var pieces_3d: Dictionary = {}

@onready var env_3d: TabletopEnvironment3D = $TabletopEnvironment3D
@onready var board_3d: Board3D = $Board3D
@onready var pieces_root: Node3D = $PiecesRoot
@onready var status_label = $UI/VBoxContainer/StatusLabel
@onready var score_label = $UI/VBoxContainer/ScoreLabel
@onready var btn_cast_sticks = $UI/SticksArea/BtnCastSticks
@onready var sticks_label = $UI/SticksArea/SticksLabel
@onready var btn_restart = $UI/Actions/BtnRestart
@onready var touch_grid = $UI/CenterContainer/TouchGrid

func _ready():
	board_3d.setup_board(3, 10, 0.65, "wood_checkered")
	_setup_touch_grid()
	_start_new_game()

func _setup_touch_grid():
	for c in touch_grid.get_children(): c.queue_free()
	# Senet 3x10 grid serpentine
	for r in range(3):
		for c in range(10):
			var sq_num = 0
			if r == 0: sq_num = c + 1
			elif r == 1: sq_num = 20 - c
			else: sq_num = 21 + c
			
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(34, 38)
			btn.flat = true
			btn.pressed.connect(_on_square_clicked.bind(sq_num))
			touch_grid.add_child(btn)

func _get_square_row_col(sq_num: int) -> Vector2i:
	if sq_num <= 10:
		return Vector2i(0, sq_num - 1)
	elif sq_num <= 20:
		return Vector2i(1, 20 - sq_num)
	else:
		return Vector2i(2, sq_num - 21)

func _start_new_game():
	game_over = false
	is_player_turn = true
	can_throw = true
	current_throw = 0
	has_extra_throw = false
	player_borne_off = 0
	ai_borne_off = 0
	valid_moves.clear()
	btn_restart.hide()
	
	board.clear()
	for i in range(1, 31):
		board[i] = 0
		
	# Peças iniciais intercaladas (5 peças cada)
	for i in range(1, 11):
		board[i] = 1 if i % 2 == 1 else 2
		
	sticks_label.text = "Lance as 4 varetas sagradas"
	status_label.text = "Sua Vez! Lance as varetas."
	btn_cast_sticks.disabled = false
	_sync_pieces_3d()

func _sync_pieces_3d():
	for p in pieces_root.get_children(): p.queue_free()
	pieces_3d.clear()
	
	for sq in range(1, 31):
		var val = board[sq]
		var rc = _get_square_row_col(sq)
		board_3d.reset_cell_material(rc.x, rc.y)
		
		if val != 0:
			var piece = preload("res://shared/3d/Token3D.tscn").instantiate()
			piece.token_type = "pawn"
			piece.material_name = "gold" if val == 1 else "obsidian"
			piece.position = board_3d.get_cell_position_3d(rc.x, rc.y, 0.12)
			pieces_root.add_child(piece)
			pieces_3d[sq] = piece
			
	score_label.text = "Você (Ouro): %d/5  |  IA (Obsidiana): %d/5 retiradas" % [player_borne_off, ai_borne_off]

func _on_btn_cast_sticks_pressed():
	if not can_throw or game_over: return
	can_throw = false
	btn_cast_sticks.disabled = true
	
	var throw_res = _cast_sticks()
	current_throw = throw_res["value"]
	has_extra_throw = throw_res["extra"]
	
	sticks_label.text = "Varetas: %s (Avanço: %d)" % [throw_res["display"], current_throw]
	
	if is_player_turn:
		valid_moves = _get_valid_moves(1, current_throw)
		if valid_moves.is_empty():
			status_label.text = "Sem movimentos possíveis com %d!" % current_throw
			await get_tree().create_timer(0.9).timeout
			_handle_end_of_turn()
		else:
			status_label.text = "Escolha qual peça avançar %d casas:" % current_throw
			for m in valid_moves:
				var rc = _get_square_row_col(m["from"])
				board_3d.highlight_cell(rc.x, rc.y, Color(0.2, 0.85, 0.4))
	else:
		_play_ai_move()

func _cast_sticks() -> Dictionary:
	var white_count = 0
	var disp = ""
	for i in range(4):
		if randf() > 0.5:
			white_count += 1
			disp += "⚪"
		else:
			disp += "⚫"
	var val = 5 if white_count == 0 else white_count
	var extra = (val == 1 or val == 4 or val == 5)
	return {"value": val, "extra": extra, "display": disp}

func _get_valid_moves(player_id: int, steps: int) -> Array:
	var opponent = 2 if player_id == 1 else 1
	var moves = []
	
	for sq in range(1, 31):
		if board[sq] == player_id:
			var target = sq + steps
			if target == 31: # Retirada do tabuleiro
				moves.append({"from": sq, "to": 31})
			elif target < 31:
				if board[target] == 0:
					moves.append({"from": sq, "to": target})
				elif board[target] == opponent:
					# Não pode capturar se protegido por peça adjacente
					var protected = false
					if target > 1 and board[target - 1] == opponent: protected = true
					if target < 30 and board[target + 1] == opponent: protected = true
					if not protected:
						moves.append({"from": sq, "to": target})
	return moves

func _on_square_clicked(sq_num: int):
	if game_over or not is_player_turn or can_throw: return
	
	for m in valid_moves:
		if m["from"] == sq_num:
			_execute_move(1, m["from"], m["to"])
			return

func _execute_move(player_id: int, from_sq: int, to_sq: int):
	var opponent = 2 if player_id == 1 else 1
	
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
			var rebirth = 15
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

func _handle_end_of_turn():
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
			status_label.text = "Sua Vez! Lance as varetas."
			btn_cast_sticks.disabled = false
		else:
			status_label.text = "Vez da IA..."
			btn_cast_sticks.disabled = true
			await get_tree().create_timer(0.7).timeout
			_on_btn_cast_sticks_pressed()

func _play_ai_move():
	var ai_moves = _get_valid_moves(2, current_throw)
	if ai_moves.is_empty():
		status_label.text = "IA sem movimentos possíveis!"
		await get_tree().create_timer(0.8).timeout
		_handle_end_of_turn()
		return
		
	var chosen = ai_moves.pick_random()
	_execute_move(2, chosen["from"], chosen["to"])

func _end_game(winner: int):
	game_over = true
	btn_restart.show()
	if winner == 1:
		status_label.text = "🏆 Vitória dos Deuses! Você venceu o Senet 3D!"
		env_3d.celebrate_win()
	else:
		status_label.text = "A IA alcançou a imortalidade primeiro!"

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
