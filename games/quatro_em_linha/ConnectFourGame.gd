extends Control

## ConnectFourGame: Quatro em Linha 3D com Rack Vertical e Queda Física de Fichas

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const ConnectFourRulesScript = preload("res://games/quatro_em_linha/ConnectFourRules.gd")

var grid_data: Grid2D
var is_player_turn: bool = true
var game_over: bool = false
var pieces_3d: Array = []

@onready var env_3d: TabletopEnvironment3D = $TabletopEnvironment3D
@onready var rack_root: Node3D = $RackRoot
@onready var pieces_root: Node3D = $PiecesRoot
@onready var status_label = $UI/VBoxContainer/StatusLabel
@onready var btn_restart = $UI/VBoxContainer/BtnRestart
@onready var col_buttons_container = $UI/CenterContainer/ColButtonsContainer

const COL_SPACING: float = 0.65
const ROW_SPACING: float = 0.65

func _ready():
	_setup_3d_rack()
	_setup_col_buttons()
	_start_new_game()

func _setup_3d_rack():
	# Moldura vertical do Quatro em Linha em 3D
	for c in rack_root.get_children(): c.queue_free()
	
	var total_w = ConnectFourRules.COLS * COL_SPACING
	var total_h = ConnectFourRules.ROWS * ROW_SPACING
	
	# Placa frontal translúcida / azul metálica
	var rack_front = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(total_w + 0.4, total_h + 0.3, 0.1)
	rack_front.mesh = box
	rack_front.position = Vector3(0, total_h * 0.5 + 0.1, 0.08)
	rack_front.material_override = MaterialFactory3D.get_plastic(Color(0.1, 0.3, 0.7, 0.85), true)
	rack_root.add_child(rack_front)
	
	# Suportes laterais de madeira
	var base_stand = MeshInstance3D.new()
	var base_box = BoxMesh.new()
	base_box.size = Vector3(total_w + 0.8, 0.15, 1.2)
	base_stand.mesh = base_box
	base_stand.position = Vector3(0, 0.075, 0)
	base_stand.material_override = MaterialFactory3D.get_wood_walnut()
	rack_root.add_child(base_stand)

func _setup_col_buttons():
	for c in col_buttons_container.get_children(): c.queue_free()
	for col in range(ConnectFourRules.COLS):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(48, 380)
		btn.flat = true
		btn.pressed.connect(_on_col_pressed.bind(col))
		col_buttons_container.add_child(btn)

func _start_new_game():
	game_over = false
	is_player_turn = true
	grid_data = Grid2D.new(ConnectFourRules.ROWS, ConnectFourRules.COLS, 0)
	btn_restart.hide()
	status_label.text = "Sua Vez! (Vermelho)"
	
	for p in pieces_root.get_children(): p.queue_free()
	pieces_3d.clear()

func _on_col_pressed(col: int):
	if game_over or not is_player_turn: return
	
	if ConnectFourRules.can_drop(grid_data, col):
		_do_move(col, 1) # Jogador = 1 (Vermelho)
		
		if not game_over:
			is_player_turn = false
			status_label.text = "Vez do Computador (Ouro)..."
			await get_tree().create_timer(0.5).timeout
			var ai_col = ConnectFourRules.get_best_move(grid_data, 2)
			if ai_col != -1:
				_do_move(ai_col, 2) # Computador = 2 (Ouro)
			is_player_turn = true
			if not game_over:
				status_label.text = "Sua Vez! (Vermelho)"

func _do_move(col: int, player_id: int):
	var row = ConnectFourRules.drop_piece(grid_data, col, player_id)
	if row >= 0:
		_spawn_piece_3d(col, row, player_id)
		if ConnectFourRules.check_win(grid_data, row, col, player_id):
			game_over = true
			if player_id == 1:
				status_label.text = "Você Venceu!"
				env_3d.celebrate_win()
			else:
				status_label.text = "Computador Venceu!"
			btn_restart.show()
		elif ConnectFourRules.is_full(grid_data):
			game_over = true
			status_label.text = "Empate!"
			btn_restart.show()

func _spawn_piece_3d(col: int, row: int, player_id: int):
	var total_w = ConnectFourRules.COLS * COL_SPACING
	var start_x = -(total_w * 0.5) + (COL_SPACING * 0.5)
	
	var pos_x = start_x + (col * COL_SPACING)
	var target_y = 0.4 + (row * ROW_SPACING)
	var spawn_y = target_y + 4.5
	
	var piece = preload("res://shared/3d/Token3D.tscn").instantiate()
	piece.token_type = "cylinder"
	piece.material_name = "plastic_red" if player_id == 1 else "gold"
	piece.rotation_degrees = Vector3(90, 0, 0)
	piece.position = Vector3(pos_x, spawn_y, 0)
	pieces_root.add_child(piece)
	pieces_3d.append(piece)
	
	piece.drop_to(Vector3(pos_x, target_y, 0), 0.5)

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
