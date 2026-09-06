class_name BackgammonGame
extends BaseGame

## BackgammonGame: Gamão 3D Nobre com Dados Físicos, Tabuleiro em Nogueira e Mogno, IA Tática e Gamificação.
##
## Implementa tabuleiro clássico 3D com 24 pontas entalhadas em bordo e mogno,
## 30 peças em marfim e obsidiana com friso chanfrado, barra de captura central,
## bandejas de bear-off, movimentação suave em arco parabólico via tweens,
## rolagem de dados 3D, suporte a 1P (vs IA) e 2P Local, e integração com gamificação.

const Rules = preload("res://games/gamao/BackgammonRules.gd")

const CHECKER_RADIUS: float = 0.20
const CHECKER_HEIGHT: float = 0.08
const CHECKER_SPACING: float = 0.36
const LIFT_Y: float = 0.75

# Dimensões e Coordenadas do Tabuleiro 3D
const BOARD_WIDTH: float = 7.6
const BOARD_DEPTH: float = 5.2
const BOARD_THICKNESS: float = 0.22
const BAR_WIDTH: float = 0.55
const POINT_PITCH_X: float = 0.47
const POINT_OUTER_Z: float = 2.05
const POINT_INNER_Z: float = 0.35

# Estado da Partida
var game_state: Dictionary = {}
var current_player: int = Rules.PLAYER_WHITE # 1: Brancas (Você/P1), 2: Pretas (IA/P2)
var is_vs_ai: bool = true
## Degrau de 1 a 10 do DifficultyManager, o mesmo dos outros jogos.
##
## Antes eram tres botoes -- Facil, Medio, Mestre -- num campo proprio que
## nascia sempre em "Mestre" e sumia ao fechar a cena, enquanto a escada do
## jogo andava em paralelo mexendo so no XP. Agora o botao anda na escada, e a
## escada e quem manda na IA.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL
var dice_roll_result: Dictionary = {}
var available_moves: Array[int] = []
var turn_history: Array[Dictionary] = [] # Snapshot do início do turno para botão Desfazer
var move_step_history: Array[Dictionary] = [] # Movimentos individuais do turno
var selected_pos: int = -99 # -99: nada, 0: barra, 1..24: ponto
var valid_destinations: Array[Dictionary] = []
var is_animating: bool = false
var has_rolled_dice: bool = false
var turn_count: int = 0

# Estruturas 3D
var board_root: Node3D = null
var pieces_root: Node3D = null
var highlights_root: Node3D = null
var dice_nodes: Array[Dice3D] = []
var checker_nodes: Array[Node3D] = []
var point_highlight_meshes: Dictionary = {} # pt -> MeshInstance3D

@onready var shell: GameShell = $GameShell

# Referências de Nós UI
@onready var dice_container: HBoxContainer = $UI/DiceControls/DiceHBox
@onready var btn_roll_dice: Button = $UI/DiceControls/BtnRoll
@onready var btn_end_turn: Button = $UI/DiceControls/BtnEndTurn
@onready var btn_undo: Button = $UI/Actions/BtnUndo
@onready var btn_mode_toggle: Button = $UI/Actions/BtnModeToggle
@onready var btn_diff_toggle: Button = $UI/Actions/BtnDiffToggle
## Toque e arrasto sobre as 24 pontas, a barra e a saida, projetados da
## propria mesa. Era uma camada 2D de 26 botoes reposicionados a cada
## reenquadramento; agora e o mesmo `DragPicker3D` do Hanoi, do Resta Um e das
## Damas, com tres amostras por ponta para o toque pegar a peca da base e a do
## topo. Dois toques continuam valendo.
var picker: DragPicker3D = null

## As molduras das 24 pontas: o mesmo anel do Board3D, num MultiMesh so. A
## barra e a saida continuam com as caixas douradas, porque tem outra forma.
var point_halos: CellHalo3D = null

## Peca sendo arrastada, e de onde saiu.
var _drag_node: Node3D = null
var _drag_from: int = -99

func _ready() -> void:
	env_3d = get_node_or_null("TabletopEnvironment3D") as TabletopEnvironment3D
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	shell.restart_requested.connect(_on_btn_rematch_pressed)
	menu_scene_path = BaseGame.MENU_TABULEIRO

	_setup_3d_hierarchy()
	_setup_ui_events()
	_setup_picker()
	_start_new_game()



# ---------------------------------------------------------------------------
# Montagem do Tabuleiro e Cenas 3D
# ---------------------------------------------------------------------------

