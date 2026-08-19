extends Control

const CARD_SCRIPT = preload("res://games/memoria/MemoryCard.gd")

var cards: Array[Control] = []
var first_card: Control = null
var second_card: Control = null
var pairs_found: int = 0
const TOTAL_PAIRS: int = 8
var moves_count: int = 0
var is_checking: bool = false
var game_over: bool = false

@onready var grid_container = $VBoxContainer/CenterContainer/Grid
@onready var pairs_label = $VBoxContainer/ScoreBoard/PairsPanel/HBox/Value
@onready var moves_label = $VBoxContainer/ScoreBoard/MovesPanel/HBox/Value
@onready var status_label = $VBoxContainer/StatusCard/StatusLabel
@onready var win_modal = $WinModal
@onready var win_modal_title = $WinModal/Panel/VBox/WinTitle
@onready var win_modal_sub = $WinModal/Panel/VBox/WinSub

func _ready():
	_start_new_game()

func _start_new_game():
	pairs_found = 0
	moves_count = 0
	game_over = false
	first_card = null
	second_card = null
	is_checking = false
	win_modal.visible = false
	
	_update_ui()
	_generate_deck()

func _generate_deck():
	for child in grid_container.get_children():
		child.queue_free()
	cards.clear()
	
	# 8 pairs = 16 cards
	var symbol_pool = [
		0, 0, # CROWN
		1, 1, # RUBY
		2, 2, # EMERALD
		3, 3, # SHIELD
		4, 4, # STAR
		5, 5, # CHEST
		6, 6, # CLOVER
		7, 7  # KEY
	]
	symbol_pool.shuffle()
	
	for i in range(16):
		var card = Control.new()
		card.set_script(CARD_SCRIPT)
		card.symbol_type = symbol_pool[i]
		card.is_face_up = false
		card.is_matched = false
		card.card_clicked.connect(_on_card_clicked)
		grid_container.add_child(card)
		cards.append(card)

func _on_card_clicked(card: Control):
	if is_checking or game_over:
		return
	if card == first_card or card.is_matched:
		return
		
	card.flip(true)
	
	if first_card == null:
		first_card = card
		status_label.text = "Escolha a segunda carta..."
	else:
		second_card = card
		moves_count += 1
		_update_ui()
		_check_match()

func _check_match():
	is_checking = true
	
	if first_card.symbol_type == second_card.symbol_type:
		# Match found!
		pairs_found += 1
		_update_ui()
		
		await get_tree().create_timer(0.2).timeout
		if AudioManager: AudioManager.play_card_match()
		first_card.play_match_animation()
		second_card.play_match_animation()
		
		first_card = null
		second_card = null
		is_checking = false
		
		if pairs_found == TOTAL_PAIRS:
			_handle_game_won()
		else:
			status_label.text = "Par encontrado! Continue assim!"
	else:
		# Mismatch
		status_label.text = "Não foi dessa vez..."
		await get_tree().create_timer(0.4).timeout
		first_card.play_mismatch_shake()
		second_card.play_mismatch_shake()
		
		await get_tree().create_timer(0.6).timeout
		first_card.flip(false)
		second_card.flip(false)
		first_card = null
		second_card = null
		is_checking = false
		status_label.text = "Encontre os pares correspondentes"

func _handle_game_won():
	game_over = true
	if AudioManager: AudioManager.play_win()
	
	win_modal_title.text = "🏆 Parabéns!"
	var rating = "⭐⭐⭐"
	if moves_count > 16: rating = "⭐⭐"
	if moves_count > 24: rating = "⭐"
	
	win_modal_sub.text = "Você encontrou todos os 8 pares em " + str(moves_count) + " jogadas!\nClassificação: " + rating
	
	await get_tree().create_timer(0.6).timeout
	win_modal.visible = true
	win_modal.modulate.a = 0.0
	var tw = get_tree().create_tween()
	tw.tween_property(win_modal, "modulate:a", 1.0, 0.3)

func _update_ui():
	pairs_label.text = str(pairs_found) + " / " + str(TOTAL_PAIRS)
	moves_label.text = str(moves_count)
	if pairs_found == 0 and moves_count == 0:
		status_label.text = "Toque em uma carta para começar"

func _on_restart_pressed():
	if AudioManager: AudioManager.play_click()
	_start_new_game()

func _on_back_pressed():
	if AudioManager: AudioManager.play_click()
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
