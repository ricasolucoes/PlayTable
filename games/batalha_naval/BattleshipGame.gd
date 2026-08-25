extends BaseGame

## BattleshipGame: Batalha Naval 3D com Radar Oceânico Tático e Marcadores Tridimensionais

var player_grid: Grid2D
var ai_grid: Grid2D
var player_ships: Array = []
var ai_ships: Array = []
var is_player_turn: bool = true
var viewing_radar: bool = true # true = Radar de Ataque (AI Grid), false = Frota Aliada (Player Grid)
var markers_3d: Dictionary = {}
var ships_3d: Array = []

## Altura do casco sobre a casa.
const HULL_HEIGHT := 0.22

@onready var board_3d: Board3D = $Board3D
@onready var markers_root: Node3D = $MarkersRoot
@onready var ships_root: Node3D = $ShipsRoot
@onready var fleet_info_label: Label = $UI/VBoxContainer/FleetInfoLabel
@onready var btn_tab_radar: Button = $UI/VBoxContainer/TabBar/BtnRadar
@onready var btn_tab_fleet: Button = $UI/VBoxContainer/TabBar/BtnFleet

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/VBoxContainer/BtnRestart
	env_3d.apply_theme(GameTheme3D.steel_blue())
	board_3d.setup_board(10, 10, 0.65, "ocean_radar")
	# A HUD ocupa os 220 px de cima; a camera enquadra a faixa que sobra.
	env_3d.set_safe_area(240.0, 60.0)
	env_3d.frame_content(board_3d.content_size())
	# O toque entra pelo proprio tabuleiro: a casa tocada e a casa desenhada.
	# Havia uma grade 2D de botoes de 32 px (17 dp num telefone comum) alinhada
	# a mao sobre uma camera fixa que nao coincidia com ela.
	board_3d.cell_clicked.connect(_on_cell_clicked)
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
	set_status("Sua Vez! Selecione uma coordenada no Radar.")

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
	for i in player_ships.size():
		_render_ship_3d(player_ships[i], i)

	for r in range(10):
		for c in range(10):
			var val: int = player_grid.get_cell(r, c)
			if val == 2:
				_spawn_peg_3d(r, c, false, false)
			elif val == 3:
				_spawn_peg_3d(r, c, true, false)
