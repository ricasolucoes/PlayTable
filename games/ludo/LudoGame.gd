extends Control

# Players: 0 = Player (Red), 1 = AI Blue, 2 = AI Green, 3 = AI Yellow
const PLAYER_NAMES = ["Jogador (Vermelho)", "IA (Azul)", "IA (Verde)", "IA (Amarelo)"]
const PLAYER_COLORS = [
	Color(0.9, 0.25, 0.25),
	Color(0.2, 0.55, 0.9),
	Color(0.2, 0.75, 0.35),
	Color(0.95, 0.8, 0.1)
]
const START_OFFSETS = [0, 7, 14, 21]
const TRACK_LENGTH = 28
const GOAL_STEPS = 4
const PAWNS_PER_PLAYER = 2

# Pawn state: -1 = In Base/Yard, 0 to 27 = Relative steps from player start, 28 to 31 = Home stretch, 32 = Finished (Goal)
var players_pawns = [
	[-1, -1], # Player Red
	[-1, -1], # AI Blue
	[-1, -1], # AI Green
	[-1, -1]  # AI Yellow
]

var current_turn: int = 0
var last_roll: int = 0
var can_roll: bool = true
var game_over: bool = false
var selectable_pawns: Array = []

@onready var status_label = $VBoxContainer/StatusLabel
@onready var btn_dice = $VBoxContainer/DiceArea/BtnDice
@onready var pawn_buttons_container = $VBoxContainer/PawnSelectionArea/PawnButtons
@onready var board_status_label = $VBoxContainer/BoardOverview/BoardStatusLabel
@onready var btn_restart = $VBoxContainer/Actions/BtnRestart

func _ready():
	_start_new_game()

func _start_new_game():
	game_over = false
	current_turn = 0
	last_roll = 0
	can_roll = true
	selectable_pawns.clear()
	btn_restart.hide()
	
	players_pawns = [
		[-1, -1],
		[-1, -1],
		[-1, -1],
		[-1, -1]
	]
	
	btn_dice.text = "🎲 Rolar Dado"
	btn_dice.disabled = false
	btn_dice.self_modulate = PLAYER_COLORS[0]
	status_label.text = "Sua Vez! Toque no dado para rolar."
	_update_ui()

func _update_ui():
	var text = ""
	for p in range(4):
		var p_name = PLAYER_NAMES[p]
		var pawns_desc = []
		for idx in range(PAWNS_PER_PLAYER):
			var pos = players_pawns[p][idx]
			if pos == -1:
				pawns_desc.append("Na Base 🏠")
			elif pos >= 32:
				pawns_desc.append("No Centro 🏆")
			elif pos >= 28:
				pawns_desc.append("Reta Final (%d/4)" % (pos - 27))
			else:
				pawns_desc.append("Casa %d" % ((pos + START_OFFSETS[p]) % TRACK_LENGTH))
		text += "%s:\n  Peão 1: %s | Peão 2: %s\n\n" % [p_name, pawns_desc[0], pawns_desc[1]]
		
	board_status_label.text = text
	
	# Pawn selection buttons
	for c in pawn_buttons_container.get_children(): c.queue_free()
	if current_turn == 0 and selectable_pawns.size() > 0 and not game_over:
		for p_idx in selectable_pawns:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(180, 60)
			btn.add_theme_font_size_override("font_size", 20)
			var pos = players_pawns[0][p_idx]
			if pos == -1:
				btn.text = "Mover Peão %d (Sair da Base)" % (p_idx + 1)
			else:
				btn.text = "Mover Peão %d (+%d casas)" % [p_idx + 1, last_roll]
			btn.self_modulate = PLAYER_COLORS[0]
			btn.pressed.connect(_on_player_select_pawn.bind(p_idx))
			pawn_buttons_container.add_child(btn)

func _on_btn_dice_pressed():
	if not can_roll or current_turn != 0 or game_over: return
	
	can_roll = false
	btn_dice.disabled = true
	
	# Animate roll
	for i in range(5):
		btn_dice.text = "🎲 %d" % (randi() % 6 + 1)
		await get_tree().create_timer(0.06).timeout
		
	last_roll = randi() % 6 + 1
	btn_dice.text = "🎲 %d" % last_roll
	
	_handle_roll_result(0, last_roll)

func _handle_roll_result(player_idx: int, roll: int):
	var valid_pawns = _get_movable_pawns(player_idx, roll)
	
	if valid_pawns.size() == 0:
		status_label.text = "%s tirou %d, mas não tem movimentos possíveis!" % [PLAYER_NAMES[player_idx], roll]
		await get_tree().create_timer(1.0).timeout
		_next_turn(false)
		return
		
	if player_idx == 0:
		if valid_pawns.size() == 1:
			_execute_pawn_move(0, valid_pawns[0], roll)
		else:
			selectable_pawns = valid_pawns
			status_label.text = "Você tirou %d! Escolha qual peão mover:" % roll
			_update_ui()
	else:
		# AI chooses best pawn
		var chosen_pawn = _ai_choose_pawn(player_idx, valid_pawns, roll)
		await get_tree().create_timer(0.6).timeout
		_execute_pawn_move(player_idx, chosen_pawn, roll)

