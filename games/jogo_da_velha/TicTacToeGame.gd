extends Control

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const TicTacToeRulesScript = preload("res://games/jogo_da_velha/TicTacToeRules.gd")

var grid_data: Grid2D
var game_over: bool = false

@onready var grid_container = $VBoxContainer/CenterContainer/Grid
@onready var status = $VBoxContainer/Status

func _ready():
	grid_data = Grid2D.new(3, 3, 0)
	for i in range(9):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 100)
		btn.add_theme_font_size_override("font_size", 64)
		btn.pivot_offset = Vector2(50, 50)
		btn.pressed.connect(_on_cell_pressed.bind(i, btn))
		grid_container.add_child(btn)

func _animate_move(btn: Button, text: String, color: Color):
	btn.text = text
	btn.add_theme_color_override("font_color", color)
	var tween = get_tree().create_tween()
	btn.scale = Vector2(0.5, 0.5)
	tween.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)

func _on_cell_pressed(idx: int, btn: Button):
	if game_over or grid_data.cells[idx] != 0: return
	
	# Jogada do Jogador (X = 1)
	grid_data.cells[idx] = 1
	_animate_move(btn, "X", Color(0.9, 0.2, 0.3))
	
	if TicTacToeRules.check_win(grid_data, 1):
		_end_game("Você Venceu!")
		return
	if TicTacToeRules.is_draw(grid_data):
		_end_game("Empate!")
		return
		
	status.text = "Vez da IA (O)..."
	game_over = true
	await get_tree().create_timer(0.4).timeout
	game_over = false
	
	# Jogada da IA (O = 2)
	var ai_move = TicTacToeRules.get_best_move(grid_data, 2)
	if ai_move != -1:
		grid_data.cells[ai_move] = 2
		_animate_move(grid_container.get_child(ai_move), "O", Color(0.2, 0.6, 0.9))
		
		if TicTacToeRules.check_win(grid_data, 2):
			_end_game("IA Venceu!")
			return
		if TicTacToeRules.is_draw(grid_data):
			_end_game("Empate!")
			return
			
	status.text = "Sua Vez (X)"

func _end_game(msg: String):
	game_over = true
	status.text = msg

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
