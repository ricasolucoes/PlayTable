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
var ai_difficulty: String = "hard" # easy, medium, hard
var dice_roll_result: Dictionary = {}
var available_moves: Array[int] = []
var turn_history: Array[Dictionary] = [] # Snapshot do início do turno para botão Desfazer
var move_step_history: Array[Dictionary] = [] # Movimentos individuais do turno
var selected_pos: int = -99 # -99: nada, 0: barra, 1..24: ponto
var valid_destinations: Array[Dictionary] = []
var is_animating: bool = false
var has_rolled_dice: bool = false
var turn_count: int = 0
var elapsed_time: float = 0.0
var is_timer_running: bool = false

# Estruturas 3D
var board_root: Node3D = null
var pieces_root: Node3D = null
var highlights_root: Node3D = null
var dice_nodes: Array[Dice3D] = []
var checker_nodes: Array[Node3D] = []
var point_highlight_meshes: Dictionary = {} # pt -> MeshInstance3D

# Referências de Nós UI
@onready var title_label: Label = $UI/TopBar/HeaderHBox/TitleLabel
@onready var status_bar_label: Label = $UI/VBoxContainer/StatusLabel
@onready var pip_white_label: Label = $UI/TopBar/StatsHBox/WhitePipCard/HBox/PipVal
@onready var pip_black_label: Label = $UI/TopBar/StatsHBox/BlackPipCard/HBox/PipVal
@onready var turns_label: Label = $UI/TopBar/StatsHBox/TurnsCard/TurnsVal
@onready var mode_label: Label = $UI/TopBar/StatsHBox/ModeCard/ModeVal

@onready var dice_container: HBoxContainer = $UI/DiceControls/DiceHBox
@onready var btn_roll_dice: Button = $UI/DiceControls/BtnRoll
@onready var btn_end_turn: Button = $UI/DiceControls/BtnEndTurn
@onready var btn_undo: Button = $UI/Actions/BtnUndo
@onready var btn_mode_toggle: Button = $UI/Actions/BtnModeToggle
@onready var btn_diff_toggle: Button = $UI/Actions/BtnDiffToggle
@onready var touch_buttons_container: Control = $UI/TouchGrid

## Alvo de toque de cada posicao (1..24, barra, saida), posicionado projetando
## o proprio ponto do tabuleiro na tela.
var touch_targets: Dictionary = {}

# Modal de Resultado
@onready var result_modal: Control = $ResultModal
@onready var result_title: Label = $ResultModal/Panel/VBox/ResultTitle
@onready var result_stars: Label = $ResultModal/Panel/VBox/ResultStars
@onready var result_details: Label = $ResultModal/Panel/VBox/ResultDetails
@onready var result_xp_label: Label = $ResultModal/Panel/VBox/ResultXP
@onready var btn_rematch: Button = $ResultModal/Panel/VBox/BtnRematch


func _ready() -> void:
	env_3d = get_node_or_null("TabletopEnvironment3D") as TabletopEnvironment3D
	status_label = status_bar_label
	btn_restart = $UI/Actions/BtnRestart
	menu_scene_path = BaseGame.MENU_TABULEIRO
	result_modal.visible = false

	_setup_3d_hierarchy()
	_setup_ui_events()
	_setup_touch_overlays()
	_start_new_game()


func _process(delta: float) -> void:
	if is_timer_running and not game_over:
		elapsed_time += delta


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
	env_3d.apply_theme(theme)
	env_3d.set_safe_area(220.0, 140.0)
	env_3d.frame_content(Vector2(BOARD_WIDTH + 0.6, BOARD_DEPTH + 0.4))

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

	# 2. Moldura externa elevada em mogno
	var rim_mesh := BoxMesh.new()
	rim_mesh.size = Vector3(BOARD_WIDTH + 0.3, 0.16, BOARD_DEPTH + 0.3)
	var rim := MeshInstance3D.new()
	rim.mesh = rim_mesh
	rim.position = Vector3(0.0, -0.02, 0.0)
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

		# Cria halo/indicador de destaque para cada ponto
		var halo := MeshInstance3D.new()
		var halo_box := BoxMesh.new()
		halo_box.size = Vector3(POINT_PITCH_X * 0.9, 0.04, 2.0)
		halo.mesh = halo_box
		var pos_coords := _get_point_center_3d(pt)
		halo.position = Vector3(pos_coords.x, 0.03, pos_coords.z * 0.55)
		halo.material_override = MaterialFactory3D.get_gold()
		halo.visible = false
		highlights_root.add_child(halo)
		point_highlight_meshes[pt] = halo

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

	var hw: float = POINT_PITCH_X * 0.46
	var p0 := Vector3(x_pos - hw, 0.02, base_z)
	var p1 := Vector3(x_pos + hw, 0.02, base_z)
	var p2 := Vector3(x_pos, 0.02, tip_z)

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
	btn_rematch.pressed.connect(_on_btn_rematch_pressed)


