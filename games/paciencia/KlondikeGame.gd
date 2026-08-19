extends Control

const SUITS = ["♠", "♥", "♦", "♣"]
const VALUES = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

# Card dict format: {"val": int (1-13), "val_str": String, "suit": String, "color": "red"/"black", "face_up": bool}

var deck = []
var stock = []
var waste = []
var foundations = [[], [], [], []] # 0: ♠, 1: ♥, 2: ♦, 3: ♣
var tableau = [[], [], [], [], [], [], []] # 7 columns

var selected_source: String = "" # "waste", "tableau_X", "foundation_X"
var selected_card_idx: int = -1 # For tableau sub-stacks
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
	
	# Build 52 card deck
	deck.clear()
	for s_idx in range(SUITS.size()):
		var suit = SUITS[s_idx]
		var color = "red" if (suit == "♥" or suit == "♦") else "black"
		for v in range(1, 14):
			deck.append({
				"val": v,
				"val_str": VALUES[v - 1],
				"suit": suit,
				"color": color,
				"face_up": false
			})
			
	deck.shuffle()
	
	# Clear piles
	stock.clear()
	waste.clear()
	for f in foundations: f.clear()
	for col in tableau: col.clear()
	
	# Deal to Tableau (1 to 7)
	for c in range(7):
		for r in range(c + 1):
			var card = deck.pop_back()
			if r == c:
				card["face_up"] = true
			tableau[c].append(card)
			
	# Remainder to Stock
	stock = deck.duplicate()
	deck.clear()
	
	status_label.text = "Paciência Klondike"
	_update_ui()

func _update_ui():
	moves_label.text = "Movimentos: %d" % moves_count
	
	# Update Stock & Waste
	if stock.size() > 0:
		btn_stock.text = "🎴\n(%d)" % stock.size()
		btn_stock.self_modulate = Color(0.2, 0.4, 0.7)
	else:
		btn_stock.text = "🔄\nMonte"
		btn_stock.self_modulate = Color(0.3, 0.3, 0.35)
		
	if waste.size() > 0:
		var top_w = waste.back()
		btn_waste.text = "%s %s" % [top_w["val_str"], top_w["suit"]]
		btn_waste.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2) if top_w["color"] == "red" else Color(0.9, 0.9, 0.9))
		btn_waste.self_modulate = Color(0.85, 0.7, 0.2) if selected_source == "waste" else Color(0.2, 0.25, 0.3)
	else:
		btn_waste.text = ""
		btn_waste.self_modulate = Color(0.15, 0.18, 0.22)
		
	# Update Foundations
	for i in range(4):
		var btn = foundation_buttons[i]
		if foundations[i].size() > 0:
			var top_f = foundations[i].back()
			btn.text = "%s\n%s" % [top_f["val_str"], top_f["suit"]]
			btn.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2) if top_f["color"] == "red" else Color(0.9, 0.9, 0.9))
		else:
			btn.text = SUITS[i]
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		btn.self_modulate = Color(0.85, 0.7, 0.2) if selected_source == ("foundation_" + str(i)) else Color(0.2, 0.25, 0.3)
		
	# Update Tableau Columns
	for c in range(7):
		var col_node = tableau_containers[c]
		for child in col_node.get_children(): child.queue_free()
		
		var col_cards = tableau[c]
		# Make sure top card is face up if any
		if col_cards.size() > 0 and not col_cards.back()["face_up"]:
			col_cards.back()["face_up"] = true
			
		if col_cards.size() == 0:
			# Empty column slot button
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
				
				if card["face_up"]:
					btn.text = "%s %s" % [card["val_str"], card["suit"]]
					btn.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2) if card["color"] == "red" else Color(0.9, 0.9, 0.9))
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
	
	if stock.size() > 0:
		var drawn = stock.pop_back()
		drawn["face_up"] = true
		waste.append(drawn)
		moves_count += 1
	else:
		# Recycle waste
		while waste.size() > 0:
			var card = waste.pop_back()
			card["face_up"] = false
			stock.append(card)
		moves_count += 1
		
	_update_ui()

