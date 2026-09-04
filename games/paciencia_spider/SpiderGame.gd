extends BaseGame

## Paciência Spider: dois baralhos, dez colunas e oito sequências para fechar.
##
## A mesa é deliberadamente controlada por botões grandes: no celular, tocar em
## uma coluna seleciona a maior sequência válida no fim dela e tocar no destino
## move o bloco. Assim o jogo continua confortável em retrato, sem depender de
## arrastar cartas 3D pequenas.

const SUITS := [Card.Suit.HEARTS, Card.Suit.DIAMONDS, Card.Suit.CLUBS, Card.Suit.SPADES]
const SUIT_SYMBOLS := ["♥", "♦", "♣", "♠"]
const SUIT_COUNTS := [1, 2, 3, 4]
const TABLEAU_COUNT := 10
const COMPLETE_RUNS := 8
const CARDS_PER_DEAL := 10
const DAILY_DATE_KEY := "spider_daily_date"
const DAILY_WON_KEY := "spider_daily_won"
const DAILY_CROWNS_KEY := "spider_daily_crowns"
const DAILY_STREAK_KEY := "spider_daily_streak"
const DAILY_LAST_WIN_KEY := "spider_daily_last_win"
const TROPHIES_KEY := "spider_trophies"
const SUIT_MODE_KEY := "spider_suit_mode"

var stock: CardPile
var tableau: Array[CardPile] = []
var completed_runs := 0
var moves_count := 0
var stock_deals := 0
var invalid_attempts := 0
var selected_col := -1
var selected_start := -1
var history: Array[Dictionary] = []
var current_suit_count := 4
var daily_mode := false
var daily_date := ""

@onready var cards_root: Node3D = $CardsRoot
@onready var shell = $UI/GameShell
@onready var mode_option: OptionButton = $UI/VBoxContainer/Controls/ModeOption
@onready var btn_daily: Button = $UI/VBoxContainer/Controls/BtnDaily
@onready var btn_undo: Button = $UI/VBoxContainer/Controls/BtnUndo
@onready var btn_hint: Button = $UI/VBoxContainer/Controls/BtnHint
@onready var stock_button: Button = $UI/VBoxContainer/StockRow/BtnStock
@onready var progress: Label = $UI/VBoxContainer/StockRow/Progress
@onready var tableau_buttons: Array[Button] = [
	$UI/Tableau/Col0, $UI/Tableau/Col1, $UI/Tableau/Col2, $UI/Tableau/Col3, $UI/Tableau/Col4,
	$UI/Tableau/Col5, $UI/Tableau/Col6, $UI/Tableau/Col7, $UI/Tableau/Col8, $UI/Tableau/Col9,
]

const CARD_SCENE = preload("res://shared/3d/Card3D.tscn")
const STOCK_POS := Vector3(-3.65, 0.05, -2.0)
const TABLEAU_START_X := -3.65
const TABLEAU_SPACING_X := 0.81
const TABLEAU_START_Z := -0.55
const TABLEAU_CASCADE_Z := 0.17


func _ready() -> void:
	menu_scene_path = MENU_CARTAS
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	shell.restart_requested.connect(restart_game)
	env_3d = $TabletopEnvironment3D
	env_3d.set_felt_color(Color(0.2, 0.05, 0.05))
	fit_table(Vector2(9.5, 6.0))
	for col in range(TABLEAU_COUNT):
		tableau_buttons[col].pressed.connect(_on_tableau_pressed.bind(col))
		tableau.append(CardPile.new())
	stock = CardPile.new()
	btn_daily.pressed.connect(_on_daily_pressed)
	btn_undo.pressed.connect(_on_undo_pressed)
	btn_hint.pressed.connect(_on_hint_pressed)
	stock_button.pressed.connect(_on_stock_pressed)
	# O seletor nascia vazio: as quatro opcoes existem em SUIT_COUNTS e as quatro
	# traducoes existem no CSV, mas ninguem as punha no popup. `select()` sobre
	# uma lista vazia estoura, e o erro derrubava toda montagem da cena.
	mode_option.clear()
	for n in SUIT_COUNTS:
		mode_option.add_item(tr("SPIDER_SUITS_%d" % n))
	mode_option.item_selected.connect(_on_mode_selected)
	_start_new_game()




func _table_content_size() -> Vector2:
	var width := TABLEAU_SPACING_X * 9.0 + Tokens3D.CARD_WIDTH + 0.5
	var back := STOCK_POS.z - Tokens3D.CARD_LENGTH * 0.5
	var front := TABLEAU_START_Z + TABLEAU_CASCADE_Z * 11.0 + Tokens3D.CARD_LENGTH * 0.5
	return Vector2(width, front - back + 0.4)


