extends BaseGame

## MinesweeperGame: Campo Minado 3D com Teclas Mecânicas Táteis, Pinos de Bandeira e Minas Explosivas

var grid_data: Grid2D
var first_click: bool = true
var is_flag_mode: bool = false
var game_won: bool = false

var tiles_3d: Dictionary = {}
var flags_3d: Dictionary = {}

## Quantas minas esta partida tem. Sai do degrau da escada do DifficultyManager
## -- e a unica alavanca de dificuldade que o Campo Minado tem.
var total_minas: int = MinesweeperRules.TOTAL_MINES

@onready var game_shell: GameShell = $GameShell
@onready var game_timer: GameTimer = game_shell.timer
@onready var board_3d: Board3D = $Board3D
@onready var flags_root: Node3D = $FlagsRoot
@onready var btn_mode: Button = $UI/Controls/BtnMode
@onready var btn_smiley: Button = $UI/Controls/BtnSmiley

## Cor de cada contagem, na convencao do Campo Minado desde sempre.
##
## Esta tabela existia no arquivo e nao era lida por ninguem: os numeros nunca
## chegavam a ser desenhados. A casa com uma mina em volta e a casa com tres
## recebiam o mesmo tom, e sem a contagem nao ha o que deduzir -- o jogo nao
## tinha como ser jogado.
const NUMBER_COLORS = [
	Color(0, 0, 0, 0),
	Color(0.2, 0.6, 1.0),   # 1 Azul
	Color(0.2, 0.85, 0.3),  # 2 Verde
	Color(0.95, 0.25, 0.2), # 3 Vermelho
	Color(0.6, 0.2, 0.9),   # 4 Roxo
	Color(0.9, 0.5, 0.1),   # 5 Laranja
	Color(0.1, 0.8, 0.8),   # 6 Ciano
	Color(0.1, 0.1, 0.1),   # 7 Preto
	Color(0.6, 0.6, 0.6)    # 8 Cinza
]

## Numeros ja na mesa, por casa. Reaproveitados entre partidas.
var numbers_3d: Dictionary = {}
var numbers_root: Node3D = null

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = game_shell.status_label
	btn_restart = game_shell.btn_restart
	game_shell.restart_requested.connect(_on_btn_smiley_pressed)
	game_timer.time_changed.connect(func(_sec: int): _pintar_placar())
	board_3d.setup_board(MinesweeperRules.ROWS, MinesweeperRules.COLS, 0.75, "slate_grid")
	# O toque entra pelo proprio tabuleiro: a casa tocada e a casa desenhada.
	# A grade 2D de botoes que ficava aqui era plana e ancorada no centro da
	# tela, e nao coincidia com o tabuleiro em perspectiva.
	board_3d.cell_clicked.connect(_on_cell_clicked)

	# Ardosia e um tabuleiro, nao mesa de carteado: sem tema proprio a cena herda
	# o `casino_green`, cujo teto de inclinacao de camera e 56 graus para a face
	# da carta nao achatar. Em retrato quem manda e a largura, e esse teto deixava
	# o tabuleiro menor do que a tela comporta.
	env_3d.apply_theme(GameTheme3D.stone_gallery())

	numbers_root = Node3D.new()
	numbers_root.name = "NumbersRoot"
	add_child(numbers_root)

	fit_table(board_3d.content_size())
	_start_new_game()

func _start_new_game() -> void:
	total_minas = MinesweeperRules.minas_do_degrau(DifficultyManager.get_level(game_id))
	first_click = true
	game_over = false
	game_won = false
	game_timer.reset()
	game_timer.stop()
	_pintar_placar()
	btn_smiley.text = "🙂"
	set_status(tr("MINESWEEPER_START") + difficulty_suffix())
	
	for f in flags_root.get_children(): f.queue_free()
	flags_3d.clear()

	if numbers_root:
		for n in numbers_root.get_children(): n.queue_free()
	numbers_3d.clear()
	
	board_3d.clear_states()

	grid_data = MinesweeperRules.create_empty_grid()
	_update_header_mines()

func _update_header_mines() -> void:
	_pintar_placar()


## As minas que faltam marcar e o cronometro, na barra de cima. Eram "💣 10" e
## "⏱️ 000" numa faixa propria: emoji que nenhum idioma le e numero de 22 px.
func _pintar_placar() -> void:
	var faltam := total_minas
	if grid_data != null:
		faltam = maxi(0, total_minas - MinesweeperRules.count_flagged(grid_data))
	set_counters([
		{"value": "%02d" % faltam, "label": "SCORE_MINES"},
		{"value": "%03d" % game_timer.get_time(), "label": "SCORE_TIME"},
	])

