extends BaseGame

## ReversiGame: Reversi 3D com Tabuleiro em Feltro Esmeralda e Animação 3D de Virada de Discos

var grid_data: Grid2D
var is_player_turn: bool = true
var pieces_3d: Dictionary = {}

## Degrau de 1 a 10 do DifficultyManager. Vira orcamento de busca da IA.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

@onready var board_3d: Board3D = $Board3D
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
	is_player_turn = true
	btn_restart.hide()

	ai_level = DifficultyManager.get_level(game_id)
	grid_data = ReversiRules.create_initial_board()
	_sync_pieces_3d()
	set_status(tr("REVERSI_YOUR_TURN_LONG"))

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
	destinos.assign(ReversiRules.get_valid_moves(grid_data, 1))
	board_3d.set_cells_state(destinos, Board3D.CellState.VALID)

func _on_cell_clicked(r: int, c: int) -> void:
	if game_over or not is_player_turn: return
	
	var pos := Vector2i(r, c)
	var flipped := ReversiRules.get_flipped_pieces(grid_data, pos, 1)
	if flipped.size() == 0:
		# Recusar calado e o que faz o jogo parecer quebrado: quem nao conhece a
		# regra do flanqueio conclui que o toque nao esta chegando.
		set_status(tr("REVERSI_INVALID"))
		if AudioManager:
			AudioManager.play_draw()
		return
	
	# Jogada do jogador
	grid_data.set_cell(r, c, 1)
	for f in flipped:
		grid_data.set_cell(f.x, f.y, 1)
		var p_3d = pieces_3d.get(f)
		if p_3d:
			p_3d.flip_180("obsidian", 0.35)
			
	var new_piece := preload("res://shared/3d/Token3D.tscn").instantiate()
	new_piece.token_type = "cylinder"
	new_piece.material_name = "obsidian"
	var target_3d := board_3d.get_cell_position_3d(r, c, 0.08)
	new_piece.position = target_3d + Vector3(0, 2.5, 0)
	pieces_root.add_child(new_piece)
	pieces_3d[pos] = new_piece
	new_piece.drop_to(target_3d, 0.35)
	
	_update_scores()
	_after_player_move()

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
	set_duel_score(pretas, brancas)
	level_label.text = DifficultyManager.label_for(game_id)

func _after_player_move() -> void:
	var ai_moves := ReversiRules.get_valid_moves(grid_data, 2)
	var player_moves := ReversiRules.get_valid_moves(grid_data, 1)
	
	if ai_moves.size() == 0 and player_moves.size() == 0:
		_end_game()
		return
		
	if ai_moves.size() > 0:
		is_player_turn = false
		set_status(tr("REVERSI_AI_TURN"))
		_highlight_valid_moves()
		await get_tree().create_timer(0.6).timeout
		_play_ai_turn()
	else:
		set_status(tr("REVERSI_AI_NO_MOVES"))
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
		var flipped := ReversiRules.get_flipped_pieces(grid_data, ai_move, 2)
		grid_data.set_cell(ai_move.x, ai_move.y, 2)
		for f in flipped:
			grid_data.set_cell(f.x, f.y, 2)
			var p_3d = pieces_3d.get(f)
			if p_3d:
				p_3d.flip_180("ivory", 0.35)
				
		var new_piece := preload("res://shared/3d/Token3D.tscn").instantiate()
		new_piece.token_type = "cylinder"
		new_piece.material_name = "ivory"
		var target_3d := board_3d.get_cell_position_3d(ai_move.x, ai_move.y, 0.08)
		new_piece.position = target_3d + Vector3(0, 2.5, 0)
		pieces_root.add_child(new_piece)
		pieces_3d[ai_move] = new_piece
		new_piece.drop_to(target_3d, 0.35)
		
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
	if winner == 1:
		finish_game(tr("RESULT_YOU_WIN"), true)
	elif winner == 2:
		finish_game(tr("RESULT_AI_WINS"))
	else:
		finish_game(tr("DRAW_TITLE"))
