class_name NumberPathBoard
extends Control

## Visualização e controle de entrada do tabuleiro de Caminho Numérico.
##
## Desacoplado da lógica de regras e geração: delega a validação de movimentos
## e estado para `NumberPathModel` e foca em entrada (touch/drag), animações
## e renderização completa em tela (_draw) com suporte a obstáculos, pontes,
## estrelas obrigatórias, portais quânticos, setas direcionais e pistas numéricas.

const Model := preload("res://games/caminho_numerico/NumberPathModel.gd")

signal level_completed
signal path_updated(path: Array[Vector2i])
signal mistake_made(cell: Vector2i)

var model: NumberPathModel = null

# Propriedades de enquadramento e renderização
var margin: float = 16.0
var cell_size: float = 0.0
var board_rect: Rect2 = Rect2()

# Estados de interação e animação
var _flashing_cell: Vector2i = Vector2i(-1, -1)
var _flash_tween: Tween = null
var _active_touch_index: int = -1
var _is_mouse_down: bool = false
var _anim_time: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_tween: Tween = null

# Efeitos visuais transitórios (bursts de estrelas e portais)
var _burst_effects: Array[Dictionary] = [] # [{pos: Vector2, radius: float, max_radius: float, color: Color, life: float, max_life: float}]

# Paleta visual refinada (Design Handcrafted)
const COLOR_BG_SHADOW := Color(0.12, 0.10, 0.08, 0.18)
const COLOR_BOARD_BG := Color(0.96, 0.94, 0.90, 1.0)
const COLOR_BOARD_BORDER := Color(0.82, 0.78, 0.70, 1.0)
const COLOR_CELL_BG := Color(0.98, 0.97, 0.95, 1.0)
const COLOR_CELL_BORDER := Color(0.88, 0.84, 0.78, 1.0)

# Cores de caminho
const COLOR_PATH_ACTIVE := Color(0.94, 0.50, 0.16, 0.92)
const COLOR_PATH_INNER := Color(1.0, 0.72, 0.42, 0.75)
const COLOR_PATH_HEAD := Color(1.0, 0.62, 0.18, 1.0)
const COLOR_PATH_HEAD_GLOW := Color(1.0, 0.75, 0.30, 0.35)
const COLOR_PATH_WIN := Color(0.18, 0.76, 0.40, 0.95)
const COLOR_PATH_WIN_INNER := Color(0.55, 0.92, 0.68, 0.80)

# Cores de mecânicas especiais
const COLOR_OBSTACLE_BG := Color(0.24, 0.26, 0.30, 1.0)
const COLOR_OBSTACLE_INSET := Color(0.18, 0.20, 0.23, 1.0)
const COLOR_OBSTACLE_HATCH := Color(0.38, 0.40, 0.46, 0.45)
const COLOR_BRIDGE_BG := Color(0.89, 0.84, 0.76, 1.0)
const COLOR_BRIDGE_RAIL := Color(0.48, 0.38, 0.28, 0.90)
const COLOR_BRIDGE_LANE := Color(0.80, 0.75, 0.67, 0.60)
const COLOR_STAR_GOLD := Color(1.0, 0.82, 0.10, 1.0)
const COLOR_STAR_OUTLINE := Color(0.92, 0.56, 0.05, 1.0)
const COLOR_STAR_GLOW := Color(1.0, 0.85, 0.20, 0.30)
const COLOR_PORTAL_CYAN := Color(0.25, 0.78, 0.98, 0.90)
const COLOR_PORTAL_PURPLE := Color(0.86, 0.36, 0.96, 0.90)
const COLOR_ARROW := Color(0.22, 0.54, 0.88, 0.85)

# Cores de pistas numéricas
const COLOR_CLUE_BG := Color(0.20, 0.22, 0.26, 1.0)
const COLOR_CLUE_START := Color(0.18, 0.58, 0.86, 1.0)
const COLOR_CLUE_END := Color(0.86, 0.28, 0.34, 1.0)
const COLOR_CLUE_NEXT := Color(0.92, 0.44, 0.10, 1.0)
const COLOR_CLUE_VISITED := Color(0.26, 0.62, 0.38, 1.0)
const COLOR_TEXT := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_MISTAKE := Color(0.92, 0.22, 0.22, 0.65)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	if model == null:
		model = Model.new()
	_connect_model_signals()


