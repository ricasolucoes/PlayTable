extends BaseGame

## BattleshipGame: Batalha Naval 3D com os dois mapas na mesa ao mesmo tempo.
##
## Antes havia UM tabuleiro e duas abas -- "Radar" e "Frota Aliada" -- que
## redesenhavam o mesmo tabuleiro com conteudo diferente. Batalha naval e um
## jogo de comparar dois mapas: escondendo um deles atras de um botao, o jogador
## nunca via o tiro que levou junto do tiro que deu. Agora os dois mapas ficam
## na mesa, o de ataque grande em cima e a frota aliada menor embaixo.

## Tamanho da casa em cada mapa. O de ataque recebe o toque, entao precisa de
## casa grande; o da frota so e consultado.
const RADAR_CELL := 0.58
const FLEET_CELL := 0.33
const GRID := 10

## Folga entre os dois mapas.
const BOARD_GAP := 0.55

## Altura do casco sobre a casa.
const HULL_HEIGHT := 0.22

var player_grid: Grid2D
var ai_grid: Grid2D
var player_ships: Array = []
var ai_ships: Array = []
var is_player_turn: bool = true

## Degrau de 1 a 10 do DifficultyManager. Vira a chance de a IA largar o mapa
## de densidade e sortear casa.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

## O que a IA sabe da frota do jogador -- so o que os proprios tiros contaram.
## Ela nunca le `player_grid`.
var ai_memoria: Dictionary = {}

@onready var radar_board: Board3D = $Board3D
@onready var fleet_board: Board3D = $FleetBoard
@onready var game_shell: GameShell = $GameShell
@onready var level_label: Label = game_shell.level_label

## Pinos e cascos de cada mapa, para limpar entre partidas.
var _radar_marks: Node3D
var _radar_wrecks: Node3D
var _fleet_marks: Node3D
var _fleet_hulls: Node3D
var _player_hull_nodes: Dictionary = {}   # indice do navio -> MeshInstance3D


func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = game_shell.status_label
	btn_restart = game_shell.btn_restart
	game_shell.restart_requested.connect(_on_btn_restart_pressed)
	env_3d.apply_theme(GameTheme3D.steel_blue())
	ai_level = DifficultyManager.get_level(game_id)

	radar_board.setup_board(GRID, GRID, RADAR_CELL, "ocean_radar")
	fleet_board.setup_board(GRID, GRID, FLEET_CELL, "ocean_radar")
	_place_boards()

	_radar_marks = _child_root(radar_board, "Marks")
	_radar_wrecks = _child_root(radar_board, "Wrecks")
	_fleet_marks = _child_root(fleet_board, "Marks")
	_fleet_hulls = _child_root(fleet_board, "Hulls")

	# O toque entra pelo proprio tabuleiro: a casa tocada e a casa desenhada.
	radar_board.cell_clicked.connect(_on_radar_cell_clicked)
	fleet_board.cell_clicked.connect(_on_fleet_cell_clicked)

	_start_new_game()


## Empilha os dois mapas na mesa e enquadra os dois juntos.
##
## A camera do PlayTable so precisa saber o retangulo que tem de caber; quando a
## largura manda -- e em retrato manda sempre -- ela mesma inclina mais para
## aproveitar a altura que sobraria. E o que faz os dois mapas caberem sem que
## nenhum deles vire um selo.
func _place_boards() -> void:
	var radar_size := radar_board.content_size()
	var fleet_size := fleet_board.content_size()
	var total_depth: float = radar_size.y + BOARD_GAP + fleet_size.y

	var z0: float = -total_depth * 0.5
	radar_board.position = Vector3(0.0, 0.0, z0 + radar_size.y * 0.5)
	fleet_board.position = Vector3(0.0, 0.0, z0 + radar_size.y + BOARD_GAP + fleet_size.y * 0.5)

	_board_caption(radar_board, tr("BATTLESHIP_ENEMY_FLEET"), Color(1.0, 0.47, 0.38), radar_size)
	_board_caption(fleet_board, tr("BATTLESHIP_YOUR_FLEET"), Color(0.52, 0.86, 1.0), fleet_size)

	# A HUD ocupa os 230 px de cima; a camera enquadra a faixa que sobra.
	fit_table(Vector2(maxf(radar_size.x, fleet_size.x) + 0.45, total_depth + 0.45))


func _board_caption(board: Board3D, text: String, color: Color, board_size: Vector2) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 64
	# O rotulo do mapa menor nao pode encolher junto com o mapa: ele e lido na
	# mesma tela, a mesma distancia. Por isso o tamanho e fixo em unidades de
	# mundo, e nao proporcional ao tabuleiro.
	lbl.pixel_size = 0.0042
	lbl.modulate = color
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.shaded = false
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lbl.position = Vector3(0.0, 0.02, -board_size.y * 0.5 - 0.26)
	board.add_child(lbl)


