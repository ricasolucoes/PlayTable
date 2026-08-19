class_name Grid2D
extends RefCounted

var rows: int = 0
var cols: int = 0
var cells: Array = []

func _init(p_rows: int = 0, p_cols: int = 0, default_value = null):
	rows = p_rows
	cols = p_cols
	if rows > 0 and cols > 0:
		cells.resize(rows * cols)
		cells.fill(default_value)

func is_valid(r: int, c: int) -> bool:
	return r >= 0 and r < rows and c >= 0 and c < cols

func is_valid_pos(pos: Vector2i) -> bool:
	return is_valid(pos.x, pos.y)

func get_cell(r: int, c: int):
	if not is_valid(r, c):
		return null
	return cells[r * cols + c]

func get_cell_pos(pos: Vector2i):
	return get_cell(pos.x, pos.y)

func set_cell(r: int, c: int, value) -> void:
	if is_valid(r, c):
		cells[r * cols + c] = value

func set_cell_pos(pos: Vector2i, value) -> void:
	set_cell(pos.x, pos.y, value)

func get_index(r: int, c: int) -> int:
	return r * cols + c

func get_coord(idx: int) -> Vector2i:
	if cols == 0: return Vector2i(-1, -1)
	return Vector2i(idx / cols, idx % cols)

func fill(value) -> void:
	cells.fill(value)

func clear(default_val = null) -> void:
	cells.fill(default_val)

func get_orthogonal_neighbors(r: int, c: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for d in dirs:
		var nr = r + d.x
		var nc = c + d.y
		if is_valid(nr, nc):
			result.append(Vector2i(nr, nc))
	return result

func get_all_neighbors(r: int, c: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0: continue
			var nr = r + dr
			var nc = c + dc
			if is_valid(nr, nc):
				result.append(Vector2i(nr, nc))
	return result

func count_consecutive(start: Vector2i, dir: Vector2i, match_value) -> int:
	var count = 0
	var curr = start + dir
	while is_valid_pos(curr) and get_cell_pos(curr) == match_value:
		count += 1
		curr += dir
	return count

func count_streak_bidirectional(pos: Vector2i, dir: Vector2i, match_value) -> int:
	var count = 1 # A própria peça
	count += count_consecutive(pos, dir, match_value)
	count += count_consecutive(pos, -dir, match_value)
	return count

func find_all_matching(match_value) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for r in range(rows):
		for c in range(cols):
			if get_cell(r, c) == match_value:
				result.append(Vector2i(r, c))
	return result

func count_matching(match_value) -> int:
	var count = 0
	for item in cells:
		if item == match_value:
			count += 1
	return count

func is_full(empty_value = null) -> bool:
	for item in cells:
		if item == empty_value:
			return false
	return true

func clone() -> Grid2D:
	var g = Grid2D.new(rows, cols)
	g.cells = cells.duplicate(true)
	return g

func to_dict() -> Dictionary:
	return {
		"rows": rows,
		"cols": cols,
		"cells": cells.duplicate(true)
	}

static func from_dict(data: Dictionary) -> Grid2D:
	var g = Grid2D.new(int(data.get("rows", 0)), int(data.get("cols", 0)))
	g.cells = data.get("cells", []).duplicate(true)
	return g
