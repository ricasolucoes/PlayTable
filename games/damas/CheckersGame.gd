extends BaseGame

## CheckersGame: Damas com Tabuleiro 3D em Nogueira, Peças de Marfim/Obsidiana e Coroas Douradas

var grid_data: Grid2D
var selected_pos: Vector2i = Vector2i(-1, -1)
var valid_moves: Array[Dictionary] = []
var is_player_turn: bool = true
var continuing_capture_pos: Vector2i = Vector2i(-1, -1)
var pieces_3d: Dictionary = {}

## Degrau de 1 a 10 do DifficultyManager. Vira profundidade de busca da IA.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

## Dois no mesmo aparelho: as obsidianas deixam de ser da maquina e passam a
## ser da pessoa ao lado. O tabuleiro nao muda -- o que muda e de quem sao as
## pecas que respondem ao toque agora.
var vs_ai: bool = true
var mode_switch: ModeSwitch = null

## O lado da vez na mesa compartilhada: 1 marfim, -1 obsidiana. Contra a
## maquina nao significa nada, porque quem toca e sempre o marfim.
var _lado_local: int = 1

@onready var board_3d: Board3D = $Board3D
@onready var pieces_root: Node3D = $PiecesRoot
@onready var game_shell: GameShell = $GameShell
@onready var level_label: Label = game_shell.level_label

## A arte gerada das pecas (`tools/art/damas.json`), por material. Sem o
## arquivo em `shared/assets/damas/`, fica o marfim e a obsidiana procedurais.
const ART_PECAS := {"ivory": "damas/peca_clara", "obsidian": "damas/peca_escura"}

## Toque e arrasto sobre as 64 casas, projetadas da propria mesa. Dois toques
## continuam valendo; pegar a peca com o dedo e o gesto que a pessoa tenta
## primeiro, e so o Resta Um e o Hanoi o aceitavam.
var picker: DragPicker3D = null

## Peca sendo arrastada, e de onde saiu.
var _drag_piece: Token3D = null
var _drag_from: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = game_shell.status_label
	btn_restart = game_shell.btn_restart
	game_shell.restart_requested.connect(_on_btn_restart_pressed)
	ai_level = DifficultyManager.get_level(game_id)
	env_3d.apply_theme(_build_theme())
	board_3d.setup_board(CheckersRules.ROWS, CheckersRules.COLS, 0.75, "wood_checkered")
	# O botao de modo entra ANTES do enquadramento: ele e HUD ancorada no topo,
	# `measure_hud_bands()` o mede, e o tabuleiro desce o suficiente para nao
	# ficar por baixo dele. Montado depois, a mesa era enquadrada sem saber que
	# ele existia e o botao comia o toque das casas de cima.
	mode_switch = ModeSwitch.montar(self, vs_ai)
	mode_switch.trocou.connect(_on_modo_trocado)
	# O tabuleiro se anuncia para a camera: nao existe distancia escrita a mao.
	fit_table(board_3d.content_size())
	board_3d.cell_clicked.connect(_on_cell_clicked)
	_setup_picker()
	_start_new_game()


## O picker fica por cima do picking fisico do Board3D e passa a ser a porta do
## toque: o toque simples continua caindo em `_on_cell_clicked`, e o arrasto
## ganha os tres sinais abaixo.
func _setup_picker() -> void:
	picker = DragPicker3D.new()
	add_child(picker)
	picker.attach(env_3d, Tokens3D.TILE_THICKNESS)
	var alvos: Dictionary = {}
	for r in range(CheckersRules.ROWS):
		for c in range(CheckersRules.COLS):
			alvos[Vector2i(r, c)] = board_3d.to_global(_cell_pos(r, c))
	picker.set_targets(alvos)
	picker.target_tapped.connect(func(id: Variant) -> void:
		var casa: Vector2i = id
		_on_cell_clicked(casa.x, casa.y))
	picker.drag_started.connect(_on_peca_pega)
	picker.drag_moved.connect(_on_peca_movida)
	picker.drag_ended.connect(_on_peca_solta)

