extends Control

# Senet Board: 30 squares (indices 1 to 30)
# Pieces: 1 = Player, 2 = AI, 0 = Empty

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
var valid_moves = [] # Array of Dictionary: {"from": int, "to": int}

@onready var grid = $VBoxContainer/CenterContainer/BoardContainer/Grid
@onready var status_label = $VBoxContainer/StatusLabel
@onready var score_label = $VBoxContainer/ScoreLabel
@onready var btn_cast_sticks = $VBoxContainer/SticksArea/BtnCastSticks
@onready var sticks_label = $VBoxContainer/SticksArea/SticksLabel
@onready var btn_restart = $VBoxContainer/Actions/BtnRestart

var square_buttons = {} # Map int (1..30) -> Button

func _ready():
	_setup_grid()
	_start_new_game()

func _setup_grid():
	for c in grid.get_children(): c.queue_free()
	square_buttons.clear()
	
	# Senet 3x10 grid serpentine:
	# Row 0: 1 to 10 (L to R)
	# Row 1: 20 down to 11 (R to L)
	# Row 2: 21 to 30 (L to R)
	
	for r in range(3):
		for c in range(10):
			var sq_num = 0
			if r == 0:
				sq_num = c + 1
			elif r == 1:
				sq_num = 20 - c
			else:
				sq_num = 21 + c
				
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(65, 80)
			btn.add_theme_font_size_override("font_size", 20)
			btn.pressed.connect(_on_square_clicked.bind(sq_num))
			grid.add_child(btn)
			square_buttons[sq_num] = btn

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
	
	# Initial board setup (alternating 1 to 10)
	board.clear()
	for i in range(1, 31):
		board[i] = 0
		
	for i in range(1, 11):
		if i % 2 == 1:
			board[i] = 1 # Player
		else:
			board[i] = 2 # AI
			
	btn_cast_sticks.disabled = false
	sticks_label.text = "Lance as varetas sagradas!"
	status_label.text = "Sua Vez! Lance as varetas."
	_update_ui()

func _update_ui():
	score_label.text = "Removidas do Tabuleiro: Você (%d/5) | IA (%d/5)" % [player_borne_off, ai_borne_off]
	
	for sq in range(1, 31):
		var btn = square_buttons[sq]
		var val = board[sq]
		
		var sym = ""
		if SPECIAL_SQUARES.has(sq):
			sym = SPECIAL_SQUARES[sq]["symbol"]
			
		var piece_text = ""
		if val == 1:
			piece_text = "🔺"
		elif val == 2:
			piece_text = "💠"
			
		btn.text = "%d %s\n%s" % [sq, sym, piece_text]
		
		# Colors
		var is_valid_source = false
		for vm in valid_moves:
			if vm["from"] == sq:
				is_valid_source = true
				break
				
		if is_valid_source and is_player_turn:
			btn.self_modulate = Color(0.3, 0.7, 0.4) # Green highlight
		elif SPECIAL_SQUARES.has(sq):
			btn.self_modulate = Color(0.4, 0.3, 0.2) # Sacred house gold/brown
		else:
			btn.self_modulate = Color(0.25, 0.22, 0.18)

func _on_btn_cast_sticks_pressed():
	if not can_throw or not is_player_turn or game_over: return
	
	can_throw = false
	btn_cast_sticks.disabled = true
	
	# Throw 4 sticks (0 or 1)
	var white_sticks = 0
	var sticks_vis = ""
	for i in range(4):
		var is_white = randf() > 0.5
		if is_white:
			white_sticks += 1
			sticks_vis += "⚪ "
		else:
			sticks_vis += "⚫ "
			
	if white_sticks == 1:
		current_throw = 1
		has_extra_throw = true
	elif white_sticks == 2:
		current_throw = 2
		has_extra_throw = false
	elif white_sticks == 3:
		current_throw = 3
		has_extra_throw = false
	elif white_sticks == 4:
		current_throw = 4
		has_extra_throw = true
	else:
		current_throw = 5
		has_extra_throw = true
		
	sticks_label.text = "%s = %d Pontos! %s" % [sticks_vis, current_throw, ("(Jogada Extra!)" if has_extra_throw else "")]
	
	# Calculate player valid moves
	valid_moves = _get_valid_moves_for_player(1, current_throw)
	if valid_moves.size() == 0:
		status_label.text = "Tirou %d, mas não há movimentos válidos!" % current_throw
		await get_tree().create_timer(1.2).timeout
		_end_turn_and_switch()
	else:
		status_label.text = "Tirou %d! Toque em uma peça destacada em verde." % current_throw
		_update_ui()