func _setup_3d_hierarchy() -> void:
	if env_3d == null:
		return

	# Configura tema de salão clássico
	var theme := GameTheme3D.parlour_walnut()
	theme.surface = &"felt"
	theme.surface_color = Color(0.08, 0.28, 0.20) # Feltro verde nobre
	theme.accent = Color(0.92, 0.78, 0.35)
	theme.camera_tilt = Tokens3D.CAM_TILT_TRACK
	theme.camera_max_tilt = 80.0
	env_3d.apply_theme(theme)
	fit_table(Vector2(BOARD_WIDTH + 0.35, BOARD_DEPTH + 0.25))

	board_root = $TabletopEnvironment3D/BoardRoot
	for c in board_root.get_children():
		c.queue_free()

	pieces_root = Node3D.new()
	pieces_root.name = "PiecesRoot"
	board_root.add_child(pieces_root)

	highlights_root = Node3D.new()
	highlights_root.name = "HighlightsRoot"
	board_root.add_child(highlights_root)

	_build_board_3d()
	_build_dice_3d()


func _build_board_3d() -> void:
	# 1. Base principal em nogueira nobre
	var main_slab := MeshInstance3D.new()
	main_slab.mesh = MeshBuilder3D.board_slab(BOARD_WIDTH, BOARD_DEPTH, BOARD_THICKNESS)
	main_slab.position = Vector3(0.0, -BOARD_THICKNESS * 0.5, 0.0)
	main_slab.material_override = MaterialFactory3D.get_wood_walnut()
	board_root.add_child(main_slab)

	# 2. Moldura externa elevada em mogno: quatro reguas em volta da base.
	#
	# Era UMA caixa do tamanho do tabuleiro inteiro, com o topo em y=0,06: ela
	# tapava o feltro (0,02), as vinte e quatro pontas (0,02) e qualquer halo
	# rente a mesa. O gamao era jogado sobre uma prancha lisa de mogno, sem uma
	# ponta a vista -- e ninguem reparou porque as pecas continuavam aparecendo.
	var largura_regua := 0.15
	for lado in [
		[Vector3(largura_regua, 0.16, BOARD_DEPTH + 0.3), Vector3(-(BOARD_WIDTH + largura_regua) * 0.5, -0.02, 0.0)],
		[Vector3(largura_regua, 0.16, BOARD_DEPTH + 0.3), Vector3((BOARD_WIDTH + largura_regua) * 0.5, -0.02, 0.0)],
		[Vector3(BOARD_WIDTH + 0.3, 0.16, largura_regua), Vector3(0.0, -0.02, -(BOARD_DEPTH + largura_regua) * 0.5)],
		[Vector3(BOARD_WIDTH + 0.3, 0.16, largura_regua), Vector3(0.0, -0.02, (BOARD_DEPTH + largura_regua) * 0.5)],
	]:
		var rim_mesh := BoxMesh.new()
		rim_mesh.size = lado[0]
		var rim := MeshInstance3D.new()
		rim.mesh = rim_mesh
		rim.position = lado[1]
		rim.material_override = MaterialFactory3D.get_wood_mahogany()
		board_root.add_child(rim)

	# 3. Feltro interior (Dois quadrantes: Esquerdo e Direito)
	var felt_w: float = (BOARD_WIDTH - BAR_WIDTH - 0.8) * 0.5
	var felt_d: float = BOARD_DEPTH - 0.5
	for sign_x in [-1.0, 1.0]:
		var felt := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(felt_w, 0.02, felt_d)
		felt.mesh = box
		felt.position = Vector3(sign_x * (BAR_WIDTH * 0.5 + felt_w * 0.5), 0.01, 0.0)
		felt.material_override = MaterialFactory3D.get_felt_casino(Color(0.07, 0.26, 0.18))
		board_root.add_child(felt)

	# 4. Barra Central Elevada (Bar) em madeira maciça com friso dourado
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(BAR_WIDTH, 0.12, BOARD_DEPTH - 0.4)
	bar.mesh = bar_mesh
	bar.position = Vector3(0.0, 0.06, 0.0)
	bar.material_override = MaterialFactory3D.get_wood_mahogany()
	board_root.add_child(bar)

	# 5. Bandejas Laterais de Recolhimento (Bear-Off Trays)
	for sign_z in [-1.0, 1.0]:
		var tray := MeshInstance3D.new()
		var tray_box := BoxMesh.new()
		tray_box.size = Vector3(0.65, 0.06, 1.8)
		tray.mesh = tray_box
		tray.position = Vector3(BOARD_WIDTH * 0.5 - 0.35, 0.03, sign_z * 1.3)
		tray.material_override = MaterialFactory3D.get_wood_walnut()
		board_root.add_child(tray)

	# 6. Criação dos 24 Pontos Triangulares Entalhados
	_build_triangular_points()


