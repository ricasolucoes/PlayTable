extends Control

# Card format: {"color": "red"/"blue"/"green"/"yellow"/"wild", "val": String, "type": "number"/"skip"/"reverse"/"draw2"/"wild"/"wild4"}

const COLORS = ["red", "blue", "green", "yellow"]
const COLOR_NAMES = {"red": "Vermelho", "blue": "Azul", "green": "Verde", "yellow": "Amarelo", "wild": "Curinga"}
const COLOR_VALUES = {
	"red": Color(0.9, 0.25, 0.25),
	"blue": Color(0.2, 0.55, 0.9),
	"green": Color(0.2, 0.75, 0.35),
	"yellow": Color(0.95, 0.8, 0.1),
	"wild": Color(0.3, 0.3, 0.35)
}

var draw_pile = []
var discard_pile = []
var player_hand = []
var ai_hand = []

var active_color: String = "red"
var is_player_turn: bool = true
var game_over: bool = false
var waiting_color_pick: bool = false
var pending_wild4: bool = false

@onready var btn_top_card = $VBoxContainer/TableArea/CenterContainer/HBoxContainer/BtnTopCard
@onready var btn_draw_pile = $VBoxContainer/TableArea/CenterContainer/HBoxContainer/BtnDrawPile
@onready var active_color_banner = $VBoxContainer/TableArea/ActiveColorBanner
@onready var ai_info_label = $VBoxContainer/AIArea/AIInfoLabel
@onready var status_label = $VBoxContainer/StatusLabel
@onready var player_cards_container = $VBoxContainer/PlayerArea/ScrollContainer/CardsContainer
@onready var color_picker_modal = $VBoxContainer/ColorPickerModal
@onready var btn_restart = $VBoxContainer/Actions/BtnRestart

func _ready():
	_start_new_game()

func _start_new_game():
	game_over = false
	waiting_color_pick = false
	pending_wild4 = false
	btn_restart.hide()
	color_picker_modal.hide()
	
	_build_deck()
	
	player_hand.clear()
	ai_hand.clear()
	for i in range(7):
		player_hand.append(draw_pile.pop_back())
		ai_hand.append(draw_pile.pop_back())
		
	# Flip initial top card (non-wild)
	discard_pile.clear()
	var first_card = draw_pile.pop_back()
	while first_card["color"] == "wild":
		draw_pile.push_front(first_card)
		draw_pile.shuffle()
		first_card = draw_pile.pop_back()
		
	discard_pile.append(first_card)
	active_color = first_card["color"]
	is_player_turn = true
	
	status_label.text = "Sua Vez! Jogue uma carta que combine com a mesa."
	_update_ui()

func _build_deck():
	draw_pile.clear()
	for c in COLORS:
		# 0 once
		draw_pile.append({"color": c, "val": "0", "type": "number"})
		# 1-9 twice
		for n in range(1, 10):
			draw_pile.append({"color": c, "val": str(n), "type": "number"})
			draw_pile.append({"color": c, "val": str(n), "type": "number"})
		# Action cards (2 each)
		for i in range(2):
			draw_pile.append({"color": c, "val": "🚫", "type": "skip"})
			draw_pile.append({"color": c, "val": "🔁", "type": "reverse"})
			draw_pile.append({"color": c, "val": "+2", "type": "draw2"})
			
	# Wild cards (4 each)
	for i in range(4):
		draw_pile.append({"color": "wild", "val": "🌈", "type": "wild"})
		draw_pile.append({"color": "wild", "val": "🌈+4", "type": "wild4"})
		
	draw_pile.shuffle()

func _draw_from_deck() -> Dictionary:
	if draw_pile.size() == 0:
		if discard_pile.size() > 1:
			var top = discard_pile.pop_back()
			draw_pile = discard_pile.duplicate()
			draw_pile.shuffle()
			discard_pile = [top]
		else:
			_build_deck()
	return draw_pile.pop_back()

