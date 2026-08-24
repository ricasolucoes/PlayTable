extends BaseGame

## UNO-like card game with 3D card animations and AI opponent.

## UnoLikeGame: Cartas Coloridas 3D com Cartas Físicas, Arremesso no Descarte e Partículas

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

const COLOR_NAMES = {
	Card.ColorType.RED: "Vermelho",
	Card.ColorType.BLUE: "Azul",
	Card.ColorType.GREEN: "Verde",
	Card.ColorType.YELLOW: "Amarelo",
	Card.ColorType.WILD: "Curinga"
}

var draw_pile: Deck
var discard_pile: CardPile
var player_hand: CardHand
var ai_hand: CardHand

var active_color: Card.ColorType = Card.ColorType.RED
var is_player_turn: bool = true
var waiting_color_pick: bool = false
var pending_wild4: bool = false

var discard_cards_3d: Array[Card3D] = []

@onready var cards_root: Node3D = $CardsRoot
@onready var active_color_banner = $UI/VBoxContainer/ActiveColorBanner
@onready var ai_info_label = $UI/VBoxContainer/AIInfoLabel
@onready var player_cards_container = $UI/PlayerArea/ScrollContainer/CardsContainer
@onready var color_picker_modal = $UI/ColorPickerModal
@onready var btn_draw = $UI/Actions/BtnDraw

func _ready() -> void:
	menu_scene_path = MENU_CARTAS
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/Actions/BtnRestart
	env_3d.set_felt_color(Color(0.12, 0.14, 0.22)) # Feltro Grafite Escuro
	player_hand = CardHand.new()
	ai_hand = CardHand.new()
	discard_pile = CardPile.new()
	_start_new_game()

func _start_new_game() -> void:
	game_over = false
	waiting_color_pick = false
	pending_wild4 = false
	btn_restart.hide()
	color_picker_modal.hide()
	
	for c in cards_root.get_children(): c.queue_free()
	discard_cards_3d.clear()
	
	draw_pile = Deck.create_uno_deck()
	draw_pile.shuffle()
	
	player_hand.clear()
	ai_hand.clear()
	discard_pile.clear()
	
	for i in range(7):
		player_hand.add(draw_pile.draw())
		ai_hand.add(draw_pile.draw())
		
	var first_card = draw_pile.draw()
	while first_card != null and first_card.color_type == Card.ColorType.WILD:
		draw_pile.push_front(first_card)
		draw_pile.shuffle()
		first_card = draw_pile.draw()
		
	discard_pile.push(first_card)
	active_color = first_card.color_type
	is_player_turn = true
	
	_spawn_top_discard_3d(first_card)
	status_label.text = "Sua Vez! Jogue uma carta que combine com a cor ou valor."
	_update_ui()

func _spawn_top_discard_3d(card: Card) -> void:
	var c_3d = preload("res://shared/3d/Card3D.tscn").instantiate()
	c_3d.setup(card.get_display_value(), UnoRules.get_color_symbol(card.color_type), true)
	
	var rot_y = randf_range(-15.0, 15.0)
	var target_pos = Vector3(0.0, 0.05 + (discard_cards_3d.size() * 0.004), -0.3)
	c_3d.position = target_pos + Vector3(0, 1.8, 0)
	cards_root.add_child(c_3d)
	discard_cards_3d.append(c_3d)
	
	c_3d.deal_to(target_pos, rot_y, 0.35)

func _draw_from_deck() -> Card:
	if draw_pile.is_empty():
		if discard_pile.size() > 1:
			var top = discard_pile.pop()
			draw_pile.recycle_from(discard_pile.get_all())
			discard_pile.clear()
			discard_pile.push(top)
			draw_pile.shuffle()
			status_label.text = "Descarte reciclado no monte!"
		else:
			return null
	return draw_pile.draw()

func _update_ui() -> void:
	ai_info_label.text = "IA: %d cartas" % ai_hand.size()
	
	var col = COLOR_MAP.get(active_color, Color.WHITE)
	var col_name = COLOR_NAMES.get(active_color, "Indefinida")
	active_color_banner.text = "Cor Ativa: %s" % col_name
	active_color_banner.add_theme_color_override("font_color", col)
	
	# Mão do jogador
	for c in player_cards_container.get_children(): c.queue_free()
	var top_card = discard_pile.peek()
	
	for i in range(player_hand.size()):
		var card = player_hand.get_card(i)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(72, 95)
		btn.add_theme_font_size_override("font_size", 18)
		
		var card_col = COLOR_MAP.get(card.color_type, Color.WHITE)
		btn.self_modulate = card_col
		btn.text = card.get_display_value()
		
		var can_play = UnoRules.can_play_card(card, top_card, active_color)
		btn.disabled = not is_player_turn or not can_play or game_over or waiting_color_pick
		
		btn.pressed.connect(_on_player_card_clicked.bind(i))
		player_cards_container.add_child(btn)