func _exit_tree() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		_flash_tween = null
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		_shake_tween = null
	_active_touch_index = -1
	_is_mouse_down = false
	_burst_effects.clear()


func _process(delta: float) -> void:
	_anim_time += delta
	var needs_redraw: bool = false

	# Se houver elementos animados (estrelas, portais, caminho ativo ou bursts), redesenha suavemente
	if model != null and not model.is_completed:
		if not model.stars.is_empty() or not model.portals.is_empty() or not model.player_path.is_empty():
			needs_redraw = true

	# Atualiza partículas/bursts transitórios
	if not _burst_effects.is_empty():
		needs_redraw = true
		var i: int = _burst_effects.size() - 1
		while i >= 0:
			var b: Dictionary = _burst_effects[i]
			b["life"] = float(b["life"]) + delta
			var progress: float = float(b["life"]) / float(b["max_life"])
			b["radius"] = lerpf(0.0, float(b["max_radius"]), progress)
			if progress >= 1.0:
				_burst_effects.remove_at(i)
			i -= 1

	if _flashing_cell != Vector2i(-1, -1) or _shake_offset != Vector2.ZERO:
		needs_redraw = true

	if needs_redraw:
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
	if not model.star_collected.is_connected(_on_model_star_collected):
		model.star_collected.connect(_on_model_star_collected)
	if not model.portal_used.is_connected(_on_model_portal_used):
		model.portal_used.connect(_on_model_portal_used)


func setup_puzzle(w: int, h: int, puzzle_data_or_clues: Variant) -> void:
	if model == null:
		model = Model.new()
	_connect_model_signals()

	var data: Dictionary = {}
	if puzzle_data_or_clues is Dictionary:
		var d: Dictionary = puzzle_data_or_clues as Dictionary
		if d.has("clues") or d.has("obstacles") or d.has("bridges") or d.has("stars") or d.has("portals"):
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
	_active_touch_index = -1
	_is_mouse_down = false
	_shake_offset = Vector2.ZERO
	_burst_effects.clear()
	queue_redraw()


func _on_model_path_changed(new_path: Array[Vector2i]) -> void:
	path_updated.emit(new_path)
	queue_redraw()


func _on_model_completed() -> void:
	_active_touch_index = -1
	_is_mouse_down = false
	level_completed.emit()
	queue_redraw()


func _on_model_star_collected(cell: Vector2i, _remaining: int) -> void:
	var center: Vector2 = _get_cell_center_pos(cell)
	_spawn_burst(center, cell_size * 0.75, COLOR_STAR_GOLD, 0.45)
	queue_redraw()


