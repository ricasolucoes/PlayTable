extends GridGame

## PegSolitaireGame: Resta Um 3D com Tabuleiro Circular Entalhado e Esferas Polidas de Âmbar

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const PegSolitaireRulesScript = preload("res://games/solitario/PegSolitaireRules.gd")

var grid_data: Grid2D
var selected_pos: Vector2i = Vector2i(-1, -1)
var valid_targets: Array[Dictionary] = []
var marbles_3d: Dictionary = {}

@onready var board_root: Node3D = $BoardRoot
@onready var marbles_root: Node3D = $MarblesRoot
@onready var pegs_label = $UI/VBoxContainer/PegsLabel

const CELL_SIZE: float = 0.75

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/Actions/BtnRestart
	_setup_3d_circular_board()
	build_touch_grid($UI/CenterContainer/TouchGrid, 7, 7, Vector2(44, 44),
		_on_cell_clicked, PegSolitaireRules.is_valid_cell)
	_start_new_game()

func _setup_3d_circular_board() -> void:
	for c in board_root.get_children(): c.queue_free()
	
	# Base circular de madeira nobre
	var base = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 3.2
	cyl.bottom_radius = 3.2
	cyl.height = 0.16
	cyl.radial_segments = 48
	base.mesh = cyl
	base.position = Vector3(0, -0.08, 0)
	base.material_override = MaterialFactory3D.get_wood_mahogany()
	board_root.add_child(base)
	
	# Friso central em nogueira
	var inner = MeshInstance3D.new()
	var inner_cyl = CylinderMesh.new()
	inner_cyl.top_radius = 2.9
	inner_cyl.bottom_radius = 2.9
	inner_cyl.height = 0.02
	inner_cyl.radial_segments = 48
	inner.mesh = inner_cyl
	inner.position = Vector3(0, 0.01, 0)
	inner.material_override = MaterialFactory3D.get_wood_walnut()
	board_root.add_child(inner)
	
	# Furos / Cavidades das 33 posições
	var start_x = -(7 * CELL_SIZE * 0.5) + (CELL_SIZE * 0.5)
	var start_z = -(7 * CELL_SIZE * 0.5) + (CELL_SIZE * 0.5)
	
	for r in range(7):
		for c in range(7):
			if PegSolitaireRules.is_valid_cell(r, c):
				var hole = MeshInstance3D.new()
				var h_cyl = CylinderMesh.new()
				h_cyl.top_radius = 0.22
				h_cyl.bottom_radius = 0.15
				h_cyl.height = 0.04
				hole.mesh = h_cyl
				hole.position = Vector3(start_x + (c * CELL_SIZE), 0.02, start_z + (r * CELL_SIZE))
				hole.material_override = MaterialFactory3D.get_obsidian()
				board_root.add_child(hole)

func _get_cell_pos_3d(r: int, c: int) -> Vector3:
	var start_x = -(7 * CELL_SIZE * 0.5) + (CELL_SIZE * 0.5)
	var start_z = -(7 * CELL_SIZE * 0.5) + (CELL_SIZE * 0.5)
	return Vector3(start_x + (c * CELL_SIZE), 0.14, start_z + (r * CELL_SIZE))

func _start_new_game() -> void:
	game_over = false
	selected_pos = Vector2i(-1, -1)
	valid_targets.clear()
	btn_restart.hide()
	
	grid_data = PegSolitaireRules.create_initial_board()
	_sync_marbles_3d()
	_update_ui()
	status_label.text = "Toque em uma esfera para selecionar e saltar!"

func _sync_marbles_3d() -> void:
	for m in marbles_root.get_children(): m.queue_free()
	marbles_3d.clear()
	
	for r in range(7):
		for c in range(7):
			if grid_data.get_cell(r, c) == 1:
				var marble = preload("res://shared/3d/Token3D.tscn").instantiate()
				marble.token_type = "sphere"
				marble.material_name = "amber"
				marble.position = _get_cell_pos_3d(r, c)
				marbles_root.add_child(marble)
				marbles_3d[Vector2i(r, c)] = marble

func _update_ui() -> void:
	var pegs_count = PegSolitaireRules.count_pegs(grid_data)
	pegs_label.text = "Esferas Restantes: %d / 32" % pegs_count

func _on_cell_clicked(r: int, c: int):
	if game_over: return
	var clicked_pos = Vector2i(r, c)
	
	for vt in valid_targets:
		if vt["land"] == clicked_pos:
			_execute_jump(selected_pos, vt)
			return
			
	var val = grid_data.get_cell(r, c)
	if val == 1:
		selected_pos = clicked_pos
		valid_targets = PegSolitaireRules.get_valid_moves_for_peg(grid_data, selected_pos)
		
		# Destaca esfera selecionada
		for pos in marbles_3d.keys():
			var m = marbles_3d[pos] as Token3D
			m.highlight(pos == selected_pos)
			
		if valid_targets.is_empty():
			status_label.text = "Esta esfera não tem saltos possíveis."
		else:
			status_label.text = "Selecione o furo de destino iluminado!"
	else:
		selected_pos = Vector2i(-1, -1)
		valid_targets.clear()
		for pos in marbles_3d.keys():
			marbles_3d[pos].highlight(false)

func _execute_jump(from_pos: Vector2i, target_dict: Dictionary) -> void:
	var to_pos = target_dict["land"]
	var jumped_pos = target_dict["over"]
	
	grid_data.set_cell(from_pos.x, from_pos.y, 0)
	grid_data.set_cell(jumped_pos.x, jumped_pos.y, 0)
	grid_data.set_cell(to_pos.x, to_pos.y, 1)
	
	var moving_marble = marbles_3d.get(from_pos)
	if moving_marble:
		marbles_3d.erase(from_pos)
		marbles_3d[to_pos] = moving_marble
		moving_marble.jump_to(_get_cell_pos_3d(to_pos.x, to_pos.y), 0.6, 0.35)
		moving_marble.highlight(false)
		
	var jumped_marble = marbles_3d.get(jumped_pos)
	if jumped_marble:
		var tween = create_tween()
		tween.tween_property(jumped_marble, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
		tween.tween_callback(func(): jumped_marble.queue_free())
		marbles_3d.erase(jumped_pos)
		
	selected_pos = Vector2i(-1, -1)
	valid_targets.clear()
	_update_ui()
	
	if not PegSolitaireRules.has_any_valid_moves(grid_data):
		_end_game()

func _end_game() -> void:
	var remaining: int = PegSolitaireRules.count_pegs(grid_data)
	if remaining == 1:
		finish_game("🏆 Incrível! Apenas 1 esfera restante! Vitória perfeita!", true)
	elif remaining <= 3:
		finish_game("Muito bem! Restaram apenas %d esferas." % remaining)
	else:
		finish_game("Fim de Jogo! Restaram %d esferas." % remaining)