func _build_triangular_points() -> void:
	for pt in range(1, 25):
		var mesh_inst := _create_point_triangle_mesh(pt)
		board_root.add_child(mesh_inst)

	# Uma moldura por ponta, no mesmo MultiMesh: selecionada, destino e "da
	# para pegar" sao a mesma malha em tres cores, sem material novo por estado.
	point_halos = CellHalo3D.new()
	highlights_root.add_child(point_halos)
	point_halos.setup_frames(24, Vector2(POINT_PITCH_X * 0.9, 2.0))
	var alvos: Array = []
	for pt in range(1, 25):
		var pos_coords := _get_point_center_3d(pt)
		alvos.append(Vector3(pos_coords.x, 0.04 - CellHalo3D.ALTURA, pos_coords.z * 0.55))
	point_halos.set_targets(alvos)

	# Halo da Barra
	var bar_halo := MeshInstance3D.new()
	var bh_box := BoxMesh.new()
	bh_box.size = Vector3(BAR_WIDTH * 0.9, 0.05, 2.2)
	bar_halo.mesh = bh_box
	bar_halo.position = Vector3(0.0, 0.12, 0.0)
	bar_halo.material_override = MaterialFactory3D.get_gold()
	bar_halo.visible = false
	highlights_root.add_child(bar_halo)
	point_highlight_meshes[Rules.BAR_POS] = bar_halo

	# Halo do Bear-off
	var bear_halo := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.75, 0.08, 1.9)
	bear_halo.mesh = b_box
	bear_halo.position = Vector3(BOARD_WIDTH * 0.5 - 0.35, 0.07, 1.3)
	bear_halo.material_override = MaterialFactory3D.get_gold()
	bear_halo.visible = false
	highlights_root.add_child(bear_halo)
	point_highlight_meshes[Rules.BEAR_OFF_POS] = bear_halo


func _create_point_triangle_mesh(pt: int) -> MeshInstance3D:
	var is_top := (pt >= 13 and pt <= 24)
	var x_pos := _get_point_x_coord(pt)
	var base_z := -POINT_OUTER_Z if is_top else POINT_OUTER_Z
	var tip_z := -POINT_INNER_Z if is_top else POINT_INNER_Z

	# Meio centimetro acima do feltro (0,02), senao os dois planos disputam o z.
	var hw: float = POINT_PITCH_X * 0.46
	var p0 := Vector3(x_pos - hw, 0.025, base_z)
	var p1 := Vector3(x_pos + hw, 0.025, base_z)
	var p2 := Vector3(x_pos, 0.025, tip_z)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)

	# Ordem de enrolamento anti-horário visto de cima
	if is_top:
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p0)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(p1)
		st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(p2)
	else:
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(p1)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p0)
		st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(p2)

	st.generate_tangents()
	var mesh := st.commit()

	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	# Alterna cores clássicas das pontas: Bordo (maple) e Mogno (mahogany)
	if (pt % 2) == 1:
		inst.material_override = MaterialFactory3D.get_wood_maple()
	else:
		inst.material_override = MaterialFactory3D.get_wood_mahogany()

	return inst


func _build_dice_3d() -> void:
	dice_nodes.clear()
	for i in range(2):
		var dice_scene: PackedScene = preload("res://shared/3d/Dice3D.tscn")
		var dice: Dice3D = dice_scene.instantiate()
		# Um pouco maiores do que a peca: e neles que o jogador le a jogada.
		dice.dice_size = 0.58
		dice.position = Vector3(-1.62 + float(i) * 0.95, 0.32, 0.0)
		board_root.add_child(dice)
		dice_nodes.append(dice)


# ---------------------------------------------------------------------------
# Conversões de Coordenadas 3D
# ---------------------------------------------------------------------------

func _get_point_x_coord(pt: int) -> float:
	# Quadrante Esquerdo: Topo (13..18), Fundo (12..7)
	# Quadrante Direito: Topo (19..24), Fundo (6..1)
	if pt >= 13 and pt <= 18:
		var idx := pt - 13 # 0..5 (da esquerda para o centro)
		return - (BAR_WIDTH * 0.5 + (5.5 - float(idx)) * POINT_PITCH_X)
	elif pt >= 7 and pt <= 12:
		var idx := 12 - pt # 0..5 (da esquerda para o centro)
		return - (BAR_WIDTH * 0.5 + (5.5 - float(idx)) * POINT_PITCH_X)
	elif pt >= 19 and pt <= 24:
		var idx := pt - 19 # 0..5 (do centro para a direita)
		return (BAR_WIDTH * 0.5 + (float(idx) + 0.5) * POINT_PITCH_X)
	else: # 1..6
		var idx := 6 - pt # 0..5 (do centro para a direita)
		return (BAR_WIDTH * 0.5 + (float(idx) + 0.5) * POINT_PITCH_X)


func _get_point_center_3d(pt: int) -> Vector3:
	var x := _get_point_x_coord(pt)
	var is_top := (pt >= 13 and pt <= 24)
	var z := -1.35 if is_top else 1.35
	return Vector3(x, 0.05, z)


func _get_checker_stack_pos(pt: int, index: int) -> Vector3:
	var x := _get_point_x_coord(pt)
	var is_top := (pt >= 13 and pt <= 24)
	var base_z := -POINT_OUTER_Z + CHECKER_RADIUS if is_top else POINT_OUTER_Z - CHECKER_RADIUS
	var dir_z := 1.0 if is_top else -1.0

	var visual_idx: int = index % 5
	var stack_tier: int = index / 5

	var z := base_z + dir_z * (float(visual_idx) * CHECKER_SPACING)
	var y := 0.05 + float(stack_tier) * CHECKER_HEIGHT
	return Vector3(x, y, z)


