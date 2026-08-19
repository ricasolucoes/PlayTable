extends Control

const DominoRulesScript = preload("res://games/domino/DominoRules.gd")

var boneyard: Array[Dictionary] = []
var player_hand: Array[Dictionary] = []
var ai_hand: Array[Dictionary] = []
var board_chain: Array[Dictionary] = []

var left_end: int = -1
var right_end: int = -1

var is_player_turn: bool = true
var game_over: bool = false
var consecutive_passes: int = 0
var selected_tile_idx: int = -1

@onready var chain_container = $VBoxContainer/TableArea/ScrollContainer/ChainContainer
@onready var player_hand_container = $VBoxContainer/PlayerArea/HandContainer
@onready var status_label = $VBoxContainer/StatusLabel
@onready var ends_label = $VBoxContainer/TableArea/EndsLabel
@onready var ai_info_label = $VBoxContainer/AIArea/AIInfoLabel
@onready var btn_draw = $VBoxContainer/Actions/BtnDraw
@onready var btn_pass = $VBoxContainer/Actions/BtnPass
@onready var btn_play_left = $VBoxContainer/Actions/BtnPlayLeft
@onready var btn_play_right = $VBoxContainer/Actions/BtnPlayRight
@onready var btn_restart = $VBoxContainer/Actions/BtnRestart

func _ready():
	_start_new_game()

func _start_new_game():
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
		
	# Encontra maior bucha para abrir
	board_chain.clear()
	var starting_tile = {}
	var starting_player = 0
	
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
	
	_update_ui()
	
	if starting_player == 1:
		status_label.text = "Você abriu com [%d|%d]! Vez da IA..." % [starting_tile["a"], starting_tile["b"]]
		is_player_turn = false
		await get_tree().create_timer(0.8).timeout
		_play_ai_turn()
	else:
		status_label.text = "IA abriu com [%d|%d]! Sua vez." % [starting_tile["a"], starting_tile["b"]]
		is_player_turn = true
		_update_action_buttons()

