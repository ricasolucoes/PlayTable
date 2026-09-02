class_name NumberPathBoard
extends Control

signal level_completed
signal mistakes_made(count: int)

var grid_w: int = 3
var grid_h: int = 3
var clues: Dictionary = {} # cell_pos (Vector2i) -> number (int)
var path: Array[Vector2i] = [] # Current path drawn by player
var max_number: int = 0
var completed: bool = false
var start_cell: Vector2i = Vector2i(-1, -1)

# Drawing properties
var cell_size: float = 0.0
var margin: float = 10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
func setup_puzzle(w: int, h: int, puzzle_clues: Dictionary) -> void:
	grid_w = w
	grid_h = h
	clues = puzzle_clues.duplicate()
	path.clear()
	completed = false
	
	max_number = 0
	for num in clues.values():
		max_number = maxi(max_number, num)
		if num == 1:
			start_cell = clues.find_key(1)
			
	path.append(start_cell)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if completed:
		return
		
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pos = event.position
		var cell = _pos_to_cell(pos)
		
		if event.is_pressed():
			if cell in path:
				# Truncate path up to this cell
				var idx = path.find(cell)
				path = path.slice(0, idx + 1)
				queue_redraw()
		
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and (Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_LEFT)):
		var pos = event.position
		var cell = _pos_to_cell(pos)
		
		if _is_valid_cell(cell):
			var last_cell = path.back()
			if cell != last_cell:
				# Check if adjacent
				if abs(cell.x - last_cell.x) + abs(cell.y - last_cell.y) == 1:
					if cell in path:
						# Backtracking
						var idx = path.find(cell)
						path = path.slice(0, idx + 1)
						queue_redraw()
					else:
						# Forward tracking
						# Verify if we hit a clue out of order
						var hit_clue = clues.get(cell, -1)
						var current_progress = _get_current_target()
						
						if current_progress > max_number:
							# Already reached the last number, cannot continue
							pass
						elif hit_clue != -1 and hit_clue != current_progress:
							# Hit wrong number, block
							pass
						else:
							path.append(cell)
							queue_redraw()
							_check_completion()

func _get_current_target() -> int:
	var target = 1
	for p in path:
		if clues.has(p):
			target = clues[p] + 1
	return target

func _check_completion() -> void:
	if path.size() == grid_w * grid_h:
		var last = path.back()
		if clues.has(last) and clues[last] == max_number:
			completed = true
			level_completed.emit()
			queue_redraw()

func _pos_to_cell(pos: Vector2) -> Vector2i:
	var w_avail = size.x - margin * 2
	var h_avail = size.y - margin * 2
	var min_dim = minf(w_avail / grid_w, h_avail / grid_h)
	
	var board_w = min_dim * grid_w
	var board_h = min_dim * grid_h
	var offset_x = (size.x - board_w) / 2.0
	var offset_y = (size.y - board_h) / 2.0
	
	var x = int((pos.x - offset_x) / min_dim)
	var y = int((pos.y - offset_y) / min_dim)
	return Vector2i(x, y)

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_w and cell.y >= 0 and cell.y < grid_h

func _draw() -> void:
	if grid_w == 0 or grid_h == 0:
		return
		
	var w_avail = size.x - margin * 2
	var h_avail = size.y - margin * 2
	cell_size = minf(w_avail / grid_w, h_avail / grid_h)
	
	var board_w = cell_size * grid_w
	var board_h = cell_size * grid_h
	var offset_x = (size.x - board_w) / 2.0
	var offset_y = (size.y - board_h) / 2.0
	
	# Draw background
	var bg_rect = Rect2(offset_x, offset_y, board_w, board_h)
	draw_rect(bg_rect, Color(0.95, 0.9, 0.85), true)
	
	# Draw grid lines
	for x in range(grid_w + 1):
		var p1 = Vector2(offset_x + x * cell_size, offset_y)
		var p2 = Vector2(offset_x + x * cell_size, offset_y + board_h)
		draw_line(p1, p2, Color(0.8, 0.75, 0.7), 2.0)
	for y in range(grid_h + 1):
		var p1 = Vector2(offset_x, offset_y + y * cell_size)
		var p2 = Vector2(offset_x + board_w, offset_y + y * cell_size)
		draw_line(p1, p2, Color(0.8, 0.75, 0.7), 2.0)
		
	# Draw path
	var path_color = Color(0.9, 0.4, 0.1, 0.8) if not completed else Color(0.2, 0.8, 0.3, 0.8)
	var line_points: PackedVector2Array = []
	for p in path:
		var center = Vector2(offset_x + p.x * cell_size + cell_size/2, offset_y + p.y * cell_size + cell_size/2)
		line_points.append(center)
		
	if line_points.size() > 1:
		draw_polyline(line_points, path_color, cell_size * 0.4, true)
		for pt in line_points:
			draw_circle(pt, cell_size * 0.2, path_color)
			
	# Draw clues
	var font = ThemeDB.fallback_font
	var font_size = int(cell_size * 0.5)
	
	for cell in clues.keys():
		var center = Vector2(offset_x + cell.x * cell_size + cell_size/2, offset_y + cell.y * cell_size + cell_size/2)
		draw_circle(center, cell_size * 0.35, Color(0.1, 0.1, 0.1))
		
		var num_str = str(clues[cell])
		var string_size = font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = center - string_size / 2.0 + Vector2(0, font.get_ascent(font_size))
		draw_string(font, text_pos, num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
