extends Control

const ROWS = 9
const COLS = 9
const MINES_COUNT = 10

# Cell states:
# is_mine: bool
# is_revealed: bool
# is_flagged: bool
# adjacent_mines: int

var grid_data = []
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
	
	for r in range(ROWS):
		var row_btns = []
		for c in range(COLS):
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
	
	grid_data.clear()
	for r in range(ROWS):
		var row = []
		for c in range(COLS):
			row.append({
				"is_mine": false,
				"is_revealed": false,
				"is_flagged": false,
				"adjacent_mines": 0
			})
		grid_data.append(row)
		
	_update_ui()

func _generate_mines(safe_r: int, safe_c: int):
	var placed = 0
	while placed < MINES_COUNT:
		var r = randi() % ROWS
		var c = randi() % COLS
		# Don't place on first clicked cell or its immediate neighbors
		if abs(r - safe_r) <= 1 and abs(c - safe_c) <= 1:
			continue
		if not grid_data[r][c]["is_mine"]:
			grid_data[r][c]["is_mine"] = true
			placed += 1
			
	# Calculate adjacent mines
	for r in range(ROWS):
		for c in range(COLS):
			if grid_data[r][c]["is_mine"]:
				continue
			var count = 0
			for dr in [-1, 0, 1]:
				for dc in [-1, 0, 1]:
					var nr = r + dr
					var nc = c + dc
					if nr >= 0 and nr < ROWS and nc >= 0 and nc < COLS:
						if grid_data[nr][nc]["is_mine"]:
							count += 1
			grid_data[r][c]["adjacent_mines"] = count

func _on_cell_clicked(r: int, c: int):
	if game_over or game_won: return
	
	var cell = grid_data[r][c]
	
	if is_flag_mode:
		if not cell["is_revealed"]:
			cell["is_flagged"] = not cell["is_flagged"]
			_update_ui()
			_check_win_condition()
		return
		
	# Reveal mode
	if cell["is_flagged"]:
		return
		
	if first_click:
		first_click = false
		_generate_mines(r, c)
		timer_active = true
		status_label.text = "Campo ativo!"
		
	if cell["is_mine"]:
		_trigger_game_over(r, c)
		return
		
	_reveal_cell(r, c)
	_update_ui()
	_check_win_condition()

func _reveal_cell(r: int, c: int):
	if r < 0 or r >= ROWS or c < 0 or c >= COLS: return
	var cell = grid_data[r][c]
	if cell["is_revealed"] or cell["is_flagged"] or cell["is_mine"]: return
	
	cell["is_revealed"] = true
	
	if cell["adjacent_mines"] == 0:
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				if dr != 0 or dc != 0:
					_reveal_cell(r + dr, c + dc)

func _update_ui():
	var flag_count = 0
	
	for r in range(ROWS):
		for c in range(COLS):
			var btn = cell_buttons[r][c]
			var cell = grid_data[r][c]
			
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
				
	mines_label.text = "💣 Minas: %d" % (MINES_COUNT - flag_count)

func _get_number_color(num: int) -> Color:
	match num:
		1: return Color(0.2, 0.6, 1.0) # Blue
		2: return Color(0.3, 0.8, 0.3) # Green
		3: return Color(0.9, 0.2, 0.2) # Red
		4: return Color(0.6, 0.2, 0.8) # Purple
		5: return Color(0.9, 0.5, 0.1) # Orange
		6: return Color(0.1, 0.8, 0.8) # Cyan
		7: return Color(0.1, 0.1, 0.1) # Black
		8: return Color(0.6, 0.6, 0.6) # Gray
		_: return Color.WHITE

func _trigger_game_over(hit_r: int, hit_c: int):
	game_over = true
	timer_active = false
	btn_smiley.text = "😵"
	status_label.text = "💥 Você acertou uma mina! Fim de Jogo."
	
	# Reveal all mines
	for r in range(ROWS):
		for c in range(COLS):
			if grid_data[r][c]["is_mine"]:
				grid_data[r][c]["is_revealed"] = true
				
	_update_ui()
	cell_buttons[hit_r][hit_c].text = "💥"
	cell_buttons[hit_r][hit_c].self_modulate = Color(0.9, 0.2, 0.2)

func _check_win_condition():
	if game_over or game_won: return
	
	var unrevealed_safe = 0
	for r in range(ROWS):
		for c in range(COLS):
			var cell = grid_data[r][c]
			if not cell["is_mine"] and not cell["is_revealed"]:
				unrevealed_safe += 1
				
	if unrevealed_safe == 0 and not first_click:
		game_won = true
		timer_active = false
		btn_smiley.text = "😎"
		status_label.text = "🏆 Parabéns! Você limpou todas as minas!"
		for r in range(ROWS):
			for c in range(COLS):
				if grid_data[r][c]["is_mine"]:
					grid_data[r][c]["is_flagged"] = true
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