func _child_root(parent: Node3D, name_: String) -> Node3D:
	var node := Node3D.new()
	node.name = name_
	parent.add_child(node)
	return node


func _start_new_game() -> void:
	game_over = false
	is_player_turn = true
	btn_restart.hide()

	player_grid = Grid2D.new(GRID, GRID, 0)
	ai_grid = Grid2D.new(GRID, GRID, 0)
	player_ships = BattleshipRules.place_all_ships_random(player_grid)
	ai_ships = BattleshipRules.place_all_ships_random(ai_grid)
	ai_level = DifficultyManager.get_level(game_id)
	ai_memoria = BattleshipAI.nova_memoria()

	for root in [_radar_marks, _radar_wrecks, _fleet_marks, _fleet_hulls]:
		for c in root.get_children():
			c.queue_free()
	_player_hull_nodes.clear()

	radar_board.clear_states()
	fleet_board.clear_states()

	# A frota aliada fica a vista o tempo todo: e o mapa que o jogador consulta.
	for i in player_ships.size():
		_render_player_hull(player_ships[i], i)

	_update_fleet_status_labels()
	set_status(tr("BATTLESHIP_YOUR_TURN"))


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

## Crava o pino na coordenada. Ele cai de cima e assenta com um recuo curto;
## o de acerto ainda pulsa uma vez.
func _spawn_peg(board: Board3D, root: Node3D, r: int, c: int, is_hit: bool) -> void:
	var scale_ref: float = board.cell_size / RADAR_CELL
	var peg := MeshInstance3D.new()
	peg.mesh = MeshBuilder3D.create_peg_pin(0.35 * scale_ref, 0.1 * scale_ref)
	var target := board.get_cell_position_3d(r, c, 0.18 * scale_ref)
	peg.position = target
	if is_hit:
		peg.material_override = MaterialFactory3D.get_glow(Color(1.0, 0.25, 0.1), 2.5)
	else:
		peg.material_override = MaterialFactory3D.get_silver()
	root.add_child(peg)

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


## Geometria do casco a partir das casas que o navio ocupa.
## Devolve `{size, center}` em coordenadas locais do tabuleiro.
func _hull_geometry(board: Board3D, ship: Dictionary) -> Dictionary:
	var cells: Array = ship["cells"]
	var primeira: Vector2i = cells[0]
	var ultima: Vector2i = cells[cells.size() - 1]
	var is_vert: bool = primeira.x != ultima.x
	var cell := board.cell_size
	var ao_longo: float = float(cells.size()) * cell * 0.92
	var atraves: float = cell * 0.62
	var a := board.get_cell_position_3d(primeira.x, primeira.y, 0.0)
	var b := board.get_cell_position_3d(ultima.x, ultima.y, 0.0)
	var center := (a + b) * 0.5
	var height: float = HULL_HEIGHT * (cell / RADAR_CELL)
	center.y = Tokens3D.TILE_THICKNESS + height * 0.5
	return {
		"size": Vector3(atraves if is_vert else ao_longo, height, ao_longo if is_vert else atraves),
		"center": center,
	}


func _render_player_hull(ship: Dictionary, index: int) -> void:
	if (ship["cells"] as Array).is_empty():
		return
	var geo := _hull_geometry(fleet_board, ship)
	var box := BoxMesh.new()
	box.size = geo["size"]
	var hull := MeshInstance3D.new()
	hull.mesh = box
	hull.material_override = MaterialFactory3D.get_plastic(Color(0.86, 0.88, 0.84), true)
	hull.position = geo["center"]
	_fleet_hulls.add_child(hull)
	_player_hull_nodes[index] = hull

	var d := Quality3D.duration(Tokens3D.DUR_SLOW)
	if d <= 0.0:
		return
	hull.position = geo["center"] - Vector3(0.0, 0.5, 0.0)
	var tw := hull.create_tween()
	tw.tween_interval(float(index) * 0.06)
	tw.tween_property(hull, "position", geo["center"], d) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## O navio inimigo afundado aparece inteiro no mapa de ataque.
