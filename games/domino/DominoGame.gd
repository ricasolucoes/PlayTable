extends BaseGame

## DominoGame: Dominó 3D com Pedras em Marfim Nobre, Rebites Dourados e Disposição na Mesa

## Medidas da pedra, em unidades de mundo. `LEN` corre ao longo da corrente.
const TILE_LEN := 0.82
const TILE_WID := 0.41
const TILE_THICK := 0.12

## Largura maxima de uma fileira antes de a corrente dobrar para a de baixo.
const ROW_MAX_X := 5.0

## Distancia entre fileiras da corrente.
const ROW_PITCH := 0.86

var boneyard: Array[Dictionary] = []
var player_hand: Array[Dictionary] = []
var ai_hand: Array[Dictionary] = []
var board_chain: Array[Dictionary] = []

var left_end: int = -1
var right_end: int = -1

var is_player_turn: bool = true
var consecutive_passes: int = 0
var selected_tile_idx: int = -1

## Degrau de 1 a 10 do DifficultyManager. Vira a chance de a IA largar a
## avaliacao e sortear a pedra.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

## O que a IA aprendeu do jogador: cada vez que ele compra ou passa, ele diz
## que nao tem as duas pontas da mesa.
var ai_memoria: Dictionary = {}

@onready var table_tiles_root: Node3D = $TableTilesRoot
@onready var ends_label: Label = $UI/VBoxContainer/EndsLabel
@onready var ai_info_label: Label = $UI/VBoxContainer/AIInfoLabel
@onready var player_hand_container: HBoxContainer = $UI/PlayerArea/HandVBox/HandContainer
@onready var btn_draw: Button = $UI/Actions/BtnDraw
@onready var btn_pass: Button = $UI/Actions/BtnPass
@onready var btn_play_left: Button = $UI/Actions/BtnPlayLeft
@onready var btn_play_right: Button = $UI/Actions/BtnPlayRight

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/Actions/BtnRestart
	menu_scene_path = MENU_TABULEIRO
	_start_new_game()

func _start_new_game() -> void:
	game_over = false
	consecutive_passes = 0
	selected_tile_idx = -1
	ai_level = DifficultyManager.get_level(game_id)
	ai_memoria = DominoAI.nova_memoria()
	btn_restart.hide()
	btn_play_left.hide()
	btn_play_right.hide()
	
	boneyard = DominoRules.generate_boneyard_28()
	boneyard.shuffle()
	
	player_hand.clear()
	ai_hand.clear()
	for i in range(7):
		player_hand.append(boneyard.pop_back())
		ai_hand.append(boneyard.pop_back())
		
	board_chain.clear()
	var starting_tile := {}
	var starting_player: int = 0
	for double_val in range(6, -1, -1):
		for p_idx in range(player_hand.size()):
			var t := player_hand[p_idx]
			if t["a"] == double_val and t["b"] == double_val:
				starting_tile = player_hand.pop_at(p_idx)
				starting_player = 1
				break
		if starting_tile.size() > 0: break
		
		for ai_idx in range(ai_hand.size()):
			var t := ai_hand[ai_idx]
			if t["a"] == double_val and t["b"] == double_val:
				starting_tile = ai_hand.pop_at(ai_idx)
				starting_player = 2
				break
		if starting_tile.size() > 0: break
		
	if starting_tile.size() == 0:
		starting_tile = player_hand.pop_back()
		starting_player = 1
		
	board_chain.append(starting_tile)
	left_end = starting_tile["a"]
	right_end = starting_tile["b"]
	
	_render_table_tiles_3d()
	_update_ui()
	
	if starting_player == 1:
		set_status(tr("DOMINO_YOU_OPEN") % [starting_tile["a"], starting_tile["b"]])
		is_player_turn = false
		await get_tree().create_timer(0.8).timeout
		_play_ai_turn()
	else:
		set_status(tr("DOMINO_AI_OPENS") % [starting_tile["a"], starting_tile["b"]])
		is_player_turn = true
		_update_action_buttons()

