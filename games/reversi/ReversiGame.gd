extends BaseGame

## ReversiGame: Reversi 3D com Tabuleiro em Feltro Esmeralda e Animação 3D de Virada de Discos

var grid_data: Grid2D
var is_player_turn: bool = true
var pieces_3d: Dictionary = {}

## Partida em rede: as pretas sao de quem abriu a sala, as brancas de quem
## entrou. `is_player_turn` continua sendo "a vez deste aparelho"; a jogada do
## outro chega por `_on_net_move` e passa pelo mesmo `_aplicar_jogada`.
var em_rede: bool = false

## Degrau de 1 a 10 do DifficultyManager. Vira orcamento de busca da IA.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

@onready var board_3d: Board3D = $Board3D

## A arte gerada de cada face do disco (`tools/art/reversi.json`). Indexada pelo
## material porque a peca vira: `flip_180("obsidian")` troca o material e a
## arte tem de ir junto. Sem o arquivo, fica o procedural.
const ART_DISCOS := {"obsidian": "reversi/disco_preto", "ivory": "reversi/disco_branco"}

@onready var pieces_root: Node3D = $PiecesRoot
@onready var level_label: Label = $UI/VBoxContainer/LevelLabel

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/VBoxContainer/BtnRestart
	ai_level = DifficultyManager.get_level(game_id)
	board_3d.setup_board(8, 8, 0.75, "reversi_green")
	# O toque entra pelo proprio tabuleiro: a casa tocada e a casa desenhada.
	board_3d.cell_clicked.connect(_on_cell_clicked)
	# Sem tema proprio a cena herda o `casino_green`, mesa de carteado, cujo teto de
	# inclinacao de camera e 56 graus para a face da carta nao achatar. Isto aqui e
	# tabuleiro: em retrato quem manda e a largura, a camera quer deitar mais para
	# aproveitar a altura que sobra, e batia nesse teto. Os outros temas herdam os
	# 74 graus do padrao.
	env_3d.apply_theme(GameTheme3D.stone_gallery())

	fit_table(board_3d.content_size())
	_start_new_game()

func _start_new_game() -> void:
	game_over = false
	em_rede = net_active()
	# As pretas abrem. Em rede, o convidado (brancas) espera a primeira jogada.
	is_player_turn = _meu() == 1
	btn_restart.hide()

	ai_level = DifficultyManager.get_level(game_id)
	grid_data = ReversiRules.create_initial_board()
	_sync_pieces_3d()
	if em_rede and not is_player_turn:
		set_status(tr("NET_THEIR_TURN") % net_opponent_name())
	else:
		set_status(tr("REVERSI_YOUR_TURN_LONG"))


## O lado deste aparelho: pretas (1) fora da rede, o assento da sala em rede.
func _meu() -> int:
	return NetworkManager.local_seat if em_rede else 1


func _rival() -> int:
	return 3 - _meu()


static func _material_de(player: int) -> String:
	return "obsidian" if player == 1 else "ivory"

func _sync_pieces_3d() -> void:
	for p in pieces_root.get_children(): p.queue_free()
	pieces_3d.clear()
	
	var black_count: int = 0
	var white_count: int = 0
	board_3d.clear_states()
	for r in range(8):
		for c in range(8):
			var val: int = grid_data.get_cell(r, c)
			if val != 0:
				var piece := preload("res://shared/3d/Token3D.tscn").instantiate()
				piece.token_type = "cylinder"
				piece.material_name = "obsidian" if val == 1 else "ivory"
				piece.art_by_material = ART_DISCOS
				piece.position = board_3d.get_cell_position_3d(r, c, 0.08)
				pieces_root.add_child(piece)
				pieces_3d[Vector2i(r, c)] = piece
				
				if val == 1: black_count += 1
				else: white_count += 1

	_pintar_placar(black_count, white_count)
	_highlight_valid_moves()