## Damas de salao: tabuleiro de bordo e nogueira sobre couro, luz de abajur.
func _build_theme() -> GameTheme3D:
	var theme := GameTheme3D.parlour_walnut()
	theme.surface = &"leather"
	theme.surface_color = Color(0.21, 0.13, 0.10)
	theme.accent = Color(0.95, 0.78, 0.30)
	return theme

func _start_new_game() -> void:
	game_over = false
	is_player_turn = true
	_lado_local = 1
	selected_pos = Vector2i(-1, -1)
	continuing_capture_pos = Vector2i(-1, -1)
	valid_moves.clear()
	btn_restart.hide()
	
	ai_level = DifficultyManager.get_level(game_id)
	_update_level_label()
	grid_data = CheckersRules.create_initial_board()
	_sync_pieces_3d()
	set_status(tr("CHECKERS_YOUR_TURN") if vs_ai else tr("TURN_PLAYER") % 1)


## De quem sao as pecas que o toque move agora. Contra a maquina e sempre o
## marfim; na mesa compartilhada alterna.
func _lado() -> int:
	return 1 if vs_ai else _lado_local


## O lado como numero de jogador, para as frases: marfim e o 1, obsidiana o 2.
static func _numero_do_lado(lado: int) -> int:
	return 1 if lado > 0 else 2


## O jogador trocou o modo: a partida recomeca, porque meia partida contra a
## maquina nao vira meia partida entre duas pessoas.
func _on_modo_trocado(novo_vs_ai: bool) -> void:
	vs_ai = novo_vs_ai
	restart_game()


func _update_level_label() -> void:
	if level_label == null:
		return
	if not vs_ai:
		# Sem maquina na mesa nao ha degrau de IA para mostrar.
		level_label.text = tr("MODE_LABEL") % tr("MODE_TWO_PLAYERS")
		return
	level_label.text = DifficultyManager.label_for(game_id)

func _sync_pieces_3d() -> void:
	for p in pieces_root.get_children(): p.queue_free()
	pieces_3d.clear()
	board_3d.clear_states()

	for r in range(CheckersRules.ROWS):
		for c in range(CheckersRules.COLS):
			var val: int = grid_data.get_cell(r, c)
			if val != 0:
				var piece := preload("res://shared/3d/Token3D.tscn").instantiate()
				piece.token_type = "cylinder"
				piece.token_radius = 0.30
				piece.material_name = "ivory" if val > 0 else "obsidian"
				piece.art_by_material = ART_PECAS
				piece.position = _cell_pos(r, c)
				pieces_root.add_child(piece)
				pieces_3d[Vector2i(r, c)] = piece

				if abs(val) == 2:
					piece.promote_queen()

	_update_score()

## Altura de apoio da peca: o topo da casa, nunca um valor solto.
func _cell_pos(r: int, c: int) -> Vector3:
	return board_3d.get_cell_position_3d(r, c, Tokens3D.TILE_THICKNESS)

func _update_score() -> void:
	var player_count: int = 0
	var ai_count: int = 0
	for r in range(CheckersRules.ROWS):
		for c in range(CheckersRules.COLS):
			var val: int = grid_data.get_cell(r, c)
			if val > 0: player_count += 1
			elif val < 0: ai_count += 1
	if vs_ai:
		set_duel_score(player_count, ai_count)
	else:
		set_duel_score(player_count, ai_count, "SCORE_PLAYER_1", "SCORE_PLAYER_2")

