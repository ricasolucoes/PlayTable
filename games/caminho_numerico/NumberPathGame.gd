class_name NumberPathGame
extends BaseGame

## Controlador principal da cena de Caminho Numérico.
##
## Gerencia a progressão de fases, temporizador de conclusão, pontuação acumulada,
## integração com BaseGame, GameTopBar, PlayerProfile e LeaderboardSync.

@onready var num_board: NumberPathBoard = $UI/VBoxContainer/CenterContainer/NumberPathBoard
@onready var status_lbl: Label = $UI/VBoxContainer/StatusBox/StatusLabel
@onready var substatus_lbl: Label = $UI/VBoxContainer/StatusBox/SubStatusLabel
@onready var btn_restart_node: Button = $UI/VBoxContainer/BottomBar/BtnRestart
@onready var btn_hint_node: Button = $UI/VBoxContainer/BottomBar/BtnHint

var current_level: int = 1
var total_score: int = 0
var level_start_ticks: int = 0
var current_puzzle: Dictionary = {}
var is_transitioning: bool = false


func _ready() -> void:
	status_label = status_lbl
	btn_restart = btn_restart_node

	if btn_restart_node:
		btn_restart_node.pressed.connect(_on_restart_pressed)
	if btn_hint_node:
		btn_hint_node.pressed.connect(_on_btn_hint_pressed)

	if num_board:
		num_board.level_completed.connect(_on_level_completed)
		num_board.mistake_made.connect(_on_mistake_made)
		num_board.path_updated.connect(_on_path_updated)

	_start_new_game()
	begin_match()


func _start_new_game() -> void:
	game_over = false
	is_transitioning = false
	level_start_ticks = Time.get_ticks_msec()

	# Gera puzzle proporcional ao nível
	current_puzzle = NumberPathGenerator.generate_level(current_level)

	if num_board:
		num_board.setup_puzzle(current_puzzle["width"], current_puzzle["height"], current_puzzle)

	_update_header()


func _update_header() -> void:
	if status_lbl:
		status_lbl.text = tr("GAME_DESC_NUMBER_PATH")

	if substatus_lbl:
		var grid_desc := "%dx%d" % [current_puzzle.get("width", 3), current_puzzle.get("height", 3)]
		var clues_num: int = current_puzzle.get("clues_count", 4)
		substatus_lbl.text = "%s %d  •  %s  •  %d %s%s" % [
			tr("LEVEL"),
			current_level,
			grid_desc,
			clues_num,
			tr("NUMBER_PATH_CLUES"),
			difficulty_suffix()
		]

	set_counters([
		{"value": str(current_level), "label": "LEVEL"},
		{"value": str(total_score), "label": "SCORE"},
	])


func _on_path_updated(_path: Array[Vector2i]) -> void:
	if num_board and num_board.model:
		var progress := int(num_board.model.get_progress_ratio() * 100.0)
		var next_info := num_board.model.get_next_clue_info()
		if not next_info.is_empty() and status_lbl and not num_board.model.is_completed:
			status_lbl.text = tr("NUMBER_PATH_CONNECT") % [
				num_board.model.get_current_target() - 1,
				num_board.model.get_current_target()
			]


func _on_mistake_made(_cell: Vector2i) -> void:
	if AudioManager:
		AudioManager.play_click()


func _on_btn_hint_pressed() -> void:
	if game_over or is_transitioning or num_board == null or num_board.model == null:
		return

	var hint_step := num_board.model.get_hint_next_step()
	if hint_step != Vector2i(-1, -1):
		num_board.model.extend_to(hint_step)
	else:
		if status_lbl:
			status_lbl.text = tr("NUMBER_PATH_HINT_BACKTRACK")


func _on_level_completed() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	var elapsed_secs := (Time.get_ticks_msec() - level_start_ticks) / 1000.0
	var mistakes := num_board.model.mistakes_count if num_board.model else 0
	var hints := num_board.model.hints_used if num_board.model else 0

	var score_data := NumberPathScoring.calculate_score(
		current_puzzle.get("width", 3),
		current_puzzle.get("height", 3),
		current_puzzle.get("clues_count", 4),
		elapsed_secs,
		mistakes,
		hints
	)

	total_score += int(score_data["score"])
	score_data["total_score"] = total_score
	score_data["level"] = current_level

	_update_header()

	if status_lbl:
		status_lbl.text = tr("NUMBER_PATH_WIN") + "  +" + str(score_data["score"]) + " pts"

	if AudioManager:
		AudioManager.play_victory()

	# Registra a vitória e pontuação na infraestrutura de gamificação
	finish_game(tr("NUMBER_PATH_WIN"), true, score_data)

	current_level += 1

	# Pequena pausa antes de carregar o próximo nível
	var timer := get_tree().create_timer(1.8)
	timer.timeout.connect(_start_new_game)