## Desenha a corrente na mesa.
##
## A versao anterior punha as pedras em fila reta, todas com a mesma cara de
## retangulo de marfim: sem os pontos nao havia o que ler, e depois de umas dez
## jogadas a fila saia da tela pelos dois lados. Agora cada pedra tem os pontos
## gravados, a bucha entra atravessada como manda o jogo, e a corrente dobra
## para a fileira de baixo quando enche a largura da mesa. No fim a camera
## reenquadra o que existe -- a corrente cresce, o enquadramento cresce junto.
func _render_table_tiles_3d() -> void:
	for c in table_tiles_root.get_children(): c.queue_free()

	var rows := _layout_chain_rows()
	if rows.is_empty():
		return

	var widest := 0.0
	for row in rows:
		widest = maxf(widest, float(row["width"]))

	var total_depth := float(rows.size()) * ROW_PITCH
	var z0 := -total_depth * 0.5 + ROW_PITCH * 0.5

	for row_idx in rows.size():
		var row: Dictionary = rows[row_idx]
		var row_z: float = z0 + float(row_idx) * ROW_PITCH
		var x: float = -float(row["width"]) * 0.5
		for entry in (row["tiles"] as Array):
			var span := float(entry["span"])
			_spawn_table_tile(entry["tile"], Vector3(x + span * 0.5, 0.06, row_z),
				bool(entry["is_double"]), int(entry["end_mark"]), span)
			x += span

	# Enquadra o que a corrente ocupa agora, com folga para a proxima jogada.
	fit_table(Vector2(maxf(widest, 1.8) + 0.6, maxf(total_depth, 1.0) + 0.6))


## Divide a corrente em fileiras que cabem na largura da mesa.
##
## Devolve `[{width: float, tiles: [{tile, span, is_double, end_mark}]}]`, onde
## `end_mark` e -1 na ponta esquerda, 1 na direita e 0 no meio.
func _layout_chain_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var current: Array = []
	var width := 0.0
	var last := board_chain.size() - 1

	for i in board_chain.size():
		var tile: Dictionary = board_chain[i]
		var is_double: bool = tile["a"] == tile["b"]
		# A bucha entra atravessada: ocupa a largura da pedra, nao o comprimento.
		var span: float = (TILE_WID if is_double else TILE_LEN) + 0.03
		if not current.is_empty() and width + span > ROW_MAX_X:
			rows.append({"width": width, "tiles": current})
			current = []
			width = 0.0
		var end_mark := 0
		if i == 0:
			end_mark = -1
		elif i == last:
			end_mark = 1
		current.append({"tile": tile, "span": span, "is_double": is_double, "end_mark": end_mark})
		width += span

	if not current.is_empty():
		rows.append({"width": width, "tiles": current})
	return rows


func _spawn_table_tile(tile: Dictionary, pos: Vector3, is_double: bool, end_mark: int,
		span: float) -> void:
	var node := Node3D.new()
	node.position = pos
	# A malha nasce comprida em Z. Pedra normal deita ao longo da corrente (X);
	# a bucha fica como nasceu, atravessada.
	node.rotation_degrees.y = 0.0 if is_double else 90.0

	var tile_mesh := MeshInstance3D.new()
	tile_mesh.mesh = MeshBuilder3D.create_domino_tile(TILE_LEN, TILE_WID, TILE_THICK)
	tile_mesh.material_override = MaterialFactory3D.get_ivory()
	node.add_child(tile_mesh)

	node.add_child(PipFactory3D.domino_divider(TILE_LEN, TILE_WID, TILE_THICK))
	node.add_child(PipFactory3D.domino_pips(tile["a"], tile["b"], TILE_LEN, TILE_WID, TILE_THICK))

	table_tiles_root.add_child(node)

	if end_mark != 0 and board_chain.size() > 1:
		table_tiles_root.add_child(_end_marker(pos, end_mark, span))