func _start_new_game() -> void:
	completed_runs = 0
	moves_count = 0
	stock_deals = 0
	invalid_attempts = 0
	shell.timer.reset()
	shell.timer.start()
	game_over = false
	selected_col = -1
	selected_start = -1
	history.clear()
	if btn_restart:
		btn_restart.hide()

	var deck := _build_deck()
	stock.clear()
	for pile in tableau:
		pile.clear()
	if daily_mode:
		_shuffle_seeded(deck, hash("%s:%d" % [daily_date, current_suit_count]))
	else:
		deck.shuffle()

	for col in range(TABLEAU_COUNT):
		var amount := 6 if col < 4 else 5
		for row in range(amount):
			var card := deck.draw()
			card.is_face_up = row == amount - 1
			tableau[col].push(card)
	while not deck.is_empty():
		var card := deck.draw()
		card.is_face_up = false
		stock.push(card)
	_sync_3d_table()
	_update_ui()
	begin_match("solo")
	set_status(tr("SPIDER_DAILY_STARTED") % current_suit_count if daily_mode else tr("SPIDER_START"))


func _build_deck() -> Deck:
	var deck := Deck.new()
	var copies_base := 8 / current_suit_count
	var remainder := 8 - copies_base * current_suit_count
	for suit_index in range(current_suit_count):
		var copies := copies_base + (1 if suit_index < remainder else 0)
		for copy in range(copies):
			for value in range(1, 14):
				var suit: Card.Suit = SUITS[suit_index]
				deck.add_card(Card.new(value, suit, Card.ColorType.NONE, "standard", {
					"id_suffix": "spider_%d_%d" % [suit_index, copy]
				}))
	return deck


