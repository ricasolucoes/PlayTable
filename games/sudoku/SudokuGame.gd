class_name SudokuGame
extends BaseGame

const CELL_SCENE := preload("res://games/sudoku/SudokuCell.tscn")

@onready var main_grid = $BoardContainer/MainGrid
@onready var num_pad = $NumberPad
@onready var btn_notes = $VBoxContainer/TopBar/BtnNotes
@onready var status_lbl = $VBoxContainer/StatusCard/StatusVBox/StatusLabel
@onready var level_lbl = $VBoxContainer/StatusCard/StatusVBox/LevelLabel
@onready var win_modal = $WinModal

var cells_2d := [] # 9x9 Array of SudokuCell
var solution_grid := []
var notes_mode := false
var selected_cell: SudokuCell = null

func _ready() -> void:
	status_label = status_lbl
	btn_restart = $VBoxContainer/TopBar/BtnRestart
	
	_setup_board_ui()
	_setup_numpad()
	
	
	_start_new_game()
	begin_match()

func _setup_board_ui() -> void:
	cells_2d.clear()
	for r in range(9):
		var row := []
		for c in range(9):
			row.append(null)
		cells_2d.append(row)
		
	var blocks := []
	for i in range(9):
		var b = GridContainer.new()
		b.columns = 3
		b.add_theme_constant_override("h_separation", 2)
		b.add_theme_constant_override("v_separation", 2)
		main_grid.add_child(b)
		blocks.append(b)
		
	for r in range(9):
		for c in range(9):
			var cell = CELL_SCENE.instantiate() as SudokuCell
			cell.setup(r, c)
			cell.cell_clicked.connect(_on_cell_clicked)
			var block_idx = (r / 3) * 3 + (c / 3)
			blocks[block_idx].add_child(cell)
			cells_2d[r][c] = cell

func _setup_numpad() -> void:
	for i in range(1, 10):
		var btn = Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(72, 72)
		btn.add_theme_font_size_override("font_size", 32)
		btn.pressed.connect(_on_numpad_pressed.bind(i))
		num_pad.add_child(btn)
		
	var btn_clear = Button.new()
	btn_clear.text = "X"
	btn_clear.custom_minimum_size = Vector2(72, 72)
	btn_clear.add_theme_font_size_override("font_size", 32)
	btn_clear.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	btn_clear.pressed.connect(_on_numpad_pressed.bind(0))
	num_pad.add_child(btn_clear)

func _start_new_game() -> void:
	win_modal.hide()
	notes_mode = false
	btn_notes.button_pressed = false
	btn_notes.text = "SUDOKU_NOTES_OFF"
	_select_cell(null)
	game_over = false
	
	# Determina nível atual pelo DifficultyManager se existir
	var level = 1
	if DifficultyManager != null:
		level = DifficultyManager.get_level(game_id)
		level_lbl.text = difficulty_suffix()
		
	var data = SudokuGenerator.generate_board(level)
	var puzzle = data["puzzle"]
	solution_grid = data["solution"]
	
	for r in range(9):
		for c in range(9):
			var cell = cells_2d[r][c]
			var val = puzzle[r][c]
			cell.notes.clear()
			cell.is_fixed = false
			if val != 0:
				cell.set_fixed_value(val)
			else:
				cell.set_user_value(0)
			cell.highlight(false)

	set_status("SUDOKU_PLAYING")

func _on_cell_clicked(r: int, c: int) -> void:
	if game_over:
		return
	var cell = cells_2d[r][c]
	_select_cell(cell)

func _select_cell(cell: SudokuCell) -> void:
	if selected_cell != null:
		selected_cell.highlight(false, _has_conflict(selected_cell.row, selected_cell.col, selected_cell.value))
	selected_cell = cell
	if selected_cell != null:
		selected_cell.highlight(true, _has_conflict(selected_cell.row, selected_cell.col, selected_cell.value))

func _on_btn_notes_toggled(button_pressed: bool) -> void:
	notes_mode = button_pressed
	if notes_mode:
		btn_notes.text = "SUDOKU_NOTES_ON"
	else:
		btn_notes.text = "SUDOKU_NOTES_OFF"

func _on_numpad_pressed(num: int) -> void:
	if game_over or selected_cell == null or selected_cell.is_fixed:
		return
		
	if notes_mode and num != 0:
		selected_cell.toggle_note(num)
	else:
		selected_cell.set_user_value(num)
		_check_conflicts()
		if _check_win():
			_do_win()

func _check_conflicts() -> void:
	for r in range(9):
		for c in range(9):
			var cell = cells_2d[r][c]
			if not cell.is_fixed and cell.value != 0:
				var conflict = _has_conflict(r, c, cell.value)
				cell.highlight(cell == selected_cell, conflict)

func _has_conflict(row: int, col: int, val: int) -> bool:
	if val == 0:
		return false
	for i in range(9):
		if i != col and cells_2d[row][i].value == val: return true
		if i != row and cells_2d[i][col].value == val: return true
		
	var br = (row / 3) * 3
	var bc = (col / 3) * 3
	for r in range(3):
		for c in range(3):
			var rr = br + r
			var cc = bc + c
			if (rr != row or cc != col) and cells_2d[rr][cc].value == val:
				return true
	return false

func _check_win() -> bool:
	for r in range(9):
		for c in range(9):
			if cells_2d[r][c].value != solution_grid[r][c]:
				return false
	return true

func _do_win() -> void:
	_select_cell(null)
	finish_game("SUDOKU_WIN", true)
	reveal_result_modal(win_modal)
