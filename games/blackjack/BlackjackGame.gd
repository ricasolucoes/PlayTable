extends Control

var deck = []
var player_hand = []
var dealer_hand = []
var game_over = false

var chips = 100
var current_bet = 10

@onready var chips_label = $VBoxContainer/Header/ChipsLabel
@onready var bet_label = $VBoxContainer/Header/BetLabel
@onready var status = $VBoxContainer/Status
@onready var player_cards_container = $VBoxContainer/PlayerArea/PlayerCards
@onready var dealer_cards_container = $VBoxContainer/DealerArea/DealerCards
@onready var btn_hit = $VBoxContainer/Buttons/BtnHit
@onready var btn_stand = $VBoxContainer/Buttons/BtnStand
@onready var btn_double = $VBoxContainer/Buttons/BtnDouble
@onready var btn_restart = $VBoxContainer/Buttons/BtnRestart

func _ready():
	_start_game()

func _start_game():
	if chips <= 0:
		chips = 50
		status.text = "Recarga grátis de 50 fichas!"
		
	if chips < current_bet:
		current_bet = chips
		
	chips -= current_bet
	_update_chips_ui()
	
	game_over = false
	deck.clear()
	player_hand.clear()
	dealer_hand.clear()
	
	btn_hit.disabled = false
	btn_stand.disabled = false
	btn_double.disabled = (chips < current_bet)
	btn_restart.hide()
	
	_build_deck()
	deck.shuffle()
	
	player_hand.append(_draw_card())
	dealer_hand.append(_draw_card())
	player_hand.append(_draw_card())
	dealer_hand.append(_draw_card())
	
	_update_ui(false)
	status.text = "Sua vez! Pontos: %d" % _calculate_score(player_hand)
	
	if _calculate_score(player_hand) == 21:
		var payout = int(current_bet * 2.5) # 3:2 blackjack payout
		chips += payout
		_update_chips_ui()
		_end_game("🎉 Blackjack Natural! Você ganhou %d fichas!" % payout)

func _update_chips_ui():
	chips_label.text = "💰 Fichas: %d" % chips
	bet_label.text = "Aposta: %d" % current_bet

func _build_deck():
	var suits = ["♥", "♦", "♣", "♠"]
	var values = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	for s in suits:
		for v in values:
			deck.append({"val": v, "suit": s})

func _draw_card() -> Dictionary:
	return deck.pop_back()

func _calculate_score(hand: Array) -> int:
	var score = 0
	var aces = 0
	for card in hand:
		var v = card["val"]
		if v == "A":
			aces += 1
			score += 11
		elif v in ["J", "Q", "K"]:
			score += 10
		else:
			score += v.to_int()
			
	while score > 21 and aces > 0:
		score -= 10
		aces -= 1
		
	return score

func _update_ui(show_dealer: bool):
	for c in player_cards_container.get_children(): c.queue_free()
	for c in dealer_cards_container.get_children(): c.queue_free()
	
	for card in player_hand:
		var btn = _create_card_visual(card["val"], card["suit"])
		player_cards_container.add_child(btn)
		
	for i in range(dealer_hand.size()):
		var btn
		if i == 0 and not show_dealer and not game_over:
			btn = _create_card_visual("?", "?")
		else:
			btn = _create_card_visual(dealer_hand[i]["val"], dealer_hand[i]["suit"])
		dealer_cards_container.add_child(btn)

func _create_card_visual(val: String, suit: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(85, 125)
	btn.add_theme_font_size_override("font_size", 28)
	btn.disabled = true
	if val == "?":
		btn.text = "🎴"
		btn.self_modulate = Color(0.2, 0.25, 0.3)
	else:
		btn.text = val + "\n" + suit
		var is_red = (suit == "♥" or suit == "♦")
		btn.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25) if is_red else Color(0.95, 0.95, 0.95))
		btn.self_modulate = Color(0.22, 0.28, 0.35)
	return btn

func _on_btn_hit_pressed():
	if game_over: return
	btn_double.disabled = true
	player_hand.append(_draw_card())
	_update_ui(false)
	
	var p_score = _calculate_score(player_hand)
	status.text = "Pontos: %d" % p_score
	
	if p_score > 21:
		_end_game("💥 Estourou! (%d pontos) Você Perdeu." % p_score)

func _on_btn_double_pressed():
	if game_over or chips < current_bet: return
	chips -= current_bet
	current_bet *= 2
	_update_chips_ui()
	
	player_hand.append(_draw_card())
	_update_ui(false)
	
	var p_score = _calculate_score(player_hand)
	if p_score > 21:
		_end_game("💥 Estourou no Dobro! (%d pontos) Você Perdeu." % p_score)
	else:
		_on_btn_stand_pressed()

func _on_btn_stand_pressed():
	if game_over: return
	btn_hit.disabled = true
	btn_stand.disabled = true
	btn_double.disabled = true
	_update_ui(true)
	
	status.text = "Vez do Dealer..."
	_play_dealer()

func _play_dealer():
	while _calculate_score(dealer_hand) < 17:
		await get_tree().create_timer(0.8).timeout
		dealer_hand.append(_draw_card())
		_update_ui(true)
		
		if _calculate_score(dealer_hand) > 21:
			var win_amt = current_bet * 2
			chips += win_amt
			_update_chips_ui()
			_end_game("🎉 Dealer Estourou! Você Ganhou %d fichas!" % win_amt)
			return
			
	var p_score = _calculate_score(player_hand)
	var d_score = _calculate_score(dealer_hand)
	
	if d_score > p_score:
		_end_game("Dealer (%d) venceu Você (%d)!" % [d_score, p_score])
	elif d_score < p_score:
		var win_amt = current_bet * 2
		chips += win_amt
		_update_chips_ui()
		_end_game("🎉 Você (%d) venceu o Dealer (%d)! Ganhou %d fichas!" % [p_score, d_score, win_amt])
	else:
		chips += current_bet # Push (Empate)
		_update_chips_ui()
		_end_game("🤝 Empate (%d pontos)! Aposta devolvida." % p_score)

func _end_game(msg: String):
	game_over = true
	btn_hit.disabled = true
	btn_stand.disabled = true
	btn_double.disabled = true
	btn_restart.show()
	status.text = msg
	_update_ui(true)

func _on_btn_restart_pressed():
	current_bet = 10 # Reset base bet
	_start_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