func _on_model_portal_used(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var c1: Vector2 = _get_cell_center_pos(from_cell)
	var c2: Vector2 = _get_cell_center_pos(to_cell)
	_spawn_burst(c1, cell_size * 0.8, COLOR_PORTAL_CYAN, 0.5)
	_spawn_burst(c2, cell_size * 0.8, COLOR_PORTAL_PURPLE, 0.5)
	queue_redraw()


func _spawn_burst(pos: Vector2, max_radius: float, color: Color, duration: float) -> void:
	_burst_effects.append({
		"pos": pos,
		"radius": 0.0,
		"max_radius": max_radius,
		"color": color,
		"life": 0.0,
		"max_life": duration
	})


func _on_model_mistake(cell: Vector2i, _reason: String) -> void:
	_flashing_cell = cell
	mistake_made.emit(cell)

	# Efeito de tremor (shake)
	if is_inside_tree():
		if _shake_tween and _shake_tween.is_valid():
			_shake_tween.kill()
		_shake_tween = create_tween()
		_shake_tween.tween_method(func(val: float) -> void:
			_shake_offset = Vector2(sin(val * PI * 6.0) * 6.0 * (1.0 - val), 0.0)
		, 0.0, 1.0, 0.25)
		_shake_tween.tween_callback(func() -> void:
			_shake_offset = Vector2.ZERO
		)

		if _flash_tween and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_interval(0.28)
		_flash_tween.tween_callback(func() -> void:
			_flashing_cell = Vector2i(-1, -1)
			queue_redraw()
		)
	else:
		_flashing_cell = Vector2i(-1, -1)
		_shake_offset = Vector2.ZERO

	queue_redraw()


# =============================================================================
# ENTRADA DO USUÁRIO & TOUCH / DRAG
# =============================================================================

func _gui_input(event: InputEvent) -> void:
	if model == null or model.is_completed:
		return

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.is_pressed():
			if _active_touch_index == -1:
				_active_touch_index = st.index
				var pos: Vector2 = st.position - _shake_offset
				var cell: Vector2i = _pos_to_cell(pos)
				if cell != Vector2i(-1, -1):
					_handle_tap_cell(cell)
		else:
			if st.index == _active_touch_index:
				_active_touch_index = -1
		accept_event()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.is_pressed():
				_is_mouse_down = true
				var pos: Vector2 = mb.position - _shake_offset
				var cell: Vector2i = _pos_to_cell(pos)
				if cell != Vector2i(-1, -1):
					_handle_tap_cell(cell)
			else:
				_is_mouse_down = false
			accept_event()

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _active_touch_index == -1 or sd.index == _active_touch_index:
			_active_touch_index = sd.index
			var pos: Vector2 = sd.position - _shake_offset
			var cell: Vector2i = _pos_to_cell(pos)
			_handle_drag_to_cell(cell)
		accept_event()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_mouse_down or (Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_LEFT != 0):
			var pos: Vector2 = mm.position - _shake_offset
			var cell: Vector2i = _pos_to_cell(pos)
			_handle_drag_to_cell(cell)
			accept_event()


func _handle_tap_cell(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1) or not model.is_valid_cell(cell):
		return

	if model.player_path.is_empty():
		if cell == model.start_cell:
			model.extend_to(cell)
		return

	var last_cell: Vector2i = model.player_path.back()
	if cell == last_cell:
		return

	if model.player_path.has(cell):
		# Se for uma ponte já visitada que ainda pode ser cruzada na outra direção
		if model.bridges.has(cell) and model.can_extend_to(cell):
			model.extend_to(cell)
		else:
			model.truncate_to(cell)
	else:
		model.extend_to(cell)


func _handle_drag_to_cell(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1) or not model.is_valid_cell(cell):
		return

	if model.player_path.is_empty():
		if cell == model.start_cell:
			model.extend_to(cell)
		return

	var last_cell: Vector2i = model.player_path.back()
	if cell == last_cell:
		return

	if model.player_path.has(cell):
		# Se for uma ponte e o movimento ortogonal for uma nova travessia válida
		if model.bridges.has(cell) and model.can_extend_to(cell):
			model.extend_to(cell)
		else:
			model.truncate_to(cell)
	else:
		if model.is_adjacent(cell, last_cell) or (model.portals.has(last_cell) and model.portals[last_cell] == cell):
			model.extend_to(cell)


# =============================================================================
# COORDENADAS E GEOMETRIA
# =============================================================================

func _pos_to_cell(pos: Vector2) -> Vector2i:
	if model == null or model.grid_w <= 0 or model.grid_h <= 0:
		return Vector2i(-1, -1)

	var w_avail: float = size.x - margin * 2.0
	var h_avail: float = size.y - margin * 2.0
	if w_avail <= 0.0 or h_avail <= 0.0:
		return Vector2i(-1, -1)

	var min_dim: float = minf(w_avail / float(model.grid_w), h_avail / float(model.grid_h))
	if min_dim <= 0.0:
		return Vector2i(-1, -1)

	var board_w: float = min_dim * float(model.grid_w)
	var board_h: float = min_dim * float(model.grid_h)
	var offset_x: float = (size.x - board_w) / 2.0
	var offset_y: float = (size.y - board_h) / 2.0

	if pos.x < offset_x or pos.x >= offset_x + board_w or pos.y < offset_y or pos.y >= offset_y + board_h:
		return Vector2i(-1, -1)

	var x: int = int((pos.x - offset_x) / min_dim)
	var y: int = int((pos.y - offset_y) / min_dim)
	if x < 0 or x >= model.grid_w or y < 0 or y >= model.grid_h:
		return Vector2i(-1, -1)

	return Vector2i(x, y)


func _cell_to_center(cell: Vector2i, offset_x: float, offset_y: float, c_size: float) -> Vector2:
	return Vector2(offset_x + float(cell.x) * c_size + c_size * 0.5, offset_y + float(cell.y) * c_size + c_size * 0.5)


func _get_cell_center_pos(cell: Vector2i) -> Vector2:
	if model == null or model.grid_w <= 0 or model.grid_h <= 0:
		return Vector2.ZERO
	var w_avail: float = size.x - margin * 2.0
	var h_avail: float = size.y - margin * 2.0
	var c_size: float = minf(w_avail / float(model.grid_w), h_avail / float(model.grid_h))
	var board_w: float = c_size * float(model.grid_w)
	var board_h: float = c_size * float(model.grid_h)
	var offset_x: float = (size.x - board_w) / 2.0
	var offset_y: float = (size.y - board_h) / 2.0
	return _cell_to_center(cell, offset_x, offset_y, c_size)


# =============================================================================
# RENDERIZAÇÃO COMPLETA NO CANVAS (_DRAW)
# =============================================================================

func _draw() -> void:
	if model == null or model.grid_w <= 0 or model.grid_h <= 0:
		return

	var w_avail: float = size.x - margin * 2.0
	var h_avail: float = size.y - margin * 2.0
	if w_avail <= 0.0 or h_avail <= 0.0:
		return

	cell_size = minf(w_avail / float(model.grid_w), h_avail / float(model.grid_h))
	if cell_size <= 0.0:
		return

	var board_w: float = cell_size * float(model.grid_w)
	var board_h: float = cell_size * float(model.grid_h)
	var offset_x: float = (size.x - board_w) * 0.5 + _shake_offset.x
	var offset_y: float = (size.y - board_h) * 0.5 + _shake_offset.y
	board_rect = Rect2(offset_x, offset_y, board_w, board_h)

	# 1. Fundo do tabuleiro com sombra projetada e borda suave
	var shadow_rect := Rect2(offset_x + 5.0, offset_y + 6.0, board_w, board_h)
	draw_rect(shadow_rect, COLOR_BG_SHADOW, true)
	draw_rect(board_rect, COLOR_BOARD_BG, true)
	draw_rect(board_rect, COLOR_BOARD_BORDER, false, 3.0)

	# 2. Renderização de células de fundo (Grid Tiles)
	var cell_pad: float = maxf(2.0, cell_size * 0.04)
	for y in range(model.grid_h):
		for x in range(model.grid_w):
			var cell := Vector2i(x, y)
			var c_rect := Rect2(
				offset_x + float(x) * cell_size + cell_pad,
				offset_y + float(y) * cell_size + cell_pad,
				cell_size - cell_pad * 2.0,
				cell_size - cell_pad * 2.0
			)

			if model.obstacles.has(cell):
				_draw_obstacle(c_rect, cell_size)
			elif model.bridges.has(cell):
				_draw_bridge_base(c_rect, cell_size, cell)
			else:
				draw_rect(c_rect, COLOR_CELL_BG, true)
				draw_rect(c_rect, COLOR_CELL_BORDER, false, 1.5)

	# 3. Flash visual de erro / movimento inválido
	if _flashing_cell != Vector2i(-1, -1):
		var flash_rect := Rect2(
			offset_x + float(_flashing_cell.x) * cell_size,
			offset_y + float(_flashing_cell.y) * cell_size,
			cell_size,
			cell_size
		)
		draw_rect(flash_rect, COLOR_MISTAKE, true)

	# 4. Portais Quânticos (Vórtices Cósmicos)
	_draw_all_portals(offset_x, offset_y, cell_size)

	# 5. Setas Direcionais
	_draw_all_directional(offset_x, offset_y, cell_size)

	# 6. Estrelas Obrigatórias
	_draw_all_stars(offset_x, offset_y, cell_size)

	# 7. Caminho do Jogador (Linhas, Overpass de Pontes e Ponta Ativa)
	_draw_player_path(offset_x, offset_y, cell_size)

	# 8. Efeitos Transitórios de Bursts (Estrelas coletadas e Portais)
	_draw_bursts()

	# 9. Pistas Numéricas (Badges, Textos e Indicador do Próximo Alvo)
	_draw_all_clues(offset_x, offset_y, cell_size)


# =============================================================================
# SUB-RENDERIZADORES DEDICADOS
# =============================================================================

func _draw_obstacle(rect: Rect2, c_size: float) -> void:
	# Bloco de rocha sólida escura com chanfro
	draw_rect(rect, COLOR_OBSTACLE_BG, true)
	var inset_pad: float = maxf(3.0, c_size * 0.08)
	var inner_rect := Rect2(
		rect.position.x + inset_pad,
		rect.position.y + inset_pad,
		rect.size.x - inset_pad * 2.0,
		rect.size.y - inset_pad * 2.0
	)
	draw_rect(inner_rect, COLOR_OBSTACLE_INSET, true)

	# Hachuras diagonais de textura de pedra
	var hatch_lines: int = 4
	var step: float = inner_rect.size.x / float(hatch_lines)
	for i in range(hatch_lines + 1):
		var p1 := Vector2(inner_rect.position.x + float(i) * step, inner_rect.position.y)
		var p2 := Vector2(inner_rect.position.x, inner_rect.position.y + float(i) * step)
		draw_line(p1, p2, COLOR_OBSTACLE_HATCH, 2.0)
		var p3 := Vector2(inner_rect.end.x - float(i) * step, inner_rect.end.y)
		var p4 := Vector2(inner_rect.end.x, inner_rect.end.y - float(i) * step)
		draw_line(p3, p4, COLOR_OBSTACLE_HATCH, 2.0)

	# Bordas de relevo
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.42, 0.45, 0.50, 0.8), 2.0)
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), Color(0.42, 0.45, 0.50, 0.8), 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(0.12, 0.13, 0.16, 0.8), 2.0)
	draw_line(Vector2(rect.end.x, rect.position.y), rect.end, Color(0.12, 0.13, 0.16, 0.8), 2.0)