## Acende as casas onde o jogador pode pousar uma peca.
##
## Antes isto passava uma cor solta a `highlight_cell`, que decide o estado
## comparando a cor com as constantes: `Color(0.2, 0.8, 0.4)` nao casava com
## `Tokens3D.COLOR_VALID` (0.24, 0.78, 0.46) e caia em HIGHLIGHT -- tom palido
## e, pior, sem o anel de acessibilidade. Sobre feltro verde nao se via nada, e
## era por isso que dava para clicar na tela toda sem conseguir jogar.
##
## Em lote tambem: casa a casa, cada chamada reconstruia os buffers de MultiMesh
## das 64 casas.
func _highlight_valid_moves() -> void:
	board_3d.clear_states()
	if not is_player_turn or game_over:
		return
	var destinos: Array = []
	destinos.assign(ReversiRules.get_valid_moves(grid_data, _meu()))
	board_3d.set_cells_state(destinos, Board3D.CellState.VALID)

func _on_cell_clicked(r: int, c: int) -> void:
	if game_over or not is_player_turn: return
	
	var pos := Vector2i(r, c)
	var eu := _meu()
	var flipped := ReversiRules.get_flipped_pieces(grid_data, pos, eu)
	if flipped.size() == 0:
		# Recusar calado e o que faz o jogo parecer quebrado: quem nao conhece a
		# regra do flanqueio conclui que o toque nao esta chegando.
		set_status(tr("REVERSI_INVALID"))
		if AudioManager:
			AudioManager.play_error()
		return
	
	if em_rede:
		net_send({"r": r, "c": c})
	_aplicar_jogada(pos, eu)
	_after_player_move()


## A jogada do outro aparelho. So na vez dele, e so se for legal aqui tambem.
func _on_net_move(payload: Dictionary) -> void:
	if not em_rede or game_over or is_player_turn:
		return
	var pos := Vector2i(int(payload.get("r", -1)), int(payload.get("c", -1)))
	if not grid_data.is_valid(pos.x, pos.y) or int(grid_data.get_cell(pos.x, pos.y)) != 0:
		return
	var rival := _rival()
	if ReversiRules.get_flipped_pieces(grid_data, pos, rival).size() == 0:
		return
	_aplicar_jogada(pos, rival)
	_after_remote_move()


## Pousa o disco de `player` em `pos` e vira os flanqueados. E o mesmo caminho
## para a pessoa, a IA e o outro aparelho: a mesa nao sabe quem jogou.
func _aplicar_jogada(pos: Vector2i, player: int) -> void:
	var flipped := ReversiRules.get_flipped_pieces(grid_data, pos, player)
	var mat := _material_de(player)
	grid_data.set_cell(pos.x, pos.y, player)
	for f in flipped:
		grid_data.set_cell(f.x, f.y, player)
		var p_3d = pieces_3d.get(f)
		if p_3d:
			p_3d.flip_180(mat, 0.35)

	var new_piece := preload("res://shared/3d/Token3D.tscn").instantiate()
	new_piece.token_type = "cylinder"
	new_piece.material_name = mat
	new_piece.art_by_material = ART_DISCOS
	var target_3d := board_3d.get_cell_position_3d(pos.x, pos.y, 0.08)
	new_piece.position = target_3d + Vector3(0, 2.5, 0)
	pieces_root.add_child(new_piece)
	pieces_3d[pos] = new_piece
	new_piece.drop_to(target_3d, 0.35)
	# O Reversi era mudo do inicio ao fim. O som separa a peca que pousa das
	# que viram, que e a informacao da jogada.
	if AudioManager:
		AudioManager.play_piece_place()
		if flipped.size() > 0:
			AudioManager.play_capture()
	_update_scores()


## Depois da jogada do outro aparelho: minha vez se tenho jogada; senao ele
## joga de novo, e os dois lados chegam a mesma conclusao pelo mesmo tabuleiro.
func _after_remote_move() -> void:
	var minhas := ReversiRules.get_valid_moves(grid_data, _meu())
	var dele := ReversiRules.get_valid_moves(grid_data, _rival())
	if minhas.size() == 0 and dele.size() == 0:
		_end_game()
		return
	if minhas.size() > 0:
		is_player_turn = true
		set_status(tr("NET_YOUR_TURN"))
	else:
		is_player_turn = false
		set_status(tr("NET_YOU_PASS") % net_opponent_name())
	_highlight_valid_moves()

