extends Control

## MinesweeperGame: Campo Minado 3D com Teclas Mecânicas Táteis, Pinos de Bandeira e Minas Explosivas

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const MinesweeperRulesScript = preload("res://games/campo_minado/MinesweeperRules.gd")

var grid_data: Grid2D
var first_click: bool = true
var is_flag_mode: bool = false
var game_over: bool = false
var game_won: bool = false
var elapsed_time: float = 0.0
var timer_active: bool = false

var tiles_3d: Dictionary = {}
var flags_3d: Dictionary = {}

@onready var env_3d: TabletopEnvironment3D = $TabletopEnvironment3D
@onready var board_3d: Board3D = $Board3D
@onready var flags_root: Node3D = $FlagsRoot
@onready var status_label = $UI/VBoxContainer/StatusLabel
@onready var mines_label = $UI/VBoxContainer/Header/MinesLabel
@onready var timer_label = $UI/VBoxContainer/Header/TimerLabel
@onready var btn_mode = $UI/Controls/BtnMode
@onready var btn_smiley = $UI/VBoxContainer/Header/BtnSmiley
@onready var touch_grid = $UI/CenterContainer/TouchGrid

const NUMBER_COLORS = [
	Color(0, 0, 0, 0),
	Color(0.2, 0.6, 1.0),   # 1 Azul
	Color(0.2, 0.85, 0.3),  # 2 Verde
	Color(0.95, 0.25, 0.2), # 3 Vermelho
	Color(0.6, 0.2, 0.9),   # 4 Roxo
	Color(0.9, 0.5, 0.1),   # 5 Laranja
	Color(0.1, 0.8, 0.8),   # 6 Ciano
	Color(0.1, 0.1, 0.1),   # 7 Preto
	Color(0.6, 0.6, 0.6)    # 8 Cinza
]

func _ready() -> void:
	board_3d.setup_board(MinesweeperRules.ROWS, MinesweeperRules.COLS, 0.75, "slate_grid")
	_setup_touch_grid()
	_start_new_game()

func _process(delta: float) -> void:
	if timer_active and not game_over and not game_won:
		elapsed_time += delta
		timer_label.text = "⏱️ %03d" % int(elapsed_time)

func _setup_touch_grid() -> void:
	for c in touch_grid.get_children(): c.queue_free()
	for r in range(MinesweeperRules.ROWS):
		for c in range(MinesweeperRules.COLS):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(40, 40)
			btn.flat = true
			btn.pressed.connect(_on_cell_clicked.bind(r, c))
			touch_grid.add_child(btn)

func _start_new_game() -> void:
	first_click = true
	game_over = false
	game_won = false
	elapsed_time = 0.0
	timer_active = false
	timer_label.text = "⏱️ 000"
	btn_smiley.text = "🙂"
	status_label.text = "Toque em uma tecla mecânica para iniciar!"
	
	for f in flags_root.get_children(): f.queue_free()
	flags_3d.clear()
	
	for r in range(MinesweeperRules.ROWS):
		for c in range(MinesweeperRules.COLS):
			board_3d.reset_cell_material(r, c)
			var tile_mesh = board_3d.cell_meshes[r][c] as MeshInstance3D
			tile_mesh.position.y = 0.06 # Tecla elevada
			tile_mesh.material_override = MaterialFactory3D.get_plastic(Color(0.28, 0.32, 0.38), true)
			
	grid_data = MinesweeperRules.create_empty_grid()
	_update_header_mines()

func _update_header_mines() -> void:
	var flagged = MinesweeperRules.count_flagged(grid_data)
	mines_label.text = "💣 %02d" % max(0, MinesweeperRules.TOTAL_MINES - flagged)

func _on_cell_clicked(r: int, c: int):
	if game_over or game_won: return
	var cell = grid_data.get_cell(r, c)
	
	if is_flag_mode:
		if not cell["is_revealed"]:
			cell["is_flagged"] = not cell["is_flagged"]
			_update_flag_3d(r, c, cell["is_flagged"])
			_update_header_mines()
			_check_win_condition()
		return
		
	if cell["is_flagged"]: return
	
	if first_click:
		first_click = false
		MinesweeperRules.generate_mines(grid_data, r, c)
		timer_active = true
		status_label.text = "Campo desarmado!"
		
	if cell["is_mine"]:
		_trigger_game_over(r, c)
		return
		
	MinesweeperRules.reveal_cell(grid_data, r, c)
	_sync_revealed_3d()
	_check_win_condition()

func _update_flag_3d(r: int, c: int, is_flagged: bool) -> void:
	var pos = Vector2i(r, c)
	if is_flagged:
		var flag = preload("res://shared/3d/Token3D.tscn").instantiate()
		flag.token_type = "pawn"
		flag.material_name = "ruby"
		flag.position = board_3d.get_cell_position_3d(r, c, 0.15)
		flags_root.add_child(flag)
		flags_3d[pos] = flag
	else:
		if flags_3d.has(pos):
			flags_3d[pos].queue_free()
			flags_3d.erase(pos)

func _sync_revealed_3d() -> void:
	for r in range(MinesweeperRules.ROWS):
		for c in range(MinesweeperRules.COLS):
			var cell = grid_data.get_cell(r, c)
			if cell["is_revealed"]:
				var tile = board_3d.cell_meshes[r][c] as MeshInstance3D
				# Tecla afunda ao ser pressionada
				var tween = create_tween()
				tween.tween_property(tile, "position:y", 0.01, 0.15)
				
				var count = cell["adjacent_mines"]
				if count > 0:
					var mat = StandardMaterial3D.new()
					mat.albedo_color = NUMBER_COLORS[count]
					mat.emission_enabled = true
					mat.emission = NUMBER_COLORS[count]
					mat.emission_energy_multiplier = 0.5
					tile.material_override = mat
				else:
					tile.material_override = MaterialFactory3D.get_plastic(Color(0.14, 0.16, 0.2), false)

func _trigger_game_over(hit_r: int, hit_c: int) -> void:
	game_over = true
	timer_active = false
	btn_smiley.text = "😵"
	status_label.text = "💥 BOOM! Você detonou uma mina!"
	
	for r in range(MinesweeperRules.ROWS):
		for c in range(MinesweeperRules.COLS):
			var cell = grid_data.get_cell(r, c)
			if cell["is_mine"]:
				var tile = board_3d.cell_meshes[r][c] as MeshInstance3D
				tile.material_override = MaterialFactory3D.get_glow(Color(1.0, 0.2, 0.1), 3.0)

func _check_win_condition() -> void:
	if MinesweeperRules.check_win(grid_data):
		game_won = true
		timer_active = false
		btn_smiley.text = "😎"
		status_label.text = "🏆 Campo 100%% Desarmado! Vitória em %d segundos!" % int(elapsed_time)
		env_3d.celebrate_win()

func _on_btn_mode_pressed() -> void:
	is_flag_mode = not is_flag_mode
	if is_flag_mode:
		btn_mode.text = "Modo: 🚩 Bandeira"
		btn_mode.self_modulate = Color(0.95, 0.4, 0.4)
	else:
		btn_mode.text = "Modo: ⛏️ Revelar"
		btn_mode.self_modulate = Color(0.4, 0.7, 0.95)

func _on_btn_smiley_pressed() -> void:
	_start_new_game()

func _on_btn_back_pressed() -> void:
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