## Monta a camada de toque sobre o tabuleiro.
##
## Antes isto era uma fileira de 12 botoes em cima e outra embaixo, esticadas
## pela largura da tela em HBoxContainer. O tabuleiro e 3D em perspectiva: as
## duas fileiras planas nao coincidiam com ponta nenhuma -- ficavam uma dentro
## da HUD marrom e a outra abaixo do tabuleiro, no feltro vazio. Tocar uma peca
## nao fazia nada, e era por isso que nao dava para mover.
##
## Agora cada alvo e posicionado projetando o proprio ponto do tabuleiro na
## tela pela camera, e se reposiciona sozinho quando o enquadramento muda.
func _setup_touch_overlays() -> void:
	for c in touch_buttons_container.get_children():
		c.queue_free()
	touch_targets.clear()

	touch_buttons_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for pt in range(1, 25):
		touch_targets[pt] = _create_touch_button(pt, "%d" % pt)
	touch_targets[Rules.BAR_POS] = _create_touch_button(Rules.BAR_POS, "BARRA")
	touch_targets[Rules.BEAR_OFF_POS] = _create_touch_button(Rules.BEAR_OFF_POS, "SAÍDA")

	if env_3d:
		env_3d.framing_changed.connect(func(_size: Vector2): _refresh_touch_overlays())
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_refresh_touch_overlays)
	_refresh_touch_overlays.call_deferred()


func _create_touch_button(pt: int, label: String) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = label
	btn.add_theme_font_size_override("font_size", 13)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(func(): _on_position_touched(pt))
	touch_buttons_container.add_child(btn)
	return btn


## Retangulo de tela que o ponto `pt` ocupa, projetando o contorno dele.
##
## Projeta os oito cantos da caixa que envolve a ponta -- e nao so o centro --
## porque em perspectiva a mesma ponta e larga na borda da mesa e estreita na
## ponta do triangulo. A altura entra na conta para a pilha de pecas empilhadas
## tambem ficar dentro do alvo.
func _touch_rect(cam: Camera3D, pt: int) -> Rect2:
	var x := 0.0
	var hw := POINT_PITCH_X * 0.5
	var z0 := 0.0
	var z1 := 0.0

	if pt == Rules.BAR_POS:
		hw = BAR_WIDTH * 0.62
		z0 = -1.2
		z1 = 1.2
	elif pt == Rules.BEAR_OFF_POS:
		x = BOARD_WIDTH * 0.5 - 0.35
		hw = 0.42
		z0 = 0.35
		z1 = 2.25
	else:
		x = _get_point_x_coord(pt)
		var is_top := pt >= 13
		z0 = -POINT_OUTER_Z if is_top else POINT_INNER_Z
		z1 = -POINT_INNER_Z if is_top else POINT_OUTER_Z

	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for sx in [-hw, hw]:
		for sz in [z0, z1]:
			for sy in [0.0, 0.36]:
				var mundo: Vector3 = board_root.to_global(Vector3(x + sx, sy, sz))
				var tela := cam.unproject_position(mundo)
				min_p = min_p.min(tela)
				max_p = max_p.max(tela)

	# Alvo minimo de 44 px: e o menor toque confortavel num telefone, e as
	# pontas do fundo projetam mais estreitas que isso.
	var rect := Rect2(min_p, max_p - min_p)
	var falta := Vector2(maxf(44.0 - rect.size.x, 0.0), maxf(44.0 - rect.size.y, 0.0))
	rect.position -= falta * 0.5
	rect.size += falta
	return rect


func _refresh_touch_overlays() -> void:
	if env_3d == null or board_root == null or not is_inside_tree():
		return
	var cam := env_3d.camera
	if cam == null:
		return
	var origem := touch_buttons_container.global_position
	for pt in touch_targets:
		var btn: Button = touch_targets[pt]
		if not is_instance_valid(btn):
			continue
		var rect := _touch_rect(cam, pt)
		btn.position = rect.position - origem
		btn.size = rect.size
	_sync_touch_visuals()


