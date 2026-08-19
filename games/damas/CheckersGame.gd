extends Control

## CheckersGame: Damas com Tabuleiro 3D em Nogueira, Peças de Marfim/Obsidiana e Coroas Douradas

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const CheckersRulesScript = preload("res://games/damas/CheckersRules.gd")

var grid_data: Grid2D
var selected_pos: Vector2i = Vector2i(-1, -1)
var valid_moves: Array[Dictionary] = []
var is_player_turn: bool = true
var game_over: bool = false
var continuing_capture_pos: Vector2i = Vector2i(-1, -1)
var pieces_3d: Dictionary = {}

@onready var env_3d: TabletopEnvironment3D = $TabletopEnvironment3D
@onready var board_3d: Board3D = $Board3D
@onready var pieces_root: Node3D = $PiecesRoot
@onready var status_label = $UI/VBoxContainer/StatusLabel
@onready var score_label = $UI/VBoxContainer/ScoreLabel
@onready var btn_restart = $UI/VBoxContainer/BtnRestart
@onready var touch_grid = $UI/CenterContainer/TouchGrid

func _ready() -> void:
	board_3d.setup_board(CheckersRules.ROWS, CheckersRules.COLS, 0.75, "wood_checkered")
	_setup_touch_grid()
	_start_new_game()

func _setup_touch_grid() -> void:
	for c in touch_grid.get_children(): c.queue_free()
	for r in range(CheckersRules.ROWS):
		for c in range(CheckersRules.COLS):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(40, 40)
			btn.flat = true
			btn.pressed.connect(_on_cell_clicked.bind(r, c))
			touch_grid.add_child(btn)

func _start_new_game() -> void:
	game_over = false
	is_player_turn = true
	selected_pos = Vector2i(-1, -1)
	continuing_capture_pos = Vector2i(-1, -1)
	valid_moves.clear()
	btn_restart.hide()
	
	grid_data = CheckersRules.create_initial_board()
	_sync_pieces_3d()
	status_label.text = "Sua Vez! (Marfim)"

func _sync_pieces_3d() -> void:
	for p in pieces_root.get_children(): p.queue_free()
	pieces_3d.clear()
	
	var player_count: int = 0
	var ai_count: int = 0
	for r in range(CheckersRules.ROWS):
		for c in range(CheckersRules.COLS):
			board_3d.reset_cell_material(r, c)
			var val = grid_data.get_cell(r, c)
			if val != 0:
				var piece = preload("res://shared/3d/Token3D.tscn").instantiate()
				piece.token_type = "cylinder"
				piece.material_name = "ivory" if val > 0 else "obsidian"
				piece.position = board_3d.get_cell_position_3d(r, c, 0.08)
				pieces_root.add_child(piece)
				pieces_3d[Vector2i(r, c)] = piece
				
				if abs(val) == 2:
					piece.promote_queen()
					
				if val > 0: player_count += 1
				else: ai_count += 1
				
	score_label.text = "Você: %d  |  IA: %d" % [player_count, ai_count]

func _on_cell_clicked(r: int, c: int):
	if game_over or not is_player_turn: return
	
	var clicked_pos = Vector2i(r, c)
	
	for vm in valid_moves:
		if vm["to"] == clicked_pos:
			_execute_player_move(selected_pos, vm)
			return
			
	if continuing_capture_pos != Vector2i(-1, -1):
		return
		
	var val = grid_data.get_cell(r, c)
	if val > 0: # Peça do jogador
		selected_pos = clicked_pos
		valid_moves = CheckersRules.get_valid_moves_for_piece(grid_data, selected_pos)
		
		# Limpa destaques anteriores e destaca destinos válidos
		for row in range(CheckersRules.ROWS):
			for col in range(CheckersRules.COLS):
				board_3d.reset_cell_material(row, col)
		board_3d.highlight_cell(r, c, Color(0.9, 0.75, 0.2))
		for vm in valid_moves:
			board_3d.highlight_cell(vm["to"].x, vm["to"].y, Color(0.2, 0.8, 0.4))
	else:
		selected_pos = Vector2i(-1, -1)
		valid_moves.clear()
		for row in range(CheckersRules.ROWS):
			for col in range(CheckersRules.COLS):
				board_3d.reset_cell_material(row, col)

