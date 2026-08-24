extends BaseGame

## MancalaGame: Mancala 3D com Tabuleiro Esculpido em Madeira Nobre e Gemas Preciosas

var pits: Array = []
var is_player_turn: bool = true
var gems_3d: Dictionary = {}

@onready var board_root: Node3D = $BoardRoot
@onready var gems_root: Node3D = $GemsRoot
@onready var player_pits_container = $UI/CenterContainer/VBox/PlayerRow
@onready var ai_pits_container = $UI/CenterContainer/VBox/AIRow
@onready var player_store_label = $UI/CenterContainer/HBoxStores/PlayerStoreLabel
@onready var ai_store_label = $UI/CenterContainer/HBoxStores/AIStoreLabel

const PIT_POSITIONS_3D = {
	# Jogador (0 a 5): De -2.0 a +2.0 em X, Z = 0.6
	0: Vector3(-1.9, 0.08, 0.6),
	1: Vector3(-1.14, 0.08, 0.6),
	2: Vector3(-0.38, 0.08, 0.6),
	3: Vector3(0.38, 0.08, 0.6),
	4: Vector3(1.14, 0.08, 0.6),
	5: Vector3(1.9, 0.08, 0.6),
	# Kalah Jogador (6): Direita, Z = 0.0
	6: Vector3(2.8, 0.08, 0.0),
	# IA (7 a 12): Direita para Esquerda, Z = -0.6
	7: Vector3(1.9, 0.08, -0.6),
	8: Vector3(1.14, 0.08, -0.6),
	9: Vector3(0.38, 0.08, -0.6),
	10: Vector3(-0.38, 0.08, -0.6),
	11: Vector3(-1.14, 0.08, -0.6),
	12: Vector3(-1.9, 0.08, -0.6),
	# Kalah IA (13): Esquerda, Z = 0.0
	13: Vector3(-2.8, 0.08, 0.0)
}

const GEM_MATERIALS = ["ruby", "sapphire", "emerald", "amber", "gold"]

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/VBoxContainer/BtnRestart
	_setup_3d_mancala_board()
	_setup_ui_buttons()
	_start_new_game()

func _setup_3d_mancala_board() -> void:
	for c in board_root.get_children(): c.queue_free()
	
	# Base de madeira entalhada
	var base = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(6.6, 0.22, 2.2)
	base.mesh = box
	base.position = Vector3(0, -0.11, 0)
	base.material_override = MaterialFactory3D.get_wood_mahogany()
	board_root.add_child(base)
	
	# Cavidades / Covas escavadas
	for idx in PIT_POSITIONS_3D.keys():
		var pit_mesh = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		var is_store = (idx == 6 or idx == 13)
		cyl.top_radius = 0.45 if is_store else 0.32
		cyl.bottom_radius = 0.38 if is_store else 0.28
		cyl.height = 0.06
		pit_mesh.mesh = cyl
		pit_mesh.position = PIT_POSITIONS_3D[idx] - Vector3(0, 0.02, 0)
		pit_mesh.material_override = MaterialFactory3D.get_wood_walnut()
		board_root.add_child(pit_mesh)

func _setup_ui_buttons() -> void:
	for c in player_pits_container.get_children(): c.queue_free()
	for i in range(6):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(52, 60)
		btn.pressed.connect(_on_player_pit_clicked.bind(i))
		player_pits_container.add_child(btn)

func _start_new_game() -> void:
	game_over = false
	is_player_turn = true
	btn_restart.hide()
	
	pits.clear()
	for i in range(14):
		pits.append(0 if (i == 6 or i == 13) else 4)
		
	status_label.text = "Sua Vez! Escolha uma cova para semear."
	_sync_gems_3d()
	_update_ui()

func _sync_gems_3d() -> void:
	for g in gems_root.get_children(): g.queue_free()
	gems_3d.clear()
	
	for pit_idx in range(14):
		var count = pits[pit_idx]
		var pit_pos = PIT_POSITIONS_3D[pit_idx]
		var gem_list: Array = []
		for g_i in range(count):
			var gem = preload("res://shared/3d/Token3D.tscn").instantiate()
			gem.token_type = "sphere"
			gem.material_name = GEM_MATERIALS[g_i % GEM_MATERIALS.size()]
			
			# Espalha sementes levemente dentro da cova
			var offset_x = (randf() - 0.5) * (0.4 if (pit_idx == 6 or pit_idx == 13) else 0.22)
			var offset_z = (randf() - 0.5) * (0.4 if (pit_idx == 6 or pit_idx == 13) else 0.22)
			var offset_y = 0.05 + (g_i * 0.04)
			gem.position = pit_pos + Vector3(offset_x, offset_y, offset_z)
			
			gems_root.add_child(gem)
			gem_list.append(gem)
		gems_3d[pit_idx] = gem_list

