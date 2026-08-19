extends Control

## BlackjackGame: 21 / Blackjack 3D com Cartas Físicas em Mesa de Cassino e Animação de Distribuição

const CardScript = preload("res://shared/core_engine/cards/Card.gd")
const DeckScript = preload("res://shared/core_engine/cards/Deck.gd")
const CardHandScript = preload("res://shared/core_engine/cards/CardHand.gd")
const BlackjackRulesScript = preload("res://games/blackjack/BlackjackRules.gd")

var deck: Deck
var player_hand: CardHand
var dealer_hand: CardHand
var game_over: bool = false

var player_cards_3d: Array = []
var dealer_cards_3d: Array = []

@onready var env_3d: TabletopEnvironment3D = $TabletopEnvironment3D
@onready var cards_root: Node3D = $CardsRoot
@onready var status = $UI/VBoxContainer/Status
@onready var dealer_score_label = $UI/VBoxContainer/DealerScoreLabel
@onready var player_score_label = $UI/VBoxContainer/PlayerScoreLabel
@onready var btn_hit = $UI/Buttons/BtnHit
@onready var btn_stand = $UI/Buttons/BtnStand
@onready var btn_restart = $UI/Buttons/BtnRestart

func _ready() -> void:
	env_3d.set_felt_color(Color(0.06, 0.32, 0.18)) # Verde cassino clássico
	player_hand = CardHand.new()
	dealer_hand = CardHand.new()
	_start_game()

func _start_game() -> void:
	game_over = false
	player_hand.clear()
	dealer_hand.clear()
	
	for c in cards_root.get_children(): c.queue_free()
	player_cards_3d.clear()
	dealer_cards_3d.clear()
	
	btn_hit.disabled = false
	btn_stand.disabled = false
	btn_restart.hide()
	
	deck = Deck.create_standard_52()
	deck.shuffle()
	
	# Distribuição inicial em 3D
	var p_c1 = deck.draw()
	var d_c1 = deck.draw() # Carta oculta do dealer
	var p_c2 = deck.draw()
	var d_c2 = deck.draw()
	
	player_hand.add(p_c1)
	dealer_hand.add(d_c1)
	player_hand.add(p_c2)
	dealer_hand.add(d_c2)
	
	_spawn_card_3d(p_c1, true, 0, true)
	_spawn_card_3d(d_c1, false, 0, false) # Oculta
	_spawn_card_3d(p_c2, true, 1, true)
	_spawn_card_3d(d_c2, false, 1, true) # Visível
	
	_update_labels(false)
	status.text = "Sua vez! Pedir carta ou parar?"
	
	if BlackjackRules.is_blackjack(player_hand.get_all()):
		_reveal_dealer_and_end("🏆 Blackjack Natural! Você Venceu!", true)

func _spawn_card_3d(card: Card, is_player: bool, index: int, face_up: bool) -> Card3D:
	var c_3d = preload("res://shared/3d/Card3D.tscn").instantiate()
	var disp_val = card.get_display_value()
	var suit_sym = card.get_suit_symbol()
	c_3d.setup(disp_val, suit_sym, face_up)
	
	var shoe_pos = Vector3(2.6, 0.4, -1.8)
	c_3d.position = shoe_pos
	cards_root.add_child(c_3d)
	
	var target_z = 0.8 if is_player else -0.8
	var spacing_x = 0.85
	var start_x = -1.2 + (index * spacing_x)
	var target_pos = Vector3(start_x, 0.05 + (index * 0.005), target_z)
	
	c_3d.deal_to(target_pos, 0.0, 0.45)
	
	if is_player:
		player_cards_3d.append(c_3d)
	else:
		dealer_cards_3d.append(c_3d)
		
	return c_3d

func _update_labels(show_dealer: bool) -> void:
	var p_score = BlackjackRules.calculate_hand_value(player_hand.get_all())
	player_score_label.text = "Sua Mão: %d pontos" % p_score
	
	if show_dealer or game_over:
		var d_score = BlackjackRules.calculate_hand_value(dealer_hand.get_all())
		dealer_score_label.text = "Mão da Mesa (Dealer): %d pontos" % d_score
	else:
		var visible_cards = dealer_hand.get_all().slice(1)
		var partial_score = BlackjackRules.calculate_hand_value(visible_cards)
		dealer_score_label.text = "Mão da Mesa: %d + [Oculta]" % partial_score

func _on_btn_hit_pressed() -> void:
	if game_over: return
	
	var card = deck.draw()
	player_hand.add(card)
	_spawn_card_3d(card, true, player_hand.size() - 1, true)
	_update_labels(false)
	
	if BlackjackRules.is_busted(player_hand.get_all()):
		_reveal_dealer_and_end("Estourou! Você ultrapassou 21.", false)

func _on_btn_stand_pressed() -> void:
	if game_over: return
	
	btn_hit.disabled = true
	btn_stand.disabled = true
	status.text = "Vez do Dealer..."
	
	# Vira a carta oculta do dealer em 3D
	if dealer_cards_3d.size() > 0:
		dealer_cards_3d[0].flip(true, 0.4)
		
	await get_tree().create_timer(0.6).timeout
	_update_labels(true)
	
	# Dealer joga até 17+
	while BlackjackRules.should_dealer_hit(dealer_hand.get_all()):
		await get_tree().create_timer(0.6).timeout
		var card = deck.draw()
		dealer_hand.add(card)
		_spawn_card_3d(card, false, dealer_hand.size() - 1, true)
		_update_labels(true)
		
	var outcome = BlackjackRules.determine_winner(player_hand.get_all(), dealer_hand.get_all())
	var d_score = BlackjackRules.calculate_hand_value(dealer_hand.get_all())
	
	if outcome == BlackjackRules.Winner.PLAYER:
		if d_score > 21:
			_end_game("🏆 Dealer estourou (%d)! Você Venceu!" % d_score, true)
		else:
			_end_game("🏆 Você Venceu a rodada!", true)
	elif outcome == BlackjackRules.Winner.DEALER:
		_end_game("Dealer Venceu (%d pontos)." % d_score, false)
	else:
		_end_game("Empate (Push)! As apostas retornam.", false)

func _reveal_dealer_and_end(msg: String, is_player_win: bool) -> void:
	if dealer_cards_3d.size() > 0:
		dealer_cards_3d[0].flip(true, 0.4)
	_update_labels(true)
	_end_game(msg, is_player_win)

func _end_game(msg: String, is_player_win: bool) -> void:
	game_over = true
	status.text = msg
	btn_hit.disabled = true
	btn_stand.disabled = true
	btn_restart.show()
	if is_player_win:
		env_3d.celebrate_win()

func _on_btn_restart_pressed() -> void:
	_start_game()

func _on_btn_back_pressed() -> void:
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
