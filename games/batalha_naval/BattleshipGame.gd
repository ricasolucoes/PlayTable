extends Control

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const BattleshipRulesScript = preload("res://games/batalha_naval/BattleshipRules.gd")

var player_grid: Grid2D
var ai_grid: Grid2D
var player_ships: Array[Dictionary] = []
var ai_ships: Array[Dictionary] = []

var is_combat_phase: bool = false
var is_player_turn: bool = true
var game_over: bool = false
var current_view: String = "radar"

var ai_hit_stack: Array = []
var ai_shots_fired: Array = []

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
	player_grid = BattleshipRules.create_empty_grid()
	ai_grid = BattleshipRules.create_empty_grid()
	_create_grid_ui()
	_start_setup_phase()

func _create_grid_ui():
	for c in grid_radar.get_children(): c.queue_free()
	for c in grid_fleet.get_children(): c.queue_free()
	radar_buttons.clear()
	fleet_buttons.clear()
	
	for r in range(BattleshipRules.GRID_SIZE):
		var r_row = []
		var f_row = []
		for c in range(BattleshipRules.GRID_SIZE):
			var r_btn = Button.new()
			r_btn.custom_minimum_size = Vector2(50, 50)
			r_btn.add_theme_font_size_override("font_size", 24)
			r_btn.pressed.connect(_on_radar_cell_clicked.bind(r, c))
			grid_radar.add_child(r_btn)
			r_row.append(r_btn)
			
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
	
	player_ships = BattleshipRules.place_all_ships_randomly(player_grid)
	ai_ships = BattleshipRules.place_all_ships_randomly(ai_grid)
	
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

func _update_ui():
	for r in range(BattleshipRules.GRID_SIZE):
		for c in range(BattleshipRules.GRID_SIZE):
			var r_btn = radar_buttons[r][c]
			var ai_val = ai_grid.get_cell(r, c)
			if ai_val == 2:
				r_btn.text = "🌊"
				r_btn.self_modulate = Color(0.2, 0.4, 0.7)
			elif ai_val == 3:
				r_btn.text = "💥"
				r_btn.self_modulate = Color(0.9, 0.2, 0.2)
			else:
				r_btn.text = ""
				r_btn.self_modulate = Color(0.18, 0.24, 0.3)
				
			var f_btn = fleet_buttons[r][c]
			var p_val = player_grid.get_cell(r, c)
			if p_val == 1:
				f_btn.text = "🚢"
				f_btn.self_modulate = Color(0.3, 0.6, 0.4)
			elif p_val == 2:
				f_btn.text = "🌊"
				f_btn.self_modulate = Color(0.2, 0.4, 0.7)
			elif p_val == 3:
				f_btn.text = "🔥"
				f_btn.self_modulate = Color(0.9, 0.3, 0.1)
			else:
				f_btn.text = ""
				f_btn.self_modulate = Color(0.18, 0.24, 0.3)

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
	player_ships = BattleshipRules.place_all_ships_randomly(player_grid)
	_update_ui()

func _on_radar_cell_clicked(r: int, c: int):
	if not is_combat_phase or not is_player_turn or game_over: return
	
	var shot_res = BattleshipRules.register_shot(ai_grid, Vector2i(r, c), ai_ships)
	if not shot_res["valid"]: return
	
	if shot_res["is_hit"]:
		if shot_res["sunk_ship"] != null:
			status_label.text = "🎯 Você afundou o %s inimigo!" % shot_res["sunk_ship"]["name"]
		else:
			status_label.text = "💥 Fogo certeiro no navio inimigo!"
	else:
		status_label.text = "Água! Vez do Inimigo..."
		
	_update_ui()
	_update_fleet_info()
	
	if shot_res["all_sunk"]:
		_end_game("🏆 Vitória Total! Você destruiu a frota inimiga!")
		return
		
	is_player_turn = false
	await get_tree().create_timer(0.6).timeout
	_play_ai_attack()

func _play_ai_attack():
	if game_over: return
	
	var shot_pos = BattleshipRules.get_ai_shot(ai_hit_stack, ai_shots_fired)
	if shot_pos == Vector2i(-1, -1): return
	
	ai_shots_fired.append(shot_pos)
	var shot_res = BattleshipRules.register_shot(player_grid, shot_pos, player_ships)
	
	if shot_res["is_hit"]:
		# Adiciona vizinhos à pilha de caça
		ai_hit_stack.append(Vector2i(shot_pos.x + 1, shot_pos.y))
		ai_hit_stack.append(Vector2i(shot_pos.x - 1, shot_pos.y))
		ai_hit_stack.append(Vector2i(shot_pos.x, shot_pos.y + 1))
		ai_hit_stack.append(Vector2i(shot_pos.x, shot_pos.y - 1))
		
		if shot_res["sunk_ship"] != null:
			status_label.text = "⚠️ O inimigo afundou seu %s!" % shot_res["sunk_ship"]["name"]
		else:
			status_label.text = "🔥 O inimigo atingiu seu navio!"
			
	_update_ui()
	_update_fleet_info()
	
	if shot_res["all_sunk"]:
		_end_game("💀 Derrota! Toda a sua frota foi destruída.")
		return
		
	is_player_turn = true
	if current_view == "radar":
		status_label.text = "Sua Vez! Escolha as coordenadas no Radar."

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