func _get_bar_pos(player: int, index: int) -> Vector3:
	var z_sign := 1.0 if player == Rules.PLAYER_WHITE else -1.0
	var z := z_sign * (0.45 + float(index % 4) * CHECKER_SPACING)
	var y := 0.12 + float(index / 4) * CHECKER_HEIGHT
	return Vector3(0.0, y, z)


func _get_bear_off_pos(player: int, index: int) -> Vector3:
	var z_sign := 1.0 if player == Rules.PLAYER_WHITE else -1.0
	var z := z_sign * (0.8 + float(index % 5) * (CHECKER_SPACING * 0.7))
	var y := 0.06 + float(index / 5) * CHECKER_HEIGHT
	return Vector3(BOARD_WIDTH * 0.5 - 0.35, y, z)


# ---------------------------------------------------------------------------
# Inicialização e Ciclo de Partida
# ---------------------------------------------------------------------------

func _setup_ui_events() -> void:
	btn_roll_dice.pressed.connect(_on_btn_roll_dice_pressed)
	btn_end_turn.pressed.connect(_on_btn_end_turn_pressed)
	btn_undo.pressed.connect(_on_btn_undo_pressed)
	btn_mode_toggle.pressed.connect(_on_btn_mode_toggle_pressed)
	btn_diff_toggle.pressed.connect(_on_btn_diff_toggle_pressed)


## Os alvos do toque, projetados da propria mesa.
##
## Antes isto era uma fileira de 12 botoes em cima e outra embaixo, esticadas
## pela largura da tela; depois, 26 botoes reposicionados pela projecao de cada
## ponta a cada reenquadramento. O `DragPicker3D` faz a projecao sozinho e
## acrescenta o arrasto. Cada ponta tem TRES amostras, da base ao topo da
## pilha: com um ponto so no centro, tocar a peca encostada na borda da mesa
## caia fora do raio.
func _setup_picker() -> void:
	picker = DragPicker3D.new()
	add_child(picker)
	picker.attach(env_3d, 0.05)
	var alvos: Dictionary = {}
	for pt in range(1, 25):
		alvos[pt] = [
			board_root.to_global(_get_checker_stack_pos(pt, 0)),
			board_root.to_global(_get_checker_stack_pos(pt, 2)),
			board_root.to_global(_get_checker_stack_pos(pt, 4)),
		]
	alvos[Rules.BAR_POS] = [
		board_root.to_global(_get_bar_pos(Rules.PLAYER_WHITE, 0)),
		board_root.to_global(_get_bar_pos(Rules.PLAYER_WHITE, 2)),
		board_root.to_global(_get_bar_pos(Rules.PLAYER_BLACK, 0)),
		board_root.to_global(_get_bar_pos(Rules.PLAYER_BLACK, 2)),
	]
	alvos[Rules.BEAR_OFF_POS] = [
		board_root.to_global(_get_bear_off_pos(Rules.PLAYER_WHITE, 0)),
		board_root.to_global(_get_bear_off_pos(Rules.PLAYER_WHITE, 3)),
		board_root.to_global(_get_bear_off_pos(Rules.PLAYER_BLACK, 0)),
		board_root.to_global(_get_bear_off_pos(Rules.PLAYER_BLACK, 3)),
	]
	picker.set_targets(alvos)
	picker.target_tapped.connect(func(id: Variant) -> void: _on_position_touched(int(id)))
	picker.drag_started.connect(_on_peca_pega)
	picker.drag_moved.connect(_on_peca_movida)
	picker.drag_ended.connect(_on_peca_solta)


## Pinta o tabuleiro com o que da para fazer: a ponta escolhida, os destinos e,
## depois de rolar, as pontas de onde da para pegar uma peca. E o que a camada
## 2D contava com bordas coloridas; agora e a moldura do proprio tabuleiro.
func _paint_halos() -> void:
	if point_halos == null:
		return
	point_halos.clear()
	var destinos := {}
	for dest in valid_destinations:
		destinos[int(dest["to"])] = true
	var board: Array = game_state.get("board", [])
	var na_barra := has_rolled_dice \
		and Rules.has_checkers_on_bar(game_state, current_player)
	var minha_vez := not (is_vs_ai and current_player == Rules.PLAYER_BLACK)

	for pt in range(1, 25):
		var cor := Color.TRANSPARENT
		if pt == selected_pos:
			cor = Tokens3D.COLOR_SELECTED
		elif destinos.has(pt):
			cor = Tokens3D.COLOR_VALID
		elif has_rolled_dice and minha_vez and not na_barra and _has_own_checker(board, pt):
			cor = Tokens3D.COLOR_HINT
		if cor.a > 0.0:
			point_halos.light(pt - 1, cor)

	if point_highlight_meshes.has(Rules.BAR_POS):
		point_highlight_meshes[Rules.BAR_POS].visible = selected_pos == Rules.BAR_POS \
			or destinos.has(Rules.BAR_POS) or (na_barra and minha_vez)
	if point_highlight_meshes.has(Rules.BEAR_OFF_POS):
		point_highlight_meshes[Rules.BEAR_OFF_POS].visible = destinos.has(Rules.BEAR_OFF_POS)


