extends BaseGame

## Memory matching card game implementation.

const CARD_SCRIPT = preload("res://games/memoria/MemoryCard.gd")

var cards: Array[Control] = []
var first_card: Control = null
var second_card: Control = null
var pairs_found: int = 0
var TOTAL_PAIRS: int = MemoryRules.TOTAL_PAIRS
var difficulty_level: int = DifficultyManager.DEFAULT_LEVEL
var moves_count: int = 0
var is_checking: bool = false
var is_local_multiplayer: bool = false
var current_player: int = 1
var player_one_pairs: int = 0
var player_two_pairs: int = 0

const GRID_GAP := 16.0
const CARD_ASPECT := 1.25
const HORIZONTAL_MARGIN := 48.0
const VERTICAL_RESERVE := 300.0

## Instante em que a partida comecou, para o tempo entrar no resultado. No modo
## solo o placar mede desempenho; no local, os pares viram pontos de cada lado.
var _started_at: float = 0.0

@onready var grid_container: GridContainer = $VBoxContainer/ScrollContainer/CenterContainer/Grid
@onready var win_modal: ColorRect = $WinModal
@onready var win_modal_title: Label = $WinModal/Panel/VBox/WinTitle
@onready var win_modal_sub: Label = $WinModal/Panel/VBox/WinSub
@onready var btn_mode_toggle: Button = $VBoxContainer/TopBar/BtnModeToggle

func _ready() -> void:
	menu_scene_path = MENU_CARTAS
	status_label = $VBoxContainer/StatusCard/StatusLabel
	btn_mode_toggle.pressed.connect(_on_mode_toggle_pressed)
	_update_mode_button()
	_start_new_game()

func _start_new_game() -> void:
	pairs_found = 0
	moves_count = 0
	current_player = 1
	player_one_pairs = 0
	player_two_pairs = 0
	game_over = false
	first_card = null
	second_card = null
	is_checking = false
	win_modal.visible = false
	_started_at = Time.get_ticks_msec() / 1000.0
	begin_match("versus" if is_local_multiplayer else "solo")

	_update_ui()
	_generate_deck()

func _generate_deck() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	cards.clear()

	difficulty_level = DifficultyManager.get_level(game_id) if DifficultyManager else DifficultyManager.DEFAULT_LEVEL
	var board_size := MemoryRules.board_size_for_level(difficulty_level)
	TOTAL_PAIRS = MemoryRules.total_pairs_for_level(difficulty_level)
	grid_container.columns = board_size.x
	var card_size := _card_size_for_board(board_size)
	var symbol_pool := MemoryRules.symbol_pool_for_pairs(TOTAL_PAIRS)
	symbol_pool.shuffle()
	
	for symbol in symbol_pool:
		var card := Control.new()
		card.set_script(CARD_SCRIPT)
		card.symbol_type = symbol
		card.is_face_up = false
		card.is_matched = false
		card.card_clicked.connect(_on_card_clicked)
		grid_container.add_child(card)
		card.call("set_card_size", card_size)
		cards.append(card)


func _card_size_for_board(board_size: Vector2i) -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width", 720),
			ProjectSettings.get_setting("display/window/size/viewport_height", 1280))

	var available_width := maxf(viewport_size.x - HORIZONTAL_MARGIN, 240.0)
	var available_height := maxf(viewport_size.y - VERTICAL_RESERVE, 320.0)
	var width_by_columns := (available_width - GRID_GAP * float(board_size.x - 1)) / float(board_size.x)
	var height_by_rows := (available_height - GRID_GAP * float(board_size.y - 1)) / float(board_size.y)
	var card_width := minf(width_by_columns, height_by_rows / CARD_ASPECT)
	card_width = maxf(card_width, 48.0)
	return Vector2(floor(card_width), floor(card_width * CARD_ASPECT))