func _on_cell_clicked(r: int, c: int) -> void:
	if game_over or game_won: return
	var cell: Dictionary = grid_data.get_cell(r, c)
	
	if is_flag_mode:
		if not cell["is_revealed"]:
			cell["is_flagged"] = not cell["is_flagged"]
			_update_flag_3d(r, c, cell["is_flagged"])
			_update_header_mines()
			_check_win_condition()
		return
		
	if cell["is_flagged"]: return
	
	if first_click:
		first_click = false
		MinesweeperRules.generate_mines(grid_data, r, c, total_minas)
		game_timer.start()
		set_status(tr("MINESWEEPER_CLEARED"))
		
	if cell["is_mine"]:
		_trigger_game_over(r, c)
		return
		
	MinesweeperRules.reveal_cell(grid_data, r, c)
	_sync_revealed_3d()
	_check_win_condition()

func _update_flag_3d(r: int, c: int, is_flagged: bool) -> void:
	var pos := Vector2i(r, c)
	if is_flagged:
		var flag := preload("res://shared/3d/Token3D.tscn").instantiate()
		flag.token_type = "pawn"
		flag.material_name = "ruby"
		flag.position = board_3d.get_cell_position_3d(r, c, 0.15)
		flags_root.add_child(flag)
		flags_3d[pos] = flag
	else:
		if flags_3d.has(pos):
			flags_3d[pos].queue_free()
			flags_3d.erase(pos)

## Poe na mesa o que o tabuleiro ja revelou: o tom da casa aberta e, onde ha
## minas em volta, o algarismo.
##
## Casa aberta agora e `REVEALED`. Antes a casa vazia recebia `LAST_MOVE`, que
## ganha o anel de aviso: o alastramento do primeiro clique abre dezenas delas
## de uma vez, e a tela enchia de aneis acesos que nao queriam dizer nada.
## `HIGHLIGHT` na casa numerada tinha o problema oposto -- destacava sem
## informar, porque o numero nunca era desenhado.
func _sync_revealed_3d() -> void:
	for r in range(MinesweeperRules.ROWS):
		for c in range(MinesweeperRules.COLS):
			var cell: Dictionary = grid_data.get_cell(r, c)
			if not cell["is_revealed"]:
				continue
			board_3d.stage_cell_state(r, c, Board3D.CellState.REVEALED)
			_mostrar_numero(r, c, int(cell["adjacent_mines"]))
	board_3d.commit_states()


## Desenha (ou apaga) o algarismo de uma casa aberta.
##
## `Label3D` deitado sobre a casa, com contorno preto: a leitura tem de sair a
## meio metro do rosto, num quadrado de ~63 px. Casa com zero minas em volta nao
## mostra nada -- e o que separa visualmente a regiao limpa do resto.
func _mostrar_numero(r: int, c: int, count: int) -> void:
	var pos := Vector2i(r, c)
	if count <= 0:
		if numbers_3d.has(pos):
			numbers_3d[pos].queue_free()
			numbers_3d.erase(pos)
		return
	if numbers_3d.has(pos):
		return
	var rotulo := Label3D.new()
	rotulo.text = str(count)
	rotulo.font_size = 96
	rotulo.pixel_size = 0.0045
	rotulo.outline_size = 20
	rotulo.outline_modulate = Color(0.04, 0.05, 0.07, 0.9)
	rotulo.modulate = NUMBER_COLORS[clampi(count, 1, NUMBER_COLORS.size() - 1)]
	rotulo.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	rotulo.no_depth_test = false
	rotulo.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	rotulo.position = board_3d.get_cell_position_3d(r, c, Tokens3D.TILE_THICKNESS + 0.03)
	numbers_root.add_child(rotulo)
	numbers_3d[pos] = rotulo

func _trigger_game_over(hit_r: int, hit_c: int) -> void:
	game_timer.stop()
	btn_smiley.text = "😵"
	finish_game(tr("MINESWEEPER_BOOM"), false, {"time": float(game_timer.get_time())})
	
	for r in range(MinesweeperRules.ROWS):
		for c in range(MinesweeperRules.COLS):
			var cell: Dictionary = grid_data.get_cell(r, c)
			if cell["is_mine"]:
				board_3d.set_cell_state(r, c, Board3D.CellState.INVALID)

func _check_win_condition() -> void:
	if MinesweeperRules.check_win(grid_data):
		game_won = true
		game_timer.stop()
		btn_smiley.text = "😎"
		# O tempo e o que o Campo Minado tem de recorde: alimenta o placar
		# LB_MINESWEEPER_TIME e a conquista de vitoria rapida.
		finish_game(tr("MINESWEEPER_WIN") % game_timer.get_time(), true,
			{"time": float(game_timer.get_time())})

func _on_btn_mode_pressed() -> void:
	is_flag_mode = not is_flag_mode
	if is_flag_mode:
		btn_mode.text = tr("MINESWEEPER_MODE_FLAG")
		btn_mode.self_modulate = Color(0.95, 0.4, 0.4)
	else:
		btn_mode.text = tr("MINESWEEPER_MODE_DIG")
		btn_mode.self_modulate = Color(0.4, 0.7, 0.95)

func _on_btn_smiley_pressed() -> void:
	restart_game()