func _on_cell_clicked(r: int, c: int) -> void:
	if game_over or not is_player_turn: return
	
	var clicked_pos := Vector2i(r, c)
	
	for vm in valid_moves:
		if vm["to"] == clicked_pos:
			_execute_player_move(selected_pos, vm)
			return
			
	if continuing_capture_pos != Vector2i(-1, -1):
		return
		
	var val: int = grid_data.get_cell(r, c)
	if val != 0 and signi(val) == _lado(): # Peça de quem joga agora
		# Captura e obrigatoria -- e sempre foi, em `get_all_valid_moves`. Só a
		# tela nao cobrava: dava para deixar a captura de lado e passear com
		# outra peca enquanto a IA, que joga pelas regras, era obrigada a comer.
		# Era metade do motivo de ganhar das Damas sem pensar.
		if not _piece_is_playable(clicked_pos):
			set_status(tr("CHECKERS_MUST_CAPTURE"))
			_highlight_forced_captures()
			return
		selected_pos = clicked_pos
		valid_moves = CheckersRules.get_valid_moves_for_piece(grid_data, selected_pos)
		
		_show_selection(clicked_pos)
	else:
		# Tocar fora das proprias pecas desfaz a selecao.
		_clear_selection()
		selected_pos = Vector2i(-1, -1)
		valid_moves.clear()

## As pecas que o jogador pode mover agora. Havendo captura em qualquer peca,
## so as que capturam entram na lista.
func _playable_origins() -> Array[Vector2i]:
	var origens: Array[Vector2i] = []
	for m in CheckersRules.get_all_valid_moves(grid_data, _lado()):
		if not origens.has(m["from"]):
			origens.append(m["from"])
	return origens


func _piece_is_playable(pos: Vector2i) -> bool:
	return _playable_origins().has(pos)


## Aponta quem tem de comer, para a recusa nao ser um "nao" sem explicacao.
func _highlight_forced_captures() -> void:
	board_3d.clear_states()
	_lower_all_pieces()
	var destinos: Array = []
	destinos.assign(_playable_origins())
	board_3d.set_cells_state(destinos, Board3D.CellState.VALID)


## Marca a origem, levanta a peca e aponta cada destino possivel. O destaque
## usa tom E anel: quem nao distingue as cores ainda ve a marca.
func _show_selection(origin: Vector2i) -> void:
	board_3d.clear_states()
	board_3d.set_cell_state(origin.x, origin.y, Board3D.CellState.SELECTED)
	var destinations: Array = []
	for vm in valid_moves:
		destinations.append(vm["to"])
	board_3d.set_cells_state(destinations, Board3D.CellState.VALID)

	_lower_all_pieces()
	var piece = pieces_3d.get(origin)
	if piece:
		piece.select(true)

func _clear_selection() -> void:
	board_3d.clear_states()
	_lower_all_pieces()

func _lower_all_pieces() -> void:
	for piece in pieces_3d.values():
		piece.select(false)

func _execute_player_move(from_pos: Vector2i, move_dict: Dictionary) -> void:
	var to_pos = move_dict["to"]
	var captured_pos = move_dict["captured"]
	
	var piece_3d = pieces_3d.get(from_pos)
	if piece_3d:
		pieces_3d.erase(from_pos)
		pieces_3d[to_pos] = piece_3d
		piece_3d.select(false)
		piece_3d.jump_to(_cell_pos(to_pos.x, to_pos.y),
			Tokens3D.ARC_LONG if captured_pos != Vector2i(-1, -1) else Tokens3D.ARC_SHORT)
		
	if captured_pos != Vector2i(-1, -1):
		var cap_piece = pieces_3d.get(captured_pos)
		if cap_piece:
			cap_piece.vanish()
			pieces_3d.erase(captured_pos)

	# `apply_move` devolve um Dicionario, e todo Dicionario cheio e verdadeiro:
	# lido como bandeira, ele coroava TODA peca a cada lance -- a coroa nascia
	# na primeira jogada de cada peca e a animacao rodava de novo a cada passo.
	# A coroacao de verdade e a peca simples que virou dama neste lance.
	var era_dama := _is_queen(from_pos)
	CheckersRules.apply_move(grid_data, from_pos, to_pos, captured_pos)
	if piece_3d and not era_dama and _is_queen(to_pos):
		piece_3d.promote_queen()
		if AudioManager:
			AudioManager.play_card_match()
		
	board_3d.clear_states()

	if captured_pos != Vector2i(-1, -1):
		var further_captures := CheckersRules.get_captures_for_piece(grid_data, to_pos)
		if further_captures.size() > 0:
			continuing_capture_pos = to_pos
			selected_pos = to_pos
			valid_moves = further_captures
			# `_show_selection` ja pinta origem e destinos pelos estados certos.
			# Aqui a cena voltava a API por cor, cuja comparacao nao casava, e o
			# realce sumia justamente na captura multipla -- a jogada em que mais
			# se precisa ver para onde a peca ainda pode ir.
			_show_selection(to_pos)
			set_status(tr("CHECKERS_MUST_CHAIN"))
			return
			
	continuing_capture_pos = Vector2i(-1, -1)
	selected_pos = Vector2i(-1, -1)
	valid_moves.clear()
	
	_check_game_end_or_ai_turn()