func _get_valid_moves_for_player(player_id: int, steps: int) -> Array:
	var moves = []
	var opponent_id = 2 if player_id == 1 else 1
	
	for sq in range(1, 31):
		if board[sq] == player_id:
			var target_sq = sq + steps
			
			# Special exit rules for houses 28, 29, 30
			if sq == 28 and steps != 3: continue
			if sq == 29 and steps != 2: continue
			if sq == 30 and steps != 1: continue
			
			# Bearing off past square 30
			if target_sq > 30:
				moves.append({"from": sq, "to": 31})
				continue
				
			# Must stop on House of Beauty (26) if passing through
			if sq < 26 and target_sq > 26:
				target_sq = 26
				
			# Check target square
			if board[target_sq] == 0:
				moves.append({"from": sq, "to": target_sq})
			elif board[target_sq] == opponent_id:
				# Check if opponent is protected (has adjacent friendly piece)
				if not _is_protected(target_sq, opponent_id):
					moves.append({"from": sq, "to": target_sq})
					
	return moves

func _is_protected(sq: int, owner_id: int) -> bool:
	var left_has = (sq > 1 and board[sq - 1] == owner_id)
	var right_has = (sq < 30 and board[sq + 1] == owner_id)
	return left_has or right_has

func _on_square_clicked(sq: int):
	if game_over or not is_player_turn or can_throw: return
	
	for vm in valid_moves:
		if vm["from"] == sq:
			_execute_move(1, vm)
			return

func _execute_move(player_id: int, move_data: Dictionary):
	var from_sq = move_data["from"]
	var to_sq = move_data["to"]
	var opponent_id = 2 if player_id == 1 else 1
	
	board[from_sq] = 0
	
	if to_sq == 31: # Borne off
		if player_id == 1:
			player_borne_off += 1
		else:
			ai_borne_off += 1
	else:
		# Check attack swap
		if board[to_sq] == opponent_id:
			board[from_sq] = opponent_id
			board[to_sq] = player_id
			status_label.text = "⚔️ Peça adversária capturada e trocada de lugar!"
		else:
			# Check Nile trap (House 27)
			if to_sq == 27:
				status_label.text = "🌊 Caiu no Nilo! Peça enviada para o Renascimento (15)."
				var rebirth_sq = 15
				if board[rebirth_sq] != 0:
					rebirth_sq = 1
					while rebirth_sq < 30 and board[rebirth_sq] != 0:
						rebirth_sq += 1
				board[rebirth_sq] = player_id
			else:
				board[to_sq] = player_id
				
	valid_moves.clear()
	_update_ui()
	
	if _check_win(): return
	
	if has_extra_throw:
		has_extra_throw = false
		if player_id == 1:
			can_throw = true
			btn_cast_sticks.disabled = false
			status_label.text = "⭐ Lance extra! Jogue as varetas novamente."
		else:
			await get_tree().create_timer(0.8).timeout
			_play_ai_turn()
	else:
		_end_turn_and_switch()

func _end_turn_and_switch():
	if is_player_turn:
		is_player_turn = false
		can_throw = false
		btn_cast_sticks.disabled = true
		status_label.text = "Vez da IA..."
		_update_ui()
		await get_tree().create_timer(0.8).timeout
		_play_ai_turn()
	else:
		is_player_turn = true
		can_throw = true
		btn_cast_sticks.disabled = false
		status_label.text = "Sua Vez! Lance as varetas."
		_update_ui()

func _play_ai_turn():
	if game_over: return
	
	# AI cast sticks
	var white_sticks = 0
	var sticks_vis = ""
	for i in range(4):
		if randf() > 0.5:
			white_sticks += 1
			sticks_vis += "⚪ "
		else:
			sticks_vis += "⚫ "
			
	var ai_throw = 1
	var ai_extra = false
	if white_sticks == 1: ai_throw = 1; ai_extra = true
	elif white_sticks == 2: ai_throw = 2
	elif white_sticks == 3: ai_throw = 3
	elif white_sticks == 4: ai_throw = 4; ai_extra = true
	else: ai_throw = 5; ai_extra = true
	
	has_extra_throw = ai_extra
	sticks_label.text = "IA: %s = %d Pontos! %s" % [sticks_vis, ai_throw, ("(Jogada Extra!)" if ai_extra else "")]
	
	var ai_moves = _get_valid_moves_for_player(2, ai_throw)
	if ai_moves.size() == 0:
		status_label.text = "IA tirou %d, mas não tem jogadas!" % ai_throw
		await get_tree().create_timer(1.2).timeout
		_end_turn_and_switch()
		return
		
	# Choose best move (prioritize bearing off, then attacks, then moving furthest piece)
	ai_moves.sort_custom(func(a, b):
		var score_a = 100 if a["to"] == 31 else (50 if board[a["to"]] == 1 else a["to"])
		var score_b = 100 if b["to"] == 31 else (50 if board[b["to"]] == 1 else b["to"])
		return score_a > score_b
	)
	
	var chosen_move = ai_moves[0]
	status_label.text = "IA moveu da casa %d para %d." % [chosen_move["from"], chosen_move["to"]]
	await get_tree().create_timer(0.6).timeout
	_execute_move(2, chosen_move)

func _check_win() -> bool:
	if player_borne_off >= 5:
		game_over = true
		status_label.text = "🏆 Vitória Sagrada! Você alcançou a vida eterna no Senet!"
		btn_restart.show()
		return true
	elif ai_borne_off >= 5:
		game_over = true
		status_label.text = "💀 A IA removeu todas as peças e Venceu!"
		btn_restart.show()
		return true
	return false

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