func _draw_bridge_base(rect: Rect2, c_size: float, _cell: Vector2i) -> void:
	# Fundo da ponte
	draw_rect(rect, COLOR_BRIDGE_BG, true)

	var center := rect.get_center()
	var rail_w: float = maxf(4.0, c_size * 0.10)

	# Pista inferior (Underpass - Vertical)
	var v_lane := Rect2(center.x - c_size * 0.22, rect.position.y, c_size * 0.44, rect.size.y)
	draw_rect(v_lane, COLOR_BRIDGE_LANE, true)

	# Pista superior (Overpass - Horizontal com sombra)
	var h_lane := Rect2(rect.position.x, center.y - c_size * 0.22, rect.size.x, c_size * 0.44)
	draw_rect(Rect2(h_lane.position.x, h_lane.position.y + 2.0, h_lane.size.x, h_lane.size.y), Color(0, 0, 0, 0.15), true)
	draw_rect(h_lane, COLOR_CELL_BG, true)

	# Guarda-corpos / Trilhos de madeira nas laterais superiores e inferiores
	draw_rect(Rect2(rect.position.x, h_lane.position.y - rail_w * 0.5, rect.size.x, rail_w * 0.6), COLOR_BRIDGE_RAIL, true)
	draw_rect(Rect2(rect.position.x, h_lane.end.y - rail_w * 0.1, rect.size.x, rail_w * 0.6), COLOR_BRIDGE_RAIL, true)

	# Marcadores de rebites nos trilhos
	var rivet_rad: float = maxf(1.5, c_size * 0.035)
	draw_circle(Vector2(rect.position.x + c_size * 0.15, h_lane.position.y - rail_w * 0.2), rivet_rad, Color(0.25, 0.18, 0.12))
	draw_circle(Vector2(rect.end.x - c_size * 0.15, h_lane.position.y - rail_w * 0.2), rivet_rad, Color(0.25, 0.18, 0.12))
	draw_circle(Vector2(rect.position.x + c_size * 0.15, h_lane.end.y + rail_w * 0.2), rivet_rad, Color(0.25, 0.18, 0.12))
	draw_circle(Vector2(rect.end.x - c_size * 0.15, h_lane.end.y + rail_w * 0.2), rivet_rad, Color(0.25, 0.18, 0.12))

	draw_rect(rect, COLOR_CELL_BORDER, false, 1.5)