func _check_game_end_or_ai_turn() -> void:
	_update_score()
	var winner := CheckersRules.check_game_over(grid_data)
	if winner != 0:
		_end_game(winner)
		return
		
	# Mesa compartilhada: a vez atravessa o tabuleiro sem sair do aparelho, e
	# `is_player_turn` continua verdadeiro porque quem joga agora tambem esta aqui.
	if not vs_ai:
		_lado_local = -_lado_local
		_clear_selection()
		set_status(tr("TURN_PLAYER") % _numero_do_lado(_lado_local))
		return

	is_player_turn = false
	set_status(tr("CHECKERS_AI_TURN"))

	# A busca roda fora da linha principal e comeca junto com a pausa de
	# encenacao: no degrau 10 ela leva perto de meio segundo aqui e mais num
	# telefone, e travar a tela por isso e defeito. Como ela corre durante a
	# pausa que ja existia, na pratica a IA continua respondendo no mesmo tempo.
	var saida: Array = []
	var tarefa := WorkerThreadPool.add_task(
		CheckersAI.pensar_em_tarefa.bind(grid_data.clone(), -1, ai_level, saida))

	await get_tree().create_timer(0.6).timeout
	# A arvore fica guardada antes do laco: quando o jogador sai da cena com a
	# busca em andamento, `get_tree()` passa a devolver `null` no quadro
	# seguinte, e `await null.process_frame` estoura. A tarefa nao segura
	# referencia para a cena, entao esperar por ela aqui e seguro.
	var arvore := get_tree()
	while not WorkerThreadPool.is_task_completed(tarefa):
		if arvore == null:
			break
		await arvore.process_frame
	WorkerThreadPool.wait_for_task_completion(tarefa)

	if not is_inside_tree() or game_over:
		return
	_play_ai_turn(saida[0] if not saida.is_empty() else {})

## Encena o turno que a busca escolheu, salto a salto.
##
## `turno` traz a cadeia de capturas inteira. Antes a cena continuava a cadeia
## sozinha pegando `further[0]`, a primeira da lista, e desmanchava a linha que
## a busca tinha calculado.
func _play_ai_turn(turno: Dictionary) -> void:
	if turno.is_empty():
		_end_game(1)
		return

	var origem: Vector2i = turno["from"]
	var pos: Vector2i = origem
	var piece_3d = pieces_3d.get(origem)
	if piece_3d:
		piece_3d.select(false)

	for i in range(turno["hops"].size()):
		if i > 0:
			await get_tree().create_timer(0.4).timeout
			if not is_inside_tree():
				return
		var hop: Dictionary = turno["hops"][i]
		var destino: Vector2i = hop["to"]
		var comida: Vector2i = hop["captured"]

		if piece_3d:
			pieces_3d.erase(pos)
			pieces_3d[destino] = piece_3d
			piece_3d.jump_to(_cell_pos(destino.x, destino.y),
				Tokens3D.ARC_LONG if comida != Vector2i(-1, -1) else Tokens3D.ARC_SHORT)

		if comida != Vector2i(-1, -1):
			var cap_piece = pieces_3d.get(comida)
			if cap_piece:
				cap_piece.vanish()
				pieces_3d.erase(comida)

		var era_dama := _is_queen(pos)
		CheckersRules.apply_move(grid_data, pos, destino, comida)
		if piece_3d and not era_dama and _is_queen(destino):
			piece_3d.promote_queen()
		pos = destino

	_update_score()
	board_3d.set_cells_state([origem, pos], Board3D.CellState.LAST_MOVE)
	var winner := CheckersRules.check_game_over(grid_data)
	if winner != 0:
		_end_game(winner)
		return

	is_player_turn = true
	set_status(tr("CHECKERS_YOUR_TURN"))