func _has_own_checker(board: Array, pt: int) -> bool:
	if pt == Rules.BAR_POS:
		return Rules.has_checkers_on_bar(game_state, current_player)
	if pt == Rules.BEAR_OFF_POS or pt < 1 or pt >= board.size():
		return false
	var val: int = int(board[pt])
	return val > 0 if current_player == Rules.PLAYER_WHITE else val < 0


func _start_new_game() -> void:
	game_over = false
	current_player = Rules.PLAYER_WHITE
	has_rolled_dice = false
	selected_pos = -99
	valid_destinations.clear()
	available_moves.clear()
	turn_history.clear()
	move_step_history.clear()
	turn_count = 0
	shell.timer.reset()
	shell.timer.start()
	ai_level = DifficultyManager.get_level(game_id)
	_pintar_degrau()

	game_state = Rules.create_initial_state()
	_sync_all_checkers_3d()
	_clear_all_highlights()
	_update_ui_stats()

	btn_restart.hide()
	btn_end_turn.hide()
	btn_undo.disabled = true
	btn_roll_dice.disabled = false
	btn_roll_dice.show()

	set_status(tr("BACKGAMMON_START"))

# ---------------------------------------------------------------------------
# Sincronização 3D das Peças
# ---------------------------------------------------------------------------

func _sync_all_checkers_3d() -> void:
	for c in pieces_root.get_children():
		c.queue_free()
	checker_nodes.clear()

	var board: Array = game_state["board"]

	# 1. Peças nos 24 pontos
	for pt in range(1, 25):
		var val: int = int(board[pt])
		if val != 0:
			var player := Rules.PLAYER_WHITE if val > 0 else Rules.PLAYER_BLACK
			var count: int = absi(val)
			for i in range(count):
				var node := _instantiate_checker_3d(player)
				node.position = _get_checker_stack_pos(pt, i)
				pieces_root.add_child(node)
				checker_nodes.append(node)

	# 2. Peças na Barra
	var bar_w: int = int(game_state.get("bar_white", 0))
	for i in range(bar_w):
		var node := _instantiate_checker_3d(Rules.PLAYER_WHITE)
		node.position = _get_bar_pos(Rules.PLAYER_WHITE, i)
		pieces_root.add_child(node)
		checker_nodes.append(node)

	var bar_b: int = int(game_state.get("bar_black", 0))
	for i in range(bar_b):
		var node := _instantiate_checker_3d(Rules.PLAYER_BLACK)
		node.position = _get_bar_pos(Rules.PLAYER_BLACK, i)
		pieces_root.add_child(node)
		checker_nodes.append(node)

	# 3. Peças no Bear-off
	var borne_w: int = int(game_state.get("borne_white", 0))
	for i in range(borne_w):
		var node := _instantiate_checker_3d(Rules.PLAYER_WHITE)
		node.position = _get_bear_off_pos(Rules.PLAYER_WHITE, i)
		pieces_root.add_child(node)
		checker_nodes.append(node)

	var borne_b: int = int(game_state.get("borne_black", 0))
	for i in range(borne_b):
		var node := _instantiate_checker_3d(Rules.PLAYER_BLACK)
		node.position = _get_bear_off_pos(Rules.PLAYER_BLACK, i)
		pieces_root.add_child(node)
		checker_nodes.append(node)


func _instantiate_checker_3d(player: int) -> Node3D:
	var token_scene: PackedScene = preload("res://shared/3d/Token3D.tscn")
	var token: Token3D = token_scene.instantiate()
	token.token_type = "cylinder"
	token.token_radius = CHECKER_RADIUS
	token.material_name = "ivory" if player == Rules.PLAYER_WHITE else "obsidian"
	return token


# ---------------------------------------------------------------------------
# Lógica de Turnos e Rolagem de Dados
# ---------------------------------------------------------------------------