func _shuffle_seeded(deck: Deck, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(deck.cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: Card = deck.cards[i]
		deck.cards[i] = deck.cards[j]
		deck.cards[j] = temp


func _sync_3d_table() -> void:
	for child in cards_root.get_children():
		child.queue_free()
	for i in range(stock.size()):
		var view = CARD_SCENE.instantiate()
		view.setup("A", "♠", false)
		view.position = STOCK_POS + Vector3(0, i * 0.002, 0)
		cards_root.add_child(view)
	for col in range(TABLEAU_COUNT):
		for row in range(tableau[col].size()):
			var card := tableau[col].get_card(row)
			var view = CARD_SCENE.instantiate()
			view.setup(card.get_display_value(), card.get_suit_symbol(), card.is_face_up)
			view.position = Vector3(TABLEAU_START_X + col * TABLEAU_SPACING_X,
				0.05 + row * 0.005, TABLEAU_START_Z + row * TABLEAU_CASCADE_Z)
			cards_root.add_child(view)


func _update_ui() -> void:
	set_counters([
		{"value": moves_count, "label": "SCORE_MOVES"}
	])
	stock_button.text = tr("SPIDER_STOCK") % stock.size()
	stock_button.disabled = stock.size() < CARDS_PER_DEAL or not SpiderRules.can_deal_stock(tableau)
	btn_undo.disabled = history.is_empty()
	btn_daily.text = tr("SPIDER_EXIT_DAILY") if daily_mode else tr("SPIDER_DAILY")
	progress.text = tr("SPIDER_PROGRESS") % [completed_runs, COMPLETE_RUNS, 0, 0, 0]
	mode_option.select(SUIT_COUNTS.find(current_suit_count))
	for col in range(TABLEAU_COUNT):
		var pile := tableau[col]
		var text := tr("SPIDER_COL_EMPTY") % (col + 1)
		if not pile.is_empty():
			var top := pile.peek()
			text = tr("SPIDER_COL_CARD") % [col + 1, top.get_short_name()]
		if col == selected_col:
			text = "✓ " + text
		tableau_buttons[col].text = text


func _on_mode_selected(index: int) -> void:
	if index < 0 or index >= SUIT_COUNTS.size() or daily_mode:
		return
	current_suit_count = SUIT_COUNTS[index]
	_start_new_game()


func _on_daily_pressed() -> void:
	play_click()
	if daily_mode:
		daily_mode = false
		current_suit_count = 4
	else:
		daily_mode = true
		daily_date = Time.get_date_string_from_system()
		current_suit_count = 1 + (absi(hash(daily_date)) % 4)
	_start_new_game()


func _on_tableau_pressed(col: int) -> void:
	if game_over:
		return
	if selected_col == -1:
		var start := SpiderRules.movable_start(tableau[col])
		if start == -1:
			invalid_attempts += 1
			set_status(tr("SPIDER_NO_SEQUENCE"))
			return
		selected_col = col
		selected_start = start
		var count := tableau[col].size() - start
		set_status(tr("SPIDER_SELECTED") % [count, col + 1])
		_update_ui()
		return
	if selected_col == col:
		selected_col = -1
		selected_start = -1
		set_status(tr("SPIDER_UNSELECTED"))
		_update_ui()
		return
	var moving: Array = tableau[selected_col].get_all().slice(selected_start)
	if not SpiderRules.can_place_sequence_on_tableau(moving, tableau[col]):
		invalid_attempts += 1
		set_status(tr("SPIDER_BAD_MOVE"))
		return
	_push_history()
	var source := tableau[selected_col]
	var cards := source.slice_from(selected_start)
	if not source.is_empty():
		source.peek().is_face_up = true
	tableau[col].push_many(cards)
	moves_count += 1
	selected_col = -1
	selected_start = -1
	_remove_completed_runs()
	_sync_3d_table()
	_update_ui()
	set_status(tr("SPIDER_MOVED"))
	_check_win()


func _on_stock_pressed() -> void:
	if game_over:
		return
	if stock.size() < CARDS_PER_DEAL:
		set_status(tr("SPIDER_NO_STOCK"))
		return
	if not SpiderRules.can_deal_stock(tableau):
		invalid_attempts += 1
		set_status(tr("SPIDER_NO_EMPTY_DEAL"))
		return
	_push_history()
	for col in range(TABLEAU_COUNT):
		var card := stock.pop()
		card.is_face_up = true
		tableau[col].push(card)
	stock_deals += 1
	moves_count += 1
	_remove_completed_runs()
	_sync_3d_table()
	_update_ui()
	set_status(tr("SPIDER_DEALT"))
	_check_win()


func _on_undo_pressed() -> void:
	if history.is_empty() or game_over:
		return
	var state: Dictionary = history.pop_back()
	_restore(state)
	game_over = false
	selected_col = -1
	selected_start = -1
	_sync_3d_table()
	_update_ui()
	set_status(tr("SPIDER_UNDO"))


func _on_hint_pressed() -> void:
	for source in range(TABLEAU_COUNT):
		var start := SpiderRules.movable_start(tableau[source])
		if start == -1:
			continue
		var moving: Array = tableau[source].get_all().slice(start)
		for target in range(TABLEAU_COUNT):
			if source != target and SpiderRules.can_place_sequence_on_tableau(moving, tableau[target]):
				set_status(tr("SPIDER_HINT_MOVE") % [source + 1, target + 1])
				return
	if stock.size() >= CARDS_PER_DEAL and SpiderRules.can_deal_stock(tableau):
		set_status(tr("SPIDER_HINT_DEAL"))
	else:
		set_status(tr("SPIDER_HINT_NONE"))


func _remove_completed_runs() -> void:
	var removed := true
	while removed:
		removed = false
		for pile in tableau:
			if pile.size() < 13:
				continue
			var run: Array = pile.get_all().slice(pile.size() - 13)
			if SpiderRules.is_complete_run(run):
				pile.slice_from(pile.size() - 13)
				if not pile.is_empty():
					pile.peek().is_face_up = true
				completed_runs += 1
				removed = true
				break


func _check_win() -> void:
	if completed_runs < COMPLETE_RUNS:
		return
	shell.timer.stop()
	var score := maxi(0, 1200 - moves_count * 3 + completed_runs * 75)
	var extra := {
		"score": score,
		"moves": moves_count,
		"time": shell.timer.get_time(),
		"perfect": invalid_attempts == 0,
		"flags": ["spider_win"] + (["spider_daily_win"] if daily_mode else []),
	}
	finish_game(tr("SPIDER_WIN"), true, extra)


func _push_history() -> void:
	history.append(_snapshot())
	if history.size() > 100:
		history.pop_front()


func _snapshot() -> Dictionary:
	var state := {
		"stock": stock.to_dict(),
		"tableau": [],
		"completed_runs": completed_runs,
		"moves_count": moves_count,
		"stock_deals": stock_deals,
		"elapsed_seconds": shell.timer.get_time(),
	}
	for pile in tableau:
		state["tableau"].append(pile.to_dict())
	return state


func _restore(state: Dictionary) -> void:
	stock = CardPile.from_dict(state.get("stock", {}))
	tableau.clear()
	for pile_data in state.get("tableau", []):
		tableau.append(CardPile.from_dict(pile_data))
	completed_runs = int(state.get("completed_runs", 0))
	moves_count = int(state.get("moves_count", 0))
	stock_deals = int(state.get("stock_deals", 0))
	shell.timer.elapsed_time = float(state.get("elapsed_seconds", 0.0))


