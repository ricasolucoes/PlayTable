extends Control

## KlondikeGame: Paciência Klondike 3D com Empilhamento Físico de Cartas, Cascatas e Fundações

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

var selected_source: String = ""
var selected_card_idx: int = -1
var moves_count: int = 0
var game_won: bool = false

@onready var env_3d: TabletopEnvironment3D = $TabletopEnvironment3D
@onready var cards_root: Node3D = $CardsRoot
@onready var status_label = $UI/VBoxContainer/Header/StatusLabel
@onready var moves_label = $UI/VBoxContainer/Header/MovesLabel
@onready var btn_restart = $UI/VBoxContainer/Header/BtnRestart

@onready var btn_stock = $UI/TopRow/StockArea/BtnStock
@onready var btn_waste = $UI/TopRow/StockArea/BtnWaste
@onready var foundation_buttons = [
	$UI/TopRow/Foundations/BtnF0,
	$UI/TopRow/Foundations/BtnF1,
	$UI/TopRow/Foundations/BtnF2,
	$UI/TopRow/Foundations/BtnF3
]
@onready var tableau_buttons = [
	$UI/Tableau/Col0,
	$UI/Tableau/Col1,
	$UI/Tableau/Col2,
	$UI/Tableau/Col3,
	$UI/Tableau/Col4,
	$UI/Tableau/Col5,
	$UI/Tableau/Col6
]

# Posições 3D de referência na mesa
const STOCK_POS_3D = Vector3(-2.4, 0.05, -2.0)
const WASTE_POS_3D = Vector3(-1.6, 0.05, -2.0)
const FOUNDATION_START_X = 0.2
const TABLEAU_START_X = -2.4
const TABLEAU_SPACING_X = 0.8
const TABLEAU_START_Z = -0.7
const TABLEAU_CASCADE_Z = 0.22

func _ready():
	env_3d.set_felt_color(Color(0.06, 0.3, 0.18))
	stock = CardPile.new()
	waste = CardPile.new()
	foundations.clear()
	for i in range(4): foundations.append(CardPile.new())
	tableau.clear()
	for i in range(7): tableau.append(CardPile.new())
	
	btn_stock.pressed.connect(_on_stock_pressed)
	btn_waste.pressed.connect(_on_waste_pressed)
	for i in range(4):
		foundation_buttons[i].pressed.connect(_on_foundation_pressed.bind(i))
	for i in range(7):
		tableau_buttons[i].pressed.connect(_on_tableau_col_pressed.bind(i))
		
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
	
	for c in range(7):
		for r in range(c + 1):
			var card = deck.draw()
			card.is_face_up = (r == c)
			tableau[c].push(card)
			
	while not deck.is_empty():
		var card = deck.draw()
		card.is_face_up = false
		stock.push(card)
		
	_sync_3d_table()
	_update_ui()
	status_label.text = "Paciência Klondike 3D iniciada!"

func _sync_3d_table():
	for c in cards_root.get_children(): c.queue_free()
	
	# Renderiza Stock (Monte)
	for i in range(stock.size()):
		var card = stock.cards[i]
		var c_3d = preload("res://shared/3d/Card3D.tscn").instantiate()
		c_3d.setup(card.get_display_value(), card.get_suit_symbol(), false)
		c_3d.position = STOCK_POS_3D + Vector3(0, i * 0.003, 0)
		cards_root.add_child(c_3d)
		
	# Renderiza Waste (Descarte)
	for i in range(waste.size()):
		var card = waste.cards[i]
		var c_3d = preload("res://shared/3d/Card3D.tscn").instantiate()
		c_3d.setup(card.get_display_value(), card.get_suit_symbol(), true)
		c_3d.position = WASTE_POS_3D + Vector3(0, i * 0.003, 0)
		cards_root.add_child(c_3d)
		
	# Renderiza Fundações (4 naipes)
	for f_idx in range(4):
		var f_pile = foundations[f_idx]
		var pos_x = FOUNDATION_START_X + (f_idx * 0.8)
		for i in range(f_pile.size()):
			var card = f_pile.cards[i]
			var c_3d = preload("res://shared/3d/Card3D.tscn").instantiate()
			c_3d.setup(card.get_display_value(), card.get_suit_symbol(), true)
			c_3d.position = Vector3(pos_x, 0.05 + (i * 0.003), -2.0)
			cards_root.add_child(c_3d)
			
	# Renderiza Tableau (7 colunas em cascata)
	for col_idx in range(7):
		var col_pile = tableau[col_idx]
		var pos_x = TABLEAU_START_X + (col_idx * TABLEAU_SPACING_X)
		for r_idx in range(col_pile.size()):
			var card = col_pile.cards[r_idx]
			var c_3d = preload("res://shared/3d/Card3D.tscn").instantiate()
			c_3d.setup(card.get_display_value(), card.get_suit_symbol(), card.is_face_up)
			var pos_z = TABLEAU_START_Z + (r_idx * TABLEAU_CASCADE_Z)
			c_3d.position = Vector3(pos_x, 0.05 + (r_idx * 0.006), pos_z)
			cards_root.add_child(c_3d)

