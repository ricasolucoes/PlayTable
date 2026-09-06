extends BaseGame

## PegSolitaireGame: Resta Um 3D com Tabuleiro Circular Entalhado e Esferas Polidas de Âmbar

var grid_data: Grid2D
var selected_pos: Vector2i = Vector2i(-1, -1)
var valid_targets: Array[Dictionary] = []
var marbles_3d: Dictionary = {}

@onready var shell: GameShell = $GameShell
@onready var board_root: Node3D = $BoardRoot
@onready var marbles_root: Node3D = $MarblesRoot

const CELL_SIZE: float = 0.75

## Altura em que a esfera viaja enquanto esta sendo arrastada.
const DRAG_HEIGHT: float = 0.55

## Toque e arrasto sobre os 33 furos, projetados da propria mesa. O padrao
## nasceu aqui e virou `DragPicker3D`; esta cena e a primeira a voltar a usa-lo
## de fora, porque e a que prova que nada regrediu -- e a unica com arrasto
## coberto por teste desde o comeco.
var picker: DragPicker3D = null

## Os aneis de destino: o mesmo anel do Board3D e do Mancala, num MultiMesh so.
## Antes as 33 cavidades trocavam de material a cada gesto.
var halos: CellHalo3D = null

## Indice de cada furo dentro do `halos`.
var _halo_index: Dictionary = {}

## Casa de onde o arrasto comecou, e o furo sob o dedo agora.
var _drag_from: Vector2i = Vector2i(-1, -1)
var _hover_target: Vector2i = Vector2i(-1, -1)

## Cavidade de cada casa.
var _holes_3d: Dictionary = {}


func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	shell.restart_requested.connect(_on_restart_pressed)
	_setup_3d_circular_board()

	# Sem tema proprio a cena herda o `casino_green`, que e mesa de carteado e
	# trava a inclinacao da camera em 56 graus para a face da carta nao achatar.
	# Em retrato quem manda e a largura: a camera quer deitar mais para aproveitar
	# a altura que sobra, batia nesse teto e parava. Nogueira nao mexe no teto e
	# herda os 74 graus do padrao -- e a madeira certa para um tabuleiro assim.
	env_3d.apply_theme(GameTheme3D.parlour_walnut())

	# Enquadra a CRUZ jogavel (7 x 0,75 = 5,25 un.) com a folga do disco, e nao o
	# disco de madeira inteiro: era ele que mandava antes, e sobrava borda de
	# tabuleiro ocupando largura que as pecas precisavam.
	var cruz := 7.0 * CELL_SIZE + CELL_SIZE * 0.5
	fit_table(Vector2(cruz, cruz))

	_setup_picker()
	_start_new_game()

func _setup_3d_circular_board() -> void:
	for c in board_root.get_children(): c.queue_free()
	_holes_3d.clear()
	_halo_index.clear()
	
	# Base circular de madeira nobre.
	#
	# O topo fica em y = 0,03, e nao em zero: o feltro da mesa termina exatamente
	# em y = 0, e com os dois planos no mesmo z o tampo de mogno e o feltro
	# disputavam o pixel triangulo a triangulo -- eram os "entalhes radiais" na
	# borda do disco, que sobreviviam a esconder as esferas e a desligar a
	# sombra da luz, porque nunca foram sombra: eram o leque de triangulos do
	# tampo vencendo o feltro em umas fatias e perdendo nas outras.
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.2
	cyl.bottom_radius = 3.2
	cyl.height = 0.16
	cyl.radial_segments = 48
	base.mesh = cyl
	base.position = Vector3(0, -0.05, 0)
	base.material_override = MaterialFactory3D.get_wood_mahogany()
	board_root.add_child(base)
	
	# Friso central em nogueira, pousado sobre o tampo (0,03 a 0,05).
	var inner := MeshInstance3D.new()
	var inner_cyl := CylinderMesh.new()
	inner_cyl.top_radius = 2.9
	inner_cyl.bottom_radius = 2.9
	inner_cyl.height = 0.02
	inner_cyl.radial_segments = 48
	inner.mesh = inner_cyl
	inner.position = Vector3(0, 0.04, 0)
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
				# A cavidade atravessa o friso e assenta no tampo (0,03 a 0,07).
				hole.position = Vector3(start_x + (c * CELL_SIZE), 0.05, start_z + (r * CELL_SIZE))
				hole.material_override = MaterialFactory3D.get_obsidian()
				board_root.add_child(hole)
				_holes_3d[Vector2i(r, c)] = hole

	# Um anel por furo, pousado na boca da cavidade.
	halos = CellHalo3D.new()
	board_root.add_child(halos)
	halos.setup(_holes_3d.size(), CELL_SIZE * 0.42)
	var alvos: Array = []
	for pos in _holes_3d:
		_halo_index[pos] = alvos.size()
		var hole: MeshInstance3D = _holes_3d[pos]
		alvos.append(Vector3(hole.position.x, 0.07, hole.position.z))
	halos.set_targets(alvos)

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
	if picker:
		picker.cancel_drag()
	btn_restart.hide()
	
	grid_data = PegSolitaireRules.create_initial_board()
	_sync_marbles_3d()
	_paint_targets()
	_update_ui()
	set_status(tr("PEG_START"))
	shell.timer.reset()
	shell.timer.start()

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
	var celulas: Array = [{"value": pegs_count, "label": "SCORE_PEGS"}]

	# O recorde de partidas anteriores fica ao lado do contador: sem ele nao ha
	# como saber se a partida de agora esta indo melhor ou pior que a melhor de
	# todas, que e o unico placar que o Resta Um tem.
	var melhor := int(PlayerProfile.get_stat("record_solitario", 0)) if PlayerProfile else 0
	if melhor > 0:
		celulas.append({"value": melhor, "label": "SCORE_RECORD"})
	set_counters(celulas)

