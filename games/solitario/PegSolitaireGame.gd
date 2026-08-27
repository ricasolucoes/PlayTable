extends GridGame

## PegSolitaireGame: Resta Um 3D com Tabuleiro Circular Entalhado e Esferas Polidas de Âmbar

var grid_data: Grid2D
var selected_pos: Vector2i = Vector2i(-1, -1)
var valid_targets: Array[Dictionary] = []
var marbles_3d: Dictionary = {}

@onready var board_root: Node3D = $BoardRoot
@onready var marbles_root: Node3D = $MarblesRoot
@onready var touch_layer: Control = $UI/TouchLayer

const CELL_SIZE: float = 0.75

## Altura em que a esfera viaja enquanto esta sendo arrastada.
const DRAG_HEIGHT: float = 0.55

## Centro de cada casa projetado na tela, em pixels. Refeito quando a camera
## reenquadra ou a janela muda de tamanho.
var _cell_screen: Dictionary = {}

## Raio de captura do toque, tirado da distancia entre casas vizinhas na tela.
var _pick_radius: float = 40.0

## Casa de onde o arrasto comecou, e se o dedo chegou a sair dela.
var _drag_from: Vector2i = Vector2i(-1, -1)
var _drag_moved: bool = false
var _hover_target: Vector2i = Vector2i(-1, -1)

## Cavidade de cada casa, para poder acender o furo de destino.
var _holes_3d: Dictionary = {}


func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/Actions/BtnRestart
	_setup_3d_circular_board()

	# O tabuleiro tem 6,4 unidades de diametro; sem informar isso a camera
	# usava o enquadramento padrao de 6x6 e a grade de toque plana, que era
	# ancorada no centro da tela, nao caia sobre furo nenhum.
	fit_table(Vector2(6.8, 6.8))

	touch_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_layer.gui_input.connect(_on_touch_layer_input)
	if env_3d:
		env_3d.framing_changed.connect(func(_size: Vector2): _refresh_cell_projection())
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_refresh_cell_projection)
	_refresh_cell_projection.call_deferred()

	_start_new_game()

func _setup_3d_circular_board() -> void:
	for c in board_root.get_children(): c.queue_free()
	_holes_3d.clear()
	
	# Base circular de madeira nobre
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.2
	cyl.bottom_radius = 3.2
	cyl.height = 0.16
	cyl.radial_segments = 48
	base.mesh = cyl
	base.position = Vector3(0, -0.08, 0)
	base.material_override = MaterialFactory3D.get_wood_mahogany()
	board_root.add_child(base)
	
	# Friso central em nogueira
	var inner := MeshInstance3D.new()
	var inner_cyl := CylinderMesh.new()
	inner_cyl.top_radius = 2.9
	inner_cyl.bottom_radius = 2.9
	inner_cyl.height = 0.02
	inner_cyl.radial_segments = 48
	inner.mesh = inner_cyl
	inner.position = Vector3(0, 0.01, 0)
	inner.material_override = MaterialFactory3D.get_wood_walnut()
	board_root.add_child(inner)
	
	# Furos / Cavidades das 33 posições
	var start_x := -(7 * CELL_SIZE * 0.5) + (CELL_SIZE * 0.5)
	var start_z := -(7 * CELL_SIZE * 0.5) + (CELL_SIZE * 0.5)
	
	for r in range(7):
		for c in range(7):
			if PegSolitaireRules.is_valid_cell(r, c):
				var hole := MeshInstance3D.new()
				var h_cyl := CylinderMesh.new()
				h_cyl.top_radius = 0.22
				h_cyl.bottom_radius = 0.15
				h_cyl.height = 0.04
				hole.mesh = h_cyl
				hole.position = Vector3(start_x + (c * CELL_SIZE), 0.02, start_z + (r * CELL_SIZE))
				hole.material_override = MaterialFactory3D.get_obsidian()
				board_root.add_child(hole)
				_holes_3d[Vector2i(r, c)] = hole

func _get_cell_pos_3d(r: int, c: int) -> Vector3:
	var start_x := -(7 * CELL_SIZE * 0.5) + (CELL_SIZE * 0.5)
	var start_z := -(7 * CELL_SIZE * 0.5) + (CELL_SIZE * 0.5)
	return Vector3(start_x + (c * CELL_SIZE), 0.14, start_z + (r * CELL_SIZE))

func _start_new_game() -> void:
	game_over = false
	selected_pos = Vector2i(-1, -1)
	valid_targets.clear()
	_drag_from = Vector2i(-1, -1)
	_hover_target = Vector2i(-1, -1)
	btn_restart.hide()
	
	grid_data = PegSolitaireRules.create_initial_board()
	_sync_marbles_3d()
	_update_ui()
	set_status("Toque em uma esfera para selecionar e saltar!")