func _update_ui():
	moves_label.text = "Movimentos: %d" % moves_count
	btn_stock.text = "Monte\n(%d)" % stock.size()
	
	if waste.is_empty():
		btn_waste.text = "Vazio"
		btn_waste.disabled = true
	else:
		var top = waste.peek()
		btn_waste.text = "%s %s" % [top.get_display_value(), top.get_suit_symbol()]
		btn_waste.disabled = false
		
	for i in range(4):
		if foundations[i].is_empty():
			foundation_buttons[i].text = "%s" % SUIT_ICONS[i]
		else:
			var top = foundations[i].peek()
			foundation_buttons[i].text = "%s %s" % [top.get_display_value(), top.get_suit_symbol()]
			
	for i in range(7):
		if tableau[i].is_empty():
			tableau_buttons[i].text = "Col %d\n(Vazio)" % (i + 1)
		else:
			var top = tableau[i].peek()
			tableau_buttons[i].text = "Col %d\n%s %s" % [i + 1, top.get_display_value(), top.get_suit_symbol()]

func _on_stock_pressed():
	if game_won: return
	selected_source = ""
	selected_card_idx = -1
	
	if stock.is_empty():
		if waste.is_empty(): return
		while not waste.is_empty():
			var c = waste.pop()
			c.is_face_up = false
			stock.push(c)
		status_label.text = "Monte reiniciado."
	else:
		var card = stock.pop()
		card.is_face_up = true
		waste.push(card)
		status_label.text = "Carta virada do monte."
		
	moves_count += 1
	_sync_3d_table()
	_update_ui()

func _on_waste_pressed():
	if game_won or waste.is_empty(): return
	selected_source = "waste"
	selected_card_idx = waste.size() - 1
	var top = waste.peek()
	status_label.text = "Selecionado: %s %s do descarte." % [top.get_display_value(), top.get_suit_symbol()]

func _on_foundation_pressed(f_idx: int):
	if game_won: return
	var f_pile = foundations[f_idx]
	var req_suit = FOUNDATION_SUITS[f_idx]
	
	if selected_source == "waste":
		var card = waste.peek()
		if card.suit == req_suit and KlondikeRules.can_place_on_foundation(card, f_pile):
			waste.pop()
			f_pile.push(card)
			moves_count += 1
			status_label.text = "Movido para fundação!"
			_clear_selection_and_update()
			_check_win()
			return
	elif selected_source.begins_with("tableau_"):
		var col_idx = selected_source.split("_")[1].to_int()
		var col_pile = tableau[col_idx]
		if not col_pile.is_empty():
			var card = col_pile.peek()
			if card.suit == req_suit and KlondikeRules.can_place_on_foundation(card, f_pile):
				col_pile.pop()
				if not col_pile.is_empty(): col_pile.peek().is_face_up = true
				f_pile.push(card)
				moves_count += 1
				status_label.text = "Movido para fundação!"
				_clear_selection_and_update()
				_check_win()
				return
				
	status_label.text = "Jogada inválida para esta fundação."

func _on_tableau_col_pressed(col_idx: int):
	if game_won: return
	var target_col = tableau[col_idx]
	
	if selected_source == "":
		if not target_col.is_empty():
			selected_source = "tableau_%d" % col_idx
			selected_card_idx = target_col.size() - 1
			var top = target_col.peek()
			status_label.text = "Selecionado: %s %s da Coluna %d" % [top.get_display_value(), top.get_suit_symbol(), col_idx + 1]
		return
		
	if selected_source == "waste":
		var card = waste.peek()
		if KlondikeRules.can_place_on_tableau(card, target_col):
			waste.pop()
			target_col.push(card)
			moves_count += 1
			_clear_selection_and_update()
			return
	elif selected_source.begins_with("tableau_"):
		var src_col_idx = selected_source.split("_")[1].to_int()
		if src_col_idx == col_idx:
			selected_source = ""
			selected_card_idx = -1
			status_label.text = "Seleção desfeita."
			return
			
		var src_col = tableau[src_col_idx]
		if not src_col.is_empty():
			var card = src_col.peek()
			if KlondikeRules.can_place_on_tableau(card, target_col):
				src_col.pop()
				if not src_col.is_empty(): src_col.peek().is_face_up = true
				target_col.push(card)
				moves_count += 1
				_clear_selection_and_update()
				return
				
	status_label.text = "Jogada inválida."

func _clear_selection_and_update():
	selected_source = ""
	selected_card_idx = -1
	_sync_3d_table()
	_update_ui()

func _check_win():
	var total_found = 0
	for f in foundations: total_found += f.size()
	if total_found == 52:
		game_won = true
		status_label.text = "🏆 Parabéns! Você completou a Paciência 3D!"
		env_3d.celebrate_win()

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
