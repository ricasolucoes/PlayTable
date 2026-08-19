extends Control

const CardScript = preload("res://shared/core_engine/cards/Card.gd")
const DeckScript = preload("res://shared/core_engine/cards/Deck.gd")
const CardPileScript = preload("res://shared/core_engine/cards/CardPile.gd")
const KlondikeRulesScript = preload("res://games/paciencia/KlondikeRules.gd")

const FOUNDATION_SUITS = [Card.Suit.SPADES, Card.Suit.HEARTS, Card.Suit.DIAMONDS, Card.Suit.CLUBS]
const SUIT_ICONS = ["♠", "♥", "♦", "♣"]

var stock: CardPile
var waste: CardPile
var foundations: Array[CardPile] = []
var tableau: Array[CardPile] = []

var selected_source: String = "" # "waste", "tableau_X", "foundation_X"
var selected_card_idx: int = -1
var moves_count: int = 0
var game_won: bool = false

@onready var btn_stock = $VBoxContainer/TopRow/StockArea/BtnStock
@onready var btn_waste = $VBoxContainer/TopRow/StockArea/BtnWaste
@onready var foundation_buttons = [
	$VBoxContainer/TopRow/Foundations/BtnF0,
	$VBoxContainer/TopRow/Foundations/BtnF1,
	$VBoxContainer/TopRow/Foundations/BtnF2,
	$VBoxContainer/TopRow/Foundations/BtnF3
]
@onready var tableau_containers = [
	$VBoxContainer/Tableau/Col0,
	$VBoxContainer/Tableau/Col1,
	$VBoxContainer/Tableau/Col2,
	$VBoxContainer/Tableau/Col3,
	$VBoxContainer/Tableau/Col4,
	$VBoxContainer/Tableau/Col5,
	$VBoxContainer/Tableau/Col6
]
@onready var status_label = $VBoxContainer/Header/StatusLabel
@onready var moves_label = $VBoxContainer/Header/MovesLabel
@onready var btn_restart = $VBoxContainer/Header/BtnRestart

func _ready():
	stock = CardPile.new()
	waste = CardPile.new()
	foundations.clear()
	for i in range(4):
		foundations.append(CardPile.new())
	tableau.clear()
	for i in range(7):
		tableau.append(CardPile.new())
		
	btn_stock.pressed.connect(_on_stock_pressed)
	btn_waste.pressed.connect(_on_waste_pressed)
	for i in range(4):
		foundation_buttons[i].pressed.connect(_on_foundation_pressed.bind(i))
	_start_new_game()

func _start_new_game():
	moves_count = 0
	game_won = false
	selected_source = ""
	selected_card_idx = -1
	
	var deck = Deck.create_standard_52()
	deck.shuffle()
	
	stock.clear()
	waste.clear()
	for f in foundations: f.clear()
	for col in tableau: col.clear()
	
	# Distribui para as 7 colunas do Tableau
	for c in range(7):
		for r in range(c + 1):
			var card = deck.draw()
			card.is_face_up = (r == c)
			tableau[c].push(card)
			
	# Restante para o Stock (monte)
	while not deck.is_empty():
		var card = deck.draw()
		card.is_face_up = false
		stock.push(card)
		
	status_label.text = "Paciência Klondike"
	_update_ui()

func _update_ui():
	moves_label.text = "Movimentos: %d" % moves_count
	
	# Stock & Waste
	if stock.size() > 0:
		btn_stock.text = "🎴\n(%d)" % stock.size()
		btn_stock.self_modulate = Color(0.2, 0.4, 0.7)
	else:
		btn_stock.text = "🔄\nMonte"
		btn_stock.self_modulate = Color(0.3, 0.3, 0.35)
		
	var top_w = waste.peek()
	if top_w != null:
		btn_waste.text = "%s %s" % [top_w.get_display_value(), top_w.get_suit_symbol()]
		btn_waste.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2) if top_w.is_red() else Color(0.9, 0.9, 0.9))
		btn_waste.self_modulate = Color(0.85, 0.7, 0.2) if selected_source == "waste" else Color(0.2, 0.25, 0.3)
	else:
		btn_waste.text = ""
		btn_waste.self_modulate = Color(0.15, 0.18, 0.22)
		
	# Foundations
	for i in range(4):
		var btn = foundation_buttons[i]
		var top_f = foundations[i].peek()
		if top_f != null:
			btn.text = "%s\n%s" % [top_f.get_display_value(), top_f.get_suit_symbol()]
			btn.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2) if top_f.is_red() else Color(0.9, 0.9, 0.9))
		else:
			btn.text = SUIT_ICONS[i]
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		btn.self_modulate = Color(0.85, 0.7, 0.2) if selected_source == ("foundation_" + str(i)) else Color(0.2, 0.25, 0.3)
		
	# Tableau
	for c in range(7):
		var col_node = tableau_containers[c]
		for child in col_node.get_children(): child.queue_free()
		
		var col_cards = tableau[c].get_all()
		if col_cards.size() > 0 and not col_cards.back().is_face_up:
			col_cards.back().is_face_up = true
			
		if col_cards.size() == 0:
			var empty_btn = Button.new()
			empty_btn.custom_minimum_size = Vector2(85, 60)
			empty_btn.text = "---"
			empty_btn.self_modulate = Color(0.85, 0.7, 0.2) if selected_source == ("tableau_" + str(c)) else Color(0.15, 0.18, 0.22)
			empty_btn.pressed.connect(_on_tableau_col_clicked.bind(c, -1))
			col_node.add_child(empty_btn)
		else:
			for idx in range(col_cards.size()):
				var card = col_cards[idx]
				var btn = Button.new()
				btn.custom_minimum_size = Vector2(85, 45)
				btn.add_theme_font_size_override("font_size", 20)
				
				if card.is_face_up:
					btn.text = "%s %s" % [card.get_display_value(), card.get_suit_symbol()]
					btn.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2) if card.is_red() else Color(0.9, 0.9, 0.9))
					var is_selected = (selected_source == ("tableau_" + str(c)) and idx >= selected_card_idx)
					btn.self_modulate = Color(0.85, 0.7, 0.2) if is_selected else Color(0.22, 0.28, 0.34)
					btn.pressed.connect(_on_tableau_col_clicked.bind(c, idx))
				else:
					btn.text = "🎴"
					btn.self_modulate = Color(0.15, 0.2, 0.26)
					
				col_node.add_child(btn)

