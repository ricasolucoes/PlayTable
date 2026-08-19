extends Control

const CardScript = preload("res://shared/core_engine/cards/Card.gd")
const DeckScript = preload("res://shared/core_engine/cards/Deck.gd")
const CardHandScript = preload("res://shared/core_engine/cards/CardHand.gd")
const BlackjackRulesScript = preload("res://games/blackjack/BlackjackRules.gd")

var deck: Deck
var player_hand: CardHand
var dealer_hand: CardHand
var game_over: bool = false

@onready var status = $VBoxContainer/Status
@onready var player_cards_container = $VBoxContainer/PlayerArea/PlayerCards
@onready var dealer_cards_container = $VBoxContainer/DealerArea/DealerCards
@onready var btn_hit = $VBoxContainer/Buttons/BtnHit
@onready var btn_stand = $VBoxContainer/Buttons/BtnStand
@onready var btn_restart = $VBoxContainer/Buttons/BtnRestart

func _ready():
	player_hand = CardHand.new()
	dealer_hand = CardHand.new()
	_start_game()

func _start_game():
	game_over = false
	player_hand.clear()
	dealer_hand.clear()
	
	btn_hit.disabled = false
	btn_stand.disabled = false
	btn_restart.hide()
	
	deck = Deck.create_standard_52()
	deck.shuffle()
	
	player_hand.add(deck.draw())
	dealer_hand.add(deck.draw())
	player_hand.add(deck.draw())
	dealer_hand.add(deck.draw())
	
	_update_ui(false)
	status.text = "Sua vez!"
	
	if BlackjackRules.is_blackjack(player_hand.get_all()):
		_end_game("Blackjack! Você Venceu!")

func _update_ui(show_dealer: bool):
	for c in player_cards_container.get_children(): c.queue_free()
	for c in dealer_cards_container.get_children(): c.queue_free()
	
	for card in player_hand.get_all():
		var btn = _create_card_visual(card.get_display_value(), card.get_suit_symbol(), card.is_red())
		player_cards_container.add_child(btn)
		
	var d_cards = dealer_hand.get_all()
	for i in range(d_cards.size()):
		var card = d_cards[i]
		var btn: Button
		if i == 0 and not show_dealer and not game_over:
			btn = _create_card_visual("?", "?", false)
		else:
			btn = _create_card_visual(card.get_display_value(), card.get_suit_symbol(), card.is_red())
		dealer_cards_container.add_child(btn)

func _create_card_visual(val: String, suit: String, is_red: bool) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 120)
	btn.add_theme_font_size_override("font_size", 32)
	btn.disabled = true # Apenas decorativo
	if is_red:
		btn.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
	else:
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		
	if val == "?":
		btn.text = "?"
	else:
		btn.text = val + "\n" + suit
	return btn

func _on_btn_hit_pressed():
	if game_over: return
	player_hand.add(deck.draw())
	_update_ui(false)
	
	if BlackjackRules.is_bust(player_hand.get_all()):
		_end_game("Estourou! Você Perdeu.")

func _on_btn_stand_pressed():
	if game_over: return
	btn_hit.disabled = true
	btn_stand.disabled = true
	_update_ui(true)
	
	status.text = "Vez do Dealer..."
	_play_dealer()

func _play_dealer():
	while BlackjackRules.dealer_should_hit(dealer_hand.get_all()):
		await get_tree().create_timer(0.8).timeout
		dealer_hand.add(deck.draw())
		_update_ui(true)
		
		if BlackjackRules.is_bust(dealer_hand.get_all()):
			_end_game("Dealer Estourou! Você Venceu.")
			return
			
	var match_result = BlackjackRules.evaluate_match(player_hand.get_all(), dealer_hand.get_all())
	_end_game(match_result["message"])

func _end_game(msg: String):
	game_over = true
	btn_hit.disabled = true
	btn_stand.disabled = true
	btn_restart.show()
	status.text = msg
	_update_ui(true)

func _on_btn_restart_pressed():
	_start_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
