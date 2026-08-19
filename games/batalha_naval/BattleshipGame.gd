extends Control

const GRID_SIZE = 10

# Ship specifications: name, size
const SHIP_DEFS = [
	{"name": "Porta-Aviões", "size": 5},
	{"name": "Encouraçado", "size": 4},
	{"name": "Cruzador", "size": 3},
	{"name": "Submarino", "size": 3},
	{"name": "Destroyer", "size": 2}
]

# Cell states:
# 0 = Empty
# 1 = Ship present (hidden from enemy)
# 2 = Miss (water)
# 3 = Hit (ship damaged)

var player_grid = []
var ai_grid = []
var player_ships = [] # Array of dicts: {name, size, cells: [Vector2i], hits: 0, sunk: false}
var ai_ships = []

var is_combat_phase: bool = false
var is_player_turn: bool = true
var game_over: bool = false
var current_view: String = "radar" # "radar" or "fleet"

# AI Hunt & Target state
var ai_hit_stack: Array = []
var ai_shots_fired: Array = [] # Array of Vector2i

@onready var grid_radar = $VBoxContainer/CenterContainer/RadarContainer/GridRadar
@onready var grid_fleet = $VBoxContainer/CenterContainer/FleetContainer/GridFleet
@onready var radar_container = $VBoxContainer/CenterContainer/RadarContainer
@onready var fleet_container = $VBoxContainer/CenterContainer/FleetContainer
@onready var status_label = $VBoxContainer/StatusLabel
@onready var fleet_info_label = $VBoxContainer/FleetInfoLabel
@onready var btn_tab_radar = $VBoxContainer/TabButtons/BtnTabRadar
@onready var btn_tab_fleet = $VBoxContainer/TabButtons/BtnTabFleet
@onready var btn_start = $VBoxContainer/ControlButtons/BtnStart
@onready var btn_randomize = $VBoxContainer/ControlButtons/BtnRandomize
@onready var btn_restart = $VBoxContainer/ControlButtons/BtnRestart

var radar_buttons = []
var fleet_buttons = []

func _ready():
	_create_grid_ui()
	_start_setup_phase()

func _create_grid_ui():
	for c in grid_radar.get_children(): c.queue_free()
	for c in grid_fleet.get_children(): c.queue_free()
	radar_buttons.clear()
	fleet_buttons.clear()
	
	for r in range(GRID_SIZE):
		var r_row = []
		var f_row = []
		for c in range(GRID_SIZE):
			# Radar button (Player attacks AI)
			var r_btn = Button.new()
			r_btn.custom_minimum_size = Vector2(50, 50)
			r_btn.add_theme_font_size_override("font_size", 24)
			r_btn.pressed.connect(_on_radar_cell_clicked.bind(r, c))
			grid_radar.add_child(r_btn)
			r_row.append(r_btn)
			
			# Fleet button (Display player's ships & enemy attacks)
			var f_btn = Button.new()
			f_btn.custom_minimum_size = Vector2(50, 50)
			f_btn.add_theme_font_size_override("font_size", 24)
			grid_fleet.add_child(f_btn)
			f_row.append(f_btn)
			
		radar_buttons.append(r_row)
		fleet_buttons.append(f_row)

func _start_setup_phase():
	is_combat_phase = false
	game_over = false
	is_player_turn = true
	ai_hit_stack.clear()
	ai_shots_fired.clear()
	
	btn_start.show()
	btn_randomize.show()
	btn_restart.hide()
	
	_randomize_player_fleet()
	_randomize_ai_fleet()
	
	_switch_view("fleet")
	status_label.text = "Posicione sua frota e clique em Iniciar!"
	_update_fleet_info()

func _switch_view(view: String):
	current_view = view
	if view == "radar":
		radar_container.show()
		fleet_container.hide()
		btn_tab_radar.add_theme_color_override("font_color", Color(0.2, 0.8, 0.9))
		btn_tab_fleet.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	else:
		radar_container.hide()
		fleet_container.show()
		btn_tab_fleet.add_theme_color_override("font_color", Color(0.2, 0.8, 0.9))
		btn_tab_radar.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_update_ui()