func _on_btn_roll_dice_pressed() -> void:
	if has_rolled_dice or is_animating or game_over:
		return

	if AudioManager:
		AudioManager.play_click()

	btn_roll_dice.disabled = true
	is_animating = true

	dice_roll_result = Rules.roll_dice()
	available_moves = (dice_roll_result["moves"] as Array).duplicate()
	has_rolled_dice = true

	# Salva snapshot para permitir Desfazer durante o turno
	turn_history = [Rules.clone_state(game_state)]
	move_step_history.clear()
	btn_undo.disabled = true

	# Animação de rolagem 3D dos dados
	if dice_nodes.size() >= 2:
		dice_nodes[0].roll(dice_roll_result["d1"], 0.75)
		dice_nodes[1].roll(dice_roll_result["d2"], 0.85)
		await dice_nodes[1].roll_finished

	is_animating = false
	_render_dice_ui()
	_paint_halos()

	# Verifica se há qualquer jogada legal possível
	var legal_moves := Rules.get_all_legal_single_moves(game_state, current_player, available_moves)
	if legal_moves.is_empty():
		set_status(tr("BACKGAMMON_NO_MOVES"))
		await get_tree().create_timer(1.2).timeout
		_finish_turn()
	else:
		if current_player == Rules.PLAYER_WHITE:
			if Rules.has_checkers_on_bar(game_state, current_player):
				set_status(tr("BACKGAMMON_ON_BAR"))
				_on_position_touched(Rules.BAR_POS)
			else:
				set_status(tr("BACKGAMMON_PICK_CHECKER"))
		btn_end_turn.show()


func _render_dice_ui() -> void:
	for c in dice_container.get_children():
		c.queue_free()

	for d in available_moves:
		var pnl := PanelContainer.new()
		pnl.custom_minimum_size = Vector2(44, 44)
		var lbl := Label.new()
		lbl.text = "%d" % d
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		pnl.add_child(lbl)
		dice_container.add_child(pnl)


func _on_position_touched(pt: int) -> void:
	if game_over or is_animating or not has_rolled_dice:
		return
	if is_vs_ai and current_player == Rules.PLAYER_BLACK:
		return

	# Se clicou em um destino válido para a peça atualmente selecionada
	for dest in valid_destinations:
		if dest["to"] == pt:
			_execute_player_move(selected_pos, dest)
			return

	# Caso contrário, tenta selecionar a peça na posição tocada
	_select_position(pt)


func _select_position(pt: int) -> void:
	_clear_all_highlights()
	selected_pos = -99
	valid_destinations.clear()

	if available_moves.is_empty():
		return

	# Se houver peças na Barra, é obrigatório selecionar a Barra
	if Rules.has_checkers_on_bar(game_state, current_player) and pt != Rules.BAR_POS:
		set_status(tr("BACKGAMMON_MUST_REENTER"))
		_select_position(Rules.BAR_POS)
		return

	# Verifica se a posição possui peças do jogador atual
	var board: Array = game_state["board"]
	var has_piece := false
	if pt == Rules.BAR_POS:
		has_piece = Rules.has_checkers_on_bar(game_state, current_player)
	elif pt >= 1 and pt <= 24:
		var val: int = int(board[pt])
		has_piece = (val > 0) if current_player == Rules.PLAYER_WHITE else (val < 0)

	if not has_piece:
		_paint_halos()
		return

	# Calcula destinos válidos
	var moves := Rules.get_valid_moves_for_position(game_state, current_player, pt, available_moves)
	if moves.is_empty():
		set_status(tr("BACKGAMMON_NO_MOVE_HERE"))
		_paint_halos()
		return

	selected_pos = pt
	valid_destinations = moves
	_paint_halos()

	if pt == Rules.BAR_POS:
		set_status(tr("BACKGAMMON_BAR_PICKED"))
	else:
		set_status(tr("BACKGAMMON_POINT_PICKED") % pt)


## A peca do topo de uma posicao, pela posicao esperada dela: as pecas sao
## refeitas a cada jogada e nao guardam de que ponta sao.
func _top_checker_node(pt: int) -> Node3D:
	var esperado := Vector3.INF
	var board: Array = game_state.get("board", [])
	if pt == Rules.BAR_POS:
		var na_barra: int = int(game_state.get("bar_white" if current_player == Rules.PLAYER_WHITE else "bar_black", 0))
		if na_barra > 0:
			esperado = _get_bar_pos(current_player, na_barra - 1)
	elif pt >= 1 and pt <= 24 and pt < board.size():
		var quantas: int = absi(int(board[pt]))
		if quantas > 0:
			esperado = _get_checker_stack_pos(pt, quantas - 1)
	if esperado == Vector3.INF:
		return null
	for node in checker_nodes:
		if is_instance_valid(node) and node.position.distance_to(esperado) < 0.01:
			return node
	return null


func _on_peca_pega(id: Variant) -> void:
	var pt: int = int(id)
	if game_over or is_animating or not has_rolled_dice \
			or (is_vs_ai and current_player == Rules.PLAYER_BLACK):
		picker.cancel_drag()
		return
	_select_position(pt)
	# A selecao pode ter sido recusada (ponta vazia, sem jogada) ou redirigida
	# para a barra; so a peca da ponta escolhida de fato sobe com o dedo.
	if selected_pos != pt:
		picker.cancel_drag()
		return
	var node: Node3D = _top_checker_node(pt)
	if node == null:
		picker.cancel_drag()
		return
	_drag_node = node
	_drag_from = pt
	if node is Token3D:
		(node as Token3D).set_lift(Tokens3D.LIFT_DRAG)


