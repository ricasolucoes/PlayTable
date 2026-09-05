class_name NumberPathGame
extends BaseGame

## Controlador principal da cena de Caminho Numérico.
##
## Gerencia o ciclo de vida do jogo, progressão de fases (1 a 30+), temporizador
## decrescente com Game Over por timeout, monitoramento de estrelas obrigatórias,
## pontuação com bônus de velocidade/estrelas e integração com BaseGame e GameShell.

const Generator := preload("res://games/caminho_numerico/NumberPathGenerator.gd")
const Scoring := preload("res://games/caminho_numerico/NumberPathScoring.gd")
const Model := preload("res://games/caminho_numerico/NumberPathModel.gd")

@onready var game_shell: GameShell = $GameShell
@onready var num_board: NumberPathBoard = $UI/VBoxContainer/CenterContainer/NumberPathBoard
@onready var status_lbl: Label = game_shell.status_label
@onready var substatus_lbl: Label = game_shell.level_label
@onready var btn_restart_node: Button = game_shell.btn_restart
@onready var btn_hint_node: Button = $UI/VBoxContainer/BottomBar/BtnHint

var current_level: int = 1
var total_score: int = 0
var level_start_ticks: int = 0
var current_puzzle: Dictionary = {}
var is_transitioning: bool = false
var _transition_tween: Tween = null

# Temporizador decrescente e contagem de tempo
var time_limit: float = 0.0
var time_elapsed: float = 0.0
var time_remaining: float = 0.0
var is_timer_running: bool = false


func _ready() -> void:
	status_label = status_lbl
	btn_restart = btn_restart_node
	set_process(true)

	game_shell.restart_requested.connect(_on_restart_pressed)
	if btn_hint_node:
		btn_hint_node.pressed.connect(_on_btn_hint_pressed)

	if num_board:
		num_board.level_completed.connect(_on_level_completed)
		num_board.mistake_made.connect(_on_mistake_made)
		num_board.path_updated.connect(_on_path_updated)

	_start_new_game()


func _exit_tree() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
		_transition_tween = null
	is_timer_running = false


func _process(delta: float) -> void:
	if not is_timer_running or game_over or is_transitioning:
		return

	time_elapsed += delta

	if time_limit > 0.0:
		time_remaining = maxf(0.0, time_limit - time_elapsed)
		if time_remaining <= 0.0:
			time_remaining = 0.0
			is_timer_running = false
			_on_time_out()
			return

	_update_header()


func _start_new_game() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
		_transition_tween = null

	game_over = false
	is_transitioning = false
	_result_reported = false
	level_start_ticks = Time.get_ticks_msec()
	time_elapsed = 0.0

	if top_bar != null:
		top_bar.mark_win(false)

	begin_match()

	# Gera quebra-cabeça proporcional ao nível atual
	current_puzzle = Generator.generate_level(current_level)
	time_limit = float(current_puzzle.get("time_limit", 0.0))
	time_remaining = time_limit
	is_timer_running = true

	if num_board:
		var pw: int = int(current_puzzle.get("width", 3))
		var ph: int = int(current_puzzle.get("height", 3))
		num_board.setup_puzzle(pw, ph, current_puzzle)
		_connect_board_model_signals()

	if game_shell:
		game_shell.hide_restart()

	_update_header()


func _connect_board_model_signals() -> void:
	if num_board == null or num_board.model == null:
		return
	var m: NumberPathModel = num_board.model
	if not m.star_collected.is_connected(_on_model_star_collected):
		m.star_collected.connect(_on_model_star_collected)
	if not m.portal_used.is_connected(_on_model_portal_used):
		m.portal_used.connect(_on_model_portal_used)
	if not m.clue_reached.is_connected(_on_model_clue_reached):
		m.clue_reached.connect(_on_model_clue_reached)