## Halo dourado rente a mesa, encostado na ponta livre da corrente. E o que liga
## o rotulo "Pontas: [ 3 ] <-> [ 5 ]" a pedra de onde aquele numero saiu.
##
## Fica preso ao TableTilesRoot, e nao a pedra: a pedra normal esta girada 90
## graus e a bucha nao, entao um filho da pedra apontaria para lados diferentes
## nos dois casos. Em coordenadas de mesa a corrente sempre corre em X.
func _end_marker(tile_pos: Vector3, end_mark: int, span: float) -> MeshInstance3D:
	var halo := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = TILE_WID * 0.22
	disc.bottom_radius = TILE_WID * 0.22
	disc.height = 0.014
	halo.mesh = disc
	halo.position = tile_pos + Vector3(float(end_mark) * (span * 0.5 + TILE_WID * 0.30),
		-0.05, 0.0)
	halo.material_override = MaterialFactory3D.get_glow(Color(1.0, 0.82, 0.28), 0.85)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return halo

func _update_ui() -> void:
	set_duel_score(player_hand.size(), ai_hand.size(), "SCORE_YOURS", "SCORE_AI_CARDS")
	ai_info_label.text = tr("DOMINO_BONEYARD") % boneyard.size() + difficulty_suffix()
	ends_label.text = tr("DOMINO_ENDS") % [left_end, right_end]
	
	# Mão do Jogador: pedras desenhadas, nao botoes com o texto "6/---/4".
	for c in player_hand_container.get_children(): c.queue_free()

	# Com 7 pedras na mao e a largura fixa do container, cada pedra tem 82 px.
	# Passando disso (compra do monte) elas encolhem ate caber, em vez de a
	# fileira transbordar e sumir pelas bordas da tela.
	var count: int = maxi(player_hand.size(), 1)
	var available: float = player_hand_container.size.x
	if available <= 0.0:
		available = 600.0
	var sep: float = player_hand_container.get_theme_constant("separation")
	var tile_w: float = clampf((available - sep * float(count - 1)) / float(count), 36.0, 74.0)

	for i in range(player_hand.size()):
		var tile: Dictionary = player_hand[i]
		var view := DominoTile2D.new()
		view.custom_minimum_size = Vector2(tile_w, tile_w * 1.8)
		view.setup(tile["a"], tile["b"])
		view.selected = (i == selected_tile_idx)
		view.playable = is_player_turn and DominoRules.can_play_tile(tile, left_end, right_end)
		view.pressed.connect(_on_player_tile_selected.bind(i))
		player_hand_container.add_child(view)

	_update_action_buttons()

func _update_action_buttons() -> void:
	if game_over or not is_player_turn:
		btn_draw.hide()
		btn_pass.hide()
		btn_play_left.hide()
		btn_play_right.hide()
		return
		
	if selected_tile_idx >= 0 and selected_tile_idx < player_hand.size():
		var tile := player_hand[selected_tile_idx]
		var can_left = (tile["a"] == left_end or tile["b"] == left_end)
		var can_right = (tile["a"] == right_end or tile["b"] == right_end)
		
		btn_play_left.visible = can_left
		btn_play_right.visible = can_right
		btn_draw.hide()
		btn_pass.hide()
	else:
		btn_play_left.hide()
		btn_play_right.hide()
		var has_moves := DominoRules.has_any_valid_move(player_hand, left_end, right_end)
		if has_moves:
			btn_draw.hide()
			btn_pass.hide()
		else:
			if boneyard.size() > 0:
				btn_draw.show()
				btn_pass.hide()
			else:
				btn_draw.hide()
				btn_pass.show()

func _on_player_tile_selected(idx: int) -> void:
	if not is_player_turn or game_over: return
	selected_tile_idx = idx if selected_tile_idx != idx else -1
	_update_ui()

func _on_btn_play_left_pressed() -> void:
	_play_player_tile("left")

func _on_btn_play_right_pressed() -> void:
	_play_player_tile("right")

func _play_player_tile(side: String) -> void:
	if selected_tile_idx < 0: return
	var tile = player_hand.pop_at(selected_tile_idx)
	selected_tile_idx = -1
	consecutive_passes = 0
	
	if side == "left":
		if tile["b"] == left_end:
			board_chain.push_front(tile)
			left_end = tile["a"]
		else:
			var flipped := {"a": tile["b"], "b": tile["a"]}
			board_chain.push_front(flipped)
			left_end = flipped["a"]
	else:
		if tile["a"] == right_end:
			board_chain.push_back(tile)
			right_end = tile["b"]
		else:
			var flipped := {"a": tile["b"], "b": tile["a"]}
			board_chain.push_back(flipped)
			right_end = flipped["b"]
			
	_render_table_tiles_3d()
	_update_ui()
	
	if player_hand.size() == 0:
		_end_game(tr("DOMINO_YOU_WIN"), true)
		return
		
	is_player_turn = false
	set_status(tr("AI_TURN_SHORT"))
	_update_action_buttons()
	await get_tree().create_timer(0.8).timeout
	_play_ai_turn()

