extends Control

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const PegSolitaireRulesScript = preload("res://games/solitario/PegSolitaireRules.gd")

var grid_data: Grid2D
var selected_pos: Vector2i = Vector2i(-1, -1)
var valid_targets: Array[Dictionary] = []
var move_history: Array[Grid2D] = []
var game_over: bool = false

@onready var grid = $VBoxContainer/CenterContainer/BoardContainer/Grid
@onready var status_label = $VBoxContainer/StatusLabel
@onready var pegs_label = $VBoxContainer/PegsLabel
@onready var btn_undo = $VBoxContainer/Actions/BtnUndo
@onready var btn_restart = $VBoxContainer/Actions/BtnRestart

var cell_buttons = []

func _ready():
	_setup_grid()
	_start_new_game()

func _setup_grid():
	for c in grid.get_children(): c.queue_free()
	cell_buttons.clear()
	
	for r in range(PegSolitaireRules.SIZE):
		var row_btns = []
		for c in range(PegSolitaireRules.SIZE):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(65, 65)
			btn.add_theme_font_size_override("font_size", 28)
			btn.pivot_offset = Vector2(32, 32)
			btn.pressed.connect(_on_cell_clicked.bind(r, c))
			grid.add_child(btn)
			row_btns.append(btn)
		cell_buttons.append(row_btns)

func _start_new_game():
	game_over = false
	selected_pos = Vector2i(-1, -1)
	valid_targets.clear()
	move_history.clear()
	
	grid_data = PegSolitaireRules.create_initial_board()
	_update_ui()
	status_label.text = "Selecione um pino para saltar!"

func _update_ui():
	var pegs_count = PegSolitaireRules.count_pegs(grid_data)
	pegs_label.text = "Pinos Restantes: %d / 32" % pegs_count
	btn_undo.disabled = (move_history.size() == 0)
	
	for r in range(PegSolitaireRules.SIZE):
		for c in range(PegSolitaireRules.SIZE):
			var btn = cell_buttons[r][c]
			var val = grid_data.get_cell(r, c)
			
			if val == -1:
				btn.text = ""
				btn.disabled = true
				btn.flat = true
				btn.self_modulate = Color(0, 0, 0, 0)
			else:
				btn.disabled = false
				btn.flat = false
				var is_selected = (selected_pos == Vector2i(r, c))
				var is_target = false
				for vt in valid_targets:
					if vt["land"] == Vector2i(r, c):
						is_target = true
						break
						
				if is_selected:
					btn.self_modulate = Color(0.9, 0.75, 0.2)
				elif is_target:
					btn.self_modulate = Color(0.3, 0.8, 0.4)
				else:
					btn.self_modulate = Color(0.2, 0.25, 0.3)
					
				if val == 1:
					btn.text = "🔴"
				else:
					btn.text = "⚫" if not is_target else "⭕"

func _on_cell_clicked(r: int, c: int):
	if game_over or not PegSolitaireRules.is_valid_hole(r, c): return
	
	var clicked = Vector2i(r, c)
	
	for vt in valid_targets:
		if vt["land"] == clicked:
			_execute_move(selected_pos, vt["over"], vt["land"])
			return
			
	if grid_data.get_cell(r, c) == 1:
		selected_pos = clicked
		valid_targets = PegSolitaireRules.get_valid_moves_for_peg(grid_data, clicked)
		_update_ui()
		if valid_targets.is_empty():
			status_label.text = "Este pino não pode saltar."
		else:
			status_label.text = "Escolha a casa de destino."
	else:
		selected_pos = Vector2i(-1, -1)
		valid_targets.clear()
		_update_ui()

func _execute_move(from_pos: Vector2i, over_pos: Vector2i, land_pos: Vector2i):
	move_history.append(grid_data.clone())
	PegSolitaireRules.execute_jump(grid_data, from_pos, over_pos, land_pos)
	
	selected_pos = Vector2i(-1, -1)
	valid_targets.clear()
	_update_ui()
	_check_game_status()

func _check_game_status():
	var pegs_count = PegSolitaireRules.count_pegs(grid_data)
	var total_moves = PegSolitaireRules.count_total_moves(grid_data)
	
	if total_moves == 0:
		game_over = true
		if pegs_count == 1:
			if grid_data.get_cell(3, 3) == 1:
				status_label.text = "🏆 Incrível! Vitória Perfeita (1 pino no centro)!"
			else:
				status_label.text = "🏆 Parabéns! Você venceu (1 pino restante)!"
		elif pegs_count == 2:
			status_label.text = "🥈 Excelente! Restaram apenas 2 pinos!"
		elif pegs_count <= 4:
			status_label.text = "🥉 Muito Bom! Restaram %d pinos." % pegs_count
		else:
			status_label.text = "Fim de jogo! Restaram %d pinos." % pegs_count

func _on_btn_undo_pressed():
	if not move_history.is_empty():
		grid_data = move_history.pop_back()
		selected_pos = Vector2i(-1, -1)
		valid_targets.clear()
		game_over = false
		status_label.text = "Jogada desfeita."
		_update_ui()

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