func _randomize_player_fleet():
	player_grid.clear()
	for r in range(GRID_SIZE):
		var row = []
		for c in range(GRID_SIZE): row.append(0)
		player_grid.append(row)
	player_ships = _place_all_ships(player_grid)
	_update_ui()

func _randomize_ai_fleet():
	ai_grid.clear()
	for r in range(GRID_SIZE):
		var row = []
		for c in range(GRID_SIZE): row.append(0)
		ai_grid.append(row)
	ai_ships = _place_all_ships(ai_grid)

func _place_all_ships(grid_data: Array) -> Array:
	var placed_ships = []
	for s_def in SHIP_DEFS:
		var placed = false
		var attempts = 0
		while not placed and attempts < 200:
			attempts += 1
			var horizontal = randi() % 2 == 0
			var size = s_def["size"]
			var max_r = GRID_SIZE - 1 if horizontal else GRID_SIZE - size
			var max_c = GRID_SIZE - size if horizontal else GRID_SIZE - 1
			var r = randi() % (max_r + 1)
			var c = randi() % (max_c + 1)
			
			var can_place = true
			var cells = []
			for i in range(size):
				var cr = r if horizontal else r + i
				var cc = c + i if horizontal else c
				if grid_data[cr][cc] != 0:
					can_place = false
					break
				cells.append(Vector2i(cr, cc))
				
			if can_place:
				for cell in cells:
					grid_data[cell.x][cell.y] = 1
				placed_ships.append({
					"name": s_def["name"],
					"size": size,
					"cells": cells,
					"hits": 0,
					"sunk": false
				})
				placed = true
	return placed_ships

func _update_ui():
	# Update Radar UI
	for r in range(GRID_SIZE):
		for c in range(GRID_SIZE):
			var btn = radar_buttons[r][c]
			var val = ai_grid[r][c]
			if val == 2:
				btn.text = "🌊"
				btn.self_modulate = Color(0.2, 0.4, 0.7)
			elif val == 3:
				btn.text = "💥"
				btn.self_modulate = Color(0.9, 0.2, 0.2)
			else:
				btn.text = ""
				btn.self_modulate = Color(0.18, 0.24, 0.3)
				
	# Update Fleet UI
	for r in range(GRID_SIZE):
		for c in range(GRID_SIZE):
			var btn = fleet_buttons[r][c]
			var val = player_grid[r][c]
			if val == 1:
				btn.text = "🚢"
				btn.self_modulate = Color(0.3, 0.6, 0.4)
			elif val == 2:
				btn.text = "🌊"
				btn.self_modulate = Color(0.2, 0.4, 0.7)
			elif val == 3:
				btn.text = "🔥"
				btn.self_modulate = Color(0.9, 0.3, 0.1)
			else:
				btn.text = ""
				btn.self_modulate = Color(0.18, 0.24, 0.3)

func _update_fleet_info():
	var ai_sunk = 0
	for s in ai_ships:
		if s["sunk"]: ai_sunk += 1
	var player_sunk = 0
	for s in player_ships:
		if s["sunk"]: player_sunk += 1
	fleet_info_label.text = "Inimigo Afundado: %d/5  |  Sua Frota Afundada: %d/5" % [ai_sunk, player_sunk]

func _on_btn_start_pressed():
	is_combat_phase = true
	btn_start.hide()
	btn_randomize.hide()
	_switch_view("radar")
	status_label.text = "Batalha Iniciada! Dispare no Radar Inimigo."

func _on_btn_randomize_pressed():
	_randomize_player_fleet()

func _on_radar_cell_clicked(r: int, c: int):
	if not is_combat_phase or not is_player_turn or game_over:
		return
		
	var cell_val = ai_grid[r][c]
	if cell_val == 2 or cell_val == 3:
		# Already attacked
		return
		
	if cell_val == 1:
		ai_grid[r][c] = 3 # Hit!
		_register_hit(Vector2i(r, c), ai_ships, true)
	else:
		ai_grid[r][c] = 2 # Miss!
		status_label.text = "Água! Vez do Inimigo..."
		
	_update_ui()
	_update_fleet_info()
	
	if _check_battle_over():
		return
		
	is_player_turn = false
	await get_tree().create_timer(0.6).timeout
	_play_ai_attack()

