class_name BattleshipRules
extends RefCounted

## Rules and logic for Batalha Naval.

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")

const GRID_SIZE = 10

const SHIP_DEFS = [
	{"name": "Porta-Aviões", "size": 5},
	{"name": "Encouraçado", "size": 4},
	{"name": "Cruzador", "size": 3},
	{"name": "Submarino", "size": 3},
	{"name": "Destroyer", "size": 2}
]

# Estados de célula:
# 0 = Vazio (Água oculta)
# 1 = Navio presente
# 2 = Tiro na Água (Miss)
# 3 = Tiro Certeiro (Hit)

static func create_empty_grid() -> Grid2D:
	return Grid2D.new(GRID_SIZE, GRID_SIZE, 0)

static func place_all_ships_random(grid: Grid2D) -> Array[Dictionary]:
	return place_all_ships_randomly(grid)

static func count_sunk_ships(fleet: Array) -> int:
	var count: int = 0
	for s in fleet:
		if s.get("sunk", false): count += 1
	return count

static func check_ship_sunk(fleet: Array, grid: Grid2D, r: int, c: int) -> Dictionary:
	var pos = Vector2i(r, c)
	for s in fleet:
		if pos in s["cells"]:
			var all_hit: bool = true
			for cell in s["cells"]:
				if grid.get_cell(cell.x, cell.y) != 3:
					all_hit = false
					break
			if all_hit:
				s["sunk"] = true
				return s
			break
	return {}

static func check_all_sunk(fleet: Array) -> bool:
	for s in fleet:
		if not s.get("sunk", false): return false
	return true

static func place_all_ships_randomly(grid: Grid2D) -> Array[Dictionary]:
	grid.fill(0)
	var placed_ships: Array[Dictionary] = []
	
	for s_def in SHIP_DEFS:
		var placed: bool = false
		var attempts: int = 0
		var size = s_def["size"]
		
		while not placed and attempts < 300:
			attempts += 1
			var horizontal = randi() % 2 == 0
			var max_r = GRID_SIZE - 1 if horizontal else GRID_SIZE - size
			var max_c = GRID_SIZE - size if horizontal else GRID_SIZE - 1
			var r = randi() % (max_r + 1)
			var c = randi() % (max_c + 1)
			
			var can_place: bool = true
			var cells: Array[Vector2i] = []
			for i in range(size):
				var cr = r if horizontal else r + i
				var cc = c + i if horizontal else c
				if grid.get_cell(cr, cc) != 0:
					can_place = false
					break
				cells.append(Vector2i(cr, cc))
				
			if can_place:
				for cell in cells:
					grid.set_cell(cell.x, cell.y, 1)
				placed_ships.append({
					"name": s_def["name"],
					"size": size,
					"cells": cells,
					"hits": 0,
					"sunk": false
				})
				placed = true
	return placed_ships

static func register_shot(grid: Grid2D, pos: Vector2i, fleet: Array) -> Dictionary:
	var cell_val = grid.get_cell(pos.x, pos.y)
	if cell_val == 2 or cell_val == 3:
		return {"valid": false, "is_hit": false, "sunk_ship": null, "all_sunk": false}
		
	var is_hit = (cell_val == 1)
	grid.set_cell(pos.x, pos.y, 3 if is_hit else 2)
	
	var sunk_ship = null
	if is_hit:
		for s in fleet:
			if pos in s["cells"]:
				s["hits"] += 1
				if s["hits"] >= s["size"]:
					s["sunk"] = true
					sunk_ship = s
				break
				
	var all_sunk: bool = true
	for s in fleet:
		if not s["sunk"]:
			all_sunk = false
			break
			
	return {
		"valid": true,
		"is_hit": is_hit,
		"sunk_ship": sunk_ship,
		"all_sunk": all_sunk
	}

static func get_ai_shot(arg1, arg2 = null) -> Vector2i:
	if arg1 is Grid2D:
		var grid: Grid2D = arg1
		var candidates: Array[Vector2i] = []
		for r in range(GRID_SIZE):
			for c in range(GRID_SIZE):
				var v = grid.get_cell(r, c)
				if v != 2 and v != 3:
					candidates.append(Vector2i(r, c))
		if candidates.is_empty():
			return Vector2i(0, 0)
		candidates.shuffle()
		return candidates[0]

	var ai_hit_stack: Array = arg1 if arg1 is Array else []
	var shots_fired: Array = arg2 if arg2 is Array else []
	var shot_pos = Vector2i(-1, -1)
	
	# 1. Alvos prioritários na pilha de caça (Hunt & Target)
	while not ai_hit_stack.is_empty():
		var candidate = ai_hit_stack.pop_back()
		if candidate.x >= 0 and candidate.x < GRID_SIZE and candidate.y >= 0 and candidate.y < GRID_SIZE:
			if not (candidate in shots_fired):
				shot_pos = candidate
				break
				
	# 2. Padrão de paridade (tabuleiro de xadrez)
	if shot_pos == Vector2i(-1, -1):
		var candidates: Array[Vector2i] = []
		for r in range(GRID_SIZE):
			for c in range(GRID_SIZE):
				var p = Vector2i(r, c)
				if not (p in shots_fired):
					if (r + c) % 2 == 0:
						candidates.append(p)
		if candidates.is_empty():
			for r in range(GRID_SIZE):
				for c in range(GRID_SIZE):
					var p = Vector2i(r, c)
					if not (p in shots_fired):
						candidates.append(p)
		if not candidates.is_empty():
			candidates.shuffle()
			shot_pos = candidates[0]
			
	return shot_pos