func _update_ui() -> void:
	player_store_label.text = "Sua Kalah:\n💎 %d" % pits[6]
	ai_store_label.text = "Kalah IA:\n💎 %d" % pits[13]
	
	for i in range(6):
		var btn = player_pits_container.get_child(i) as Button
		var count = pits[i]
		btn.text = "%d" % count
		btn.disabled = not is_player_turn or count == 0 or game_over

func _on_player_pit_clicked(pit_idx: int):
	if game_over or not is_player_turn or pits[pit_idx] == 0: return
	
	var seeds = pits[pit_idx]
	pits[pit_idx] = 0
	var curr = pit_idx
	
	while seeds > 0:
		curr = (curr + 1) % 14
		if curr == 13: continue # Pula o Kalah da IA
		pits[curr] += 1
		seeds -= 1
		
	# Regra de captura do Mancala
	if curr >= 0 and curr <= 5 and pits[curr] == 1 and pits[12 - curr] > 0:
		var captured = pits[12 - curr] + 1
		pits[curr] = 0
		pits[12 - curr] = 0
		pits[6] += captured
		status_label.text = "💎 Captura espetacular! +%d gemas!" % captured
		
	_sync_gems_3d()
	_update_ui()
	
	if _check_game_over(): return
	
	if curr == 6:
		status_label.text = "Última gema caiu na sua Kalah! Jogue novamente."
		return
		
	is_player_turn = false
	status_label.text = "Vez da IA..."
	_update_ui()
	await get_tree().create_timer(0.7).timeout
	_play_ai_turn()

func _play_ai_turn():
	var valid_pits: Array = []
	for i in range(7, 13):
		if pits[i] > 0: valid_pits.append(i)
		
	if valid_pits.is_empty():
		_check_game_over()
		return
		
	var chosen_pit = valid_pits.pick_random()
	var seeds = pits[chosen_pit]
	pits[chosen_pit] = 0
	var curr = chosen_pit
	
	while seeds > 0:
		curr = (curr + 1) % 14
		if curr == 6: continue # Pula Kalah do Jogador
		pits[curr] += 1
		seeds -= 1
		
	if curr >= 7 and curr <= 12 and pits[curr] == 1 and pits[12 - curr] > 0:
		var captured = pits[12 - curr] + 1
		pits[curr] = 0
		pits[12 - curr] = 0
		pits[13] += captured
		status_label.text = "IA capturou suas gemas!"
		
	_sync_gems_3d()
	_update_ui()
	
	if _check_game_over(): return
	
	if curr == 13:
		status_label.text = "IA jogou no próprio Kalah e joga novamente!"
		await get_tree().create_timer(0.7).timeout
		_play_ai_turn()
		return
		
	is_player_turn = true
	status_label.text = "Sua Vez! Escolha uma cova."
	_update_ui()

func _check_game_over() -> bool:
	var player_empty: bool = true
	for i in range(6):
		if pits[i] > 0: player_empty = false; break
		
	var ai_empty: bool = true
	for i in range(7, 13):
		if pits[i] > 0: ai_empty = false; break
		
	if player_empty or ai_empty:
		# Coleta sementes restantes
		for i in range(6): pits[6] += pits[i]; pits[i] = 0
		for i in range(7, 13): pits[13] += pits[i]; pits[i] = 0
		_sync_gems_3d()
		_update_ui()
		
		if pits[6] > pits[13]:
			finish_game("🏆 Você Venceu! (%d x %d)" % [pits[6], pits[13]], true)
		elif pits[13] > pits[6]:
			finish_game("IA Venceu! (%d x %d)" % [pits[13], pits[6]])
		else:
			finish_game("Empate! (%d x %d)" % [pits[6], pits[13]])
		return true
	return false