func _update_scores() -> void:
	var black_count: int = 0
	var white_count: int = 0
	for r in range(8):
		for c in range(8):
			var v: int = grid_data.get_cell(r, c)
			if v == 1: black_count += 1
			elif v == 2: white_count += 1
	_pintar_placar(black_count, white_count)


## Os discos vao para a barra de cima, iguais aos dos outros dezoito jogos. O
## degrau fica na tela: o numero da dificuldade existia e mexia no XP sem o
## jogador nunca ver em que degrau estava jogando.
func _pintar_placar(pretas: int, brancas: int) -> void:
	if em_rede:
		var meu := pretas if _meu() == 1 else brancas
		var dele := brancas if _meu() == 1 else pretas
		set_duel_score(meu, dele, "NET_YOU", "NET_OPPONENT")
		level_label.text = tr("NET_MODE_LABEL") % net_opponent_name()
		return
	set_duel_score(pretas, brancas)
	level_label.text = DifficultyManager.label_for(game_id)

func _after_player_move() -> void:
	var rival_moves := ReversiRules.get_valid_moves(grid_data, _rival())
	var player_moves := ReversiRules.get_valid_moves(grid_data, _meu())
	
	if rival_moves.size() == 0 and player_moves.size() == 0:
		_end_game()
		return
		
	if rival_moves.size() > 0:
		is_player_turn = false
		if em_rede:
			set_status(tr("NET_THEIR_TURN") % net_opponent_name())
			_highlight_valid_moves()
			return
		set_status(tr("REVERSI_AI_TURN"))
		_highlight_valid_moves()
		await get_tree().create_timer(0.6).timeout
		_play_ai_turn()
	else:
		is_player_turn = true
		set_status(tr("NET_THEY_PASS") % net_opponent_name() if em_rede else tr("REVERSI_AI_NO_MOVES"))
		_highlight_valid_moves()

## Pensa fora da linha principal, durante a pausa de encenacao que ja existia.
##
## No degrau 10 a busca chega a meio segundo no computador e mais num telefone.
## A tarefa recebe uma copia plana do tabuleiro, nunca a cena: a cena pode ser
## fechada com a busca ainda rodando.
func _pensar_jogada_ia() -> Vector2i:
	var saida: Array = []
	var tarefa := WorkerThreadPool.add_task(
		ReversiAI.pensar_em_tarefa.bind(ReversiAI.achatar(grid_data), 2, ai_level, saida))
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
	if saida.is_empty() or int(saida[0]) < 0:
		return Vector2i(-1, -1)
	var idx := int(saida[0])
	return Vector2i(idx / ReversiRules.COLS, idx % ReversiRules.COLS)


func _play_ai_turn() -> void:
	var ai_move: Vector2i = await _pensar_jogada_ia()
	if not is_inside_tree() or game_over:
		return
	if ai_move != Vector2i(-1, -1):
		_aplicar_jogada(ai_move, 2)
	_update_scores()
	
	var player_moves := ReversiRules.get_valid_moves(grid_data, 1)
	var ai_moves := ReversiRules.get_valid_moves(grid_data, 2)
	
	if player_moves.size() == 0 and ai_moves.size() == 0:
		_end_game()
		return
		
	if player_moves.size() > 0:
		is_player_turn = true
		set_status(tr("REVERSI_YOUR_TURN"))
		_highlight_valid_moves()
	else:
		set_status(tr("REVERSI_YOU_NO_MOVES"))
		await get_tree().create_timer(0.6).timeout
		_play_ai_turn()

func _end_game() -> void:
	# get_winner devolve {"winner", "black", "white"}, nao o id do vencedor.
	var winner: int = ReversiRules.get_winner(grid_data)["winner"]
	if winner == _meu():
		finish_game(tr("RESULT_YOU_WIN"), true, {"mode": "online" if em_rede else "ai"})
	elif winner == _rival():
		var msg := tr("NET_OPPONENT_WINS") % net_opponent_name() if em_rede else tr("RESULT_AI_WINS")
		finish_game(msg, false, {"mode": "online" if em_rede else "ai"})
	else:
		finish_game(tr("DRAW_TITLE"), false, {"draw": true, "mode": "online" if em_rede else "ai"})