func _sync_marbles_3d() -> void:
	for m in marbles_root.get_children(): m.queue_free()
	marbles_3d.clear()
	
	for r in range(7):
		for c in range(7):
			if grid_data.get_cell(r, c) == 1:
				var marble := preload("res://shared/3d/Token3D.tscn").instantiate()
				marble.token_type = "sphere"
				marble.material_name = "amber"
				marble.position = _get_cell_pos_3d(r, c)
				marbles_root.add_child(marble)
				marbles_3d[Vector2i(r, c)] = marble

func _update_ui() -> void:
	var pegs_count := PegSolitaireRules.count_pegs(grid_data)
	set_counter(pegs_count, "esferas")

# ---------------------------------------------------------------------------
# Toque e arrasto
# ---------------------------------------------------------------------------

## Onde cada furo cai na tela.
##
## Antes o toque entrava por uma grade 7x7 de botoes de 44 px ancorada no centro
## da tela. O tabuleiro e 3D em perspectiva e circular: a grade plana nao
## coincidia com os furos, e por isso era dificil acertar a esfera certa. Aqui
## cada furo e projetado pela propria camera, e o toque vai para o furo mais
## PROXIMO -- nao para o que estiver exatamente sob o dedo.
func _refresh_cell_projection() -> void:
	_cell_screen.clear()
	if env_3d == null or not is_inside_tree():
		return
	var cam := env_3d.camera
	if cam == null:
		return

	for r in range(7):
		for c in range(7):
			if PegSolitaireRules.is_valid_cell(r, c):
				var mundo: Vector3 = board_root.to_global(_get_cell_pos_3d(r, c))
				_cell_screen[Vector2i(r, c)] = cam.unproject_position(mundo)

	# Metade da distancia entre duas casas vizinhas do centro: mais que isso e o
	# toque roubaria a casa do lado.
	var a: Vector2 = _cell_screen.get(Vector2i(3, 2), Vector2.ZERO)
	var b: Vector2 = _cell_screen.get(Vector2i(3, 3), Vector2.ZERO)
	if a != Vector2.ZERO and b != Vector2.ZERO:
		_pick_radius = maxf(a.distance_to(b) * 0.62, 26.0)


## Acende os furos onde a esfera escolhida pode cair, e acende mais forte o que
## esta debaixo do dedo. Sem isto o arrasto seria as cegas.
func _paint_targets() -> void:
	var destinos := {}
	for vt in valid_targets:
		destinos[vt["land"]] = true

	for pos in _holes_3d:
		var hole: MeshInstance3D = _holes_3d[pos]
		if not is_instance_valid(hole):
			continue
		if destinos.has(pos):
			var forte: bool = pos == _hover_target
			hole.material_override = MaterialFactory3D.get_glow(
				Color(0.42, 0.95, 0.55), 2.4 if forte else 1.1)
			hole.scale = Vector3.ONE * (1.35 if forte else 1.0)
		else:
			hole.material_override = MaterialFactory3D.get_obsidian()
			hole.scale = Vector3.ONE


## O furo mais proximo do ponto, ou (-1,-1) se o toque caiu longe do tabuleiro.
func _cell_at(ponto: Vector2) -> Vector2i:
	var melhor := Vector2i(-1, -1)
	var menor := _pick_radius
	for pos in _cell_screen:
		var d: float = (_cell_screen[pos] as Vector2).distance_to(ponto)
		if d < menor:
			menor = d
			melhor = pos
	return melhor


func _on_touch_layer_input(event: InputEvent) -> void:
	if game_over:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_press(mb.position)
		else:
			_end_press(mb.position)
		touch_layer.accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_press(st.position)
		else:
			_end_press(st.position)
		touch_layer.accept_event()
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if _drag_from.x >= 0:
			_update_drag(event.position)
			touch_layer.accept_event()


func _begin_press(ponto: Vector2) -> void:
	var pos := _cell_at(ponto)
	_drag_moved = false
	_hover_target = Vector2i(-1, -1)

	# Toque num destino iluminado fecha o salto de duas batidas.
	if selected_pos.x >= 0:
		for vt in valid_targets:
			if vt["land"] == pos:
				_execute_jump(selected_pos, vt)
				return

	if pos.x < 0 or grid_data.get_cell(pos.x, pos.y) != 1:
		_clear_selection()
		return

	_select(pos)
	_drag_from = pos
	var marble: Token3D = marbles_3d.get(pos)
	if marble:
		marble.set_lift(DRAG_HEIGHT * 0.35)


