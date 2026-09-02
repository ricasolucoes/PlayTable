class_name NumberPathBoard
extends Control

## Visualização e controle de entrada do tabuleiro de Caminho Numérico.
##
## Desacoplado da lógica de regras e geração: delega a validação de movimentos
## e estado para `NumberPathModel` e foca em entrada (touch/drag) e renderização (_draw).

signal level_completed
signal path_updated(path: Array[Vector2i])
signal mistake_made(cell: Vector2i)

var model: NumberPathModel = null

# Propriedades de renderização
var margin: float = 16.0
var cell_size: float = 0.0
var board_rect: Rect2 = Rect2()

var _flashing_cell: Vector2i = Vector2i(-1, -1)
var _flash_timer: float = 0.0

# Paleta visual refinada
const COLOR_BG := Color(0.96, 0.94, 0.90)
const COLOR_GRID := Color(0.85, 0.81, 0.75)
const COLOR_PATH_ACTIVE := Color(0.92, 0.48, 0.15, 0.85)
const COLOR_PATH_HEAD := Color(1.0, 0.60, 0.20, 1.0)
const COLOR_PATH_WIN := Color(0.18, 0.72, 0.38, 0.90)
const COLOR_CLUE_BG := Color(0.18, 0.20, 0.24)
const COLOR_CLUE_NEXT := Color(0.85, 0.40, 0.10)
const COLOR_CLUE_VISITED := Color(0.30, 0.55, 0.35)
const COLOR_TEXT := Color(1.0, 1.0, 1.0)
const COLOR_MISTAKE := Color(0.9, 0.2, 0.2, 0.6)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if model == null:
		model = NumberPathModel.new()
	_connect_model_signals()


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flashing_cell = Vector2i(-1, -1)
			queue_redraw()


func _connect_model_signals() -> void:
	if model == null:
		return
	if not model.path_changed.is_connected(_on_model_path_changed):
		model.path_changed.connect(_on_model_path_changed)
	if not model.completed.is_connected(_on_model_completed):
		model.completed.connect(_on_model_completed)
	if not model.mistake_occurred.is_connected(_on_model_mistake):
		model.mistake_occurred.connect(_on_model_mistake)


func setup_puzzle(w: int, h: int, puzzle_data_or_clues: Variant) -> void:
	if model == null:
		model = NumberPathModel.new()
		_connect_model_signals()

	var data: Dictionary = {}
	if puzzle_data_or_clues is Dictionary:
		var d := puzzle_data_or_clues as Dictionary
		if d.has("clues"):
			data = d
		else:
			data = {
				"width": w,
				"height": h,
				"clues": d,
				"solution": [],
			}
	else:
		data = {
			"width": w,
			"height": h,
			"clues": {},
			"solution": [],
		}

	model.setup_puzzle(data)
	_flashing_cell = Vector2i(-1, -1)
	queue_redraw()


func _on_model_path_changed(new_path: Array[Vector2i]) -> void:
	path_updated.emit(new_path)
	queue_redraw()


func _on_model_completed() -> void:
	level_completed.emit()
	queue_redraw()


func _on_model_mistake(cell: Vector2i, _reason: String) -> void:
	_flashing_cell = cell
	_flash_timer = 0.25
	mistake_made.emit(cell)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if model == null or model.is_completed:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pos: Vector2 = event.position
		var cell := _pos_to_cell(pos)

		if event.is_pressed():
			if cell in model.player_path:
				model.truncate_to(cell)
			elif model.can_extend_to(cell):
				model.extend_to(cell)
		accept_event()

	elif event is InputEventScreenDrag:
		var pos: Vector2 = event.position
		var cell := _pos_to_cell(pos)
		_handle_drag_to_cell(cell)
		accept_event()

	elif event is InputEventMouseMotion:
		if Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_LEFT:
			var pos: Vector2 = event.position
			var cell := _pos_to_cell(pos)
			_handle_drag_to_cell(cell)
			accept_event()


func _handle_drag_to_cell(cell: Vector2i) -> void:
	if not model.is_valid_cell(cell):
		return

	if model.player_path.is_empty():
		if cell == model.start_cell:
			model.extend_to(cell)
		return

	var last_cell := model.player_path.back()
	if cell == last_cell:
		return

	if model.is_adjacent(cell, last_cell):
		if cell in model.player_path:
			model.truncate_to(cell)
		else:
			model.extend_to(cell)


