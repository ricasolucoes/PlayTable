extends BaseGame

## Memory matching card game implementation.

const CARD_SCRIPT = preload("res://games/memoria/MemoryCard.gd")

var cards: Array[Control] = []
var first_card: Control = null
var second_card: Control = null
var pairs_found: int = 0
const TOTAL_PAIRS: int = MemoryRules.TOTAL_PAIRS
var moves_count: int = 0
var is_checking: bool = false

## Instante em que a partida comecou, para o tempo entrar no resultado. O
## Memoria e um dos jogos que valem placar por desempenho, nao por vitoria:
## todo mundo vence, o que distingue e em quantas jogadas.
var _started_at: float = 0.0

@onready var grid_container: GridContainer = $VBoxContainer/CenterContainer/Grid
@onready var win_modal: ColorRect = $WinModal
@onready var win_modal_title: Label = $WinModal/Panel/VBox/WinTitle
@onready var win_modal_sub: Label = $WinModal/Panel/VBox/WinSub

func _ready() -> void:
	menu_scene_path = MENU_CARTAS
	status_label = $VBoxContainer/StatusCard/StatusLabel
	_start_new_game()

func _start_new_game() -> void:
	pairs_found = 0
	moves_count = 0
	game_over = false
	first_card = null
	second_card = null
	is_checking = false
	win_modal.visible = false
	_started_at = Time.get_ticks_msec() / 1000.0
	begin_match()

	_update_ui()
	_generate_deck()

func _generate_deck() -> void:
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
		var card := Control.new()
		card.set_script(CARD_SCRIPT)
		card.symbol_type = symbol_pool[i]
		card.is_face_up = false
		card.is_matched = false
		card.card_clicked.connect(_on_card_clicked)
		grid_container.add_child(card)
		cards.append(card)

func _on_card_clicked(card: Control) -> void:
	if is_checking or game_over:
		return
	if card == first_card or card.is_matched:
		return
		
	card.flip(true)
	
	if first_card == null:
		first_card = card
		set_status("Escolha a segunda carta...")
	else:
		second_card = card
		moves_count += 1
		_update_ui()
		_check_match()

func _check_match() -> void:
	is_checking = true
	
	if MemoryRules.symbols_match(first_card.symbol_type, second_card.symbol_type):
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
		
		if MemoryRules.is_game_won(pairs_found, TOTAL_PAIRS):
			_handle_game_won()
		else:
			set_status("Par encontrado! Continue assim!")
	else:
		# Mismatch
		set_status("Não foi dessa vez...")
		await get_tree().create_timer(0.4).timeout
		first_card.play_mismatch_shake()
		second_card.play_mismatch_shake()
		
		await get_tree().create_timer(0.6).timeout
		first_card.flip(false)
		second_card.flip(false)
		first_card = null
		second_card = null
		is_checking = false
		set_status("Encontre os pares correspondentes")

func _handle_game_won() -> void:
	game_over = true
	if AudioManager: AudioManager.play_win()

	# O Memoria nunca reportou partida: XP, streak, maestria e a conquista de
	# Memoria Fotografica nao existiam para quem so jogava aqui.
	report_match_result(true, {
		"time": Time.get_ticks_msec() / 1000.0 - _started_at,
		"moves": moves_count,
		"perfect": moves_count <= TOTAL_PAIRS + 2,
	})
	
	win_modal_title.text = "🏆 Parabéns!"
	var rating := "⭐⭐⭐"
	if moves_count > 16: rating = "⭐⭐"
	if moves_count > 24: rating = "⭐"
	
	win_modal_sub.text = "Você encontrou todos os 8 pares em " + str(moves_count) + " jogadas!\nClassificação: " + rating
	
	reveal_result_modal(win_modal)

func _update_ui() -> void:
	set_counters([
		{"value": "%d/%d" % [pairs_found, TOTAL_PAIRS], "label": "pares"},
		{"value": moves_count, "label": "jogadas"},
	])
	if pairs_found == 0 and moves_count == 0:
		set_status("Toque em uma carta para começar")