func _draw_all_portals(offset_x: float, offset_y: float, c_size: float) -> void:
	if model == null or model.portals.is_empty():
		return

	var drawn_pairs: Dictionary = {}
	var pair_idx: int = 0

	for src in model.portals.keys():
		var dest: Vector2i = model.portals[src]
		var pair_key: String = "%d_%d" % [mini(src.x * 100 + src.y, dest.x * 100 + dest.y), maxi(src.x * 100 + src.y, dest.x * 100 + dest.y)]
		if not drawn_pairs.has(pair_key):
			drawn_pairs[pair_key] = pair_idx
			pair_idx += 1

		var current_pair_num: int = drawn_pairs[pair_key]
		var base_color: Color = COLOR_PORTAL_CYAN if current_pair_num % 2 == 0 else COLOR_PORTAL_PURPLE
		var center: Vector2 = _cell_to_center(src, offset_x, offset_y, c_size)
		_draw_single_portal_vortex(center, c_size * 0.36, base_color)


func _draw_single_portal_vortex(center: Vector2, radius: float, color: Color) -> void:
	# Halo luminoso pulsante
	var pulse: float = 0.85 + 0.15 * sin(_anim_time * 3.5)
	draw_circle(center, radius * pulse, Color(color, 0.25))

	# Anéis concêntricos de vórtice espiral
	var num_arcs: int = 3
	for i in range(num_arcs):
		var arc_rad: float = radius * (0.35 + float(i) * 0.25)
		var start_angle: float = _anim_time * (2.5 - float(i) * 0.8) + float(i) * (TAU / float(num_arcs))
		var end_angle: float = start_angle + PI * 1.1
		draw_arc(center, arc_rad, start_angle, end_angle, 16, color, maxf(2.0, radius * 0.12), true)

	# Núcleo brilhante central
	draw_circle(center, radius * 0.22, Color(1.0, 1.0, 1.0, 0.9))