func _on_card_clicked(card: Control) -> void:
	if is_checking or game_over:
		return
	if card == first_card or card.is_matched:
		return
		
	card.flip(true)
	
	if first_card == null:
		first_card = card
		set_status(tr("MEMORY_PLAYER_SECOND_CARD") % current_player if is_local_multiplayer else tr("MEMORY_SECOND_CARD"))
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
		if is_local_multiplayer:
			if current_player == 1:
				player_one_pairs += 1
			else:
				player_two_pairs += 1
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
			set_status(tr("MEMORY_PLAYER_PAIR_FOUND") % current_player if is_local_multiplayer else tr("MEMORY_PAIR_FOUND"))
	else:
		# Mismatch
		set_status(tr("MEMORY_NO_PAIR"))
		await get_tree().create_timer(0.4).timeout
		first_card.play_mismatch_shake()
		second_card.play_mismatch_shake()
		
		await get_tree().create_timer(0.6).timeout
		first_card.flip(false)
		second_card.flip(false)
		first_card = null
		second_card = null
		is_checking = false
		if is_local_multiplayer:
			current_player = 3 - current_player
			_update_ui()
			set_status(tr("MEMORY_PLAYER_TURN") % current_player)
		else:
			set_status(tr("MEMORY_FIND_PAIRS"))

func _handle_game_won() -> void:
	game_over = true
	if AudioManager: AudioManager.play_win()
	var winner := 1 if not is_local_multiplayer else MemoryRules.winner_for_scores(player_one_pairs, player_two_pairs)
	var is_draw := is_local_multiplayer and winner == 0

	# O Memoria nunca reportou partida: XP, streak, maestria e a conquista de
	# Memoria Fotografica nao existiam para quem so jogava aqui.
	report_match_result(not is_draw and winner == 1, {
		"time": Time.get_ticks_msec() / 1000.0 - _started_at,
		"moves": moves_count,
		"perfect": moves_count <= TOTAL_PAIRS + 2,
		"winner": winner,
		"draw": is_draw,
		"mode": "versus" if is_local_multiplayer else "solo",
	})

	if is_local_multiplayer:
		if is_draw:
			win_modal_title.text = tr("MEMORY_LOCAL_DRAW_TITLE")
		else:
			win_modal_title.text = tr("MEMORY_LOCAL_WIN_TITLE") % winner
		win_modal_sub.text = tr("MEMORY_LOCAL_WIN_DESC") % [player_one_pairs, player_two_pairs, moves_count]
	else:
		win_modal_title.text = tr("RESULT_CONGRATS")
		var rating := "⭐⭐⭐"
		if moves_count > TOTAL_PAIRS + 8: rating = "⭐⭐"
		if moves_count > TOTAL_PAIRS + 16: rating = "⭐"
		win_modal_sub.text = tr("MEMORY_WIN_DESC") % [TOTAL_PAIRS, moves_count, rating]
	
	reveal_result_modal(win_modal)

func _update_ui() -> void:
	set_counters([
		{"value": "%d/%d" % [pairs_found, TOTAL_PAIRS], "label": "SCORE_PAIRS"},
		{"value": moves_count, "label": "SCORE_PLAYS"},
	])
	if is_local_multiplayer:
		set_duel_score(player_one_pairs, player_two_pairs, "SCORE_PLAYER_1", "SCORE_PLAYER_2")
		set_active_side(current_player == 1)
	if pairs_found == 0 and moves_count == 0:
		var start_status := tr("MEMORY_LOCAL_START") if is_local_multiplayer else tr("MEMORY_START")
		set_status(start_status + difficulty_suffix())


func _on_mode_toggle_pressed() -> void:
	play_click()
	is_local_multiplayer = not is_local_multiplayer
	_update_mode_button()
	restart_game()


func _update_mode_button() -> void:
	if btn_mode_toggle:
		btn_mode_toggle.text = tr("MEMORY_BTN_SOLO") if is_local_multiplayer else tr("MEMORY_BTN_TWO_PLAYERS")