func _on_btn_draw_pressed() -> void:
	if boneyard.size() > 0:
		# O botao so aparece quando o jogador nao tem jogada: comprar denuncia
		# que ele nao tem nenhuma das duas pontas.
		DominoAI.registrar_falta(ai_memoria, left_end, right_end)
		var drawn = boneyard.pop_back()
		player_hand.append(drawn)
		set_status(tr("DOMINO_YOU_DREW"))
		_update_ui()

func _on_btn_pass_pressed() -> void:
	DominoAI.registrar_falta(ai_memoria, left_end, right_end)
	consecutive_passes += 1
	set_status(tr("DOMINO_YOU_PASSED"))
	if consecutive_passes >= 2:
		_check_board_lock()
		return
	is_player_turn = false
	_update_action_buttons()
	await get_tree().create_timer(0.8).timeout
	_play_ai_turn()

## O turno da IA.
##
## A compra segue a mesma regra que o jogador ja seguia: quem nao tem jogada
## compra ate ter uma, e so passa com o monte vazio. Antes a IA comprava UMA
## pedra e passava a vez mesmo quando a pedra comprada encaixava, enquanto o
## jogador podia comprar quantas quisesse sem gastar turno -- a regra valia
## para um lado so.
func _play_ai_turn() -> void:
	while not DominoRules.has_any_valid_move(ai_hand, left_end, right_end) \
			and boneyard.size() > 0:
		ai_hand.append(boneyard.pop_back())
		set_status(tr("DOMINO_AI_DREW"))

	var ai_play := DominoAI.escolher(ai_hand, left_end, right_end, ai_memoria, ai_level)
	if ai_play.size() > 0:
		var t_idx = ai_play["tile_index"]
		var side = ai_play["side"]
		var tile = ai_hand.pop_at(t_idx)
		consecutive_passes = 0
		
		if side == "left":
			if tile["b"] == left_end:
				board_chain.push_front(tile)
				left_end = tile["a"]
			else:
				var flipped := {"a": tile["b"], "b": tile["a"]}
				board_chain.push_front(flipped)
				left_end = flipped["a"]
		else:
			if tile["a"] == right_end:
				board_chain.push_back(tile)
				right_end = tile["b"]
			else:
				var flipped := {"a": tile["b"], "b": tile["a"]}
				board_chain.push_back(flipped)
				right_end = flipped["b"]
				
		_render_table_tiles_3d()
		set_status(tr("DOMINO_AI_PLAYED") % tr("DOMINO_SIDE_LEFT" if side == "left" else "DOMINO_SIDE_RIGHT"))
		
		if ai_hand.size() == 0:
			_end_game(tr("DOMINO_AI_WIN"), false)
			return
	else:
		# Chegou aqui com o monte vazio e sem jogada: so resta passar.
		consecutive_passes += 1
		set_status(tr("DOMINO_AI_PASSED"))
		if consecutive_passes >= 2:
			_check_board_lock()
			return
				
	is_player_turn = true
	_update_ui()

func _check_board_lock() -> void:
	var p_pts := DominoRules.calculate_hand_points(player_hand)
	var ai_pts := DominoRules.calculate_hand_points(ai_hand)
	if p_pts < ai_pts:
		_end_game(tr("DOMINO_LOCK_YOU_WIN") % [p_pts, ai_pts], true)
	elif ai_pts < p_pts:
		_end_game(tr("DOMINO_LOCK_AI_WIN") % [ai_pts, p_pts], false)
	else:
		_end_game(tr("DOMINO_LOCK_DRAW") % p_pts, false)

func _end_game(msg: String, is_player_win: bool) -> void:
	finish_game(msg, is_player_win)
	_update_action_buttons()