## Deixa a camada de toque contar a mesma historia que os halos do tabuleiro:
## o que da para escolher, o que esta escolhido e para onde da para ir.
func _sync_touch_visuals() -> void:
	var destinos := {}
	for dest in valid_destinations:
		destinos[int(dest["to"])] = true

	var na_barra := has_rolled_dice \
		and Rules.has_checkers_on_bar(game_state, current_player)
	var board: Array = game_state.get("board", [])

	for pt in touch_targets:
		var btn: Button = touch_targets[pt]
		if not is_instance_valid(btn):
			continue
		var estado := "idle"
		if pt == selected_pos:
			estado = "selected"
		elif destinos.has(pt):
			estado = "target"
		elif has_rolled_dice and _has_own_checker(board, pt) \
				and (not na_barra or pt == Rules.BAR_POS):
			estado = "ready"

		btn.visible = pt != Rules.BEAR_OFF_POS or estado != "idle"
		for nome in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(nome, _touch_style(estado))
		btn.add_theme_color_override("font_color", _touch_ink(estado))


func _has_own_checker(board: Array, pt: int) -> bool:
	if pt == Rules.BAR_POS:
		return Rules.has_checkers_on_bar(game_state, current_player)
	if pt == Rules.BEAR_OFF_POS or pt < 1 or pt >= board.size():
		return false
	var val: int = int(board[pt])
	return val > 0 if current_player == Rules.PLAYER_WHITE else val < 0