func _update_ui():
	# AI info
	ai_info_label.text = "IA: %d cartas %s" % [ai_hand.size(), (" (⚠️ UNO!)" if ai_hand.size() == 1 else "")]
	
	# Top card
	var top_c = discard_pile.back()
	btn_top_card.text = top_c["val"]
	btn_top_card.self_modulate = COLOR_VALUES[top_c["color"]]
	
	# Draw pile button
	btn_draw_pile.text = "🎴\n(%d)" % draw_pile.size()
	
	# Active color banner
	active_color_banner.text = "Cor Atual da Mesa: " + COLOR_NAMES[active_color].to_upper()
	active_color_banner.add_theme_color_override("font_color", COLOR_VALUES[active_color])
	
	# Player hand
	for c in player_cards_container.get_children(): c.queue_free()
	for i in range(player_hand.size()):
		var card = player_hand[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(85, 120)
		btn.add_theme_font_size_override("font_size", 26)
		btn.text = card["val"]
		btn.self_modulate = COLOR_VALUES[card["color"]]
		
		var can_play = _is_valid_card_play(card)
		if can_play and is_player_turn and not waiting_color_pick and not game_over:
			btn.disabled = false
		else:
			btn.disabled = false # Keep clickable but show feedback or allow play
			
		btn.pressed.connect(_on_player_card_clicked.bind(i))
		player_cards_container.add_child(btn)

func _is_valid_card_play(card: Dictionary) -> bool:
	var top_c = discard_pile.back()
	if card["color"] == "wild":
		return true
	if card["color"] == active_color:
		return true
	if card["val"] == top_c["val"]:
		return true
	return false

func _on_player_card_clicked(idx: int):
	if game_over or not is_player_turn or waiting_color_pick: return
	
	var card = player_hand[idx]
	if not _is_valid_card_play(card):
		status_label.text = "Carta inválida! Deve ter a cor %s ou o mesmo valor." % COLOR_NAMES[active_color]
		return
		
	player_hand.remove_at(idx)
	discard_pile.append(card)
	
	if card["color"] != "wild":
		active_color = card["color"]
		
	_update_ui()
	
	if player_hand.size() == 0:
		_end_game("🏆 UNO! Você descartou todas as cartas e Venceu!")
		return
	elif player_hand.size() == 1:
		status_label.text = "⚠️ UNO! Você tem apenas 1 carta!"
		
	# Handle card effects
	if card["type"] == "wild" or card["type"] == "wild4":
		waiting_color_pick = true
		pending_wild4 = (card["type"] == "wild4")
		color_picker_modal.show()
		status_label.text = "Escolha a nova cor da mesa!"
		return
	elif card["type"] == "draw2":
		status_label.text = "Você jogou +2! IA comprou 2 cartas e perdeu a vez."
		ai_hand.append(_draw_from_deck())
		ai_hand.append(_draw_from_deck())
		_update_ui()
		# Player gets another turn
		return
	elif card["type"] == "skip" or card["type"] == "reverse":
		status_label.text = "Você bloqueou a IA! Jogue novamente."
		_update_ui()
		# Player gets another turn
		return
		
	# Switch to AI
	is_player_turn = false
	status_label.text = "Vez da IA..."
	await get_tree().create_timer(0.9).timeout
	_play_ai_turn()

func _on_color_chosen(col: String):
	active_color = col
	waiting_color_pick = false
	color_picker_modal.hide()
	
	if pending_wild4:
		pending_wild4 = false
		status_label.text = "Cor mudou para %s! IA compra 4 cartas e perde a vez." % COLOR_NAMES[active_color]
		for i in range(4):
			ai_hand.append(_draw_from_deck())
		_update_ui()
		return
		
	status_label.text = "Cor mudou para %s. Vez da IA..." % COLOR_NAMES[active_color]
	_update_ui()
	
	is_player_turn = false
	await get_tree().create_timer(0.9).timeout
	_play_ai_turn()

func _on_btn_draw_pile_pressed():
	if game_over or not is_player_turn or waiting_color_pick: return
	
	var drawn = _draw_from_deck()
	player_hand.append(drawn)
	status_label.text = "Você comprou uma carta."
	_update_ui()
	
	# If drawn card is playable, allow player to play or switch
	if not _is_valid_card_play(drawn):
		is_player_turn = false
		await get_tree().create_timer(0.8).timeout
		_play_ai_turn()

func _play_ai_turn():
	if game_over: return
	
	var playable_indices = []
	for i in range(ai_hand.size()):
		if _is_valid_card_play(ai_hand[i]):
			playable_indices.append(i)
			
	if playable_indices.size() == 0:
		# Draw from deck
		var drawn = _draw_from_deck()
		ai_hand.append(drawn)
		if _is_valid_card_play(drawn):
			playable_indices.append(ai_hand.size() - 1)
		else:
			status_label.text = "IA comprou uma carta e passou. Sua vez!"
			is_player_turn = true
			_update_ui()
			return
			
	# Pick best card (prioritize action cards/+2, then colored, then wild)
	playable_indices.sort_custom(func(a, b):
		var card_a = ai_hand[a]
		var card_b = ai_hand[b]
		var score_a = 3 if card_a["type"] in ["draw2", "wild4"] else (2 if card_a["type"] in ["skip", "reverse"] else (1 if card_a["color"] != "wild" else 0))
		var score_b = 3 if card_b["type"] in ["draw2", "wild4"] else (2 if card_b["type"] in ["skip", "reverse"] else (1 if card_b["color"] != "wild" else 0))
		return score_a > score_b
	)
	
	var chosen_idx = playable_indices[0]
	var card = ai_hand.pop_at(chosen_idx)
	discard_pile.append(card)
	
	if card["color"] != "wild":
		active_color = card["color"]
	else:
		# Pick AI's most frequent color in hand
		var col_counts = {"red": 0, "blue": 0, "green": 0, "yellow": 0}
		for c in ai_hand:
			if c["color"] in col_counts: col_counts[c["color"]] += 1
		var best_col = "red"
		var max_c = -1
		for col in col_counts:
			if col_counts[col] > max_c:
				max_c = col_counts[col]
				best_col = col
		active_color = best_col
		
	_update_ui()
	
	if ai_hand.size() == 0:
		_end_game("💀 IA descartou todas as cartas e Venceu!")
		return
	elif ai_hand.size() == 1:
		status_label.text = "⚠️ IA gritou UNO! (Resta 1 carta)"
		
	if card["type"] == "wild4":
		status_label.text = "IA jogou Curinga +4! Nova cor: %s. Você compra 4 e perde a vez." % COLOR_NAMES[active_color]
		for i in range(4):
			player_hand.append(_draw_from_deck())
		_update_ui()
		await get_tree().create_timer(1.2).timeout
		_play_ai_turn()
		return
	elif card["type"] == "draw2":
		status_label.text = "IA jogou +2! Você comprou 2 cartas e perdeu a vez."
		player_hand.append(_draw_from_deck())
		player_hand.append(_draw_from_deck())
		_update_ui()
		await get_tree().create_timer(1.2).timeout
		_play_ai_turn()
		return
	elif card["type"] == "skip" or card["type"] == "reverse":
		status_label.text = "IA bloqueou sua vez com %s!" % card["val"]
		_update_ui()
		await get_tree().create_timer(1.2).timeout
		_play_ai_turn()
		return
	elif card["type"] == "wild":
		status_label.text = "IA jogou Curinga! Nova cor: %s. Sua vez!" % COLOR_NAMES[active_color]
	else:
		status_label.text = "IA jogou %s (%s). Sua vez!" % [card["val"], COLOR_NAMES[card["color"]]]
		
	is_player_turn = true
	_update_ui()

func _end_game(msg: String):
	game_over = true
	status_label.text = msg
	btn_restart.show()

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
