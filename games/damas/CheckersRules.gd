class_name CheckersRules
extends RefCounted

## Rules and logic for Damas.

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")

const ROWS = 8
const COLS = 8

# 1: Brancas (Player), 2: Dama Branca, -1: Pretas (IA/Oponente), -2: Dama Preta

static func create_initial_board() -> Grid2D:
	var grid := Grid2D.new(ROWS, COLS, 0)
	for r in range(ROWS):
		for c in range(COLS):
			if (r + c) % 2 == 1:
				if r < 3:
					grid.set_cell(r, c, -1) # Peça preta
				elif r > 4:
					grid.set_cell(r, c, 1)  # Peça branca
	return grid

static func get_piece_captures(grid: Grid2D, r: int, c: int) -> Array[Dictionary]:
	var captures: Array[Dictionary] = []
	var piece = grid.get_cell(r, c)
	if piece == null or piece == 0: return captures
	
	var is_player = piece > 0
	var is_king = abs(piece) == 2
	var directions := [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]
	
	for d in directions:
		if not is_king:
			if is_player and d.x > 0: continue
			if not is_player and d.x < 0: continue
			
		var over_r = r + d.x
		var over_c = c + d.y
		var land_r = r + d.x * 2
		var land_c = c + d.y * 2
		
		if grid.is_valid(land_r, land_c) and grid.is_valid(over_r, over_c):
			var target_piece = grid.get_cell(over_r, over_c)
			if target_piece != 0 and (target_piece > 0) != is_player:
				if grid.get_cell(land_r, land_c) == 0:
					captures.append({
						"from": Vector2i(r, c),
						"to": Vector2i(land_r, land_c),
						"captures": [Vector2i(over_r, over_c)]
					})
	return captures

static func get_captures_for_piece(grid: Grid2D, pos: Vector2i) -> Array[Dictionary]:
	var caps := get_piece_captures(grid, pos.x, pos.y)
	var formatted: Array[Dictionary] = []
	for c in caps:
		var cap_pos = c["captures"][0] if (c.has("captures") and c["captures"].size() > 0) else Vector2i(-1, -1)
		formatted.append({
			"from": c["from"],
			"to": c["to"],
			"captured": cap_pos
		})
	return formatted

static func get_valid_moves_for_piece(grid: Grid2D, pos: Vector2i) -> Array[Dictionary]:
	var moves := get_piece_moves(grid, pos.x, pos.y)
	var formatted: Array[Dictionary] = []
	for m in moves:
		var cap_pos = m["captures"][0] if (m.has("captures") and m["captures"].size() > 0) else Vector2i(-1, -1)
		formatted.append({
			"from": m["from"],
			"to": m["to"],
			"captured": cap_pos
		})
	return formatted

static func get_best_ai_move(grid: Grid2D) -> Dictionary:
	var moves := get_all_valid_moves(grid, -1)
	if moves.is_empty(): return {}
	var chosen := moves[0]
	var cap_pos = chosen["captures"][0] if (chosen.has("captures") and chosen["captures"].size() > 0) else Vector2i(-1, -1)
	return {
		"from": chosen["from"],
		"to": chosen["to"],
		"captured": cap_pos
	}

static func apply_move(grid: Grid2D, from_pos: Vector2i, to_pos: Vector2i, captured_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var move := {
		"from": from_pos,
		"to": to_pos,
		"captures": [captured_pos] if captured_pos != Vector2i(-1, -1) else []
	}
	return execute_move(grid, move)

static func check_game_over(grid: Grid2D) -> int:
	var p1_moves := get_all_valid_moves(grid, 1)
	var p2_moves := get_all_valid_moves(grid, -1)
	var p1_pieces: int = 0
	var p2_pieces: int = 0
	for cell in grid.cells:
		if cell > 0: p1_pieces += 1
		elif cell < 0: p2_pieces += 1
	if p1_pieces == 0 or p1_moves.is_empty():
		return -1
	if p2_pieces == 0 or p2_moves.is_empty():
		return 1
	return 0

static func get_piece_moves(grid: Grid2D, r: int, c: int) -> Array[Dictionary]:
	var moves := get_piece_captures(grid, r, c)
	if not moves.is_empty():
		return moves
		
	var piece = grid.get_cell(r, c)
	if piece == null or piece == 0: return []
	
	var is_player = piece > 0
	var is_king = abs(piece) == 2
	var directions: Array[Vector2i] = []
	
	if is_player or is_king:
		directions.append(Vector2i(-1, -1))
		directions.append(Vector2i(-1, 1))
	if not is_player or is_king:
		directions.append(Vector2i(1, -1))
		directions.append(Vector2i(1, 1))
		
	for d in directions:
		var nr := r + d.x
		var nc := c + d.y
		if grid.is_valid(nr, nc) and grid.get_cell(nr, nc) == 0:
			moves.append({
				"from": Vector2i(r, c),
				"to": Vector2i(nr, nc),
				"captures": []
			})
			
	return moves

static func get_all_valid_moves(grid: Grid2D, side: int) -> Array[Dictionary]:
	var is_player := side > 0
	var all_moves: Array[Dictionary] = []
	var has_captures: bool = false
	for r in range(ROWS):
		for c in range(COLS):
			var p = grid.get_cell(r, c)
			if p != 0 and (p > 0) == is_player:
				var caps := get_piece_captures(grid, r, c)
				if not caps.is_empty():
					has_captures = true
					for cap in caps:
						all_moves.append(cap)
						
	if has_captures:
		return all_moves
		
	for r in range(ROWS):
		for c in range(COLS):
			var p = grid.get_cell(r, c)
			if p != 0 and (p > 0) == is_player:
				var mvs := get_piece_moves(grid, r, c)
				for m in mvs:
					all_moves.append(m)
					
	return all_moves

static func execute_move(grid: Grid2D, move: Dictionary) -> Dictionary:
	var from_p = move["from"]
	var to_p = move["to"]
	var piece = grid.get_cell(from_p.x, from_p.y)
	
	grid.set_cell(from_p.x, from_p.y, 0)
	
	var captured_any: bool = false
	if move.has("captures") and move["captures"].size() > 0:
		captured_any = true
		for cap in move["captures"]:
			grid.set_cell(cap.x, cap.y, 0)
			
	# Promoção a Dama
	if piece == 1 and to_p.x == 0:
		piece = 2
	elif piece == -1 and to_p.x == ROWS - 1:
		piece = -2
		
	grid.set_cell(to_p.x, to_p.y, piece)
	
	# Verifica se há capturas consecutivas para esta peça
	var further_captures: Array[Dictionary] = []
	if captured_any:
		further_captures = get_piece_captures(grid, to_p.x, to_p.y)
		
	return {
		"captured_any": captured_any,
		"further_captures": further_captures,
		"promoted": abs(piece) == 2
	}