##
## Ate aqui o jogador so ficava com os pinos vermelhos espalhados e nunca via o
## que tinha derrubado. O casco sobe do fundo no lugar exato das casas, ja em
## tom de destroco, e estoura em volta.
func _reveal_enemy_wreck(ship: Dictionary) -> void:
	if (ship["cells"] as Array).is_empty():
		return
	var geo := _hull_geometry(radar_board, ship)
	var size: Vector3 = geo["size"]
	var center: Vector3 = geo["center"]

	var box := BoxMesh.new()
	box.size = size
	var wreck := MeshInstance3D.new()
	wreck.mesh = box
	wreck.material_override = MaterialFactory3D.get_plastic(Color(0.30, 0.26, 0.24), false)
	wreck.position = center
	_radar_wrecks.add_child(wreck)

	_explode_around(_radar_wrecks, center, size)

	var d := Quality3D.duration(Tokens3D.DUR_SLOW)
	if d <= 0.0:
		return
	wreck.position = center - Vector3(0.0, 0.45, 0.0)
	wreck.create_tween().tween_property(wreck, "position", center, d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## O navio aliado afundado queima no lugar onde estava.
func _burn_player_hull(ship: Dictionary) -> void:
	var index := player_ships.find(ship)
	var geo := _hull_geometry(fleet_board, ship)
	if _player_hull_nodes.has(index):
		var hull: MeshInstance3D = _player_hull_nodes[index]
		if is_instance_valid(hull):
			hull.material_override = MaterialFactory3D.get_plastic(Color(0.28, 0.24, 0.22), false)
	_explode_around(_fleet_hulls, geo["center"], geo["size"])


func _explode_around(parent: Node3D, center: Vector3, size: Vector3) -> void:
	# Meias-medidas: o estouro parte do contorno do casco, nao de um ponto no
	# meio dele -- e o que faz o fogo abrir EM VOLTA do navio.
	Explosion3D.burst(parent, center, size * 0.5)
	if env_3d:
		env_3d.focus_on(parent.to_global(center))


func _update_fleet_status_labels() -> void:
	var ai_sunk := BattleshipRules.count_sunk_ships(ai_ships)
	var player_sunk := BattleshipRules.count_sunk_ships(player_ships)
	set_duel_score("%d/5" % ai_sunk, "%d/5" % player_sunk, "SCORE_SUNK", "SCORE_LOST")
	level_label.text = DifficultyManager.label_for(game_id)


# ---------------------------------------------------------------------------
# Turnos
# ---------------------------------------------------------------------------

func _on_fleet_cell_clicked(_r: int, _c: int) -> void:
	if game_over:
		return
	set_status(tr("BATTLESHIP_WRONG_BOARD"))


func _on_radar_cell_clicked(r: int, c: int) -> void:
	if game_over or not is_player_turn:
		return
	var cell_val: int = ai_grid.get_cell(r, c)
	if cell_val == 2 or cell_val == 3:
		set_status(tr("BATTLESHIP_ALREADY_SHOT"))
		return

	var is_hit: bool = cell_val == 1
	ai_grid.set_cell(r, c, 3 if is_hit else 2)
	_spawn_peg(radar_board, _radar_marks, r, c, is_hit)
	if AudioManager:
		AudioManager.play_piece_place()

	if is_hit:
		var sunk_ship := BattleshipRules.check_ship_sunk(ai_ships, ai_grid, r, c)
		if sunk_ship.size() > 0:
			set_status(tr("BATTLESHIP_YOU_SANK") % tr(str(sunk_ship["name"])))
			_reveal_enemy_wreck(sunk_ship)
		else:
			set_status(tr("BATTLESHIP_HIT"))
	else:
		set_status(tr("BATTLESHIP_MISS"))

	_update_fleet_status_labels()

	if BattleshipRules.check_all_sunk(ai_ships):
		_end_game(true)
		return

	is_player_turn = false
	await get_tree().create_timer(0.6).timeout
	_play_ai_turn()


func _play_ai_turn() -> void:
	var ai_target := BattleshipAI.escolher_tiro(ai_memoria, ai_level)
	if ai_target.x < 0:
		is_player_turn = true
		return
	var r := ai_target.x
	var c := ai_target.y

	var is_hit: bool = int(player_grid.get_cell(r, c)) == 1
	player_grid.set_cell(r, c, 3 if is_hit else 2)
	_spawn_peg(fleet_board, _fleet_marks, r, c, is_hit)

	# A IA so fica sabendo o que o tiro revelou -- acerto, erro e, quando
	# afunda, as casas do navio. E dai que sai o mapa do proximo tiro.
	var afundadas: Array = []
	if is_hit:
		var sunk := BattleshipRules.check_ship_sunk(player_ships, player_grid, r, c)
		if sunk.size() > 0:
			afundadas = sunk["cells"]
			set_status(tr("BATTLESHIP_AI_SANK") % tr(str(sunk["name"])))
			_burn_player_hull(sunk)
		else:
			set_status(tr("BATTLESHIP_AI_HIT"))
	else:
		set_status(tr("BATTLESHIP_AI_MISS"))
	BattleshipAI.registrar(ai_memoria, ai_target, is_hit, afundadas)

	_update_fleet_status_labels()

	if BattleshipRules.check_all_sunk(player_ships):
		_end_game(false)
		return

	is_player_turn = true


func _end_game(is_player_win: bool) -> void:
	if is_player_win:
		finish_game(tr("BATTLESHIP_WIN"), true)
	else:
		finish_game(tr("BATTLESHIP_LOSE"))