## Enquanto o dedo anda, a esfera anda junto e o furo sob ela acende.
func _update_drag(ponto: Vector2) -> void:
	var marble: Token3D = marbles_3d.get(_drag_from)
	if marble == null:
		return
	var alvo := _cell_at(ponto)
	if alvo != _drag_from:
		_drag_moved = true

	var mundo := _screen_to_board(ponto)
	if mundo != Vector3.INF:
		marble.position = Vector3(mundo.x, _get_cell_pos_3d(0, 0).y + DRAG_HEIGHT, mundo.z)

	if alvo != _hover_target:
		_hover_target = alvo
		_paint_targets()


func _end_press(ponto: Vector2) -> void:
	if _drag_from.x < 0:
		return
	var origem := _drag_from
	_drag_from = Vector2i(-1, -1)
	_hover_target = Vector2i(-1, -1)

	var marble: Token3D = marbles_3d.get(origem)
	var alvo := _cell_at(ponto)

	for vt in valid_targets:
		if vt["land"] == alvo:
			if marble:
				marble.position = _get_cell_pos_3d(origem.x, origem.y)
				marble.set_lift(0.0)
			_execute_jump(origem, vt)
			return

	# Soltou fora de um destino: a esfera volta para o furo dela. A selecao
	# continua de pe para quem prefere jogar com duas batidas.
	if marble:
		marble.slide_to(_get_cell_pos_3d(origem.x, origem.y))
		marble.set_lift(0.0)
	if _drag_moved and alvo != origem:
		set_status("Solte a esfera num furo iluminado.")
	_paint_targets()


func _select(pos: Vector2i) -> void:
	selected_pos = pos
	valid_targets = PegSolitaireRules.get_valid_moves_for_peg(grid_data, pos)
	for p in marbles_3d.keys():
		(marbles_3d[p] as Token3D).highlight(p == pos)
	_paint_targets()
	if valid_targets.is_empty():
		set_status("Esta esfera não tem saltos possíveis.")
	else:
		set_status("Arraste até um furo iluminado — ou toque nele.")


func _clear_selection() -> void:
	selected_pos = Vector2i(-1, -1)
	valid_targets.clear()
	for p in marbles_3d.keys():
		(marbles_3d[p] as Token3D).highlight(false)
	_paint_targets()


## Converte um ponto da tela no ponto correspondente do plano do tabuleiro.
func _screen_to_board(ponto: Vector2) -> Vector3:
	if env_3d == null or env_3d.camera == null:
		return Vector3.INF
	var cam := env_3d.camera
	var origem := cam.project_ray_origin(ponto)
	var direcao := cam.project_ray_normal(ponto)
	var plano_y: float = board_root.to_global(_get_cell_pos_3d(0, 0)).y
	if absf(direcao.y) < 0.0001:
		return Vector3.INF
	var t: float = (plano_y - origem.y) / direcao.y
	if t < 0.0:
		return Vector3.INF
	return board_root.to_local(origem + direcao * t)

func _execute_jump(from_pos: Vector2i, target_dict: Dictionary) -> void:
	var to_pos = target_dict["land"]
	var jumped_pos = target_dict["over"]
	
	grid_data.set_cell(from_pos.x, from_pos.y, 0)
	grid_data.set_cell(jumped_pos.x, jumped_pos.y, 0)
	grid_data.set_cell(to_pos.x, to_pos.y, 1)
	
	var moving_marble = marbles_3d.get(from_pos)
	if moving_marble:
		marbles_3d.erase(from_pos)
		marbles_3d[to_pos] = moving_marble
		moving_marble.jump_to(_get_cell_pos_3d(to_pos.x, to_pos.y), 0.6, 0.35)
		moving_marble.highlight(false)
		
	var jumped_marble = marbles_3d.get(jumped_pos)
	if jumped_marble:
		var tween := create_tween()
		tween.tween_property(jumped_marble, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
		tween.tween_callback(func(): jumped_marble.queue_free())
		marbles_3d.erase(jumped_pos)
		
	selected_pos = Vector2i(-1, -1)
	valid_targets.clear()
	_paint_targets()
	_update_ui()

	if not PegSolitaireRules.has_any_valid_moves(grid_data):
		_end_game()

func _end_game() -> void:
	var remaining: int = PegSolitaireRules.count_pegs(grid_data)
	# `pegs` e a metrica de placar do Resta Um: quanto menos sobra, melhor.
	# So a esfera unica conta como vitoria -- e o objetivo do jogo.
	var fatos := {"pegs": remaining, "perfect": remaining == 1}
	if remaining == 1:
		finish_game("🏆 Incrível! Apenas 1 esfera restante! Vitória perfeita!", true, fatos)
	elif remaining <= 3:
		finish_game("Muito bem! Restaram apenas %d esferas." % remaining, false, fatos)
	else:
		finish_game("Fim de Jogo! Restaram %d esferas." % remaining, false, fatos)