func _on_waste_pressed():
	if game_won or waste.size() == 0: return
	
	# Try auto-moving to Foundation first on double tap/click
	if selected_source == "waste":
		if _try_auto_foundation(waste.back()):
			waste.pop_back()
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
	
	if selected_source == "waste" and waste.size() > 0:
		var card = waste.back()
		if _can_add_to_foundation(card, f_idx):
			foundations[f_idx].append(waste.pop_back())
			selected_source = ""
			moves_count += 1
			_update_ui()
			_check_win()
			return
	elif selected_source.begins_with("tableau_"):
		var col_idx = selected_source.trim_prefix("tableau_").to_int()
		if tableau[col_idx].size() > 0 and selected_card_idx == tableau[col_idx].size() - 1:
			var card = tableau[col_idx].back()
			if _can_add_to_foundation(card, f_idx):
				foundations[f_idx].append(tableau[col_idx].pop_back())
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
	
	# 1. Moving from Waste to this Tableau column
	if selected_source == "waste" and waste.size() > 0:
		var card = waste.back()
		if _can_add_to_tableau(card, col_idx):
			tableau[col_idx].append(waste.pop_back())
			selected_source = ""
			moves_count += 1
			_update_ui()
			return
			
	# 2. Moving from another Tableau column
	elif selected_source.begins_with("tableau_"):
		var src_col = selected_source.trim_prefix("tableau_").to_int()
		if src_col != col_idx and selected_card_idx >= 0 and selected_card_idx < tableau[src_col].size():
			var moving_card = tableau[src_col][selected_card_idx]
			if _can_add_to_tableau(moving_card, col_idx):
				var moving_stack = tableau[src_col].slice(selected_card_idx)
				tableau[src_col] = tableau[src_col].slice(0, selected_card_idx)
				tableau[col_idx].append_array(moving_stack)
				selected_source = ""
				selected_card_idx = -1
				moves_count += 1
				_update_ui()
				return
				
	# 3. Double-tapping the top card to auto-move to Foundation
	if card_idx == tableau[col_idx].size() - 1 and selected_source == ("tableau_" + str(col_idx)):
		var card = tableau[col_idx].back()
		if _try_auto_foundation(card):
			tableau[col_idx].pop_back()
			selected_source = ""
			selected_card_idx = -1
			moves_count += 1
			_update_ui()
			_check_win()
			return
			
	# 4. Selecting card in this column
	if card_idx >= 0 and tableau[col_idx][card_idx]["face_up"]:
		selected_source = "tableau_" + str(col_idx)
		selected_card_idx = card_idx
	else:
		selected_source = "tableau_" + str(col_idx)
		selected_card_idx = -1
	_update_ui()

func _can_add_to_foundation(card: Dictionary, f_idx: int) -> bool:
	if card["suit"] != SUITS[f_idx]:
		return false
	if foundations[f_idx].size() == 0:
		return card["val"] == 1 # Ace
	var top = foundations[f_idx].back()
	return card["val"] == top["val"] + 1

func _try_auto_foundation(card: Dictionary) -> bool:
	for f_idx in range(4):
		if _can_add_to_foundation(card, f_idx):
			foundations[f_idx].append(card)
			return true
	return false

func _can_add_to_tableau(card: Dictionary, col_idx: int) -> bool:
	if tableau[col_idx].size() == 0:
		return card["val"] == 13 # Only King can fill empty column
	var top = tableau[col_idx].back()
	if not top["face_up"]: return false
	return (card["val"] == top["val"] - 1) and (card["color"] != top["color"])

func _check_win():
	var total_foundations = 0
	for f in foundations:
		total_foundations += f.size()
	if total_foundations == 52:
		game_won = true
		status_label.text = "🏆 Parabéns! Você completou a Paciência!"

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