func _touch_style(estado: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	match estado:
		"selected":
			style.bg_color = Color(0.96, 0.78, 0.26, 0.30)
			style.border_color = Color(1.0, 0.86, 0.36, 0.95)
			style.set_border_width_all(3)
		"target":
			style.bg_color = Color(0.30, 0.85, 0.45, 0.26)
			style.border_color = Color(0.44, 0.95, 0.58, 0.90)
			style.set_border_width_all(3)
		"ready":
			style.bg_color = Color(1.0, 1.0, 1.0, 0.06)
			style.border_color = Color(1.0, 1.0, 1.0, 0.34)
			style.set_border_width_all(2)
		_:
			style.bg_color = Color(0, 0, 0, 0.0)
			style.border_color = Color(1, 1, 1, 0.10)
			style.set_border_width_all(1)
	return style


func _touch_ink(estado: String) -> Color:
	match estado:
		"selected": return Color(1.0, 0.90, 0.48)
		"target": return Color(0.62, 1.0, 0.74)
		"ready": return Color(1, 1, 1, 0.72)
		_: return Color(1, 1, 1, 0.28)


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
	elapsed_time = 0.0
	is_timer_running = true

	game_state = Rules.create_initial_state()
	_sync_all_checkers_3d()
	_clear_all_highlights()
	_update_ui_stats()

	btn_restart.hide()
	btn_end_turn.hide()
	btn_undo.disabled = true
	btn_roll_dice.disabled = false
	btn_roll_dice.show()
	result_modal.visible = false

	set_status("Sua Vez! Role os dados para começar.")


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
	_sync_touch_visuals()

	# Verifica se há qualquer jogada legal possível
	var legal_moves := Rules.get_all_legal_single_moves(game_state, current_player, available_moves)
	if legal_moves.is_empty():
		set_status("Sem jogadas possíveis! Turno encerrado.")
		await get_tree().create_timer(1.2).timeout
		_finish_turn()
	else:
		if current_player == Rules.PLAYER_WHITE:
			if Rules.has_checkers_on_bar(game_state, current_player):
				set_status("Você tem peças na Barra! Reentre no tabuleiro.")
				_on_position_touched(Rules.BAR_POS)
			else:
				set_status("Escolha uma peça para mover.")
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
		set_status("Reentrada obrigatória a partir da Barra!")
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
		return

	# Calcula destinos válidos
	var moves := Rules.get_valid_moves_for_position(game_state, current_player, pt, available_moves)
	if moves.is_empty():
		set_status("Nenhum movimento válido para esta peça com os dados atuais.")
		return

	selected_pos = pt
	valid_destinations = moves

	# Ativa destaques visuais
	if point_highlight_meshes.has(pt):
		point_highlight_meshes[pt].visible = true

	for dest in valid_destinations:
		var target_pt: int = dest["to"]
		if point_highlight_meshes.has(target_pt):
			point_highlight_meshes[target_pt].visible = true

	_sync_touch_visuals()

	if pt == Rules.BAR_POS:
		set_status("Barra selecionada. Escolha a casa de reentrada.")
	else:
		set_status("Ponto %d selecionado. Escolha o destino." % pt)


func _clear_all_highlights() -> void:
	for halo in point_highlight_meshes.values():
		halo.visible = false
	_sync_touch_visuals()


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
			set_status("Movimento realizado! Escolha a próxima peça.")


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
	_sync_touch_visuals()

	if is_vs_ai and current_player == Rules.PLAYER_BLACK:
		btn_roll_dice.disabled = true
		btn_roll_dice.hide()
		set_status("Vez da IA (Pretas)... Rolando dados.")
		await get_tree().create_timer(0.6).timeout
		_play_ai_turn()
	else:
		btn_roll_dice.disabled = false
		btn_roll_dice.show()
		var player_name := "Você" if current_player == Rules.PLAYER_WHITE else "Jogador 2"
		set_status("Sua Vez (%s)! Role os dados." % player_name)


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

	var ai_sequence := Rules.get_best_ai_turn(game_state, Rules.PLAYER_BLACK, available_moves, ai_difficulty)

	if ai_sequence.is_empty():
		set_status("A IA não tem jogadas legais.")
		await get_tree().create_timer(1.0).timeout
	else:
		for mv in ai_sequence:
			if game_over:
				break
			set_status("IA movendo de %s para %s..." % [
				"Barra" if mv["from"] == 0 else str(mv["from"]),
				"Bear-off" if mv["to"] == 25 else str(mv["to"])
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

	set_status("Lance desfeito. Escolha outro movimento.")


func _on_btn_mode_toggle_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	is_vs_ai = not is_vs_ai
	mode_label.text = "vs IA" if is_vs_ai else "2 Jogadores"
	btn_mode_toggle.text = "Modo: %s" % ("vs IA" if is_vs_ai else "2 Jogadores")
	_start_new_game()


func _on_btn_diff_toggle_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	match ai_difficulty:
		"easy":
			ai_difficulty = "medium"
		"medium":
			ai_difficulty = "hard"
		"hard":
			ai_difficulty = "easy"

	var diff_name := "Fácil"
	if ai_difficulty == "medium":
		diff_name = "Médio"
	elif ai_difficulty == "hard":
		diff_name = "Mestre"

	btn_diff_toggle.text = "IA: %s" % diff_name


func _on_btn_rematch_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	result_modal.visible = false
	_start_new_game()


func _update_ui_stats() -> void:
	var white_pip := Rules.calculate_pip_count(game_state, Rules.PLAYER_WHITE)
	var black_pip := Rules.calculate_pip_count(game_state, Rules.PLAYER_BLACK)
	pip_white_label.text = "%d" % white_pip
	pip_black_label.text = "%d" % black_pip
	turns_label.text = "%d" % turn_count


# ---------------------------------------------------------------------------
# Fim de Jogo e Gamificação
# ---------------------------------------------------------------------------

func _handle_game_over(winner: int) -> void:
	game_over = true
	is_timer_running = false
	_clear_all_highlights()
	btn_roll_dice.hide()
	btn_end_turn.hide()
	btn_undo.disabled = true
	btn_restart.show()

	var win_type := Rules.get_win_type(game_state, winner)
	var is_player_win := (winner == Rules.PLAYER_WHITE)

	var win_type_title := "Vitória Simples"
	var multiplier := 1
	if win_type == "gammon":
		win_type_title = "Vitória por GAMMON! (2x)"
		multiplier = 2
	elif win_type == "backgammon":
		win_type_title = "Vitória por BACKGAMMON! (3x)"
		multiplier = 3

	var msg := ""
	if is_player_win:
		msg = "Parabéns! Você venceu (%s)!" % win_type_title
	else:
		msg = "A IA venceu a partida (%s)." % win_type_title

	# A gamificacao sai por BaseGame.report_match_result: quem credita o XP,
	# conta a partida e cuida da streak e o GamificationManager, ouvindo o
	# barramento. O jogo so diz quanto vale a vitoria neste tabuleiro.
	var xp_reward: int = (60 * multiplier) if is_player_win else 15
	report_match_result(is_player_win, {
		"xp": xp_reward,
		"win_type": win_type,
		"turns": turn_count,
		"time": elapsed_time,
	})
	finish_game(msg, is_player_win)

	# Modal de Resultado
	_show_result_modal(is_player_win, win_type_title, xp_reward)


func _show_result_modal(is_win: bool, win_type_text: String, xp_earned: int) -> void:
	result_modal.visible = true
	result_modal.modulate.a = 0.0

	if is_win:
		result_title.text = "🏆 VITÓRIA!"
		result_stars.text = "⭐⭐⭐"
		result_details.text = "%s\nTurnos: %d • Tempo: %02d:%02d" % [
			win_type_text, turn_count, int(elapsed_time) / 60, int(elapsed_time) % 60
		]
	else:
		result_title.text = "FIM DE JOGO"
		result_stars.text = "⭐"
		result_details.text = "%s\nTurnos: %d" % [win_type_text, turn_count]

	result_xp_label.text = "+%d XP Ganho" % xp_earned

	var tw := create_tween()
	tw.tween_property(result_modal, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC)
