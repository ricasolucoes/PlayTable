extends Control

const SUITS = ["♠", "♥", "♦", "♣"]
const VALUES = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]

# Card format: {"val": int (2-14), "val_str": String, "suit": String, "color": "red"/"black"}

var deck = []
var player_cards = []
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

func _build_deck():
	deck.clear()
	for s in SUITS:
		var color = "red" if (s == "♥" or s == "♦") else "black"
		for v_idx in range(VALUES.size()):
			deck.append({
				"val": v_idx + 2, # 2 to 14 (Ace = 14)
				"val_str": VALUES[v_idx],
				"suit": s,
				"color": color
			})
	deck.shuffle()

func _on_btn_action_pressed():
	if game_phase == "bet":
		if chips < current_bet:
			status_label.text = "Fichas insuficientes para esta aposta!"
			return
		chips -= current_bet
		_update_chips_ui()
		
		_build_deck()
		player_cards.clear()
		for i in range(5):
			player_cards.append(deck.pop_back())
			held_cards[i] = false
			
		game_phase = "hold"
		btn_bet_minus.disabled = true
		btn_bet_plus.disabled = true
		btn_action.text = "🔄 TROCAR CARTAS"
		btn_action.self_modulate = Color(0.2, 0.5, 0.85)
		status_label.text = "Toque nas cartas que deseja MANTER (HOLD)."
		_render_cards()
		
	elif game_phase == "hold":
		# Replace non-held cards
		for i in range(5):
			if not held_cards[i]:
				player_cards[i] = deck.pop_back()
				
		_render_cards()
		_evaluate_and_payout()
		
	elif game_phase == "result":
		_reset_to_bet_phase()

func _render_cards():
	for i in range(5):
		var card = player_cards[i]
		var btn = card_buttons[i]
		btn.text = "%s\n%s" % [card["val_str"], card["suit"]]
		btn.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25) if card["color"] == "red" else Color(0.95, 0.95, 0.95))
		
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
	
	var result = _evaluate_hand(player_cards)
	var rank_name = result["name"]
	var multiplier = result["mult"]
	
	var win_amount = current_bet * multiplier
	if win_amount > 0:
		chips += win_amount
		status_label.text = "🎉 %s! Ganhou %d fichas (+%dx)!" % [rank_name, win_amount, multiplier]
	else:
		status_label.text = "%s. Tente novamente!" % rank_name
		
	_update_chips_ui()

func _evaluate_hand(cards: Array) -> Dictionary:
	var vals = []
	var suits = []
	for c in cards:
		vals.append(c["val"])
		suits.append(c["suit"])
		
	vals.sort()
	
	# Check Flush
	var is_flush = (suits[0] == suits[1] and suits[1] == suits[2] and suits[2] == suits[3] and suits[3] == suits[4])
	
	# Check Straight
	var is_straight = false
	if (vals[4] - vals[0] == 4) and (vals[1] - vals[0] == 1) and (vals[2] - vals[1] == 1) and (vals[3] - vals[2] == 1):
		is_straight = true
	elif vals == [2, 3, 4, 5, 14]: # Wheel straight (A-2-3-4-5)
		is_straight = true
		
	# Value frequency counts
	var freq = {}
	for v in vals:
		freq[v] = freq.get(v, 0) + 1
	var counts = freq.values()
	counts.sort()
	
	# Hand evaluations
	if is_flush and is_straight and vals[0] == 10 and vals[4] == 14:
		return {"name": "Royal Flush", "mult": 800}
	if is_flush and is_straight:
		return {"name": "Straight Flush", "mult": 50}
	if 4 in counts:
		return {"name": "Quadra (4 of a Kind)", "mult": 25}
	if counts == [2, 3]:
		return {"name": "Full House", "mult": 9}
	if is_flush:
		return {"name": "Flush (Cor)", "mult": 6}
	if is_straight:
		return {"name": "Sequência (Straight)", "mult": 4}
	if 3 in counts:
		return {"name": "Trinca (3 of a Kind)", "mult": 3}
	if counts == [1, 2, 2]:
		return {"name": "Dois Pares", "mult": 2}
	if 2 in counts:
		# Check if pair is Jacks or Better (11, 12, 13, 14)
		for v in freq:
			if freq[v] == 2 and v >= 11:
				return {"name": "Par de Valetes ou Maior", "mult": 1}
		return {"name": "Par Baixo (Sem prêmio)", "mult": 0}
		
	return {"name": "Carta Alta (Sem prêmio)", "mult": 0}

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