func _execute_player_move(from_pos: Vector2i, move_dict: Dictionary):
	var to_pos = move_dict["to"]
	var captured_pos = move_dict["captured"]
	
	var piece_3d = pieces_3d.get(from_pos)
	if piece_3d:
		pieces_3d.erase(from_pos)
		pieces_3d[to_pos] = piece_3d
		var target_3d = board_3d.get_cell_position_3d(to_pos.x, to_pos.y, 0.08)
		piece_3d.jump_to(target_3d, 0.5, 0.3)
		
	if captured_pos != Vector2i(-1, -1):
		var cap_piece = pieces_3d.get(captured_pos)
		if cap_piece:
			cap_piece.queue_free()
			pieces_3d.erase(captured_pos)
			
	var became_queen = CheckersRules.apply_move(grid_data, from_pos, to_pos, captured_pos)
	if became_queen and piece_3d:
		piece_3d.promote_queen()
		
	for row in range(CheckersRules.ROWS):
		for col in range(CheckersRules.COLS):
			board_3d.reset_cell_material(row, col)
			
	if captured_pos != Vector2i(-1, -1):
		var further_captures = CheckersRules.get_captures_for_piece(grid_data, to_pos)
		if further_captures.size() > 0:
			continuing_capture_pos = to_pos
			selected_pos = to_pos
			valid_moves = further_captures
			board_3d.highlight_cell(to_pos.x, to_pos.y, Color(0.9, 0.75, 0.2))
			for vm in valid_moves:
				board_3d.highlight_cell(vm["to"].x, vm["to"].y, Color(0.2, 0.8, 0.4))
			status_label.text = "Captura múltipla obrigatória!"
			return
			
	continuing_capture_pos = Vector2i(-1, -1)
	selected_pos = Vector2i(-1, -1)
	valid_moves.clear()
	
	_check_game_end_or_ai_turn()

func _check_game_end_or_ai_turn():
	_sync_pieces_3d()
	var winner = CheckersRules.check_game_over(grid_data)
	if winner != 0:
		_end_game(winner)
		return
		
	is_player_turn = false
	status_label.text = "Vez da IA (Obsidiana)..."
	await get_tree().create_timer(0.6).timeout
	
	_play_ai_turn()

func _play_ai_turn():
	var ai_move = CheckersRules.get_best_ai_move(grid_data)
	if ai_move.is_empty():
		_end_game(1)
		return
		
	var from_pos = ai_move["from"]
	var to_pos = ai_move["to"]
	var captured_pos = ai_move["captured"]
	
	var piece_3d = pieces_3d.get(from_pos)
	if piece_3d:
		pieces_3d.erase(from_pos)
		pieces_3d[to_pos] = piece_3d
		var target_3d = board_3d.get_cell_position_3d(to_pos.x, to_pos.y, 0.08)
		piece_3d.jump_to(target_3d, 0.5, 0.3)
		
	if captured_pos != Vector2i(-1, -1):
		var cap_piece = pieces_3d.get(captured_pos)
		if cap_piece:
			cap_piece.queue_free()
			pieces_3d.erase(captured_pos)
			
	var became_queen = CheckersRules.apply_move(grid_data, from_pos, to_pos, captured_pos)
	if became_queen and piece_3d:
		piece_3d.promote_queen()
		
	# Capturas sucessivas da IA
	if captured_pos != Vector2i(-1, -1):
		var further = CheckersRules.get_captures_for_piece(grid_data, to_pos)
		while further.size() > 0:
			await get_tree().create_timer(0.4).timeout
			var next_m = further[0]
			var next_to = next_m["to"]
			var next_cap = next_m["captured"]
			
			pieces_3d.erase(to_pos)
			pieces_3d[next_to] = piece_3d
			var next_target_3d = board_3d.get_cell_position_3d(next_to.x, next_to.y, 0.08)
			piece_3d.jump_to(next_target_3d, 0.5, 0.3)
			
			var next_cap_piece = pieces_3d.get(next_cap)
			if next_cap_piece:
				next_cap_piece.queue_free()
				pieces_3d.erase(next_cap)
				
			CheckersRules.apply_move(grid_data, to_pos, next_to, next_cap)
			to_pos = next_to
			further = CheckersRules.get_captures_for_piece(grid_data, to_pos)
			
	_sync_pieces_3d()
	var winner = CheckersRules.check_game_over(grid_data)
	if winner != 0:
		_end_game(winner)
		return
		
	is_player_turn = true
	status_label.text = "Sua Vez! (Marfim)"

func _end_game(winner: int) -> void:
	game_over = true
	btn_restart.show()
	if winner == 1:
		status_label.text = "🏆 Você Venceu!"
		env_3d.celebrate_win()
	else:
		status_label.text = "IA Venceu!"

func _on_btn_restart_pressed() -> void:
	_start_new_game()

func _on_btn_back_pressed() -> void:
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
