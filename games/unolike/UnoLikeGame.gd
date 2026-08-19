extends Control

const CardScript = preload("res://shared/core_engine/cards/Card.gd")
const DeckScript = preload("res://shared/core_engine/cards/Deck.gd")
const CardHandScript = preload("res://shared/core_engine/cards/CardHand.gd")
const CardPileScript = preload("res://shared/core_engine/cards/CardPile.gd")
const UnoRulesScript = preload("res://games/unolike/UnoRules.gd")

const COLOR_MAP = {
	Card.ColorType.RED: Color(0.9, 0.25, 0.25),
	Card.ColorType.BLUE: Color(0.2, 0.55, 0.9),
	Card.ColorType.GREEN: Color(0.2, 0.75, 0.35),
	Card.ColorType.YELLOW: Color(0.95, 0.8, 0.1),
	Card.ColorType.WILD: Color(0.3, 0.3, 0.35),
	Card.ColorType.NONE: Color(0.3, 0.3, 0.35)
}

var draw_pile: Deck
var discard_pile: CardPile
var player_hand: CardHand
var ai_hand: CardHand

var active_color: Card.ColorType = Card.ColorType.RED
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
	player_hand = CardHand.new()
	ai_hand = CardHand.new()
	discard_pile = CardPile.new()
	_start_new_game()

func _start_new_game():
	game_over = false
	waiting_color_pick = false
	pending_wild4 = false
	btn_restart.hide()
	color_picker_modal.hide()
	
	draw_pile = Deck.create_uno_deck()
	draw_pile.shuffle()
	
	player_hand.clear()
	ai_hand.clear()
	discard_pile.clear()
	
	for i in range(7):
		player_hand.add(draw_pile.draw())
		ai_hand.add(draw_pile.draw())
		
	# Carta inicial da mesa não pode ser Curinga
	var first_card = draw_pile.draw()
	while first_card != null and first_card.color_type == Card.ColorType.WILD:
		draw_pile.push_front(first_card)
		draw_pile.shuffle()
		first_card = draw_pile.draw()
		
	discard_pile.push(first_card)
	active_color = first_card.color_type
	is_player_turn = true
	
	status_label.text = "Sua Vez! Jogue uma carta que combine com a mesa."
	_update_ui()

func _draw_from_deck() -> Card:
	if draw_pile.is_empty():
		if discard_pile.size() > 1:
			var top = discard_pile.pop()
			draw_pile.recycle_from(discard_pile.get_all())
			discard_pile.clear()
			discard_pile.push(top)
		else:
			draw_pile = Deck.create_uno_deck()
			draw_pile.shuffle()
	return draw_pile.draw()

