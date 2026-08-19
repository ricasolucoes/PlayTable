extends Control

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const MinesweeperRulesScript = preload("res://games/campo_minado/MinesweeperRules.gd")

var grid_data: Grid2D
var first_click: bool = true
var is_flag_mode: bool = false
var game_over: bool = false
var game_won: bool = false
var elapsed_time: float = 0.0
var timer_active: bool = false

@onready var grid_container = $VBoxContainer/CenterContainer/BoardContainer/Grid
@onready var status_label = $VBoxContainer/Header/StatusLabel
@onready var mines_label = $VBoxContainer/Header/MinesLabel
@onready var timer_label = $VBoxContainer/Header/TimerLabel
@onready var btn_mode = $VBoxContainer/Controls/BtnMode
@onready var btn_smiley = $VBoxContainer/Header/BtnSmiley

var cell_buttons = []

func _ready():
	_setup_grid_ui()
	_start_new_game()

func _process(delta: float):
	if timer_active and not game_over and not game_won:
		elapsed_time += delta
		timer_label.text = "⏱️ %03d" % int(elapsed_time)

func _setup_grid_ui():
	for c in grid_container.get_children(): c.queue_free()
	cell_buttons.clear()
	
	for r in range(MinesweeperRules.ROWS):
		var row_btns = []
		for c in range(MinesweeperRules.COLS):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(60, 60)
			btn.add_theme_font_size_override("font_size", 24)
			btn.pressed.connect(_on_cell_clicked.bind(r, c))
			grid_container.add_child(btn)
			row_btns.append(btn)
		cell_buttons.append(row_btns)

func _start_new_game():
	first_click = true
	game_over = false
	game_won = false
	elapsed_time = 0.0
	timer_active = false
	timer_label.text = "⏱️ 000"
	btn_smiley.text = "🙂"
	status_label.text = "Toque em uma casa para começar!"
	
	grid_data = MinesweeperRules.create_empty_grid()
	_update_ui()

func _on_cell_clicked(r: int, c: int):
	if game_over or game_won: return
	
	var cell = grid_data.get_cell(r, c)
	
	if is_flag_mode:
		if not cell["is_revealed"]:
			cell["is_flagged"] = not cell["is_flagged"]
			_update_ui()
			_check_win_condition()
		return
		
	if cell["is_flagged"]: return
	
	if first_click:
		first_click = false
		MinesweeperRules.generate_mines(grid_data, r, c)
		timer_active = true
		status_label.text = "Campo ativo!"
		
	if cell["is_mine"]:
		_trigger_game_over(r, c)
		return
		
	MinesweeperRules.reveal_cell(grid_data, r, c)
	_update_ui()
	_check_win_condition()

func _update_ui():
	var flag_count = 0
	
	for r in range(MinesweeperRules.ROWS):
		for c in range(MinesweeperRules.COLS):
			var btn = cell_buttons[r][c]
			var cell = grid_data.get_cell(r, c)
			
			if cell["is_flagged"]:
				flag_count += 1
				btn.text = "🚩"
				btn.self_modulate = Color(0.3, 0.4, 0.5)
			elif cell["is_revealed"]:
				btn.self_modulate = Color(0.18, 0.22, 0.28)
				if cell["is_mine"]:
					btn.text = "💣"
				elif cell["adjacent_mines"] > 0:
					btn.text = str(cell["adjacent_mines"])
					btn.add_theme_color_override("font_color", _get_number_color(cell["adjacent_mines"]))
				else:
					btn.text = ""
			else:
				btn.text = ""
				btn.self_modulate = Color(0.35, 0.4, 0.48)
				
	mines_label.text = "💣 Minas: %d" % (MinesweeperRules.MINES_COUNT - flag_count)

func _get_number_color(num: int) -> Color:
	match num:
		1: return Color(0.2, 0.6, 1.0)
		2: return Color(0.3, 0.8, 0.3)
		3: return Color(0.9, 0.2, 0.2)
		4: return Color(0.6, 0.2, 0.8)
		5: return Color(0.9, 0.5, 0.1)
		6: return Color(0.1, 0.8, 0.8)
		7: return Color(0.1, 0.1, 0.1)
		8: return Color(0.6, 0.6, 0.6)
		_: return Color.WHITE

func _trigger_game_over(hit_r: int, hit_c: int):
	game_over = true
	timer_active = false
	btn_smiley.text = "😵"
	status_label.text = "💥 Você acertou uma mina! Fim de Jogo."
	
	for r in range(MinesweeperRules.ROWS):
		for c in range(MinesweeperRules.COLS):
			if grid_data.get_cell(r, c)["is_mine"]:
				grid_data.get_cell(r, c)["is_revealed"] = true
				
	_update_ui()
	cell_buttons[hit_r][hit_c].text = "💥"
	cell_buttons[hit_r][hit_c].self_modulate = Color(0.9, 0.2, 0.2)

func _check_win_condition():
	if game_over or game_won or first_click: return
	
	if MinesweeperRules.check_win(grid_data):
		game_won = true
		timer_active = false
		btn_smiley.text = "😎"
		status_label.text = "🏆 Parabéns! Você limpou todas as minas!"
		for r in range(MinesweeperRules.ROWS):
			for c in range(MinesweeperRules.COLS):
				if grid_data.get_cell(r, c)["is_mine"]:
					grid_data.get_cell(r, c)["is_flagged"] = true
		_update_ui()

func _on_btn_mode_pressed():
	is_flag_mode = not is_flag_mode
	if is_flag_mode:
		btn_mode.text = "Modo: 🚩 Bandeira"
		btn_mode.self_modulate = Color(0.9, 0.4, 0.4)
	else:
		btn_mode.text = "Modo: 🔍 Revelar"
		btn_mode.self_modulate = Color(0.3, 0.7, 0.9)

func _on_btn_smiley_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