func _on_stock_pressed():
	if game_won: return
	selected_source = ""
	selected_card_idx = -1
	
	if not stock.is_empty():
		var drawn = stock.pop()
		drawn.is_face_up = true
		waste.push(drawn)
		moves_count += 1
	else:
		while not waste.is_empty():
			var card = waste.pop()
			card.is_face_up = false
			stock.push(card)
		moves_count += 1
		
	_update_ui()

func _on_waste_pressed():
	if game_won or waste.is_empty(): return
	
	# Auto-move on double-click
	if selected_source == "waste":
		var target_f = KlondikeRules.find_auto_foundation_index(waste.peek(), foundations, FOUNDATION_SUITS)
		if target_f != -1:
			foundations[target_f].push(waste.pop())
			selected_source = ""
			moves_count += 1
			_update_ui()
			_check_win()
			return
			
	selected_source = "waste"
	selected_card_idx = -1
	_update_ui()

func _on_foundation_pressed(f_idx: int):
	if game_won: return
	
	if selected_source == "waste" and not waste.is_empty():
		var card = waste.peek()
		if KlondikeRules.can_add_to_foundation(card, FOUNDATION_SUITS[f_idx], foundations[f_idx].peek()):
			foundations[f_idx].push(waste.pop())
			selected_source = ""
			moves_count += 1
			_update_ui()
			_check_win()
			return
	elif selected_source.begins_with("tableau_"):
		var col_idx = selected_source.trim_prefix("tableau_").to_int()
		if tableau[col_idx].size() > 0 and selected_card_idx == tableau[col_idx].size() - 1:
			var card = tableau[col_idx].peek()
			if KlondikeRules.can_add_to_foundation(card, FOUNDATION_SUITS[f_idx], foundations[f_idx].peek()):
				foundations[f_idx].push(tableau[col_idx].pop())
				selected_source = ""
				selected_card_idx = -1
				moves_count += 1
				_update_ui()
				_check_win()
				return
				
	selected_source = "foundation_" + str(f_idx)
	_update_ui()

func _on_tableau_col_clicked(col_idx: int, card_idx: int):
	if game_won: return
	
	# 1. Movendo do Waste para o Tableau
	if selected_source == "waste" and not waste.is_empty():
		var card = waste.peek()
		if KlondikeRules.can_add_to_tableau(card, tableau[col_idx].peek()):
			tableau[col_idx].push(waste.pop())
			selected_source = ""
			moves_count += 1
			_update_ui()
			return
			
	# 2. Movendo de outra coluna do Tableau
	elif selected_source.begins_with("tableau_"):
		var src_col = selected_source.trim_prefix("tableau_").to_int()
		if src_col != col_idx and selected_card_idx >= 0 and selected_card_idx < tableau[src_col].size():
			var moving_card = tableau[src_col].get_card(selected_card_idx)
			if KlondikeRules.can_add_to_tableau(moving_card, tableau[col_idx].peek()):
				var moving_stack = tableau[src_col].slice_from(selected_card_idx)
				tableau[col_idx].push_many(moving_stack)
				selected_source = ""
				selected_card_idx = -1
				moves_count += 1
				_update_ui()
				return
				
	# 3. Auto-move para fundação no topo
	if card_idx == tableau[col_idx].size() - 1 and selected_source == ("tableau_" + str(col_idx)):
		var card = tableau[col_idx].peek()
		var target_f = KlondikeRules.find_auto_foundation_index(card, foundations, FOUNDATION_SUITS)
		if target_f != -1:
			foundations[target_f].push(tableau[col_idx].pop())
			selected_source = ""
			selected_card_idx = -1
			moves_count += 1
			_update_ui()
			_check_win()
			return
			
	# 4. Seleção
	if card_idx >= 0 and tableau[col_idx].get_card(card_idx).is_face_up:
		selected_source = "tableau_" + str(col_idx)
		selected_card_idx = card_idx
	else:
		selected_source = "tableau_" + str(col_idx)
		selected_card_idx = -1
	_update_ui()

func _check_win():
	if KlondikeRules.is_game_won(foundations):
		game_won = true
		status_label.text = "🏆 Parabéns! Você completou a Paciência!"

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