func _draw_all_directional(offset_x: float, offset_y: float, c_size: float) -> void:
	if model == null or model.directional.is_empty():
		return

	for cell in model.directional.keys():
		var dir: Vector2i = model.directional[cell]
		var center: Vector2 = _cell_to_center(cell, offset_x, offset_y, c_size)
		_draw_directional_arrow(center, dir, c_size)


func _draw_directional_arrow(center: Vector2, dir: Vector2i, c_size: float) -> void:
	var d_vec := Vector2(dir.x, dir.y).normalized()
	if d_vec == Vector2.ZERO:
		return
	var p_vec := Vector2(-d_vec.y, d_vec.x)

	var arrow_size: float = c_size * 0.28
	var tip: Vector2 = center + d_vec * arrow_size
	var left: Vector2 = center - d_vec * (arrow_size * 0.4) + p_vec * (arrow_size * 0.55)
	var right: Vector2 = center - d_vec * (arrow_size * 0.4) - p_vec * (arrow_size * 0.55)
	var base_stem: Vector2 = center - d_vec * (arrow_size * 0.8)

	# Sombra
	var shadow_offset := Vector2(1.5, 2.0)
	var pts_shadow := PackedVector2Array([tip + shadow_offset, left + shadow_offset, right + shadow_offset])
	draw_colored_polygon(pts_shadow, Color(0, 0, 0, 0.25))

	# Haste e Cabeça da seta
	draw_line(base_stem, center, COLOR_ARROW, maxf(3.0, c_size * 0.08), true)
	var pts := PackedVector2Array([tip, left, right])
	draw_colored_polygon(pts, COLOR_ARROW)