func _on_peca_movida(_from_id: Variant, _over: Variant, world: Vector3) -> void:
	if _drag_node == null or not is_instance_valid(_drag_node) or world == Vector3.INF:
		return
	var local: Vector3 = board_root.to_local(world)
	_drag_node.position = Vector3(local.x, _drag_node.position.y, local.z)


func _on_peca_solta(_from_id: Variant, to: Variant) -> void:
	var node: Node3D = _drag_node
	var origem: int = _drag_from
	_drag_node = null
	_drag_from = -99
	if node == null:
		return
	if to != null and selected_pos == origem:
		var destino: int = int(to)
		for dest in valid_destinations:
			if int(dest["to"]) == destino:
				_execute_player_move(origem, dest)
				return
	# Soltou fora de um destino: as pecas voltam ao lugar e a selecao fica de
	# pe para quem prefere os dois toques.
	_sync_all_checkers_3d()


func _clear_all_highlights() -> void:
	for halo in point_highlight_meshes.values():
		halo.visible = false
	if point_halos:
		point_halos.clear()


# ---------------------------------------------------------------------------
# Execução e Animação de Movimento
# ---------------------------------------------------------------------------

func _execute_player_move(from_pos: int, move_data: Dictionary) -> void:
	var die: int = int(move_data["die"])
	var to_pos: int = int(move_data["to"])
	var is_hit: bool = bool(move_data["is_hit"])

	_clear_all_highlights()
	selected_pos = -99
	valid_destinations.clear()
	is_animating = true

	# Registra histórico para desfazer
	turn_history.append(Rules.clone_state(game_state))
	move_step_history.append({"from": from_pos, "die": die, "to": to_pos})
	btn_undo.disabled = false

	# Aplica nas regras
	Rules.apply_move_inplace(game_state, current_player, from_pos, die)

	# Consome o dado utilizado
	var die_idx: int = available_moves.find(die)
	if die_idx != -1:
		available_moves.remove_at(die_idx)
	_render_dice_ui()

	if AudioManager:
		AudioManager.play_click()

	# Re-sincroniza visual 3D
	_sync_all_checkers_3d()
	_update_ui_stats()

	is_animating = false

	# Verifica fim de jogo
	if Rules.is_game_over(game_state):
		_handle_game_over(current_player)
		return

	# Se todos os dados foram consumidos ou não há mais jogadas possíveis
	var remaining_moves := Rules.get_all_legal_single_moves(game_state, current_player, available_moves)
	if available_moves.is_empty() or remaining_moves.is_empty():
		_finish_turn()
	else:
		if Rules.has_checkers_on_bar(game_state, current_player):
			_select_position(Rules.BAR_POS)
		else:
			set_status(tr("BACKGAMMON_MOVED"))
			_paint_halos()


func _finish_turn() -> void:
	_clear_all_highlights()
	selected_pos = -99
	valid_destinations.clear()
	available_moves.clear()
	has_rolled_dice = false
	btn_end_turn.hide()
	btn_undo.disabled = true

	turn_count += 1
	current_player = 3 - current_player # Alterna 1 <-> 2

	_update_ui_stats()
	_paint_halos()

	if is_vs_ai and current_player == Rules.PLAYER_BLACK:
		btn_roll_dice.disabled = true
		btn_roll_dice.hide()
		set_status(tr("BACKGAMMON_AI_TURN"))
		await get_tree().create_timer(0.6).timeout
		_play_ai_turn()
	else:
		btn_roll_dice.disabled = false
		btn_roll_dice.show()
		var player_name := tr("BACKGAMMON_P1") if current_player == Rules.PLAYER_WHITE else tr("BACKGAMMON_P2")
		set_status(tr("BACKGAMMON_YOUR_TURN") % player_name)


# ---------------------------------------------------------------------------
# Turno da IA
# ---------------------------------------------------------------------------

func _play_ai_turn() -> void:
	if game_over:
		return

	is_animating = true

	# Rolagem dos dados da IA
	dice_roll_result = Rules.roll_dice()
	available_moves = (dice_roll_result["moves"] as Array).duplicate()
	_render_dice_ui()

	if dice_nodes.size() >= 2:
		dice_nodes[0].roll(dice_roll_result["d1"], 0.7)
		dice_nodes[1].roll(dice_roll_result["d2"], 0.8)
		await dice_nodes[1].roll_finished

	var ai_sequence := Rules.get_ai_turn(game_state, Rules.PLAYER_BLACK, available_moves, ai_level)

	if ai_sequence.is_empty():
		set_status(tr("BACKGAMMON_AI_NO_MOVES"))
		await get_tree().create_timer(1.0).timeout
	else:
		for mv in ai_sequence:
			if game_over:
				break
			set_status(tr("BACKGAMMON_AI_MOVING") % [
				tr("BACKGAMMON_BAR") if mv["from"] == 0 else str(mv["from"]),
				tr("BACKGAMMON_BEAR_OFF") if mv["to"] == 25 else str(mv["to"])
			])
			await get_tree().create_timer(0.65).timeout

			Rules.apply_move_inplace(game_state, Rules.PLAYER_BLACK, mv["from"], mv["die"])
			var d_idx: int = available_moves.find(mv["die"])
			if d_idx != -1:
				available_moves.remove_at(d_idx)
			_render_dice_ui()

			if AudioManager:
				AudioManager.play_click()

			_sync_all_checkers_3d()
			_update_ui_stats()

			if Rules.is_game_over(game_state):
				is_animating = false
				_handle_game_over(Rules.PLAYER_BLACK)
				return

	is_animating = false
	_finish_turn()