func _pos_to_cell(pos: Vector2) -> Vector2i:
	if model == null or model.grid_w <= 0 or model.grid_h <= 0:
		return Vector2i(-1, -1)

	var w_avail := size.x - margin * 2.0
	var h_avail := size.y - margin * 2.0
	var min_dim := minf(w_avail / float(model.grid_w), h_avail / float(model.grid_h))

	var board_w := min_dim * float(model.grid_w)
	var board_h := min_dim * float(model.grid_h)
	var offset_x := (size.x - board_w) / 2.0
	var offset_y := (size.y - board_h) / 2.0

	var x := int((pos.x - offset_x) / min_dim)
	var y := int((pos.y - offset_y) / min_dim)
	return Vector2i(x, y)


func _cell_to_center(cell: Vector2i, offset_x: float, offset_y: float, c_size: float) -> Vector2:
	return Vector2(offset_x + cell.x * c_size + c_size / 2.0, offset_y + cell.y * c_size + c_size / 2.0)


func _draw() -> void:
	if model == null or model.grid_w <= 0 or model.grid_h <= 0:
		return

	var w_avail := size.x - margin * 2.0
	var h_avail := size.y - margin * 2.0
	cell_size = minf(w_avail / float(model.grid_w), h_avail / float(model.grid_h))

	var board_w := cell_size * float(model.grid_w)
	var board_h := cell_size * float(model.grid_h)
	var offset_x := (size.x - board_w) / 2.0
	var offset_y := (size.y - board_h) / 2.0
	board_rect = Rect2(offset_x, offset_y, board_w, board_h)

	# Fundo do tabuleiro com sombra suave
	draw_rect(Rect2(offset_x + 3, offset_y + 3, board_w, board_h), Color(0, 0, 0, 0.15), true)
	draw_rect(board_rect, COLOR_BG, true)

	# Flash de erro se houver
	if _flashing_cell != Vector2i(-1, -1):
		var flash_rect := Rect2(
			offset_x + _flashing_cell.x * cell_size,
			offset_y + _flashing_cell.y * cell_size,
			cell_size,
			cell_size
		)
		draw_rect(flash_rect, COLOR_MISTAKE, true)

	# Linhas da grade
	for x in range(model.grid_w + 1):
		var p1 := Vector2(offset_x + x * cell_size, offset_y)
		var p2 := Vector2(offset_x + x * cell_size, offset_y + board_h)
		draw_line(p1, p2, COLOR_GRID, 2.0)

	for y in range(model.grid_h + 1):
		var p1 := Vector2(offset_x, offset_y + y * cell_size)
		var p2 := Vector2(offset_x + board_w, offset_y + y * cell_size)
		draw_line(p1, p2, COLOR_GRID, 2.0)

	# Caminho desenhado pelo jogador
	var path_color := COLOR_PATH_WIN if model.is_completed else COLOR_PATH_ACTIVE
	var line_points: PackedVector2Array = []
	for p in model.player_path:
		line_points.append(_cell_to_center(p, offset_x, offset_y, cell_size))

	if line_points.size() > 1:
		draw_polyline(line_points, path_color, cell_size * 0.36, true)
		for pt in line_points:
			draw_circle(pt, cell_size * 0.18, path_color)

	# Destaque na ponta atual do caminho (Head)
	if not model.player_path.is_empty() and not model.is_completed:
		var head_pt := line_points[line_points.size() - 1]
		draw_circle(head_pt, cell_size * 0.22, COLOR_PATH_HEAD)

	# Dicas / Checkpoints numéricos
	var font := ThemeDB.fallback_font
	var font_size := int(cell_size * 0.44)
	var next_target := model.get_current_target()

	for cell in model.clues.keys():
		var center := _cell_to_center(cell, offset_x, offset_y, cell_size)
		var num_val := int(model.clues[cell])

		var is_visited := (cell in model.player_path)
		var is_next := (num_val == next_target and not model.is_completed)

		var badge_color := COLOR_CLUE_BG
		if model.is_completed:
			badge_color = COLOR_PATH_WIN
		elif is_visited:
			badge_color = COLOR_CLUE_VISITED
		elif is_next:
			badge_color = COLOR_CLUE_NEXT

		# Halo indicador no próximo número a alcançar
		if is_next:
			draw_circle(center, cell_size * 0.38, Color(badge_color, 0.35))

		draw_circle(center, cell_size * 0.32, badge_color)

		var num_str := str(num_val)
		var string_size := font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := center - string_size / 2.0 + Vector2(0, font.get_ascent(font_size))
		draw_string(font, text_pos, num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR_TEXT)