func _register_hit(pos: Vector2i, fleet: Array, is_player_attacking: bool):
	for s in fleet:
		if pos in s["cells"]:
			s["hits"] += 1
			if s["hits"] >= s["size"]:
				s["sunk"] = true
				if is_player_attacking:
					status_label.text = "🎯 Você afundou o %s inimigo!" % s["name"]
				else:
					status_label.text = "⚠️ O inimigo afundou seu %s!" % s["name"]
			else:
				if is_player_attacking:
					status_label.text = "💥 Fogo certeiro no navio inimigo!"
				else:
					status_label.text = "🔥 O inimigo atingiu seu navio!"
			break

func _play_ai_attack():
	if game_over: return
	
	var shot_pos = Vector2i(-1, -1)
	
	# If AI has target in stack
	while ai_hit_stack.size() > 0:
		var candidate = ai_hit_stack.pop_back()
		if candidate.x >= 0 and candidate.x < GRID_SIZE and candidate.y >= 0 and candidate.y < GRID_SIZE:
			if not (candidate in ai_shots_fired):
				shot_pos = candidate
				break
				
	# If no stack target, pick checkerboard parity cell
	if shot_pos == Vector2i(-1, -1):
		var candidates = []
		for r in range(GRID_SIZE):
			for c in range(GRID_SIZE):
				var p = Vector2i(r, c)
				if not (p in ai_shots_fired):
					if (r + c) % 2 == 0:
						candidates.append(p)
		if candidates.size() == 0:
			for r in range(GRID_SIZE):
				for c in range(GRID_SIZE):
					var p = Vector2i(r, c)
					if not (p in ai_shots_fired):
						candidates.append(p)
		candidates.shuffle()
		if candidates.size() > 0:
			shot_pos = candidates[0]
			
	if shot_pos == Vector2i(-1, -1):
		return
		
	ai_shots_fired.append(shot_pos)
	var cell_val = player_grid[shot_pos.x][shot_pos.y]
	
	if cell_val == 1:
		player_grid[shot_pos.x][shot_pos.y] = 3 # Hit
		_register_hit(shot_pos, player_ships, false)
		# Add 4 neighbors to hit stack
		ai_hit_stack.append(Vector2i(shot_pos.x + 1, shot_pos.y))
		ai_hit_stack.append(Vector2i(shot_pos.x - 1, shot_pos.y))
		ai_hit_stack.append(Vector2i(shot_pos.x, shot_pos.y + 1))
		ai_hit_stack.append(Vector2i(shot_pos.x, shot_pos.y - 1))
	else:
		player_grid[shot_pos.x][shot_pos.y] = 2 # Miss
		
	_update_ui()
	_update_fleet_info()
	
	if _check_battle_over():
		return
		
	is_player_turn = true
	if current_view == "radar":
		status_label.text = "Sua Vez! Escolha as coordenadas no Radar."

func _check_battle_over() -> bool:
	var ai_all_sunk = true
	for s in ai_ships:
		if not s["sunk"]:
			ai_all_sunk = false
			break
			
	var player_all_sunk = true
	for s in player_ships:
		if not s["sunk"]:
			player_all_sunk = false
			break
			
	if ai_all_sunk:
		_end_game("🏆 Vitória Total! Você destruiu a frota inimiga!")
		return true
	if player_all_sunk:
		_end_game("💀 Derrota! Toda a sua frota foi destruída.")
		return true
		
	return false

func _end_game(msg: String):
	game_over = true
	status_label.text = msg
	btn_restart.show()

func _on_btn_tab_radar_pressed():
	_switch_view("radar")

func _on_btn_tab_fleet_pressed():
	_switch_view("fleet")

func _on_btn_restart_pressed():
	_start_setup_phase()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
