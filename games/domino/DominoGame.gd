extends BaseGame

## DominoGame: Dominó 3D com Pedras em Marfim Nobre, Rebites Dourados e Disposição na Mesa

const DominoRulesScript = preload("res://games/domino/DominoRules.gd")

var boneyard: Array[Dictionary] = []
var player_hand: Array[Dictionary] = []
var ai_hand: Array[Dictionary] = []
var board_chain: Array[Dictionary] = []

var left_end: int = -1
var right_end: int = -1

var is_player_turn: bool = true
var consecutive_passes: int = 0
var selected_tile_idx: int = -1

@onready var table_tiles_root: Node3D = $TableTilesRoot
@onready var ends_label = $UI/VBoxContainer/EndsLabel
@onready var ai_info_label = $UI/VBoxContainer/AIInfoLabel
@onready var player_hand_container = $UI/PlayerArea/HandContainer
@onready var btn_draw = $UI/Actions/BtnDraw
@onready var btn_pass = $UI/Actions/BtnPass
@onready var btn_play_left = $UI/Actions/BtnPlayLeft
@onready var btn_play_right = $UI/Actions/BtnPlayRight

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/Actions/BtnRestart
	_start_new_game()

func _start_new_game() -> void:
	game_over = false
	consecutive_passes = 0
	selected_tile_idx = -1
	btn_restart.hide()
	btn_play_left.hide()
	btn_play_right.hide()
	
	boneyard = DominoRules.generate_boneyard_28()
	boneyard.shuffle()
	
	player_hand.clear()
	ai_hand.clear()
	for i in range(7):
		player_hand.append(boneyard.pop_back())
		ai_hand.append(boneyard.pop_back())
		
	board_chain.clear()
	var starting_tile = {}
	var starting_player: int = 0
	for double_val in range(6, -1, -1):
		for p_idx in range(player_hand.size()):
			var t = player_hand[p_idx]
			if t["a"] == double_val and t["b"] == double_val:
				starting_tile = player_hand.pop_at(p_idx)
				starting_player = 1
				break
		if starting_tile.size() > 0: break
		
		for ai_idx in range(ai_hand.size()):
			var t = ai_hand[ai_idx]
			if t["a"] == double_val and t["b"] == double_val:
				starting_tile = ai_hand.pop_at(ai_idx)
				starting_player = 2
				break
		if starting_tile.size() > 0: break
		
	if starting_tile.size() == 0:
		starting_tile = player_hand.pop_back()
		starting_player = 1
		
	board_chain.append(starting_tile)
	left_end = starting_tile["a"]
	right_end = starting_tile["b"]
	
	_render_table_tiles_3d()
	_update_ui()
	
	if starting_player == 1:
		set_status("Você abriu com [%d|%d]! Vez da IA..." % [starting_tile["a"], starting_tile["b"]])
		is_player_turn = false
		await get_tree().create_timer(0.8).timeout
		_play_ai_turn()
	else:
		set_status("IA abriu com [%d|%d]! Sua vez." % [starting_tile["a"], starting_tile["b"]])
		is_player_turn = true
		_update_action_buttons()

func _render_table_tiles_3d() -> void:
	for c in table_tiles_root.get_children(): c.queue_free()
	
	var total_tiles = board_chain.size()
	var spacing_x = 0.95
	var start_x = -(total_tiles * spacing_x * 0.5) + (spacing_x * 0.5)
	
	for i in range(total_tiles):
		var tile_data = board_chain[i]
		var tile_mesh = MeshInstance3D.new()
		tile_mesh.mesh = MeshBuilder3D.create_domino_tile(0.9, 0.45, 0.1)
		tile_mesh.material_override = MaterialFactory3D.get_ivory()
		
		var pos_x = start_x + (i * spacing_x)
		tile_mesh.position = Vector3(pos_x, 0.05, 0.0)
		
		# Se for bucha (duplo), rotaciona em 90 graus
		if tile_data["a"] == tile_data["b"]:
			tile_mesh.rotation_degrees = Vector3(0, 90, 0)
			
		# Rebite central dourado
		var rivet = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 0.12
		rivet.mesh = cyl
		rivet.material_override = MaterialFactory3D.get_gold()
		tile_mesh.add_child(rivet)
		
		table_tiles_root.add_child(tile_mesh)

