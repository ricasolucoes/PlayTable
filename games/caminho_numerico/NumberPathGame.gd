class_name NumberPathGame
extends BaseGame

@onready var num_board: NumberPathBoard = $VBoxContainer/CenterContainer/NumberPathBoard
@onready var level_label: Label = $VBoxContainer/BottomBar/LevelLabel
@onready var top_bar_voltar: Button = $VBoxContainer/TopBar/BtnVoltar
@onready var top_bar_restart: Button = $VBoxContainer/TopBar/BtnRestart
@onready var top_bar_status: Label = $VBoxContainer/TopBar/StatusLabel

var current_level: int = 1
var base_xp: int = 50

func _ready() -> void:
	status_label = top_bar_status
	btn_restart = top_bar_restart
	
	if top_bar_restart:
		top_bar_restart.pressed.connect(_start_new_game)
	if top_bar_voltar:
		top_bar_voltar.pressed.connect(_on_btn_voltar_pressed)
	
	if num_board:
		num_board.level_completed.connect(_on_level_completed)
		
	_start_new_game()

func _start_new_game() -> void:
	if status_label:
		status_label.text = tr("GAME_DESC_NUMBER_PATH")
	if level_label:
		level_label.text = tr("LEVEL") + " " + str(current_level)
		
	_generate_and_setup_puzzle()

func _generate_and_setup_puzzle() -> void:
	# Level 1-2: 3x3
	# Level 3-4: 4x4
	# Level 5+: 5x5
	var size = 3
	var num_clues = 4
	
	if current_level >= 5:
		size = 5
		num_clues = 6 + (current_level - 5) / 2
		num_clues = mini(num_clues, 15)
	elif current_level >= 3:
		size = 4
		num_clues = 5
		
	var puzzle = _generate_path(size, size, num_clues)
	if num_board:
		num_board.setup_puzzle(size, size, puzzle)

func _generate_path(w: int, h: int, clues_count: int) -> Dictionary:
	var total_cells = w * h
	var path: Array[Vector2i] = []
	var grid = []
	for y in range(h):
		grid.append([])
		for x in range(w):
			grid[y].append(false)
			
	# Start cell
	var start_x = randi() % w
	var start_y = randi() % h
	# For odd sizes, to guarantee a path, start on majority parity
	if (w * h) % 2 != 0:
		while (start_x + start_y) % 2 != 0:
			start_x = randi() % w
			start_y = randi() % h
			
	var found = _dfs(start_x, start_y, w, h, grid, path)
	if not found:
		# Fallback to simple snake if DFS fails
		path.clear()
		for y in range(h):
			var rx = range(w) if y % 2 == 0 else range(w - 1, -1, -1)
			for x in rx:
				path.append(Vector2i(x, y))
				
	# Pick clues
	var clues = {}
	clues[path[0]] = 1
	clues[path.back()] = clues_count
	
	if clues_count > 2:
		var available_indices = range(1, total_cells - 1)
		available_indices.shuffle()
		var chosen_indices = available_indices.slice(0, clues_count - 2)
		chosen_indices.sort()
		
		for i in range(chosen_indices.size()):
			clues[path[chosen_indices[i]]] = i + 2
			
	return clues

func _dfs(x: int, y: int, w: int, h: int, grid: Array, path: Array[Vector2i]) -> bool:
	path.append(Vector2i(x, y))
	grid[y][x] = true
	
	if path.size() == w * h:
		return true
		
	var neighbors = []
	var dirs = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for dir in dirs:
		var nx = x + dir.x
		var ny = y + dir.y
		if nx >= 0 and nx < w and ny >= 0 and ny < h and not grid[ny][nx]:
			# count free neighbors
			var deg = 0
			for d2 in dirs:
				var nnx = nx + d2.x
				var nny = ny + d2.y
				if nnx >= 0 and nnx < w and nny >= 0 and nny < h and not grid[nny][nnx]:
					deg += 1
			neighbors.append({"deg": deg, "r": randf(), "pos": Vector2i(nx, ny)})
			
	# Sort by degree (Warnsdorff's heuristic)
	neighbors.sort_custom(func(a, b):
		if a.deg != b.deg: return a.deg < b.deg
		return a.r < b.r
	)
	
	for n in neighbors:
		if _dfs(n.pos.x, n.pos.y, w, h, grid, path):
			return true
			
	grid[y][x] = false
	path.pop_back()
	return false

func _on_level_completed() -> void:
	if status_label:
		status_label.text = tr("LABEL_YOU_WON")
		
	if AudioManager:
		AudioManager.play_victory()
		
	if GameEventBus:
		GameEventBus.match_finished.emit("caminho_numerico", true)
		GameEventBus.xp_gained.emit(base_xp + current_level * 10, "number_path_win")
		
	current_level += 1
	
	# Wait a bit then next level
	var t = get_tree().create_timer(1.5)
	t.timeout.connect(_start_new_game)
