extends Control

## PokerGame: Video Poker 3D com Cartas Reais em Cassino, Seleção de Reter e Animações de Troca

const CardScript = preload("res://shared/core_engine/cards/Card.gd")
const DeckScript = preload("res://shared/core_engine/cards/Deck.gd")
const CardHandScript = preload("res://shared/core_engine/cards/CardHand.gd")
const PokerEvaluatorScript = preload("res://games/poker/PokerEvaluator.gd")

var deck: Deck
var player_hand: CardHand
var held_cards = [false, false, false, false, false]
var cards_3d: Array[Card3D] = []

var chips: int = 100
var current_bet: int = 5
var game_phase: String = "bet" # "bet", "hold", "result"

@onready var env_3d: TabletopEnvironment3D = $TabletopEnvironment3D
@onready var cards_root: Node3D = $CardsRoot
@onready var chips_label = $UI/VBoxContainer/Header/ChipsLabel
@onready var bet_label = $UI/VBoxContainer/Header/BetLabel
@onready var status_label = $UI/VBoxContainer/StatusLabel
@onready var payout_table_label = $UI/VBoxContainer/PayoutTableContainer/PayoutLabel
@onready var btn_action = $UI/Controls/BtnAction
@onready var btn_bet_minus = $UI/Controls/BtnBetMinus
@onready var btn_bet_plus = $UI/Controls/BtnBetPlus
@onready var touch_buttons = [
	$UI/CenterContainer/HBoxCards/BtnC0,
	$UI/CenterContainer/HBoxCards/BtnC1,
	$UI/CenterContainer/HBoxCards/BtnC2,
	$UI/CenterContainer/HBoxCards/BtnC3,
	$UI/CenterContainer/HBoxCards/BtnC4
]

const CARD_SPACING_X: float = 0.95

func _ready():
	env_3d.set_felt_color(Color(0.2, 0.08, 0.28)) # Feltro Púrpura Imperial
	player_hand = CardHand.new()
	for i in range(5):
		touch_buttons[i].pressed.connect(_on_card_clicked.bind(i))
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
		touch_buttons[i].text = ""
		touch_buttons[i].disabled = true
		
	for c in cards_root.get_children(): c.queue_free()
	cards_3d.clear()
	
	btn_bet_minus.disabled = false
	btn_bet_plus.disabled = false
	btn_action.text = "🃏 DAR CARTAS"
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
		
		for c in cards_root.get_children(): c.queue_free()
		cards_3d.clear()
		
		var start_x = -(5 * CARD_SPACING_X * 0.5) + (CARD_SPACING_X * 0.5)
		
		for i in range(5):
			var card = deck.draw()
			player_hand.add(card)
			
			var c_3d = preload("res://shared/3d/Card3D.tscn").instantiate()
			c_3d.setup(card.get_display_value(), card.get_suit_symbol(), true)
			var target_pos = Vector3(start_x + (i * CARD_SPACING_X), 0.05, 0.0)
			c_3d.position = Vector3(2.5, 0.4, -1.8)
			cards_root.add_child(c_3d)
			cards_3d.append(c_3d)
			c_3d.deal_to(target_pos, 0.0, 0.4 + (i * 0.05))
			
			touch_buttons[i].disabled = false
			touch_buttons[i].text = ""
			
		btn_bet_minus.disabled = true
		btn_bet_plus.disabled = true
		btn_action.text = "🔄 TROCAR CARTAS"
		game_phase = "hold"
		status_label.text = "Toque nas cartas que deseja RETER (HOLD)!"
		
	elif game_phase == "hold":
		# Troca as cartas não retidas
		var start_x = -(5 * CARD_SPACING_X * 0.5) + (CARD_SPACING_X * 0.5)
		
		for i in range(5):
			if not held_cards[i]:
				var new_card = deck.draw()
				player_hand.cards[i] = new_card
				
				var old_3d = cards_3d[i]
				old_3d.queue_free()
				
				var c_3d = preload("res://shared/3d/Card3D.tscn").instantiate()
				c_3d.setup(new_card.get_display_value(), new_card.get_suit_symbol(), true)
				var target_pos = Vector3(start_x + (i * CARD_SPACING_X), 0.05, 0.0)
				c_3d.position = Vector3(2.5, 0.4, -1.8)
				cards_root.add_child(c_3d)
				cards_3d[i] = c_3d
				c_3d.deal_to(target_pos, 0.0, 0.4)
				
			touch_buttons[i].disabled = true
			
		game_phase = "result"
		_evaluate_poker_hand()

func _on_card_clicked(idx: int):
	if game_phase != "hold": return
	held_cards[idx] = not held_cards[idx]
	
	var c_3d = cards_3d[idx]
	c_3d.hover(held_cards[idx])
	touch_buttons[idx].text = "RETER" if held_cards[idx] else ""

func _evaluate_poker_hand():
	var result = PokerEvaluator.evaluate(player_hand.get_all())
	var hand_name = result["name"]
	var mult = result["multiplier"]
	var win_amount = current_bet * mult
	
	if mult > 0:
		chips += win_amount
		status_label.text = "🏆 %s! Você ganhou %d fichas!" % [hand_name, win_amount]
		env_3d.celebrate_win()
	else:
		status_label.text = "%s. Nenhuma combinação premiada." % hand_name
		
	_update_chips_ui()
	btn_action.text = "🃏 NOVA RODADA"
	btn_bet_minus.disabled = false
	btn_bet_plus.disabled = false
	game_phase = "bet"

func _on_btn_bet_minus_pressed():
	if game_phase != "bet": return
	current_bet = max(5, current_bet - 5)
	_update_chips_ui()

func _on_btn_bet_plus_pressed():
	if game_phase != "bet": return
	current_bet = min(chips, current_bet + 5)
	_update_chips_ui()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
