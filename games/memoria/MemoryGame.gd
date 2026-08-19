extends Control

var deck = []
var first_card: Button = null
var second_card: Button = null
var pairs_found = 0
var total_pairs = 8
var total_moves = 0
var is_animating = false

@onready var grid = $VBoxContainer/CenterContainer/Grid
@onready var status = $VBoxContainer/Status
@onready var moves_label = $VBoxContainer/MovesLabel
@onready var btn_restart = $VBoxContainer/BtnRestart

func _ready():
	_start_new_game()

func _start_new_game():
	pairs_found = 0
	total_moves = 0
	first_card = null
	second_card = null
	is_animating = false
	btn_restart.hide()
	
	moves_label.text = "Jogadas: 0"
	status.text = "Encontre os Pares!"
	
	for c in grid.get_children(): c.queue_free()
	
	var emojis = ["🚀", "🦄", "🍕", "🎸", "💎", "🍄", "⭐", "🐱"]
	var values = []
	for e in emojis:
		values.append(e)
		values.append(e)
	values.shuffle()
	
	for i in range(16):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(90, 130)
		btn.add_theme_font_size_override("font_size", 48)
		btn.pivot_offset = Vector2(45, 65)
		btn.text = "❓"
		btn.set_meta("val", values[i])
		btn.pressed.connect(_on_card_pressed.bind(btn))
		grid.add_child(btn)

func _flip_card(btn: Button, target_text: String, tween: Tween):
	tween.tween_property(btn, "scale:x", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): btn.text = target_text)
	tween.tween_property(btn, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_SINE)

func _on_card_pressed(btn: Button):
	if is_animating or btn == first_card or btn.disabled: return
	
	var tween = get_tree().create_tween()
	_flip_card(btn, btn.get_meta("val"), tween)
	
	if first_card == null:
		first_card = btn
	else:
		second_card = btn
		is_animating = true
		total_moves += 1
		moves_label.text = "Jogadas: %d" % total_moves
		tween.tween_callback(_check_match).set_delay(0.3)

func _check_match():
	if first_card.get_meta("val") == second_card.get_meta("val"):
		var tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(first_card, "modulate:a", 0.5, 0.3)
		tween.tween_property(second_card, "modulate:a", 0.5, 0.3)
		tween.tween_property(first_card, "scale", Vector2(1.1, 1.1), 0.2)
		tween.tween_property(second_card, "scale", Vector2(1.1, 1.1), 0.2)
		
		first_card.disabled = true
		second_card.disabled = true
		pairs_found += 1
		status.text = "Pares: %d / %d" % [pairs_found, total_pairs]
		
		if pairs_found == total_pairs:
			status.text = "🏆 Vitória! Completou em %d jogadas! 🏆" % total_moves
			btn_restart.show()
		
		is_animating = false
		first_card = null
		second_card = null
	else:
		await get_tree().create_timer(0.6).timeout
		var t1 = get_tree().create_tween()
		_flip_card(first_card, "❓", t1)
		var t2 = get_tree().create_tween()
		_flip_card(second_card, "❓", t2)
		await t1.finished
		
		first_card = null
		second_card = null
		is_animating = false

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