# ---------------------------------------------------------------------------
# Controles de UI, Desfazer e Configurações
# ---------------------------------------------------------------------------

func _on_btn_end_turn_pressed() -> void:
	if not has_rolled_dice or is_animating or game_over:
		return
	if is_vs_ai and current_player == Rules.PLAYER_BLACK:
		return

	if AudioManager:
		AudioManager.play_click()

	_finish_turn()


func _on_btn_undo_pressed() -> void:
	if turn_history.size() <= 1 or is_animating:
		return

	if AudioManager:
		AudioManager.play_click()

	# Reverte para o estado anterior da rodada
	turn_history.pop_back()
	var prev_state: Dictionary = turn_history.back()
	game_state = Rules.clone_state(prev_state)

	var last_mv: Dictionary = move_step_history.pop_back()
	available_moves.append(int(last_mv["die"]))

	_sync_all_checkers_3d()
	_clear_all_highlights()
	_render_dice_ui()
	_update_ui_stats()

	selected_pos = -99
	valid_destinations.clear()
	btn_undo.disabled = (turn_history.size() <= 1)
	_paint_halos()

	set_status(tr("BACKGAMMON_UNDONE"))


func _on_btn_mode_toggle_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	is_vs_ai = not is_vs_ai
	var modo := tr("MODE_VS_AI") if is_vs_ai else tr("MODE_TWO_PLAYERS")
	btn_mode_toggle.text = tr("MODE_LABEL") % modo
	_start_new_game()


## Degraus em que o botao para. Um por faixa de `DifficultyManager.tier_name()`:
## o botao passeia pelas cinco faixas em vez de por tres nomes proprios.
const DEGRAUS_DO_BOTAO := [2, 4, 6, 8, 10]


## O botao empurra a escada para a proxima faixa. Quem grava e o
## DifficultyManager, entao a escolha sobrevive a fechar a cena -- coisa que o
## campo `ai_difficulty` nunca fez.
func _on_btn_diff_toggle_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()

	var proximo: int = DEGRAUS_DO_BOTAO[0]
	for degrau in DEGRAUS_DO_BOTAO:
		if degrau > ai_level:
			proximo = degrau
			break

	DifficultyManager.set_level(game_id, proximo)
	ai_level = DifficultyManager.get_level(game_id)
	_pintar_degrau()


func _pintar_degrau() -> void:
	if btn_diff_toggle != null:
		btn_diff_toggle.text = tr("AI_TIER") % tr(DifficultyManager.tier_name(ai_level))


func _on_btn_rematch_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	_start_new_game()


func _update_ui_stats() -> void:
	var white_pip := Rules.calculate_pip_count(game_state, Rules.PLAYER_WHITE)
	var black_pip := Rules.calculate_pip_count(game_state, Rules.PLAYER_BLACK)
	set_duel_score(white_pip, black_pip)
	var time_str := "%d:%02d" % [shell.timer.get_time() / 60, shell.timer.get_time() % 60]
	shell.set_level("T: %d  •  %s  •  %s" % [turn_count, time_str, DifficultyManager.label_for(game_id)])


# ---------------------------------------------------------------------------
# Fim de Jogo e Gamificação
# ---------------------------------------------------------------------------

func _handle_game_over(winner: int) -> void:
	game_over = true
	shell.timer.stop()
	_clear_all_highlights()
	btn_roll_dice.hide()
	btn_end_turn.hide()
	btn_undo.disabled = true

	var win_type := Rules.get_win_type(game_state, winner)
	var is_player_win := (winner == Rules.PLAYER_WHITE)

	var win_type_title := tr("BACKGAMMON_WIN_SINGLE")
	var multiplier := 1
	if win_type == "gammon":
		win_type_title = tr("BACKGAMMON_WIN_GAMMON")
		multiplier = 2
	elif win_type == "backgammon":
		win_type_title = tr("BACKGAMMON_WIN_BACKGAMMON")
		multiplier = 3

	var msg := ""
	if is_player_win:
		msg = tr("BACKGAMMON_YOU_WIN") % win_type_title
	else:
		msg = tr("BACKGAMMON_AI_WIN") % win_type_title

	var xp_reward: int = (60 * multiplier) if is_player_win else 15
	finish_game(msg, is_player_win, {
		"xp": xp_reward,
		"win_type": win_type,
		"turns": turn_count,
		"time": shell.timer.get_time(),
	})
