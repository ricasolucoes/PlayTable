extends Control

var board = [0,0,0, 0,0,0, 0,0,0]
var game_over = false

@onready var grid = $VBoxContainer/CenterContainer/Grid
@onready var status = $VBoxContainer/Status

func _ready():
	for i in range(9):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 100)
		btn.add_theme_font_size_override("font_size", 64)
		btn.pivot_offset = Vector2(50, 50)
		btn.pressed.connect(_on_cell_pressed.bind(i, btn))
		grid.add_child(btn)

func _animate_move(btn: Button, text: String, color: Color):
	btn.text = text
	btn.add_theme_color_override("font_color", color)
	var tween = get_tree().create_tween()
	btn.scale = Vector2(0.5, 0.5)
	tween.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)

func _on_cell_pressed(idx: int, btn: Button):
	if game_over or board[idx] != 0: return
	
	# Player move
	board[idx] = 1
	_animate_move(btn, "X", Color(0.9, 0.2, 0.3))
	
	if _check_win(1):
		_end_game("Você Venceu!")
		return
	if _is_draw():
		_end_game("Empate!")
		return
		
	status.text = "Vez da IA (O)..."
	game_over = true # Lock while AI thinks
	await get_tree().create_timer(0.4).timeout
	game_over = false
	
	# AI move
	var empty = []
	for i in range(9):
		if board[i] == 0: empty.append(i)
	
	if empty.size() > 0:
		empty.shuffle()
		var ai_move = empty[0]
		board[ai_move] = 2
		_animate_move(grid.get_child(ai_move), "O", Color(0.2, 0.6, 0.9))
		
		if _check_win(2):
			_end_game("IA Venceu!")
			return
		if _is_draw():
			_end_game("Empate!")
			return
			
	status.text = "Sua Vez (X)"

func _check_win(p: int) -> bool:
	var wins = [
		[0,1,2], [3,4,5], [6,7,8], # rows
		[0,3,6], [1,4,7], [2,5,8], # cols
		[0,4,8], [2,4,6]           # diags
	]
	for w in wins:
		if board[w[0]] == p and board[w[1]] == p and board[w[2]] == p:
			return true
	return false

func _is_draw() -> bool:
	for c in board:
		if c == 0: return false
	return true

func _end_game(msg: String):
	game_over = true
	status.text = msg

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