func _get_movable_pawns(p_idx: int, roll: int) -> Array:
	var movable = []
	for i in range(PAWNS_PER_PLAYER):
		var pos = players_pawns[p_idx][i]
		if pos == -1:
			if roll == 6:
				movable.append(i)
		elif pos < 32:
			if pos + roll <= 32:
				movable.append(i)
	return movable

func _execute_pawn_move(p_idx: int, pawn_idx: int, roll: int):
	selectable_pawns.clear()
	var old_pos = players_pawns[p_idx][pawn_idx]
	var new_pos: int
	
	if old_pos == -1:
		new_pos = 0 # Enters track
	else:
		new_pos = old_pos + roll
		
	players_pawns[p_idx][pawn_idx] = new_pos
	
	# Check capture on common track (pos < 28)
	var capture_happened = false
	if new_pos < 28:
		var global_pos = (new_pos + START_OFFSETS[p_idx]) % TRACK_LENGTH
		for other_p in range(4):
			if other_p != p_idx:
				for other_pawn in range(PAWNS_PER_PLAYER):
					var other_pos = players_pawns[other_p][other_pawn]
					if other_pos >= 0 and other_pos < 28:
						var other_global = (other_pos + START_OFFSETS[other_p]) % TRACK_LENGTH
						if other_global == global_pos:
							# Capture! Send back to yard
							players_pawns[other_p][other_pawn] = -1
							capture_happened = true
							status_label.text = "⚔️ %s capturou o peão de %s!" % [PLAYER_NAMES[p_idx], PLAYER_NAMES[other_p]]
							
	_update_ui()
	
	# Check victory
	var all_finished = true
	for i in range(PAWNS_PER_PLAYER):
		if players_pawns[p_idx][i] < 32:
			all_finished = false
			break
			
	if all_finished:
		_end_game("🏆 %s levou todos os peões ao centro e VENCEU!" % PLAYER_NAMES[p_idx])
		return
		
	# Extra turn if rolled 6 or captured
	var extra_turn = (roll == 6 or capture_happened)
	if extra_turn:
		status_label.text = "%s ganhou uma jogada extra!" % PLAYER_NAMES[p_idx]
		await get_tree().create_timer(1.0).timeout
		_continue_same_player()
	else:
		await get_tree().create_timer(0.8).timeout
		_next_turn(false)

func _continue_same_player():
	if current_turn == 0:
		can_roll = true
		btn_dice.disabled = false
		status_label.text = "Sua Vez Extra! Role o dado."
	else:
		_play_ai_turn()

func _next_turn(_extra: bool):
	current_turn = (current_turn + 1) % 4
	btn_dice.self_modulate = PLAYER_COLORS[current_turn]
	
	if current_turn == 0:
		can_roll = true
		btn_dice.disabled = false
		status_label.text = "Sua Vez! Role o dado."
	else:
		can_roll = false
		btn_dice.disabled = true
		status_label.text = "Vez de %s..." % PLAYER_NAMES[current_turn]
		await get_tree().create_timer(0.6).timeout
		_play_ai_turn()

func _on_player_select_pawn(pawn_idx: int):
	_execute_pawn_move(0, pawn_idx, last_roll)

func _play_ai_turn():
	if game_over: return
	
	# Animate AI roll
	for i in range(4):
		btn_dice.text = "🎲 %d" % (randi() % 6 + 1)
		await get_tree().create_timer(0.06).timeout
		
	last_roll = randi() % 6 + 1
	btn_dice.text = "🎲 %d" % last_roll
	
	_handle_roll_result(current_turn, last_roll)

func _ai_choose_pawn(p_idx: int, valid_pawns: Array, roll: int) -> int:
	# Priority 1: Leave base if roll == 6
	for p in valid_pawns:
		if players_pawns[p_idx][p] == -1 and roll == 6:
			return p
	# Priority 2: Score goal
	for p in valid_pawns:
		if players_pawns[p_idx][p] + roll == 32:
			return p
	# Priority 3: Capture opponent
	for p in valid_pawns:
		var target_pos = players_pawns[p_idx][p] + roll
		if target_pos < 28:
			var target_global = (target_pos + START_OFFSETS[p_idx]) % TRACK_LENGTH
			for other_p in range(4):
				if other_p != p_idx:
					for other_pawn in range(PAWNS_PER_PLAYER):
						var other_pos = players_pawns[other_p][other_pawn]
						if other_pos >= 0 and other_pos < 28:
							if (other_pos + START_OFFSETS[other_p]) % TRACK_LENGTH == target_global:
								return p
	# Priority 4: Furthest ahead
	valid_pawns.sort_custom(func(a, b): return players_pawns[p_idx][a] > players_pawns[p_idx][b])
	return valid_pawns[0]

func _end_game(msg: String):
	game_over = true
	status_label.text = msg
	btn_restart.show()
	btn_dice.disabled = true

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
