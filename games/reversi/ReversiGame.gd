extends GridGame

## ReversiGame: Reversi 3D com Tabuleiro em Feltro Esmeralda e Animação 3D de Virada de Discos

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const ReversiRulesScript = preload("res://games/reversi/ReversiRules.gd")

var grid_data: Grid2D
var is_player_turn: bool = true
var pieces_3d: Dictionary = {}

@onready var board_3d: Board3D = $Board3D
@onready var pieces_root: Node3D = $PiecesRoot
@onready var score_label = $UI/VBoxContainer/ScoreLabel

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/VBoxContainer/BtnRestart
	board_3d.setup_board(8, 8, 0.75, "reversi_green")
	build_touch_grid($UI/CenterContainer/TouchGrid, 8, 8, Vector2(40, 40), _on_cell_clicked)
	_start_new_game()

func _start_new_game() -> void:
	game_over = false
	is_player_turn = true
	btn_restart.hide()
	
	grid_data = ReversiRules.create_initial_board()
	_sync_pieces_3d()
	set_status("Sua Vez! (Pretas / Obsidiana)")

func _sync_pieces_3d() -> void:
	for p in pieces_root.get_children(): p.queue_free()
	pieces_3d.clear()
	
	var black_count: int = 0
	var white_count: int = 0
	for r in range(8):
		for c in range(8):
			board_3d.reset_cell_material(r, c)
			var val = grid_data.get_cell(r, c)
			if val != 0:
				var piece = preload("res://shared/3d/Token3D.tscn").instantiate()
				piece.token_type = "cylinder"
				piece.material_name = "obsidian" if val == 1 else "ivory"
				piece.position = board_3d.get_cell_position_3d(r, c, 0.08)
				pieces_root.add_child(piece)
				pieces_3d[Vector2i(r, c)] = piece
				
				if val == 1: black_count += 1
				else: white_count += 1
				
	score_label.text = "Você (Pretas): %d  |  IA (Brancas): %d" % [black_count, white_count]
	_highlight_valid_moves()

func _highlight_valid_moves() -> void:
	for r in range(8):
		for c in range(8):
			board_3d.reset_cell_material(r, c)
			
	if is_player_turn and not game_over:
		var valids = ReversiRules.get_valid_moves(grid_data, 1)
		for pos in valids:
			board_3d.highlight_cell(pos.x, pos.y, Color(0.2, 0.8, 0.4))

func _on_cell_clicked(r: int, c: int) -> void:
	if game_over or not is_player_turn: return
	
	var pos = Vector2i(r, c)
	var flipped = ReversiRules.get_flipped_pieces(grid_data, pos, 1)
	if flipped.size() == 0: return
	
	# Jogada do jogador
	grid_data.set_cell(r, c, 1)
	for f in flipped:
		grid_data.set_cell(f.x, f.y, 1)
		var p_3d = pieces_3d.get(f)
		if p_3d:
			p_3d.flip_180("obsidian", 0.35)
			
	var new_piece = preload("res://shared/3d/Token3D.tscn").instantiate()
	new_piece.token_type = "cylinder"
	new_piece.material_name = "obsidian"
	var target_3d = board_3d.get_cell_position_3d(r, c, 0.08)
	new_piece.position = target_3d + Vector3(0, 2.5, 0)
	pieces_root.add_child(new_piece)
	pieces_3d[pos] = new_piece
	new_piece.drop_to(target_3d, 0.35)
	
	_update_scores()
	_after_player_move()

func _update_scores() -> void:
	var black_count: int = 0
	var white_count: int = 0
	for r in range(8):
		for c in range(8):
			var v = grid_data.get_cell(r, c)
			if v == 1: black_count += 1
			elif v == 2: white_count += 1
	score_label.text = "Você (Pretas): %d  |  IA (Brancas): %d" % [black_count, white_count]

func _after_player_move():
	var ai_moves = ReversiRules.get_valid_moves(grid_data, 2)
	var player_moves = ReversiRules.get_valid_moves(grid_data, 1)
	
	if ai_moves.size() == 0 and player_moves.size() == 0:
		_end_game()
		return
		
	if ai_moves.size() > 0:
		is_player_turn = false
		set_status("Vez da IA (Brancas)...")
		_highlight_valid_moves()
		await get_tree().create_timer(0.6).timeout
		_play_ai_turn()
	else:
		set_status("IA sem jogadas! Sua vez novamente.")
		_highlight_valid_moves()

func _play_ai_turn():
	var ai_move = ReversiRules.get_best_move(grid_data, 2)
	if ai_move != Vector2i(-1, -1):
		var flipped = ReversiRules.get_flipped_pieces(grid_data, ai_move, 2)
		grid_data.set_cell(ai_move.x, ai_move.y, 2)
		for f in flipped:
			grid_data.set_cell(f.x, f.y, 2)
			var p_3d = pieces_3d.get(f)
			if p_3d:
				p_3d.flip_180("ivory", 0.35)
				
		var new_piece = preload("res://shared/3d/Token3D.tscn").instantiate()
		new_piece.token_type = "cylinder"
		new_piece.material_name = "ivory"
		var target_3d = board_3d.get_cell_position_3d(ai_move.x, ai_move.y, 0.08)
		new_piece.position = target_3d + Vector3(0, 2.5, 0)
		pieces_root.add_child(new_piece)
		pieces_3d[ai_move] = new_piece
		new_piece.drop_to(target_3d, 0.35)
		
	_update_scores()
	
	var player_moves = ReversiRules.get_valid_moves(grid_data, 1)
	var ai_moves = ReversiRules.get_valid_moves(grid_data, 2)
	
	if player_moves.size() == 0 and ai_moves.size() == 0:
		_end_game()
		return
		
	if player_moves.size() > 0:
		is_player_turn = true
		set_status("Sua Vez! (Pretas)")
		_highlight_valid_moves()
	else:
		set_status("Você sem jogadas! Vez da IA...")
		await get_tree().create_timer(0.6).timeout
		_play_ai_turn()

func _end_game() -> void:
	# get_winner devolve {"winner", "black", "white"}, nao o id do vencedor.
	var winner: int = ReversiRules.get_winner(grid_data)["winner"]
	if winner == 1:
		finish_game("🏆 Você Venceu!", true)
	elif winner == 2:
		finish_game("IA Venceu!")
	else:
		finish_game("Empate!")
