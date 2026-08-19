extends Control

## TicTacToeGame: Jogo da Velha com Tabuleiro 3D e Peças Esculpidas

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const TicTacToeRulesScript = preload("res://games/jogo_da_velha/TicTacToeRules.gd")

var grid_data: Grid2D
var game_over: bool = false
var pieces_3d: Dictionary = {}

@onready var env_3d: TabletopEnvironment3D = $TabletopEnvironment3D
@onready var board_3d: Board3D = $Board3D
@onready var pieces_root: Node3D = $PiecesRoot
@onready var status_label = $UI/VBoxContainer/StatusLabel
@onready var btn_restart = $UI/VBoxContainer/BtnRestart
@onready var grid_touch_container = $UI/CenterContainer/GridTouchContainer

func _ready():
	grid_data = Grid2D.new(3, 3, 0)
	board_3d.setup_board(3, 3, 1.4, "wood_checkered")
	_setup_touch_grid()
	_start_new_game()

func _setup_touch_grid():
	for c in grid_touch_container.get_children(): c.queue_free()
	for i in range(9):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(110, 110)
		btn.flat = true
		btn.pressed.connect(_on_cell_pressed.bind(i))
		grid_touch_container.add_child(btn)

func _start_new_game():
	game_over = false
	grid_data = Grid2D.new(3, 3, 0)
	btn_restart.hide()
	status_label.text = "Sua Vez (Rubi X)"
	
	for c in pieces_root.get_children(): c.queue_free()
	pieces_3d.clear()
	
	for r in range(3):
		for c in range(3):
			board_3d.reset_cell_material(r, c)

func _spawn_piece_3d(idx: int, player_id: int):
	var r = idx / 3
	var c = idx % 3
	var target_pos = board_3d.get_cell_position_3d(r, c, 0.12)
	var spawn_pos = target_pos + Vector3(0, 3.5, 0)
	
	var piece = preload("res://shared/3d/Token3D.tscn").instantiate()
	piece.token_type = "cylinder"
	piece.material_name = "ruby" if player_id == 1 else "sapphire"
	piece.position = spawn_pos
	pieces_root.add_child(piece)
	pieces_3d[idx] = piece
	piece.drop_to(target_pos, 0.4)

func _on_cell_pressed(idx: int):
	if game_over or grid_data.cells[idx] != 0: return
	
	# Jogada do Jogador (X = 1)
	grid_data.cells[idx] = 1
	_spawn_piece_3d(idx, 1)
	
	if TicTacToeRules.check_win(grid_data, 1):
		_end_game("Você Venceu!", true)
		return
	if TicTacToeRules.is_draw(grid_data):
		_end_game("Empate!", false)
		return
		
	status_label.text = "Vez da IA (Safira O)..."
	game_over = true
	await get_tree().create_timer(0.45).timeout
	game_over = false
	
	# Jogada da IA (O = 2)
	var ai_move = TicTacToeRules.get_best_move(grid_data, 2)
	if ai_move != -1:
		grid_data.cells[ai_move] = 2
		_spawn_piece_3d(ai_move, 2)
		
		if TicTacToeRules.check_win(grid_data, 2):
			_end_game("IA Venceu!", false)
			return
		if TicTacToeRules.is_draw(grid_data):
			_end_game("Empate!", false)
			return
			
	status_label.text = "Sua Vez (Rubi X)"

func _end_game(msg: String, is_player_win: bool):
	game_over = true
	status_label.text = msg
	btn_restart.show()
	if is_player_win:
		env_3d.celebrate_win()

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