func _draw_all_stars(offset_x: float, offset_y: float, c_size: float) -> void:
	if model == null or model.stars.is_empty():
		return

	for s_cell in model.stars:
		var is_visited: bool = model.visited_stars.has(s_cell)
		var center: Vector2 = _cell_to_center(s_cell, offset_x, offset_y, c_size)
		var star_radius: float = c_size * 0.30
		_draw_5point_star(center, star_radius, is_visited)


func _draw_5point_star(center: Vector2, radius: float, is_visited: bool) -> void:
	if is_visited:
		# Estrela coletada: brilho suave sob o caminho
		draw_circle(center, radius * 0.6, Color(COLOR_STAR_GOLD, 0.35))
		return

	# Pulso suave da estrela não coletada
	var pulse: float = 0.92 + 0.12 * sin(_anim_time * 4.0)
	var r_outer: float = radius * pulse
	var r_inner: float = r_outer * 0.42

	# Halo luminoso
	draw_circle(center, r_outer * 1.35, COLOR_STAR_GLOW)

	# Vértices da estrela de 5 pontas
	var pts := PackedVector2Array()
	var num_points: int = 10
	var angle_step: float = TAU / float(num_points)
	var start_rot: float = -PI * 0.5 # Apontando para o topo

	for i in range(num_points):
		var angle: float = start_rot + float(i) * angle_step
		var r: float = r_outer if (i % 2 == 0) else r_inner
		pts.append(center + Vector2(cos(angle), sin(angle)) * r)

	# Sombra projetada
	var pts_shadow := PackedVector2Array()
	for pt in pts:
		pts_shadow.append(pt + Vector2(1.5, 2.5))
	draw_colored_polygon(pts_shadow, Color(0, 0, 0, 0.20))

	# Preenchimento e Contorno
	draw_colored_polygon(pts, COLOR_STAR_GOLD)
	for i in range(num_points):
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % num_points]
		draw_line(p1, p2, COLOR_STAR_OUTLINE, 2.0, true)

	# Brilho central
	draw_circle(center, r_inner * 0.6, Color(1.0, 1.0, 0.85, 0.8))


func _draw_player_path(offset_x: float, offset_y: float, c_size: float) -> void:
	if model == null or model.player_path.is_empty():
		return

	var path_color: Color = COLOR_PATH_WIN if model.is_completed else COLOR_PATH_ACTIVE
	var inner_color: Color = COLOR_PATH_WIN_INNER if model.is_completed else COLOR_PATH_INNER
	var main_width: float = maxf(6.0, c_size * 0.34)
	var inner_width: float = maxf(2.0, c_size * 0.12)

	# Decompor o caminho em segmentos contíguos (saltando portais)
	var sub_paths: Array[PackedVector2Array] = []
	var current_sub := PackedVector2Array()
	current_sub.append(_cell_to_center(model.player_path[0], offset_x, offset_y, c_size))

	for i in range(1, model.player_path.size()):
		var prev: Vector2i = model.player_path[i - 1]
		var curr: Vector2i = model.player_path[i]

		# Se for um salto não-adjacente (como teleporte de portal), fecha a sub-linha atual
		if not model.is_adjacent(prev, curr):
			if current_sub.size() > 1:
				sub_paths.append(current_sub)
			current_sub = PackedVector2Array()
		current_sub.append(_cell_to_center(curr, offset_x, offset_y, c_size))

	if current_sub.size() > 0:
		sub_paths.append(current_sub)

	# Desenha todas as sub-linhas
	for sub in sub_paths:
		if sub.size() > 1:
			draw_polyline(sub, path_color, main_width, true)
			draw_polyline(sub, inner_color, inner_width, true)
		for pt in sub:
			draw_circle(pt, main_width * 0.5, path_color)
			draw_circle(pt, inner_width * 0.5, inner_color)

	# Tratamento visual especial para sobreposição em Pontes (Overpass Layer)
	for b_cell in model.bridges:
		if model.bridge_crossings.get(b_cell, {}).get("H", false) and model.bridge_crossings.get(b_cell, {}).get("V", false):
			var b_center: Vector2 = _cell_to_center(b_cell, offset_x, offset_y, c_size)
			# Redesenha o segmento horizontal no deck superior com destaque
			var p_left := Vector2(b_center.x - c_size * 0.5, b_center.y)
			var p_right := Vector2(b_center.x + c_size * 0.5, b_center.y)
			draw_line(p_left, p_right, path_color, main_width, true)
			draw_line(p_left, p_right, inner_color, inner_width, true)

	# Destaque na ponta atual do caminho (Head)
	if not model.player_path.is_empty() and not model.is_completed:
		var head_pt: Vector2 = _cell_to_center(model.player_path.back(), offset_x, offset_y, c_size)
		var head_pulse: float = 1.0 + 0.18 * sin(_anim_time * 6.0)
		draw_circle(head_pt, main_width * 0.75 * head_pulse, COLOR_PATH_HEAD_GLOW)
		draw_circle(head_pt, main_width * 0.55, COLOR_PATH_HEAD)
		draw_circle(head_pt, main_width * 0.25, Color(1.0, 1.0, 1.0, 0.95))