func _update_header() -> void:
	if status_lbl and not game_over and not is_transitioning:
		if num_board and num_board.model:
			var m: NumberPathModel = num_board.model
			if not m.is_completed:
				var next_info: Dictionary = m.get_next_clue_info()
				if not next_info.is_empty():
					status_lbl.text = tr("NUMBER_PATH_CONNECT") % [
						m.get_current_target() - 1,
						m.get_current_target()
					]
				elif not m.stars.is_empty() and m.visited_stars.size() < m.stars.size():
					var rem_stars: int = m.stars.size() - m.visited_stars.size()
					status_lbl.text = tr("NUMBER_PATH_STARS_REMAINING") % rem_stars
				else:
					status_lbl.text = tr("GAME_DESC_NUMBER_PATH")

	if substatus_lbl:
		var grid_desc: String = "%dx%d" % [int(current_puzzle.get("width", 3)), int(current_puzzle.get("height", 3))]
		var clues_num: int = int(current_puzzle.get("clues_count", 4))
		var sub_text: String = "%s %d  •  %s  •  %d %s%s" % [
			tr("LEVEL"),
			current_level,
			grid_desc,
			clues_num,
			tr("NUMBER_PATH_CLUES"),
			difficulty_suffix()
		]
		substatus_lbl.text = sub_text

	# Atualização de contadores na TopBar
	var counters: Array = [
		{"value": str(current_level), "label": "LEVEL"},
		{"value": str(total_score), "label": "SCORE_POINTS"},
	]

	if time_limit > 0.0:
		var time_display: String = Scoring.format_time(time_remaining)
		counters.append({"value": time_display, "label": "NUMBER_PATH_TIME_LIMIT"})
	else:
		counters.append({"value": Scoring.format_time(time_elapsed), "label": "TIME"})

	if num_board and num_board.model and not num_board.model.stars.is_empty():
		var stars_str: String = "%d/%d" % [num_board.model.visited_stars.size(), num_board.model.stars.size()]
		counters.append({"value": stars_str, "label": "NUMBER_PATH_STAR"})

	set_counters(counters)


func _get_audio_manager() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/AudioManager")


func _on_path_updated(_path: Array[Vector2i]) -> void:
	_update_header()


func _on_model_clue_reached(_cell: Vector2i, _num: int) -> void:
	var am = _get_audio_manager()
	if am and am.has_method("play_piece_place"):
		am.play_piece_place()


func _on_model_star_collected(_cell: Vector2i, _remaining: int) -> void:
	var am = _get_audio_manager()
	if am and am.has_method("play_card_match"):
		am.play_card_match()
	_update_header()


func _on_model_portal_used(_from_cell: Vector2i, _to_cell: Vector2i) -> void:
	var am = _get_audio_manager()
	if am and am.has_method("play_card_flip"):
		am.play_card_flip()


func _on_mistake_made(_cell: Vector2i) -> void:
	var am = _get_audio_manager()
	if am and am.has_method("play_click"):
		am.play_click()


func _on_time_out() -> void:
	game_over = true
	is_timer_running = false

	var am = _get_audio_manager()
	if am and am.has_method("play_draw"):
		am.play_draw()

	if status_lbl:
		status_lbl.text = tr("NUMBER_PATH_TIMEOUT")

	if game_shell:
		game_shell.show_restart()

	var extra_data: Dictionary = {
		"timeout": true,
		"level": current_level,
		"time": time_elapsed,
		"score": 0,
	}

	finish_game(tr("NUMBER_PATH_TIMEOUT"), false, extra_data)


func _on_btn_hint_pressed() -> void:
	if game_over or is_transitioning or num_board == null or num_board.model == null:
		return

	var am = _get_audio_manager()
	if am and am.has_method("play_click"):
		am.play_click()

	var hint_step: Vector2i = num_board.model.get_hint_next_step()
	if hint_step != Vector2i(-1, -1):
		num_board.model.extend_to(hint_step)
	else:
		if status_lbl:
			status_lbl.text = tr("NUMBER_PATH_HINT_BACKTRACK")


func _on_level_completed() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	is_timer_running = false

	var elapsed_secs: float = time_elapsed
	var mistakes: int = num_board.model.mistakes_count if num_board.model else 0
	var hints: int = num_board.model.hints_used if num_board.model else 0
	var stars_count: int = num_board.model.visited_stars.size() if num_board.model else 0

	var score_data: Dictionary = Scoring.calculate_score(
		int(current_puzzle.get("width", 3)),
		int(current_puzzle.get("height", 3)),
		int(current_puzzle.get("clues_count", 4)),
		elapsed_secs,
		mistakes,
		hints,
		stars_count,
		time_limit
	)

	total_score += int(score_data["score"])
	score_data["total_score"] = total_score
	score_data["level"] = current_level

	_update_header()

	if status_lbl:
		status_lbl.text = tr("NUMBER_PATH_WIN") + "  +" + str(score_data["score"]) + " pts"

	var am = _get_audio_manager()
	if am and am.has_method("play_win"):
		am.play_win()

	# Registra vitória e pontuação na infraestrutura de gamificação
	finish_game(tr("NUMBER_PATH_WIN"), true, score_data)

	current_level += 1

	# Pausa antes de carregar o próximo nível
	if is_inside_tree():
		if _transition_tween and _transition_tween.is_valid():
			_transition_tween.kill()
		_transition_tween = create_tween()
		_transition_tween.tween_interval(1.8)
		_transition_tween.tween_callback(_on_transition_finished)


func _on_transition_finished() -> void:
	if not is_inside_tree() or not is_transitioning:
		return
	_start_new_game()
