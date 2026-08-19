extends Control

const SIZE = 7

# Board layout: -1 = Invalid cell, 0 = Empty hole, 1 = Peg present
var board = []
var selected_pos = Vector2i(-1, -1)
var valid_targets = [] # Array of Dictionary: {"land": Vector2i, "over": Vector2i}
var move_history = [] # Array of board states for Undo
var game_over = false

@onready var grid = $VBoxContainer/CenterContainer/BoardContainer/Grid
@onready var status_label = $VBoxContainer/StatusLabel
@onready var pegs_label = $VBoxContainer/PegsLabel
@onready var btn_undo = $VBoxContainer/Actions/BtnUndo
@onready var btn_restart = $VBoxContainer/Actions/BtnRestart

var cell_buttons = []

func _ready():
	_setup_grid()
	_start_new_game()

func _is_valid_hole(r: int, c: int) -> bool:
	if r < 0 or r >= SIZE or c < 0 or c >= SIZE:
		return false
	# Cross pattern (corners (0,0), (0,1), (1,0), (1,1), etc are invalid)
	if (r < 2 or r > 4) and (c < 2 or c > 4):
		return false
	return true

func _setup_grid():
	for c in grid.get_children(): c.queue_free()
	cell_buttons.clear()
	
	for r in range(SIZE):
		var row_btns = []
		for c in range(SIZE):
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
	
	board.clear()
	for r in range(SIZE):
		var row = []
		for c in range(SIZE):
			if _is_valid_hole(r, c):
				if r == 3 and c == 3:
					row.append(0) # Center empty
				else:
					row.append(1) # Peg
			else:
				row.append(-1) # Invalid
		board.append(row)
		
	_update_ui()
	status_label.text = "Selecione um pino para saltar!"

func _count_remaining_pegs() -> int:
	var count = 0
	for r in range(SIZE):
		for c in range(SIZE):
			if board[r][c] == 1:
				count += 1
	return count

func _update_ui():
	var pegs_count = _count_remaining_pegs()
	pegs_label.text = "Pinos Restantes: %d / 32" % pegs_count
	btn_undo.disabled = (move_history.size() == 0)
	
	for r in range(SIZE):
		for c in range(SIZE):
			var btn = cell_buttons[r][c]
			var val = board[r][c]
			
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
					btn.self_modulate = Color(0.9, 0.75, 0.2) # Gold
				elif is_target:
					btn.self_modulate = Color(0.3, 0.8, 0.4) # Green highlight
				else:
					btn.self_modulate = Color(0.2, 0.25, 0.3)
					
				if val == 1:
					btn.text = "🔴"
				else:
					btn.text = "⚫" if not is_target else "⭕"

func _on_cell_clicked(r: int, c: int):
	if game_over or not _is_valid_hole(r, c):
		return
		
	var clicked = Vector2i(r, c)
	
	# Check if clicked a valid landing target
	for vt in valid_targets:
		if vt["land"] == clicked:
			_execute_move(selected_pos, vt["over"], vt["land"])
			return
			
	# Check if selecting a peg with valid moves
	if board[r][c] == 1:
		selected_pos = clicked
		valid_targets = _get_valid_moves_for_peg(clicked)
		_update_ui()
		if valid_targets.size() == 0:
			status_label.text = "Este pino não pode saltar."
		else:
			status_label.text = "Escolha a casa de destino."
	else:
		selected_pos = Vector2i(-1, -1)
		valid_targets.clear()
		_update_ui()

func _get_valid_moves_for_peg(pos: Vector2i) -> Array:
	var moves = []
	var directions = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	
	for d in directions:
		var over = pos + d
		var land = pos + (d * 2)
		if _is_valid_hole(over.x, over.y) and _is_valid_hole(land.x, land.y):
			if board[over.x][over.y] == 1 and board[land.x][land.y] == 0:
				moves.append({"over": over, "land": land})
				
	return moves

func _execute_move(from_pos: Vector2i, over_pos: Vector2i, land_pos: Vector2i):
	# Save state for undo
	move_history.append(_clone_board(board))
	
	# Execute
	board[from_pos.x][from_pos.y] = 0
	board[over_pos.x][over_pos.y] = 0
	board[land_pos.x][land_pos.y] = 1
	
	selected_pos = Vector2i(-1, -1)
	valid_targets.clear()
	_update_ui()
	
	_check_game_status()

func _clone_board(src: Array) -> Array:
	var copy = []
	for r in src:
		copy.append(r.duplicate())
	return copy

func _check_game_status():
	var pegs_count = _count_remaining_pegs()
	
	# Check if any peg has any move left
	var total_moves = 0
	for r in range(SIZE):
		for c in range(SIZE):
			if board[r][c] == 1:
				total_moves += _get_valid_moves_for_peg(Vector2i(r, c)).size()
				
	if total_moves == 0:
		game_over = true
		if pegs_count == 1:
			if board[3][3] == 1:
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
	if move_history.size() > 0:
		board = move_history.pop_back()
		selected_pos = Vector2i(-1, -1)
		valid_targets.clear()
		game_over = false
		status_label.text = "Jogada desfeita."
		_update_ui()

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
