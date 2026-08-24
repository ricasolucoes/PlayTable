extends BaseGame

## LudoGame: Ludo 3D com Tabuleiro em Cruz Colorido, Peões Esculpidos e Dado 3D Físico

const PLAYER_NAMES = ["Jogador (Vermelho)", "IA (Azul)", "IA (Verde)", "IA (Amarelo)"]
const PLAYER_MAT_NAMES = ["plastic_red", "plastic_blue", "plastic_green", "plastic_yellow"]
const START_OFFSETS = [0, 7, 14, 21]
const TRACK_LENGTH = 28
const PAWNS_PER_PLAYER = 2

var players_pawns = [
	[-1, -1], # Jogador
	[-1, -1], # IA Azul
	[-1, -1], # IA Verde
	[-1, -1]  # IA Amarelo
]

var current_turn: int = 0
var last_roll: int = 0
var can_roll: bool = true
var pawns_3d = [[], [], [], []]

@onready var board_root: Node3D = $BoardRoot
@onready var pawns_root: Node3D = $PawnsRoot
@onready var dice_3d: Dice3D = $Dice3D
@onready var btn_dice = $UI/DiceArea/BtnDice
@onready var pawn_buttons_container = $UI/PawnSelectionArea/PawnButtons

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/Actions/BtnRestart
	_setup_3d_ludo_board()
	_setup_3d_pawns()
	dice_3d.roll_finished.connect(_on_dice_roll_finished)
	_start_new_game()

func _setup_3d_ludo_board() -> void:
	for c in board_root.get_children(): c.queue_free()
	
	# Base de madeira nobre
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.5, 0.15, 6.5)
	base.mesh = box
	base.position = Vector3(0, -0.075, 0)
	base.material_override = MaterialFactory3D.get_wood_mahogany()
	board_root.add_child(base)
	
	# 4 Quadrantes coloridos das bases
	var quad_offsets = [
		Vector3(-1.8, 0.01, 1.8),   # Vermelho (Canto inf-esq)
		Vector3(-1.8, 0.01, -1.8),  # Azul (Canto sup-esq)
		Vector3(1.8, 0.01, -1.8),   # Verde (Canto sup-dir)
		Vector3(1.8, 0.01, 1.8)     # Amarelo (Canto inf-dir)
	]
	for p in range(4):
		var q_mesh := MeshInstance3D.new()
		var q_box := BoxMesh.new()
		q_box.size = Vector3(2.4, 0.02, 2.4)
		q_mesh.mesh = q_box
		q_mesh.position = quad_offsets[p]
		q_mesh.material_override = MaterialFactory3D.get_plastic(Color(0.2, 0.2, 0.2), false)
		board_root.add_child(q_mesh)

func _setup_3d_pawns() -> void:
	for c in pawns_root.get_children(): c.queue_free()
	pawns_3d = [[], [], [], []]
	
	for p in range(4):
		for idx in range(PAWNS_PER_PLAYER):
			var pawn := preload("res://shared/3d/Token3D.tscn").instantiate()
			pawn.token_type = "pawn"
			pawn.material_name = PLAYER_MAT_NAMES[p]
			pawns_root.add_child(pawn)
			pawns_3d[p].append(pawn)

func _get_track_position_3d(p: int, step_val: int, pawn_idx: int) -> Vector3:
	if step_val == -1: # Na base
		var base_centers = [
			Vector3(-1.8, 0.2, 1.8),
			Vector3(-1.8, 0.2, -1.8),
			Vector3(1.8, 0.2, -1.8),
			Vector3(1.8, 0.2, 1.8)
		]
		var offset := Vector3(-0.35 if pawn_idx == 0 else 0.35, 0, 0)
		return base_centers[p] + offset
	elif step_val >= 32: # No centro (Vitória)
		var center_offsets = [
			Vector3(-0.3, 0.2, 0.3),
			Vector3(-0.3, 0.2, -0.3),
			Vector3(0.3, 0.2, -0.3),
			Vector3(0.3, 0.2, 0.3)
		]
		return center_offsets[p]
	elif step_val >= 28: # Reta final até o centro
		var dist := (32 - step_val) * 0.45
		match p:
			0: return Vector3(0, 0.2, dist)
			1: return Vector3(-dist, 0.2, 0)
			2: return Vector3(0, 0.2, -dist)
			3: return Vector3(dist, 0.2, 0)
	else:
		# Pista externa (28 casas circulares)
		var abs_idx = (step_val + START_OFFSETS[p]) % TRACK_LENGTH
		var angle := (float(abs_idx) / float(TRACK_LENGTH)) * TAU
		var radius := 2.4
		return Vector3(cos(angle) * radius, 0.2, sin(angle) * radius)
	return Vector3.ZERO

func _start_new_game() -> void:
	game_over = false
	current_turn = 0
	last_roll = 0
	can_roll = true
	btn_restart.hide()
	
	players_pawns = [
		[-1, -1],
		[-1, -1],
		[-1, -1],
		[-1, -1]
	]
	
	dice_3d.position = Vector3(0, 0.35, 0)
	dice_3d.set_value_immediate(6)
	btn_dice.text = "🎲 Rolar Dado"
	btn_dice.disabled = false
	set_status("Sua Vez! Toque no dado para rolar.")
	_sync_pawns_positions(true)

