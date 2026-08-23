extends GridGame

## BattleshipGame: Batalha Naval 3D com Radar Oceânico Tático e Marcadores Tridimensionais

const Grid2DScript = preload("res://shared/core_engine/board/Grid2D.gd")
const BattleshipRulesScript = preload("res://games/batalha_naval/BattleshipRules.gd")

var player_grid: Grid2D
var ai_grid: Grid2D
var player_ships: Array = []
var ai_ships: Array = []
var is_player_turn: bool = true
var viewing_radar: bool = true # true = Radar de Ataque (AI Grid), false = Frota Aliada (Player Grid)
var markers_3d: Dictionary = {}
var ships_3d: Array = []

@onready var board_3d: Board3D = $Board3D
@onready var markers_root: Node3D = $MarkersRoot
@onready var ships_root: Node3D = $ShipsRoot
@onready var fleet_info_label = $UI/VBoxContainer/FleetInfoLabel
@onready var btn_tab_radar = $UI/VBoxContainer/TabBar/BtnRadar
@onready var btn_tab_fleet = $UI/VBoxContainer/TabBar/BtnFleet

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/VBoxContainer/BtnRestart
	board_3d.setup_board(10, 10, 0.65, "ocean_radar")
	build_touch_grid($UI/CenterContainer/TouchGrid, 10, 10, Vector2(32, 32), _on_cell_clicked)
	_start_new_game()

func _start_new_game() -> void:
	game_over = false
	is_player_turn = true
	viewing_radar = true
	btn_restart.hide()
	
	player_grid = Grid2D.new(10, 10, 0)
	ai_grid = Grid2D.new(10, 10, 0)
	
	player_ships = BattleshipRules.place_all_ships_random(player_grid)
	ai_ships = BattleshipRules.place_all_ships_random(ai_grid)
	
	_update_view_mode()
	status_label.text = "Sua Vez! Selecione uma coordenada no Radar."

func _update_view_mode() -> void:
	for m in markers_root.get_children(): m.queue_free()
	for s in ships_root.get_children(): s.queue_free()
	markers_3d.clear()
	ships_3d.clear()
	
	for r in range(10):
		for c in range(10):
			board_3d.reset_cell_material(r, c)
			
	if viewing_radar:
		btn_tab_radar.self_modulate = Color(0.3, 0.7, 1.0)
		btn_tab_fleet.self_modulate = Color(0.6, 0.6, 0.6)
		_render_radar_view()
	else:
		btn_tab_radar.self_modulate = Color(0.6, 0.6, 0.6)
		btn_tab_fleet.self_modulate = Color(0.3, 0.7, 1.0)
		_render_fleet_view()
		
	_update_fleet_status_labels()

func _render_radar_view() -> void:
	# Exibe tiros no grid da IA (2 = Erro, 3 = Acerto)
	for r in range(10):
		for c in range(10):
			var val = ai_grid.get_cell(r, c)
			if val == 2: # Erro / Água
				_spawn_peg_3d(r, c, false)
			elif val == 3: # Acerto / Fogo
				_spawn_peg_3d(r, c, true)

func _render_fleet_view() -> void:
	# Exibe navios do jogador e tiros recebidos
	for s in player_ships:
		_render_ship_3d(s)
		
	for r in range(10):
		for c in range(10):
			var val = player_grid.get_cell(r, c)
			if val == 2:
				_spawn_peg_3d(r, c, false)
			elif val == 3:
				_spawn_peg_3d(r, c, true)

func _spawn_peg_3d(r: int, c: int, is_hit: bool) -> void:
	var peg = MeshInstance3D.new()
	peg.mesh = MeshBuilder3D.create_peg_pin(0.35, 0.1)
	peg.position = board_3d.get_cell_position_3d(r, c, 0.18)
	
	if is_hit:
		peg.material_override = MaterialFactory3D.get_glow(Color(1.0, 0.25, 0.1), 2.5)
	else:
		peg.material_override = MaterialFactory3D.get_silver()
		
	markers_root.add_child(peg)
	markers_3d[Vector2i(r, c)] = peg