func _draw_bursts() -> void:
	for b in _burst_effects:
		var pos: Vector2 = b["pos"]
		var rad: float = float(b["radius"])
		var progress: float = float(b["life"]) / float(b["max_life"])
		var alpha: float = (1.0 - progress) * 0.8
		var col: Color = Color(b["color"], alpha)
		draw_arc(pos, rad, 0, TAU, 24, col, maxf(2.0, (1.0 - progress) * 5.0), true)


func _draw_all_clues(offset_x: float, offset_y: float, c_size: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		font = get_theme_default_font()
	var font_size: int = maxi(1, int(c_size * 0.44))
	var next_target: int = model.get_current_target()

	for cell in model.clues.keys():
		var cell_v := cell as Vector2i
		var center: Vector2 = _cell_to_center(cell_v, offset_x, offset_y, c_size)
		var num_val: int = int(model.clues[cell])

		var is_visited: bool = model.player_path.has(cell_v)
		var is_next: bool = (num_val == next_target and not model.is_completed)
		var is_start: bool = (num_val == 1)
		var is_end: bool = (num_val == model.max_number)

		var badge_color: Color = COLOR_CLUE_BG
		if model.is_completed:
			badge_color = COLOR_PATH_WIN
		elif is_visited:
			badge_color = COLOR_CLUE_VISITED
		elif is_next:
			badge_color = COLOR_CLUE_NEXT
		elif is_start:
			badge_color = COLOR_CLUE_START
		elif is_end:
			badge_color = COLOR_CLUE_END

		var badge_radius: float = c_size * 0.32

		# Halo indicador animado no próximo número a alcançar
		if is_next:
			var halo_pulse: float = 1.0 + 0.15 * sin(_anim_time * 5.0)
			draw_circle(center, badge_radius * 1.35 * halo_pulse, Color(badge_color, 0.35))
			draw_arc(center, badge_radius * 1.25 * halo_pulse, 0, TAU, 24, badge_color, 2.5, true)

		# Sombra do badge
		draw_circle(center + Vector2(1.5, 2.0), badge_radius, Color(0, 0, 0, 0.22))
		# Círculo do badge
		draw_circle(center, badge_radius, badge_color)
		# Anel branco sutil
		draw_arc(center, badge_radius - 1.0, 0, TAU, 24, Color(1, 1, 1, 0.45), 1.5, true)

		if font != null:
			var num_str: String = str(num_val)
			var string_size: Vector2 = font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos: Vector2 = center - string_size * 0.5 + Vector2(0, font.get_ascent(font_size))
			draw_string(font, text_pos, num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR_TEXT)