# ---------------------------------------------------------------------------
# Toque e arrasto
# ---------------------------------------------------------------------------

## Cada furo e um alvo do picker, projetado pela propria camera; o toque vai
## para o furo mais PROXIMO, nao para o que estiver exatamente sob o dedo.
##
## Antes o toque entrava por uma grade 7x7 de botoes de 44 px ancorada no centro
## da tela. O tabuleiro e 3D em perspectiva e circular: a grade plana nao
## coincidia com os furos, e por isso era dificil acertar a esfera certa.
func _setup_picker() -> void:
	picker = DragPicker3D.new()
	add_child(picker)
	picker.attach(env_3d, board_root.to_global(_get_cell_pos_3d(0, 0)).y)
	var alvos: Dictionary = {}
	for pos in _holes_3d:
		var casa: Vector2i = pos
		alvos[casa] = board_root.to_global(_get_cell_pos_3d(casa.x, casa.y))
	picker.set_targets(alvos)
	picker.target_tapped.connect(_on_furo_tocado)
	picker.drag_started.connect(_on_esfera_pega)
	picker.drag_moved.connect(_on_esfera_movida)
	picker.drag_ended.connect(_on_esfera_solta)


## Acende os furos onde a esfera escolhida pode cair, e acende mais forte o que
## esta debaixo do dedo. Sem isto o arrasto seria as cegas.
func _paint_targets() -> void:
	if halos == null:
		return
	var destinos: Array = []
	for vt in valid_targets:
		destinos.append(_halo_index.get(vt["land"], -1))
	halos.light_only(destinos)
	if _hover_target.x >= 0 and _halo_index.has(_hover_target) \
			and _halo_index[_hover_target] in destinos:
		halos.light(_halo_index[_hover_target], Tokens3D.COLOR_SELECTED)


## Tocou e soltou sem arrastar: e o esquema de duas batidas.
func _on_furo_tocado(id: Variant) -> void:
	if game_over:
		return
	var pos: Vector2i = id

	# Toque num destino iluminado fecha o salto de duas batidas.
	if selected_pos.x >= 0:
		for vt in valid_targets:
			if vt["land"] == pos:
				_execute_jump(selected_pos, vt)
				return

	if grid_data.get_cell(pos.x, pos.y) != 1:
		_clear_selection()
		return
	_select(pos)


func _on_esfera_pega(id: Variant) -> void:
	var pos: Vector2i = id
	if game_over or grid_data.get_cell(pos.x, pos.y) != 1:
		picker.cancel_drag()
		return
	_select(pos)
	_drag_from = pos
	_hover_target = Vector2i(-1, -1)
	var marble: Token3D = marbles_3d.get(pos)
	if marble:
		marble.set_lift(DRAG_HEIGHT * 0.35)


## Enquanto o dedo anda, a esfera anda junto e o furo sob ela acende.
func _on_esfera_movida(_from_id: Variant, over: Variant, world: Vector3) -> void:
	var marble: Token3D = marbles_3d.get(_drag_from)
	if marble == null:
		return
	if world != Vector3.INF:
		var local: Vector3 = board_root.to_local(world)
		marble.position = Vector3(local.x, _get_cell_pos_3d(0, 0).y + DRAG_HEIGHT, local.z)

	var alvo: Vector2i = over if over != null else Vector2i(-1, -1)
	if alvo != _hover_target:
		_hover_target = alvo
		_paint_targets()


func _on_esfera_solta(_from_id: Variant, to: Variant) -> void:
	if _drag_from.x < 0:
		return
	var origem := _drag_from
	_drag_from = Vector2i(-1, -1)
	_hover_target = Vector2i(-1, -1)

	var marble: Token3D = marbles_3d.get(origem)
	var alvo: Vector2i = to if to != null else Vector2i(-1, -1)

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
	if alvo != origem:
		set_status(tr("PEG_DROP"))
	_paint_targets()


func _select(pos: Vector2i) -> void:
	selected_pos = pos
	valid_targets = PegSolitaireRules.get_valid_moves_for_peg(grid_data, pos)
	for p in marbles_3d.keys():
		(marbles_3d[p] as Token3D).highlight(p == pos)
	_paint_targets()
	if valid_targets.is_empty():
		set_status(tr("PEG_NO_JUMPS"))
	else:
		set_status(tr("PEG_DRAG_HINT"))


func _clear_selection() -> void:
	selected_pos = Vector2i(-1, -1)
	valid_targets.clear()
	for p in marbles_3d.keys():
		(marbles_3d[p] as Token3D).highlight(false)
	_paint_targets()

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
	shell.timer.stop()
	var remaining: int = PegSolitaireRules.count_pegs(grid_data)
	var fatos := {
		"pegs": remaining,
		"perfect": remaining == 1,
		"time": shell.timer.get_time()
	}
	if remaining == 1:
		finish_game(tr("PEG_WIN_PERFECT"), true, fatos)
	elif remaining <= 3:
		finish_game(tr("PEG_GOOD") % remaining, false, fatos)
	else:
		finish_game(tr("PEG_OVER") % remaining, false, fatos)
