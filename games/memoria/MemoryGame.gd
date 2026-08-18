extends Control

var deck = []
var first_card: Button = null
var second_card: Button = null
var pairs_found = 0
var total_pairs = 8
var is_animating = false

@onready var grid = $VBoxContainer/CenterContainer/Grid
@onready var status = $VBoxContainer/Status

func _ready():
	var values = ["A", "A", "B", "B", "C", "C", "D", "D", "E", "E", "F", "F", "G", "G", "H", "H"]
	values.shuffle()
	
	for i in range(16):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 120)
		btn.add_theme_font_size_override("font_size", 48)
		btn.text = "?"
		btn.set_meta("val", values[i])
		btn.pressed.connect(_on_card_pressed.bind(btn))
		grid.add_child(btn)

func _on_card_pressed(btn: Button):
	if is_animating or btn == first_card or btn.disabled: return
	
	btn.text = btn.get_meta("val")
	
	if first_card == null:
		first_card = btn
	else:
		second_card = btn
		_check_match()

func _check_match():
	is_animating = true
	if first_card.get_meta("val") == second_card.get_meta("val"):
		first_card.disabled = true
		second_card.disabled = true
		pairs_found += 1
		status.text = "Pares: " + str(pairs_found) + "/" + str(total_pairs)
		if pairs_found == total_pairs:
			status.text = "Você Venceu!"
		is_animating = false
		first_card = null
		second_card = null
	else:
		await get_tree().create_timer(1.0).timeout
		first_card.text = "?"
		second_card.text = "?"
		first_card = null
		second_card = null
		is_animating = false

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
