extends GridGame

## CheckersGame: Damas com Tabuleiro 3D em Nogueira, Peças de Marfim/Obsidiana e Coroas Douradas

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const CheckersRulesScript = preload("res://games/damas/CheckersRules.gd")

var grid_data: Grid2D
var selected_pos: Vector2i = Vector2i(-1, -1)
var valid_moves: Array[Dictionary] = []
var is_player_turn: bool = true
var continuing_capture_pos: Vector2i = Vector2i(-1, -1)
var pieces_3d: Dictionary = {}

@onready var board_3d: Board3D = $Board3D
@onready var pieces_root: Node3D = $PiecesRoot
@onready var score_label = $UI/VBoxContainer/ScoreLabel

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/VBoxContainer/BtnRestart
	env_3d.apply_theme(_build_theme())
	board_3d.setup_board(CheckersRules.ROWS, CheckersRules.COLS, 0.75, "wood_checkered")
	# O tabuleiro se anuncia para a camera: nao existe distancia escrita a mao.
	env_3d.set_safe_area(200.0, 130.0)
	env_3d.frame_content(board_3d.content_size())
	board_3d.cell_clicked.connect(_on_cell_clicked)
	_start_new_game()

## Damas de salao: tabuleiro de bordo e nogueira sobre couro, luz de abajur.
func _build_theme() -> GameTheme3D:
	var theme := GameTheme3D.parlour_walnut()
	theme.surface = &"leather"
	theme.surface_color = Color(0.21, 0.13, 0.10)
	theme.accent = Color(0.95, 0.78, 0.30)
	return theme

func _start_new_game() -> void:
	game_over = false
	is_player_turn = true
	selected_pos = Vector2i(-1, -1)
	continuing_capture_pos = Vector2i(-1, -1)
	valid_moves.clear()
	btn_restart.hide()
	
	grid_data = CheckersRules.create_initial_board()
	_sync_pieces_3d()
	set_status("Sua Vez! (Marfim)")

func _sync_pieces_3d() -> void:
	for p in pieces_root.get_children(): p.queue_free()
	pieces_3d.clear()
	board_3d.clear_states()

	for r in range(CheckersRules.ROWS):
		for c in range(CheckersRules.COLS):
			var val = grid_data.get_cell(r, c)
			if val != 0:
				var piece := preload("res://shared/3d/Token3D.tscn").instantiate()
				piece.token_type = "cylinder"
				piece.token_radius = 0.30
				piece.material_name = "ivory" if val > 0 else "obsidian"
				piece.position = _cell_pos(r, c)
				pieces_root.add_child(piece)
				pieces_3d[Vector2i(r, c)] = piece

				if abs(val) == 2:
					piece.promote_queen()

	_update_score()

## Altura de apoio da peca: o topo da casa, nunca um valor solto.
func _cell_pos(r: int, c: int) -> Vector3:
	return board_3d.get_cell_position_3d(r, c, Tokens3D.TILE_THICKNESS)

func _update_score() -> void:
	var player_count: int = 0
	var ai_count: int = 0
	for r in range(CheckersRules.ROWS):
		for c in range(CheckersRules.COLS):
			var val = grid_data.get_cell(r, c)
			if val > 0: player_count += 1
			elif val < 0: ai_count += 1
	score_label.text = "Você: %d  |  IA: %d" % [player_count, ai_count]

func _on_cell_clicked(r: int, c: int):
	if game_over or not is_player_turn: return
	
	var clicked_pos := Vector2i(r, c)
	
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
		
		_show_selection(clicked_pos)
	else:
		# Tocar fora das proprias pecas desfaz a selecao.
		_clear_selection()
		selected_pos = Vector2i(-1, -1)
		valid_moves.clear()

## Marca a origem, levanta a peca e aponta cada destino possivel. O destaque
## usa tom E anel: quem nao distingue as cores ainda ve a marca.
func _show_selection(origin: Vector2i) -> void:
	board_3d.clear_states()
	board_3d.set_cell_state(origin.x, origin.y, Board3D.CellState.SELECTED)
	var destinations: Array = []
	for vm in valid_moves:
		destinations.append(vm["to"])
	board_3d.set_cells_state(destinations, Board3D.CellState.VALID)

	_lower_all_pieces()
	var piece = pieces_3d.get(origin)
	if piece:
		piece.select(true)

func _clear_selection() -> void:
	board_3d.clear_states()
	_lower_all_pieces()

func _lower_all_pieces() -> void:
	for piece in pieces_3d.values():
		piece.select(false)