func _sync_pawns_positions(immediate: bool = false) -> void:
	for p in range(4):
		for idx in range(PAWNS_PER_PLAYER):
			var step_val = players_pawns[p][idx]
			var target_pos := _get_track_position_3d(p, step_val, idx)
			var pawn = pawns_3d[p][idx]
			if immediate:
				pawn.position = target_pos
			else:
				pawn.jump_to(target_pos, 0.4, 0.3)

func _on_btn_dice_pressed() -> void:
	if not can_roll or game_over or current_turn != 0: return
	can_roll = false
	btn_dice.disabled = true
	
	var rolled := randi_range(1, 6)
	set_status("Rolando dado...")
	dice_3d.roll(rolled, 0.75)

func _on_dice_roll_finished(val: int) -> void:
	last_roll = val
	btn_dice.text = "🎲 Dado: %d" % last_roll
	
	if current_turn == 0:
		_handle_player_roll(last_roll)
	else:
		_handle_ai_roll(last_roll)

func _handle_player_roll(roll: int) -> void:
	var movable: Array = []
	for idx in range(PAWNS_PER_PLAYER):
		var pos = players_pawns[0][idx]
		if pos == -1 and roll == 6: movable.append(idx)
		elif pos >= 0 and pos + roll <= 32: movable.append(idx)
		
	if movable.is_empty():
		set_status("Sem movimentos possíveis com %d!" % roll)
		await get_tree().create_timer(0.8).timeout
		_next_turn()
	elif movable.size() == 1:
		_move_player_pawn(movable[0], roll)
	else:
		set_status("Escolha qual peão deseja mover:")
		for c in pawn_buttons_container.get_children(): c.queue_free()
		for idx in movable:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(140, 50)
			btn.text = "Mover Peão %d" % (idx + 1)
			btn.pressed.connect(_on_pawn_choice_selected.bind(idx, roll))
			pawn_buttons_container.add_child(btn)

func _on_pawn_choice_selected(pawn_idx: int, roll: int) -> void:
	for c in pawn_buttons_container.get_children(): c.queue_free()
	_move_player_pawn(pawn_idx, roll)

func _move_player_pawn(idx: int, roll: int) -> void:
	var pos = players_pawns[0][idx]
	if pos == -1: players_pawns[0][idx] = 0
	else: players_pawns[0][idx] += roll
	
	_sync_pawns_positions()
	_check_captures(0, idx)
	
	if _check_win(0): return
	
	if roll == 6:
		set_status("Tirou 6! Você ganha mais um turno.")
		can_roll = true
		btn_dice.disabled = false
	else:
		_next_turn()

func _next_turn() -> void:
	current_turn = (current_turn + 1) % 4
	if current_turn == 0:
		set_status("Sua Vez! Toque no dado para rolar.")
		can_roll = true
		btn_dice.disabled = false
	else:
		set_status("Vez da %s..." % PLAYER_NAMES[current_turn])
		can_roll = false
		btn_dice.disabled = true
		await get_tree().create_timer(0.6).timeout
		var ai_roll := randi_range(1, 6)
		dice_3d.roll(ai_roll, 0.6)

func _handle_ai_roll(roll: int) -> void:
	var p := current_turn
	var movable: Array = []
	for idx in range(PAWNS_PER_PLAYER):
		var pos = players_pawns[p][idx]
		if pos == -1 and roll == 6: movable.append(idx)
		elif pos >= 0 and pos + roll <= 32: movable.append(idx)
		
	if not movable.is_empty():
		var chosen = movable.pick_random()
		if players_pawns[p][chosen] == -1: players_pawns[p][chosen] = 0
		else: players_pawns[p][chosen] += roll
		_sync_pawns_positions()
		_check_captures(p, chosen)
		
	if _check_win(p): return
	
	if roll == 6:
		set_status("%s tirou 6 e joga novamente!" % PLAYER_NAMES[p])
		await get_tree().create_timer(0.6).timeout
		var ai_roll := randi_range(1, 6)
		dice_3d.roll(ai_roll, 0.6)
	else:
		_next_turn()

func _check_captures(active_p: int, active_idx: int) -> void:
	var active_pos = players_pawns[active_p][active_idx]
	if active_pos < 0 or active_pos >= 28: return
	
	var active_abs = (active_pos + START_OFFSETS[active_p]) % TRACK_LENGTH
	
	for other_p in range(4):
		if other_p == active_p: continue
		for other_idx in range(PAWNS_PER_PLAYER):
			var other_pos = players_pawns[other_p][other_idx]
			if other_pos >= 0 and other_pos < 28:
				var other_abs = (other_pos + START_OFFSETS[other_p]) % TRACK_LENGTH
				if active_abs == other_abs:
					# Captura! Peão adversário volta para a base
					players_pawns[other_p][other_idx] = -1
					set_status("💥 Peão capturado e mandado de volta à base!")
					_sync_pawns_positions()

func _check_win(p: int) -> bool:
	var all_finished: bool = true
	for idx in range(PAWNS_PER_PLAYER):
		if players_pawns[p][idx] < 32:
			all_finished = false
			break
	if all_finished:
		if p == 0:
			finish_game("🏆 Parabéns! Você venceu o Ludo 3D!", true)
		else:
			finish_game("%s venceu a partida!" % PLAYER_NAMES[p])
		return true
	return false