func _update_ui():
	ai_info_label.text = "IA: %d pedras  |  Dorme (Monte): %d pedras" % [ai_hand.size(), boneyard.size()]
	ends_label.text = "Pontas: [ %d ] <---------> [ %d ]" % [left_end, right_end]
	
	# Mesa
	for c in chain_container.get_children(): c.queue_free()
	for tile in board_chain:
		var lbl = Button.new()
		lbl.custom_minimum_size = Vector2(70, 70)
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.text = "[%d|%d]" % [tile["a"], tile["b"]]
		lbl.disabled = true
		chain_container.add_child(lbl)
		
	# Mão do Jogador
	for c in player_hand_container.get_children(): c.queue_free()
	for i in range(player_hand.size()):
		var tile = player_hand[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(85, 75)
		btn.add_theme_font_size_override("font_size", 24)
		btn.text = "[ %d | %d ]" % [tile["a"], tile["b"]]
		
		var can_play = DominoRules.can_tile_fit(tile, left_end, right_end)
		if can_play and is_player_turn and not game_over:
			btn.self_modulate = Color(0.3, 0.7, 0.4)
		else:
			btn.self_modulate = Color(0.2, 0.25, 0.3)
			
		if i == selected_tile_idx:
			btn.self_modulate = Color(0.9, 0.75, 0.2)
			
		btn.pressed.connect(_on_player_tile_clicked.bind(i))
		player_hand_container.add_child(btn)
		
	_update_action_buttons()

func _update_action_buttons():
	if game_over or not is_player_turn:
		btn_draw.hide()
		btn_pass.hide()
		btn_play_left.hide()
		btn_play_right.hide()
		return
		
	var can_play_any = DominoRules.has_any_playable(player_hand, left_end, right_end)
	
	if can_play_any:
		btn_draw.hide()
		btn_pass.hide()
	else:
		if boneyard.size() > 0:
			btn_draw.show()
			btn_draw.text = "📥 Comprar do Dorme (%d)" % boneyard.size()
			btn_pass.hide()
		else:
			btn_draw.hide()
			btn_pass.show()
			
	if selected_tile_idx >= 0 and selected_tile_idx < player_hand.size():
		var t = player_hand[selected_tile_idx]
		var can_left = (t["a"] == left_end or t["b"] == left_end)
		var can_right = (t["a"] == right_end or t["b"] == right_end)
		
		if can_left and can_right and left_end != right_end:
			btn_play_left.show()
			btn_play_right.show()
		else:
			btn_play_left.hide()
			btn_play_right.hide()
	else:
		btn_play_left.hide()
		btn_play_right.hide()

func _on_player_tile_clicked(idx: int):
	if game_over or not is_player_turn: return
	
	var tile = player_hand[idx]
	if not DominoRules.can_tile_fit(tile, left_end, right_end):
		status_label.text = "Essa pedra não encaixa em nenhuma ponta!"
		return
		
	selected_tile_idx = idx
	var can_left = (tile["a"] == left_end or tile["b"] == left_end)
	var can_right = (tile["a"] == right_end or tile["b"] == right_end)
	
	if can_left and can_right and left_end != right_end:
		status_label.text = "Pedra encaixa em ambas as pontas. Escolha o lado!"
		_update_ui()
	elif can_left:
		_play_tile_to_side(idx, "left")
	else:
		_play_tile_to_side(idx, "right")

func _play_tile_to_side(hand_idx: int, side: String):
	var tile = player_hand.pop_at(hand_idx)
	selected_tile_idx = -1
	consecutive_passes = 0
	
	var res = DominoRules.orient_tile_for_side(tile, side, left_end, right_end)
	left_end = res["new_left_end"]
	right_end = res["new_right_end"]
	
	if side == "left":
		board_chain.push_front(res["oriented_tile"])
	else:
		board_chain.push_back(res["oriented_tile"])
		
	_update_ui()
	
	if player_hand.size() == 0:
		_end_game("🏆 Você bateu o dominó e Venceu!")
		return
		
	is_player_turn = false
	status_label.text = "Vez da IA..."
	await get_tree().create_timer(0.8).timeout
	_play_ai_turn()

func _on_btn_draw_pressed():
	if game_over or not is_player_turn or boneyard.size() == 0: return
	
	var drawn = boneyard.pop_back()
	player_hand.append(drawn)
	status_label.text = "Você comprou [%d|%d]." % [drawn["a"], drawn["b"]]
	_update_ui()

func _on_btn_pass_pressed():
	if game_over or not is_player_turn: return
	consecutive_passes += 1
	status_label.text = "Você passou a vez. Vez da IA..."
	is_player_turn = false
	_update_ui()
	
	if consecutive_passes >= 2:
		_resolve_blocked_game()
		return
		
	await get_tree().create_timer(0.8).timeout
	_play_ai_turn()

func _on_btn_play_left_pressed():
	if selected_tile_idx >= 0:
		_play_tile_to_side(selected_tile_idx, "left")

func _on_btn_play_right_pressed():
	if selected_tile_idx >= 0:
		_play_tile_to_side(selected_tile_idx, "right")

func _play_ai_turn():
	if game_over: return
	
	while not DominoRules.has_any_playable(ai_hand, left_end, right_end) and boneyard.size() > 0:
		ai_hand.append(boneyard.pop_back())
		
	if not DominoRules.has_any_playable(ai_hand, left_end, right_end):
		consecutive_passes += 1
		status_label.text = "IA não tem jogadas e passou a vez!"
		if consecutive_passes >= 2:
			_resolve_blocked_game()
			return
		is_player_turn = true
		_update_ui()
		return
		
	consecutive_passes = 0
	var playable_indices = DominoRules.get_playable_indices(ai_hand, left_end, right_end)
	playable_indices.shuffle()
	
	var chosen_idx = playable_indices[0]
	var tile = ai_hand.pop_at(chosen_idx)
	
	var can_left = (tile["a"] == left_end or tile["b"] == left_end)
	var can_right = (tile["a"] == right_end or tile["b"] == right_end)
	var side = "left" if (can_left and not can_right) else ("right" if (can_right and not can_left) else ("left" if randf() > 0.5 else "right"))
	
	var res = DominoRules.orient_tile_for_side(tile, side, left_end, right_end)
	left_end = res["new_left_end"]
	right_end = res["new_right_end"]
	
	if side == "left":
		board_chain.push_front(res["oriented_tile"])
	else:
		board_chain.push_back(res["oriented_tile"])
		
	_update_ui()
	
	if ai_hand.size() == 0:
		_end_game("IA bateu o dominó e Venceu!")
		return
		
	is_player_turn = true
	status_label.text = "IA jogou [%d|%d]. Sua vez!" % [tile["a"], tile["b"]]

func _resolve_blocked_game():
	var p_sum = DominoRules.calculate_hand_points(player_hand)
	var ai_sum = DominoRules.calculate_hand_points(ai_hand)
	
	if p_sum < ai_sum:
		_end_game("🔒 Jogo Trancado! Você Venceu por pontos (%d vs %d da IA)!" % [p_sum, ai_sum])
	elif ai_sum < p_sum:
		_end_game("🔒 Jogo Trancado! IA Venceu por pontos (%d vs %d seus)!" % [ai_sum, p_sum])
	else:
		_end_game("🔒 Jogo Trancado! Empate com %d pontos cada!" % p_sum)

func _end_game(msg: String):
	game_over = true
	status_label.text = msg
	btn_restart.show()
	btn_play_left.hide()
	btn_play_right.hide()
	btn_draw.hide()
	btn_pass.hide()

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
