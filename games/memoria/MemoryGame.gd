extends Control

const CardScript = preload("res://shared/core_engine/cards/Card.gd")
const DeckScript = preload("res://shared/core_engine/cards/Deck.gd")
const MemoryRulesScript = preload("res://games/memoria/MemoryRules.gd")

var deck: Deck
var cards_grid: Array[Card] = []
var first_btn: Button = null
var second_btn: Button = null
var first_card: Card = null
var second_card: Card = null

var pairs_found: int = 0
var total_pairs: int = 8
var is_animating: bool = false

@onready var grid = $VBoxContainer/CenterContainer/Grid
@onready var status = $VBoxContainer/Status

func _ready():
	_start_new_game()

func _start_new_game():
	pairs_found = 0
	is_animating = false
	first_btn = null
	second_btn = null
	first_card = null
	second_card = null
	
	for c in grid.get_children(): c.queue_free()
	
	deck = Deck.create_memory_deck()
	deck.shuffle()
	
	cards_grid = deck.cards.duplicate()
	total_pairs = cards_grid.size() / 2
	
	for i in range(cards_grid.size()):
		var card = cards_grid[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 120)
		btn.add_theme_font_size_override("font_size", 48)
		btn.pivot_offset = Vector2(40, 60)
		btn.text = "?"
		btn.pressed.connect(_on_card_pressed.bind(i, btn))
		grid.add_child(btn)
		
	status.text = "Pares: 0/%d" % total_pairs

func _flip_card(btn: Button, target_text: String, tween: Tween):
	tween.tween_property(btn, "scale:x", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): btn.text = target_text)
	tween.tween_property(btn, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_SINE)

func _on_card_pressed(idx: int, btn: Button):
	if is_animating or btn == first_btn or btn.disabled: return
	
	var card = cards_grid[idx]
	var tween = get_tree().create_tween()
	_flip_card(btn, card.get_display_value(), tween)
	
	if first_btn == null:
		first_btn = btn
		first_card = card
	else:
		second_btn = btn
		second_card = card
		is_animating = true
		tween.tween_callback(_check_match).set_delay(0.3)

func _check_match():
	if MemoryRules.is_match(first_card, second_card):
		# Match
		var tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(first_btn, "modulate:a", 0.5, 0.3)
		tween.tween_property(second_btn, "modulate:a", 0.5, 0.3)
		tween.tween_property(first_btn, "scale", Vector2(1.1, 1.1), 0.2)
		tween.tween_property(second_btn, "scale", Vector2(1.1, 1.1), 0.2)
		
		first_btn.disabled = true
		second_btn.disabled = true
		pairs_found += 1
		status.text = "Pares: %d/%d" % [pairs_found, total_pairs]
		
		if MemoryRules.is_game_won(pairs_found, total_pairs):
			status.text = "🏆 Você Venceu! 🏆"
		
		is_animating = false
		first_btn = null
		second_btn = null
		first_card = null
		second_card = null
	else:
		await get_tree().create_timer(0.6).timeout
		var tween = get_tree().create_tween().set_parallel(true)
		
		var t1 = get_tree().create_tween()
		_flip_card(first_btn, "?", t1)
		
		var t2 = get_tree().create_tween()
		_flip_card(second_btn, "?", t2)
		
		await t1.finished
		
		first_btn = null
		second_btn = null
		first_card = null
		second_card = null
		is_animating = false

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