func _on_player_card_clicked(idx: int) -> void:
	if not is_player_turn or game_over or waiting_color_pick: return
	
	var card = player_hand.get_card(idx)
	var top_card = discard_pile.peek()
	
	if not UnoRules.can_play_card(card, top_card, active_color): return
	
	player_hand.remove_at(idx)
	discard_pile.push(card)
	_spawn_top_discard_3d(card)
	
	if card.color_type == Card.ColorType.WILD:
		waiting_color_pick = true
		pending_wild4 = (card.special_type == Card.SpecialType.WILD_DRAW_FOUR)
		color_picker_modal.show()
		status_label.text = "Escolha a nova cor da mesa!"
		_update_ui()
		return
		
	active_color = card.color_type
	_handle_card_effects_and_advance(card, true)

func _on_color_chosen(col_type: Card.ColorType) -> void:
	waiting_color_pick = false
	color_picker_modal.hide()
	active_color = col_type
	
	var played_card = discard_pile.peek()
	_handle_card_effects_and_advance(played_card, true)

func _handle_card_effects_and_advance(card: Card, was_player: bool) -> void:
	_update_ui()
	
	if was_player and player_hand.size() == 0:
		_end_game("🏆 UNO! Você descartou todas as cartas e venceu!", true)
		return
	elif not was_player and ai_hand.size() == 0:
		_end_game("A IA descartou tudo e venceu!", false)
		return
		
	if was_player and player_hand.size() == 1:
		status_label.text = "⚠️ UNO! Você tem apenas 1 carta!"
	elif not was_player and ai_hand.size() == 1:
		status_label.text = "⚠️ Atenção: IA gritou UNO (1 carta restante)!"
		
	var skip_next: bool = false
	match card.special_type:
		Card.SpecialType.DRAW_TWO:
			if was_player:
				for i in range(2):
					var d: Card = _draw_from_deck()
					if d != null:
						ai_hand.add(d)
				status_label.text = "IA comprou +2 cartas e perdeu a vez!"
				skip_next = true
			else:
				for i in range(2):
					var d: Card = _draw_from_deck()
					if d != null:
						player_hand.add(d)
				status_label.text = "Você comprou +2 cartas e perdeu a vez!"
				skip_next = true
				
		Card.SpecialType.WILD_DRAW_FOUR:
			if was_player:
				for i in range(4):
					var d: Card = _draw_from_deck()
					if d != null:
						ai_hand.add(d)
				status_label.text = "IA comprou +4 cartas e perdeu a vez!"
				skip_next = true
			else:
				for i in range(4):
					var d: Card = _draw_from_deck()
					if d != null:
						player_hand.add(d)
				status_label.text = "Você comprou +4 cartas e perdeu a vez!"
				skip_next = true
				
		Card.SpecialType.SKIP, Card.SpecialType.REVERSE:
			skip_next = true
			status_label.text = "Vez bloqueada!"
			
	_update_ui()
	
	if was_player:
		if skip_next:
			is_player_turn = true
			status_label.text = "Sua vez novamente!"
			_update_ui()
		else:
			is_player_turn = false
			status_label.text = "Vez da IA..."
			_update_ui()
			await get_tree().create_timer(0.9).timeout
			_play_ai_turn()
	else:
		if skip_next:
			is_player_turn = false
			status_label.text = "IA joga novamente!"
			_update_ui()
			await get_tree().create_timer(0.9).timeout
			_play_ai_turn()
		else:
			is_player_turn = true
			status_label.text = "Sua Vez! Escolha uma carta."
			_update_ui()

func _play_ai_turn() -> void:
	var top_card = discard_pile.peek()
	var playable_indices: Array = []
	for i in range(ai_hand.size()):
		var c = ai_hand.get_card(i)
		if UnoRules.can_play_card(c, top_card, active_color):
			playable_indices.append(i)
			
	if playable_indices.is_empty():
		var drawn: Card = _draw_from_deck()
		if drawn != null:
			ai_hand.add(drawn)
			status_label.text = "IA não tinha jogadas e comprou uma carta."
			if UnoRules.can_play_card(drawn, top_card, active_color):
				ai_hand.cards.erase(drawn)
				discard_pile.push(drawn)
				_spawn_top_discard_3d(drawn)
				if drawn.color_type == Card.ColorType.WILD:
					active_color = UnoRules.pick_best_color_for_hand(ai_hand.cards)
				else:
					active_color = drawn.color_type
				_handle_card_effects_and_advance(drawn, false)
				return
		is_player_turn = true
		status_label.text = "Sua Vez! Escolha uma carta."
		_update_ui()
	else:
		var chosen_idx = playable_indices.pick_random()
		var card = ai_hand.remove_at(chosen_idx)
		discard_pile.push(card)
		_spawn_top_discard_3d(card)
		
		if card.color_type == Card.ColorType.WILD:
			active_color = UnoRules.pick_best_color_for_hand(ai_hand.cards)
		else:
			active_color = card.color_type
			
		_handle_card_effects_and_advance(card, false)

func _on_btn_draw_pressed() -> void:
	if not is_player_turn or game_over or waiting_color_pick: return
	var drawn: Card = _draw_from_deck()
	if drawn != null:
		player_hand.add(drawn)
		status_label.text = "Você comprou uma carta."
		_update_ui()
		
		# Passa a vez
		is_player_turn = false
		status_label.text = "Vez da IA..."
		_update_ui()
		await get_tree().create_timer(0.8).timeout
		_play_ai_turn()

func _end_game(msg: String, is_player_win: bool) -> void:
	finish_game(msg, is_player_win)