func _render_ship_3d(ship: Dictionary) -> void:
	var length = ship["size"]
	var is_vert = ship["is_vertical"]
	var start_r = ship["start_row"]
	var start_c = ship["start_col"]
	
	var ship_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	var w = 0.4 if is_vert else (length * 0.65 * 0.9)
	var l = (length * 0.65 * 0.9) if is_vert else 0.4
	box.size = Vector3(w, 0.15, l)
	ship_mesh.mesh = box
	ship_mesh.material_override = MaterialFactory3D.get_plastic(Color(0.2, 0.25, 0.32), true)
	
	var center_r = start_r + ((length - 1) * 0.5 if is_vert else 0.0)
	var center_c = start_c + (0.0 if is_vert else (length - 1) * 0.5)
	
	var total_w = 10 * 0.65
	var start_x = -(total_w * 0.5) + (0.65 * 0.5)
	var start_z = -(total_w * 0.5) + (0.65 * 0.5)
	
	ship_mesh.position = Vector3(start_x + (center_c * 0.65), 0.1, start_z + (center_r * 0.65))
	ships_root.add_child(ship_mesh)

func _update_fleet_status_labels() -> void:
	var ai_sunk = BattleshipRules.count_sunk_ships(ai_ships)
	var player_sunk = BattleshipRules.count_sunk_ships(player_ships)
	fleet_info_label.text = "Navios Inimigos Afundados: %d/5  |  Aliados: %d/5" % [ai_sunk, player_sunk]

func _on_cell_clicked(r: int, c: int):
	if game_over or not is_player_turn or not viewing_radar: return
	
	var cell_val = ai_grid.get_cell(r, c)
	if cell_val == 2 or cell_val == 3: return # Já atirado
	
	var is_hit = (cell_val == 1)
	ai_grid.set_cell(r, c, 3 if is_hit else 2)
	_spawn_peg_3d(r, c, is_hit)
	
	if is_hit:
		var sunk_ship = BattleshipRules.check_ship_sunk(ai_ships, ai_grid, r, c)
		if sunk_ship.size() > 0:
			status_label.text = "💥 Você afundou o %s inimigo!" % sunk_ship["name"]
		else:
			status_label.text = "🎯 Fogo certeiro!"
	else:
		status_label.text = "🌊 Água!"
		
	_update_fleet_status_labels()
	
	if BattleshipRules.check_all_sunk(ai_ships):
		_end_game(true)
		return
		
	is_player_turn = false
	await get_tree().create_timer(0.6).timeout
	_play_ai_turn()

func _play_ai_turn():
	var ai_target = BattleshipRules.get_ai_shot(player_grid)
	var r = ai_target.x
	var c = ai_target.y
	
	var is_hit = (player_grid.get_cell(r, c) == 1)
	player_grid.set_cell(r, c, 3 if is_hit else 2)
	
	if not viewing_radar:
		_spawn_peg_3d(r, c, is_hit)
		
	if is_hit:
		var sunk = BattleshipRules.check_ship_sunk(player_ships, player_grid, r, c)
		if sunk.size() > 0:
			status_label.text = "⚠️ Inimigo afundou seu %s!" % sunk["name"]
		else:
			status_label.text = "⚠️ Inimigo acertou sua frota!"
	else:
		status_label.text = "Inimigo atirou na água. Sua vez!"
		
	_update_fleet_status_labels()
	
	if BattleshipRules.check_all_sunk(player_ships):
		_end_game(false)
		return
		
	is_player_turn = true

func _end_game(is_player_win: bool) -> void:
	if is_player_win:
		finish_game("🏆 Vitória! Toda a frota inimiga foi destruída!", true)
	else:
		finish_game("Derrota! Sua frota foi aniquilada.")

func _on_btn_radar_pressed() -> void:
	viewing_radar = true
	_update_view_mode()

func _on_btn_fleet_pressed() -> void:
	viewing_radar = false
	_update_view_mode()