func _update_ui():
	ai_info_label.text = "IA: %d cartas %s" % [ai_hand.size(), (" (⚠️ UNO!)" if ai_hand.size() == 1 else "")]
	
	# Top card
	var top_c = discard_pile.peek()
	if top_c != null:
		btn_top_card.text = top_c.get_display_value()
		btn_top_card.self_modulate = COLOR_MAP.get(top_c.color_type, Color.WHITE)
	
	# Draw pile
	btn_draw_pile.text = "🎴\n(%d)" % draw_pile.size()
	
	# Active color banner
	var col_name = Card.COLOR_NAMES.get(active_color, "").to_upper()
	active_color_banner.text = "Cor Atual da Mesa: " + col_name
	active_color_banner.add_theme_color_override("font_color", COLOR_MAP.get(active_color, Color.WHITE))
	
	# Player cards
	for c in player_cards_container.get_children(): c.queue_free()
	var p_cards = player_hand.get_all()
	for i in range(p_cards.size()):
		var card = p_cards[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(85, 120)
		btn.add_theme_font_size_override("font_size", 26)
		btn.text = card.get_display_value()
		btn.self_modulate = COLOR_MAP.get(card.color_type, Color.WHITE)
		btn.pressed.connect(_on_player_card_clicked.bind(i))
		player_cards_container.add_child(btn)

func _on_player_card_clicked(idx: int):
	if game_over or not is_player_turn or waiting_color_pick: return
	
	var card = player_hand.get_card(idx)
	if not UnoRules.is_valid_play(card, active_color, discard_pile.peek()):
		status_label.text = "Carta inválida! Deve ter a cor %s ou o mesmo valor/efeito." % Card.COLOR_NAMES.get(active_color, "")
		return
		
	player_hand.remove_at(idx)
	discard_pile.push(card)
	
	if card.color_type != Card.ColorType.WILD:
		active_color = card.color_type
		
	_update_ui()
	
	if player_hand.size() == 0:
		_end_game("🏆 UNO! Você descartou todas as cartas e Venceu!")
		return
	elif player_hand.size() == 1:
		status_label.text = "⚠️ UNO! Você tem apenas 1 carta!"
		
	# Efeitos de carta
	if card.card_type == "wild" or card.card_type == "wild4":
		waiting_color_pick = true
		pending_wild4 = (card.card_type == "wild4")
		color_picker_modal.show()
		status_label.text = "Escolha a nova cor da mesa!"
		return
	elif card.card_type == "draw2":
		status_label.text = "Você jogou +2! IA comprou 2 cartas e perdeu a vez."
		ai_hand.add(_draw_from_deck())
		ai_hand.add(_draw_from_deck())
		_update_ui()
		return
	elif card.card_type == "skip" or card.card_type == "reverse":
		status_label.text = "Você bloqueou a IA! Jogue novamente."
		_update_ui()
		return
		
	# Passa vez para IA
	is_player_turn = false
	status_label.text = "Vez da IA..."
	await get_tree().create_timer(0.9).timeout
	_play_ai_turn()

func _on_color_chosen(col_str: String):
	match col_str:
		"red": active_color = Card.ColorType.RED
		"blue": active_color = Card.ColorType.BLUE
		"green": active_color = Card.ColorType.GREEN
		"yellow": active_color = Card.ColorType.YELLOW
		
	waiting_color_pick = false
	color_picker_modal.hide()
	
	if pending_wild4:
		pending_wild4 = false
		status_label.text = "Cor mudou para %s! IA compra 4 cartas e perde a vez." % Card.COLOR_NAMES.get(active_color, "")
		for i in range(4):
			ai_hand.add(_draw_from_deck())
		_update_ui()
		return
		
	status_label.text = "Cor mudou para %s. Vez da IA..." % Card.COLOR_NAMES.get(active_color, "")
	_update_ui()
	
	is_player_turn = false
	await get_tree().create_timer(0.9).timeout
	_play_ai_turn()

func _on_btn_draw_pile_pressed():
	if game_over or not is_player_turn or waiting_color_pick: return
	
	var drawn = _draw_from_deck()
	player_hand.add(drawn)
	status_label.text = "Você comprou uma carta."
	_update_ui()
	
	if not UnoRules.is_valid_play(drawn, active_color, discard_pile.peek()):
		is_player_turn = false
		await get_tree().create_timer(0.8).timeout
		_play_ai_turn()

func _play_ai_turn():
	if game_over: return
	
	var playable = UnoRules.get_playable_cards(ai_hand.get_all(), active_color, discard_pile.peek())
	
	if playable.is_empty():
		var drawn = _draw_from_deck()
		ai_hand.add(drawn)
		if UnoRules.is_valid_play(drawn, active_color, discard_pile.peek()):
			playable.append(ai_hand.size() - 1)
		else:
			status_label.text = "IA comprou uma carta e passou. Sua vez!"
			is_player_turn = true
			_update_ui()
			return
			
	# Priorização de IA: cartas de ação > número > curinga
	playable.sort_custom(func(a, b):
		var card_a = ai_hand.get_card(a)
		var card_b = ai_hand.get_card(b)
		var score_a = 3 if card_a.card_type in ["draw2", "wild4"] else (2 if card_a.card_type in ["skip", "reverse"] else (1 if card_a.color_type != Card.ColorType.WILD else 0))
		var score_b = 3 if card_b.card_type in ["draw2", "wild4"] else (2 if card_b.card_type in ["skip", "reverse"] else (1 if card_b.color_type != Card.ColorType.WILD else 0))
		return score_a > score_b
	)
	
	var chosen_idx = playable[0]
	var card = ai_hand.remove_at(chosen_idx)
	discard_pile.push(card)
	
	if card.color_type != Card.ColorType.WILD:
		active_color = card.color_type
	else:
		active_color = UnoRules.pick_best_color_for_hand(ai_hand.get_all())
		
	_update_ui()
	
	if ai_hand.size() == 0:
		_end_game("💀 IA descartou todas as cartas e Venceu!")
		return
	elif ai_hand.size() == 1:
		status_label.text = "⚠️ IA gritou UNO! (Resta 1 carta)"
		
	if card.card_type == "wild4":
		status_label.text = "IA jogou Curinga +4! Nova cor: %s. Você compra 4 e perde a vez." % Card.COLOR_NAMES.get(active_color, "")
		for i in range(4):
			player_hand.add(_draw_from_deck())
		_update_ui()
		await get_tree().create_timer(1.2).timeout
		_play_ai_turn()
		return
	elif card.card_type == "draw2":
		status_label.text = "IA jogou +2! Você comprou 2 cartas e perdeu a vez."
		player_hand.add(_draw_from_deck())
		player_hand.add(_draw_from_deck())
		_update_ui()
		await get_tree().create_timer(1.2).timeout
		_play_ai_turn()
		return
	elif card.card_type == "skip" or card.card_type == "reverse":
		status_label.text = "IA bloqueou sua vez com %s!" % card.get_display_value()
		_update_ui()
		await get_tree().create_timer(1.2).timeout
		_play_ai_turn()
		return
	elif card.card_type == "wild":
		status_label.text = "IA jogou Curinga! Nova cor: %s. Sua vez!" % Card.COLOR_NAMES.get(active_color, "")
	else:
		status_label.text = "IA jogou %s (%s). Sua vez!" % [card.get_display_value(), Card.COLOR_NAMES.get(card.color_type, "")]
		
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