## Crava o pino na coordenada. Ele cai de cima e assenta com um recuo curto;
## o de acerto ainda pulsa uma vez. Ao trocar de aba, os pinos ja conhecidos
## aparecem no lugar, sem cair de novo.
func _spawn_peg_3d(r: int, c: int, is_hit: bool, animate: bool = true) -> void:
	var peg := MeshInstance3D.new()
	peg.mesh = MeshBuilder3D.create_peg_pin(0.35, 0.1)
	var target := board_3d.get_cell_position_3d(r, c, 0.18)
	peg.position = target
	if is_hit:
		peg.material_override = MaterialFactory3D.get_glow(Color(1.0, 0.25, 0.1), 2.5)
	else:
		peg.material_override = MaterialFactory3D.get_silver()
	markers_root.add_child(peg)
	markers_3d[Vector2i(r, c)] = peg
	if not animate:
		return
	var d := Quality3D.duration(Tokens3D.DUR_NORMAL)
	if d <= 0.0:
		return
	peg.position = target + Vector3(0.0, 0.6, 0.0)
	peg.scale = Vector3(0.6, 0.6, 0.6)
	var tw := peg.create_tween()
	tw.set_parallel(true)
	tw.tween_property(peg, "position", target, d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(peg, "scale", Vector3.ONE, d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_hit:
		var pulso := Quality3D.duration(Tokens3D.DUR_FAST)
		tw.chain().tween_property(peg, "scale", Vector3(1.3, 1.3, 1.3), pulso * 0.5)
		tw.chain().tween_property(peg, "scale", Vector3.ONE, pulso * 0.5)
## Desenha um navio da frota a partir das casas que ele ocupa.
##
## A versao anterior lia ship["is_vertical"], ["start_row"] e ["start_col"],
## chaves que BattleshipRules nunca gravou — o navio e {name, size, cells, hits,
## sunk}. A aba Frota morria no primeiro navio com "Invalid access" e casco
## nenhum era desenhado. Por cima disso, o casco era Color(0.2, 0.25, 0.32)
## sobre casas Color(0.10, 0.20, 0.34): mesma luminancia. Agora e claro, e os
## navios emergem um a um ao abrir a aba.
func _render_ship_3d(ship: Dictionary, index: int = 0) -> void:
	var cells: Array = ship["cells"]
	if cells.is_empty():
		return
	var primeira: Vector2i = cells[0]
	var ultima: Vector2i = cells[cells.size() - 1]
	var length: int = cells.size()
	var is_vert: bool = primeira.x != ultima.x

	var cell := board_3d.cell_size
	var ao_longo := length * cell * 0.92
	var atraves := cell * 0.62
	var box := BoxMesh.new()
	box.size = Vector3(atraves if is_vert else ao_longo, HULL_HEIGHT, ao_longo if is_vert else atraves)
	var ship_mesh := MeshInstance3D.new()
	ship_mesh.mesh = box
	ship_mesh.material_override = MaterialFactory3D.get_plastic(Color(0.86, 0.88, 0.84), true)

	var a := board_3d.get_cell_position_3d(primeira.x, primeira.y, 0.0)
	var b := board_3d.get_cell_position_3d(ultima.x, ultima.y, 0.0)
	var target := (a + b) * 0.5
	target.y = Tokens3D.TILE_THICKNESS + HULL_HEIGHT * 0.5
	ship_mesh.position = target
	ships_root.add_child(ship_mesh)
	ships_3d.append(ship_mesh)

	var d := Quality3D.duration(Tokens3D.DUR_SLOW)
	if d <= 0.0:
		return
	ship_mesh.position = target - Vector3(0.0, 0.5, 0.0)
	var tw := ship_mesh.create_tween()
	tw.tween_interval(index * 0.06)
	tw.tween_property(ship_mesh, "position", target, d) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func _update_fleet_status_labels() -> void:
	var ai_sunk := BattleshipRules.count_sunk_ships(ai_ships)
	var player_sunk := BattleshipRules.count_sunk_ships(player_ships)
	fleet_info_label.text = "Navios Inimigos Afundados: %d/5  |  Aliados: %d/5" % [ai_sunk, player_sunk]

func _on_cell_clicked(r: int, c: int) -> void:
	if game_over or not is_player_turn:
		return
	if not viewing_radar:
		set_status("Esta é a sua frota. Volte ao Radar para atacar.")
		return
	var cell_val: int = ai_grid.get_cell(r, c)
	if cell_val == 2 or cell_val == 3:
		set_status("Você já atirou nessa coordenada. Escolha outra.")
		return

	var is_hit = (cell_val == 1)
	ai_grid.set_cell(r, c, 3 if is_hit else 2)
	_spawn_peg_3d(r, c, is_hit)
	if AudioManager:
		AudioManager.play_piece_place()
	
	if is_hit:
		var sunk_ship := BattleshipRules.check_ship_sunk(ai_ships, ai_grid, r, c)
		if sunk_ship.size() > 0:
			set_status("💥 Você afundou o %s inimigo!" % sunk_ship["name"])
		else:
			set_status("🎯 Fogo certeiro!")
	else:
		set_status("🌊 Água!")
		
	_update_fleet_status_labels()
	
	if BattleshipRules.check_all_sunk(ai_ships):
		_end_game(true)
		return
		
	is_player_turn = false
	await get_tree().create_timer(0.6).timeout
	_play_ai_turn()

func _play_ai_turn() -> void:
	var ai_target := BattleshipRules.get_ai_shot(player_grid)
	var r := ai_target.x
	var c := ai_target.y
	
	var is_hit = (player_grid.get_cell(r, c) == 1)
	player_grid.set_cell(r, c, 3 if is_hit else 2)
	
	if not viewing_radar:
		_spawn_peg_3d(r, c, is_hit)
		
	if is_hit:
		var sunk := BattleshipRules.check_ship_sunk(player_ships, player_grid, r, c)
		if sunk.size() > 0:
			set_status("⚠️ Inimigo afundou seu %s!" % sunk["name"])
		else:
			set_status("⚠️ Inimigo acertou sua frota!")
	else:
		set_status("Inimigo atirou na água. Sua vez!")
		
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