func _is_queen(pos: Vector2i) -> bool:
	return absi(int(grid_data.get_cell(pos.x, pos.y))) == 2


# ---------------------------------------------------------------------------
# Arrastar peca
# ---------------------------------------------------------------------------

func _on_peca_pega(id: Variant) -> void:
	var origem: Vector2i = id
	var dono := signi(int(grid_data.get_cell(origem.x, origem.y)))
	if game_over or not is_player_turn or dono != _lado():
		picker.cancel_drag()
		return
	# No meio de uma captura em cadeia so a peca que esta comendo pode andar.
	if continuing_capture_pos != Vector2i(-1, -1) and origem != continuing_capture_pos:
		picker.cancel_drag()
		return
	if not _piece_is_playable(origem):
		set_status(tr("CHECKERS_MUST_CAPTURE"))
		_highlight_forced_captures()
		picker.cancel_drag()
		return
	var piece: Token3D = pieces_3d.get(origem)
	if piece == null:
		picker.cancel_drag()
		return
	selected_pos = origem
	valid_moves = CheckersRules.get_valid_moves_for_piece(grid_data, origem)
	_show_selection(origem)
	_drag_piece = piece
	_drag_from = origem
	piece.set_lift(Tokens3D.LIFT_DRAG)


func _on_peca_movida(_from_id: Variant, _over: Variant, world: Vector3) -> void:
	if _drag_piece == null or world == Vector3.INF:
		return
	# Acompanha o dedo sem tween: tween aqui atrasaria a peca em relacao ao
	# ponto tocado, e o gesto pareceria emperrado.
	var local: Vector3 = pieces_root.to_local(world)
	_drag_piece.position = Vector3(local.x, Tokens3D.TILE_THICKNESS, local.z)


func _on_peca_solta(_from_id: Variant, to: Variant) -> void:
	var piece: Token3D = _drag_piece
	var origem: Vector2i = _drag_from
	_drag_piece = null
	_drag_from = Vector2i(-1, -1)
	if piece == null:
		return
	piece.set_lift(0.0)
	if to != null:
		var destino: Vector2i = to
		for vm in valid_moves:
			if vm["to"] == destino:
				# `jump_to` sai de onde a peca esta -- debaixo do dedo -- e nao
				# da casa de origem, que e o que faz o pouso parecer continuar
				# o gesto em vez de recomecar.
				_execute_player_move(origem, vm)
				return
	# Soltou fora de um destino: a peca volta para a casa dela. A selecao
	# continua de pe para quem prefere jogar com dois toques.
	piece.slide_to(_cell_pos(origem.x, origem.y))
	piece.select(true)



func _end_game(winner: int) -> void:
	if not vs_ai:
		# Os dois estao na mesma mesa: o cartao anuncia o lado que venceu.
		var numero := _numero_do_lado(winner)
		finish_game(tr("PLAYER_WINS") % numero, numero == 1, {"mode": "versus"})
		return
	var antes := DifficultyManager.get_level(game_id)
	if winner == 1:
		finish_game(tr("RESULT_YOU_WIN"), true)
	else:
		finish_game(tr("RESULT_AI_WINS"))

	# `finish_game` publica a partida e o BaseGame move o degrau. O aviso vem
	# depois porque so ai o degrau novo existe.
	var depois := DifficultyManager.get_level(game_id)
	ai_level = depois
	_update_level_label()
	var aviso := DifficultyManager.change_notice(depois, depois - antes)
	if aviso != "":
		set_status("%s\n%s" % [status_label.text, aviso])