func _execute_player_move(from_pos: Vector2i, move_dict: Dictionary):
	var to_pos = move_dict["to"]
	var captured_pos = move_dict["captured"]
	
	var piece_3d = pieces_3d.get(from_pos)
	if piece_3d:
		pieces_3d.erase(from_pos)
		pieces_3d[to_pos] = piece_3d
		piece_3d.select(false)
		piece_3d.jump_to(_cell_pos(to_pos.x, to_pos.y),
			Tokens3D.ARC_LONG if captured_pos != Vector2i(-1, -1) else Tokens3D.ARC_SHORT)
		
	if captured_pos != Vector2i(-1, -1):
		var cap_piece = pieces_3d.get(captured_pos)
		if cap_piece:
			cap_piece.vanish()
			pieces_3d.erase(captured_pos)

	var became_queen := CheckersRules.apply_move(grid_data, from_pos, to_pos, captured_pos)
	if became_queen and piece_3d:
		piece_3d.promote_queen()
		
	for row in range(CheckersRules.ROWS):
		for col in range(CheckersRules.COLS):
			board_3d.reset_cell_material(row, col)
			
	if captured_pos != Vector2i(-1, -1):
		var further_captures := CheckersRules.get_captures_for_piece(grid_data, to_pos)
		if further_captures.size() > 0:
			continuing_capture_pos = to_pos
			selected_pos = to_pos
			valid_moves = further_captures
			board_3d.highlight_cell(to_pos.x, to_pos.y, Color(0.9, 0.75, 0.2))
			for vm in valid_moves:
				board_3d.highlight_cell(vm["to"].x, vm["to"].y, Color(0.2, 0.8, 0.4))
			set_status("Captura múltipla obrigatória!")
			return
			
	continuing_capture_pos = Vector2i(-1, -1)
	selected_pos = Vector2i(-1, -1)
	valid_moves.clear()
	
	_check_game_end_or_ai_turn()

func _check_game_end_or_ai_turn():
	_update_score()
	var winner := CheckersRules.check_game_over(grid_data)
	if winner != 0:
		_end_game(winner)
		return
		
	is_player_turn = false
	set_status("Vez da IA (Obsidiana)...")
	await get_tree().create_timer(0.6).timeout
	
	_play_ai_turn()

func _play_ai_turn():
	var ai_move := CheckersRules.get_best_ai_move(grid_data)
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
		piece_3d.select(false)
		piece_3d.jump_to(_cell_pos(to_pos.x, to_pos.y),
			Tokens3D.ARC_LONG if captured_pos != Vector2i(-1, -1) else Tokens3D.ARC_SHORT)
		
	if captured_pos != Vector2i(-1, -1):
		var cap_piece = pieces_3d.get(captured_pos)
		if cap_piece:
			cap_piece.vanish()
			pieces_3d.erase(captured_pos)

	var became_queen := CheckersRules.apply_move(grid_data, from_pos, to_pos, captured_pos)
	if became_queen and piece_3d:
		piece_3d.promote_queen()
		
	# Capturas sucessivas da IA
	if captured_pos != Vector2i(-1, -1):
		var further := CheckersRules.get_captures_for_piece(grid_data, to_pos)
		while further.size() > 0:
			await get_tree().create_timer(0.4).timeout
			var next_m := further[0]
			var next_to = next_m["to"]
			var next_cap = next_m["captured"]
			
			pieces_3d.erase(to_pos)
			pieces_3d[next_to] = piece_3d
			piece_3d.jump_to(_cell_pos(next_to.x, next_to.y), Tokens3D.ARC_LONG)
			
			var next_cap_piece = pieces_3d.get(next_cap)
			if next_cap_piece:
				next_cap_piece.vanish()
				pieces_3d.erase(next_cap)
				
			CheckersRules.apply_move(grid_data, to_pos, next_to, next_cap)
			to_pos = next_to
			further = CheckersRules.get_captures_for_piece(grid_data, to_pos)
			
	_update_score()
	board_3d.set_cells_state([from_pos, to_pos], Board3D.CellState.LAST_MOVE)
	var winner := CheckersRules.check_game_over(grid_data)
	if winner != 0:
		_end_game(winner)
		return

	is_player_turn = true
	set_status("Sua Vez! (Marfim)")

func _end_game(winner: int) -> void:
	if winner == 1:
		finish_game("🏆 Você Venceu!", true)
	else:
		finish_game("IA Venceu!")