func _update_ui() -> void:
	ai_info_label.text = "IA: %d pedras  |  Dorme (Monte): %d pedras" % [ai_hand.size(), boneyard.size()]
	ends_label.text = "Pontas: [ %d ] <---------> [ %d ]" % [left_end, right_end]
	
	# Mão do Jogador
	for c in player_hand_container.get_children(): c.queue_free()
	for i in range(player_hand.size()):
		var tile = player_hand[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(72, 80)
		btn.add_theme_font_size_override("font_size", 20)
		btn.text = "%d\n---\n%d" % [tile["a"], tile["b"]]
		
		if i == selected_tile_idx:
			btn.self_modulate = Color(0.95, 0.8, 0.2)
		else:
			var can_play = DominoRules.can_play_tile(tile, left_end, right_end)
			btn.self_modulate = Color(0.3, 0.75, 0.4) if (is_player_turn and can_play) else Color(0.85, 0.85, 0.85)
			
		btn.pressed.connect(_on_player_tile_selected.bind(i))
		player_hand_container.add_child(btn)
		
	_update_action_buttons()

func _update_action_buttons():
	if game_over or not is_player_turn:
		btn_draw.hide()
		btn_pass.hide()
		btn_play_left.hide()
		btn_play_right.hide()
		return
		
	if selected_tile_idx >= 0 and selected_tile_idx < player_hand.size():
		var tile = player_hand[selected_tile_idx]
		var can_left = (tile["a"] == left_end or tile["b"] == left_end)
		var can_right = (tile["a"] == right_end or tile["b"] == right_end)
		
		btn_play_left.visible = can_left
		btn_play_right.visible = can_right
		btn_draw.hide()
		btn_pass.hide()
	else:
		btn_play_left.hide()
		btn_play_right.hide()
		var has_moves = DominoRules.has_any_valid_move(player_hand, left_end, right_end)
		if has_moves:
			btn_draw.hide()
			btn_pass.hide()
		else:
			if boneyard.size() > 0:
				btn_draw.show()
				btn_pass.hide()
			else:
				btn_draw.hide()
				btn_pass.show()

func _on_player_tile_selected(idx: int) -> void:
	if not is_player_turn or game_over: return
	selected_tile_idx = idx if selected_tile_idx != idx else -1
	_update_ui()

func _on_btn_play_left_pressed() -> void:
	_play_player_tile("left")

func _on_btn_play_right_pressed() -> void:
	_play_player_tile("right")

func _play_player_tile(side: String):
	if selected_tile_idx < 0: return
	var tile = player_hand.pop_at(selected_tile_idx)
	selected_tile_idx = -1
	consecutive_passes = 0
	
	if side == "left":
		if tile["b"] == left_end:
			board_chain.push_front(tile)
			left_end = tile["a"]
		else:
			var flipped = {"a": tile["b"], "b": tile["a"]}
			board_chain.push_front(flipped)
			left_end = flipped["a"]
	else:
		if tile["a"] == right_end:
			board_chain.push_back(tile)
			right_end = tile["b"]
		else:
			var flipped = {"a": tile["b"], "b": tile["a"]}
			board_chain.push_back(flipped)
			right_end = flipped["b"]
			
	_render_table_tiles_3d()
	_update_ui()
	
	if player_hand.size() == 0:
		_end_game("🏆 Você bateu e venceu a partida!", true)
		return
		
	is_player_turn = false
	set_status("Vez da IA...")
	_update_action_buttons()
	await get_tree().create_timer(0.8).timeout
	_play_ai_turn()

func _on_btn_draw_pressed() -> void:
	if boneyard.size() > 0:
		var drawn = boneyard.pop_back()
		player_hand.append(drawn)
		set_status("Você comprou uma pedra do monte.")
		_update_ui()

func _on_btn_pass_pressed():
	consecutive_passes += 1
	set_status("Você passou a vez.")
	if consecutive_passes >= 2:
		_check_board_lock()
		return
	is_player_turn = false
	_update_action_buttons()
	await get_tree().create_timer(0.8).timeout
	_play_ai_turn()

func _play_ai_turn():
	var ai_play = DominoRules.find_ai_move(ai_hand, left_end, right_end)
	if ai_play.size() > 0:
		var t_idx = ai_play["tile_index"]
		var side = ai_play["side"]
		var tile = ai_hand.pop_at(t_idx)
		consecutive_passes = 0
		
		if side == "left":
			if tile["b"] == left_end:
				board_chain.push_front(tile)
				left_end = tile["a"]
			else:
				var flipped = {"a": tile["b"], "b": tile["a"]}
				board_chain.push_front(flipped)
				left_end = flipped["a"]
		else:
			if tile["a"] == right_end:
				board_chain.push_back(tile)
				right_end = tile["b"]
			else:
				var flipped = {"a": tile["b"], "b": tile["a"]}
				board_chain.push_back(flipped)
				right_end = flipped["b"]
				
		_render_table_tiles_3d()
		set_status("IA jogou na ponta %s. Sua vez!" % side)
		
		if ai_hand.size() == 0:
			_end_game("A IA bateu e venceu a partida!", false)
			return
	else:
		if boneyard.size() > 0:
			var drawn = boneyard.pop_back()
			ai_hand.append(drawn)
			set_status("IA comprou do monte e passou a vez. Sua vez!")
		else:
			consecutive_passes += 1
			set_status("IA passou a vez. Sua vez!")
			if consecutive_passes >= 2:
				_check_board_lock()
				return
				
	is_player_turn = true
	_update_ui()

func _check_board_lock() -> void:
	var p_pts = DominoRules.calculate_hand_points(player_hand)
	var ai_pts = DominoRules.calculate_hand_points(ai_hand)
	if p_pts < ai_pts:
		_end_game("Jogo Fechado! Você venceu por pontos (%d x %d)!" % [p_pts, ai_pts], true)
	elif ai_pts < p_pts:
		_end_game("Jogo Fechado! IA venceu por pontos (%d x %d)!" % [ai_pts, p_pts], false)
	else:
		_end_game("Jogo Fechado! Empate exato de pontos (%d)!" % p_pts, false)

func _end_game(msg: String, is_player_win: bool) -> void:
	finish_game(msg, is_player_win)
	_update_action_buttons()
