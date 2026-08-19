extends Control

const CardScript = preload("res://shared/core_engine/cards/Card.gd")
const DeckScript = preload("res://shared/core_engine/cards/Deck.gd")
const CardHandScript = preload("res://shared/core_engine/cards/CardHand.gd")
const PokerEvaluatorScript = preload("res://games/poker/PokerEvaluator.gd")

var deck: Deck
var player_hand: CardHand
var held_cards = [false, false, false, false, false]

var chips: int = 100
var current_bet: int = 5
var game_phase: String = "bet" # "bet", "hold", "result"

@onready var card_buttons = [
	$VBoxContainer/CardsArea/BtnCard0,
	$VBoxContainer/CardsArea/BtnCard1,
	$VBoxContainer/CardsArea/BtnCard2,
	$VBoxContainer/CardsArea/BtnCard3,
	$VBoxContainer/CardsArea/BtnCard4
]
@onready var hold_labels = [
	$VBoxContainer/HoldsArea/Hold0,
	$VBoxContainer/HoldsArea/Hold1,
	$VBoxContainer/HoldsArea/Hold2,
	$VBoxContainer/HoldsArea/Hold3,
	$VBoxContainer/HoldsArea/Hold4
]
@onready var chips_label = $VBoxContainer/Header/ChipsLabel
@onready var bet_label = $VBoxContainer/Header/BetLabel
@onready var status_label = $VBoxContainer/StatusLabel
@onready var payout_table_label = $VBoxContainer/PayoutTableContainer/PayoutLabel
@onready var btn_action = $VBoxContainer/Controls/BtnAction
@onready var btn_bet_minus = $VBoxContainer/Controls/BtnBetMinus
@onready var btn_bet_plus = $VBoxContainer/Controls/BtnBetPlus

func _ready():
	player_hand = CardHand.new()
	for i in range(5):
		card_buttons[i].pressed.connect(_on_card_clicked.bind(i))
	_update_payout_table()
	_reset_to_bet_phase()

func _update_payout_table():
	payout_table_label.text = "Royal Flush (800x) | Straight Flush (50x) | Quadra (25x) | Full House (9x)\nFlush (6x) | Sequência (4x) | Trinca (3x) | Dois Pares (2x) | Par J+ (1x)"

func _reset_to_bet_phase():
	game_phase = "bet"
	if chips <= 0:
		chips = 50
		status_label.text = "Recarga grátis de 50 fichas!"
	else:
		status_label.text = "Ajuste sua aposta e clique em 'DAR CARTAS'!"
		
	held_cards = [false, false, false, false, false]
	for i in range(5):
		hold_labels[i].text = ""
		card_buttons[i].text = "🎴"
		card_buttons[i].self_modulate = Color(0.2, 0.25, 0.3)
		
	btn_bet_minus.disabled = false
	btn_bet_plus.disabled = false
	btn_action.text = "🃏 DAR CARTAS"
	btn_action.self_modulate = Color(0.2, 0.7, 0.4)
	_update_chips_ui()

func _update_chips_ui():
	chips_label.text = "💰 Fichas: %d" % chips
	bet_label.text = "Aposta: %d" % current_bet

func _on_btn_action_pressed():
	if game_phase == "bet":
		if chips < current_bet:
			status_label.text = "Fichas insuficientes para esta aposta!"
			return
		chips -= current_bet
		_update_chips_ui()
		
		deck = Deck.create_standard_52(true)
		deck.shuffle()
		
		player_hand.clear()
		for i in range(5):
			player_hand.add(deck.draw())
			held_cards[i] = false
			
		game_phase = "hold"
		btn_bet_minus.disabled = true
		btn_bet_plus.disabled = true
		btn_action.text = "🔄 TROCAR CARTAS"
		btn_action.self_modulate = Color(0.2, 0.5, 0.85)
		status_label.text = "Toque nas cartas que deseja MANTER (HOLD)."
		_render_cards()
		
	elif game_phase == "hold":
		# Substituir cartas não mantidas
		for i in range(5):
			if not held_cards[i]:
				player_hand.cards[i] = deck.draw()
				
		_render_cards()
		_evaluate_and_payout()
		
	elif game_phase == "result":
		_reset_to_bet_phase()

func _render_cards():
	var cards_list = player_hand.get_all()
	for i in range(5):
		if i < cards_list.size():
			var card = cards_list[i]
			var btn = card_buttons[i]
			btn.text = "%s\n%s" % [card.get_display_value(), card.get_suit_symbol()]
			btn.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25) if card.is_red() else Color(0.95, 0.95, 0.95))
			
			if held_cards[i]:
				hold_labels[i].text = "MANTER"
				btn.self_modulate = Color(0.85, 0.7, 0.2)
			else:
				hold_labels[i].text = ""
				btn.self_modulate = Color(0.22, 0.28, 0.35)

func _on_card_clicked(idx: int):
	if game_phase != "hold": return
	held_cards[idx] = not held_cards[idx]
	_render_cards()

func _evaluate_and_payout():
	game_phase = "result"
	btn_action.text = "▶️ PRÓXIMA MÃO"
	btn_action.self_modulate = Color(0.3, 0.7, 0.4)
	
	var result = PokerEvaluator.evaluate_hand(player_hand.get_all())
	var rank_name = result["name"]
	var multiplier = result["mult"]
	
	var win_amount = current_bet * multiplier
	if win_amount > 0:
		chips += win_amount
		status_label.text = "🎉 %s! Ganhou %d fichas (+%dx)!" % [rank_name, win_amount, multiplier]
	else:
		status_label.text = "%s. Tente novamente!" % rank_name
		
	_update_chips_ui()

func _on_btn_bet_minus_pressed():
	if game_phase == "bet" and current_bet > 1:
		current_bet -= 1
		_update_chips_ui()

func _on_btn_bet_plus_pressed():
	if game_phase == "bet" and current_bet < 5:
		current_bet += 1
		_update_chips_ui()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
