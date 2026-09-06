extends GutTest

## O caminho do toque ate a mesa 3D.
##
## As Damas ficaram sem clique depois do merge que apagou a grade 2D delas: o
## raiz de cada jogo e uma Control de tela inteira e, no filtro padrao, retinha
## o toque antes de ele chegar ao Picker do Board3D. Nenhum teste simulava um
## toque, entao a suite seguiu verde com o jogo injogavel. Estes testes
## empurram um clique de verdade pelo viewport e olham o que aconteceu.

const DAMAS := "res://games/damas/CheckersGame.tscn"
const BATALHA_NAVAL := "res://games/batalha_naval/BattleshipGame.tscn"
const BOARD_3D := preload("res://shared/3d/Board3D.tscn")

const JOGOS := [
	"res://games/jogo_da_velha/TicTacToeGame.tscn",
	"res://games/damas/CheckersGame.tscn",
	"res://games/batalha_naval/BattleshipGame.tscn",
	"res://games/quatro_em_linha/ConnectFourGame.tscn",
	"res://games/solitario/PegSolitaireGame.tscn",
	"res://games/campo_minado/MinesweeperGame.tscn",
	"res://games/domino/DominoGame.tscn",
	"res://games/ludo/LudoGame.tscn",
	"res://games/reversi/ReversiGame.tscn",
	"res://games/mancala/MancalaGame.tscn",
	"res://games/senet/SenetGame.tscn",
	"res://games/paciencia/KlondikeGame.tscn",
	"res://games/paciencia_spider/SpiderGame.tscn",
	"res://games/memoria/MemoryGame.tscn",
	"res://games/blackjack/BlackjackGame.tscn",
	"res://games/unolike/UnoLikeGame.tscn",
	"res://games/poker/PokerGame.tscn",
	"res://games/hanoi/HanoiGame.tscn",
	"res://games/nim/NimGame.tscn",
	"res://games/gamao/BackgammonGame.tscn",
]


## Instancia o jogo no viewport raiz do runner, com picking fisico ligado —
## o mesmo caminho do aplicativo. Um SubViewport solto nao processa picking
## para eventos empurrados por push_input: o raio chegava ao Picker, o handler
## chamado a mao selecionava a peca, e mesmo assim o clique morria no meio.
func _montar(caminho: String) -> Node:
	get_viewport().physics_object_picking = true
	var jogo: Node = add_child_autofree((load(caminho) as PackedScene).instantiate())
	await wait_process_frames(2)
	await wait_physics_frames(2)
	return jogo


## Um clique de mouse no ponto da tela: e o que um toque vira com a emulacao
## de mouse ligada, que e o padrao do projeto.
func _tocar(ponto: Vector2) -> void:
	var aperta := InputEventMouseButton.new()
	aperta.button_index = MOUSE_BUTTON_LEFT
	aperta.pressed = true
	aperta.position = ponto
	aperta.global_position = ponto
	get_viewport().push_input(aperta, true)
	await wait_physics_frames(2)
	var solta := InputEventMouseButton.new()
	solta.button_index = MOUSE_BUTTON_LEFT
	solta.pressed = false
	solta.position = ponto
	solta.global_position = ponto
	get_viewport().push_input(solta, true)
	await wait_physics_frames(1)


func _na_tela(jogo: Node, mundo: Vector3) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	assert_eq(cam, (jogo.env_3d as TabletopEnvironment3D).camera, "a camera atual e a do jogo")
	return cam.unproject_position(mundo)


# ---------------------------------------------------------------- o raiz

func test_o_raiz_de_todo_jogo_deixa_o_toque_passar() -> void:
	for caminho in JOGOS:
		var jogo: Control = add_child_autofree((load(caminho) as PackedScene).instantiate())
		assert_eq(jogo.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s: o raiz nao retem o toque" % caminho.get_file())


# ---------------------------------------------------------------- Board3D

func test_toque_e_mouse_emulado_contam_como_um_toque_so() -> void:
	assert_true(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true),
		"o projeto usa a emulacao de mouse a partir do toque")
	var board: Board3D = add_child_autofree(BOARD_3D.instantiate())
	board.setup_board(8, 8, 0.75, "wood_checkered")
	watch_signals(board)
	var mundo := board.get_cell_position_3d(3, 3, 0.0)
	var toque := InputEventScreenTouch.new()
	toque.pressed = true
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	board._on_picker_input_event(null, toque, mundo, Vector3.UP, 0)
	board._on_picker_input_event(null, mouse, mundo, Vector3.UP, 0)
	assert_signal_emit_count(board, "cell_clicked", 1,
		"o par toque + mouse emulado dispara cell_clicked uma vez")


# ---------------------------------------------------------------- Damas

func test_tocar_uma_peca_das_damas_a_seleciona() -> void:
	var jogo := await _montar(DAMAS)
	var board: Board3D = jogo.board_3d
	var origem := Vector2i(-1, -1)
	for r in CheckersRules.ROWS:
		for c in CheckersRules.COLS:
			var pos := Vector2i(r, c)
			if jogo.grid_data.get_cell(r, c) > 0 \
					and not CheckersRules.get_valid_moves_for_piece(jogo.grid_data, pos).is_empty():
				origem = pos
				break
		if origem.x >= 0:
			break
	assert_ne(origem, Vector2i(-1, -1), "ha uma peca branca com jogada")
	assert_eq(jogo.selected_pos, Vector2i(-1, -1), "nada selecionado antes do toque")
	await _tocar(_na_tela(jogo, board.get_cell_position_3d(origem.x, origem.y, 0.02)))
	assert_eq(jogo.selected_pos, origem, "a peca tocada fica selecionada")
	assert_false(jogo.valid_moves.is_empty(), "e os destinos dela ficam a mostra")


# ---------------------------------------------------------- Batalha Naval

func test_tocar_uma_coordenada_do_radar_atira() -> void:
	var jogo := await _montar(BATALHA_NAVAL)
	var board: Board3D = jogo.radar_board
	var alvo := Vector2i(4, 4)
	assert_true(jogo.ai_grid.get_cell(alvo.x, alvo.y) in [0, 1], "coordenada ainda nao atacada")
	var mundo: Vector3 = board.to_global(board.get_cell_position_3d(alvo.x, alvo.y, 0.02))
	await _tocar(_na_tela(jogo, mundo))
	assert_true(jogo.ai_grid.get_cell(alvo.x, alvo.y) in [2, 3], "o tiro foi registrado")
	assert_eq(jogo._radar_marks.get_child_count(), 1, "e o pino apareceu na casa")


func test_tocar_a_propria_frota_avisa_em_vez_de_calar() -> void:
	# Os dois mapas ficam na mesa ao mesmo tempo: tocar o de baixo nao pode
	# atirar, mas tambem nao pode ficar calado.
	var jogo := await _montar(BATALHA_NAVAL)
	jogo._on_fleet_cell_clicked(0, 0)
	assert_string_contains(jogo.status_label.text, "de cima", "manda atirar no mapa de cima")
	assert_true(jogo.ai_grid.get_cell(0, 0) in [0, 1], "e nao atira")


func test_a_frota_e_visivel_sobre_o_oceano() -> void:
	# O casco antigo tinha a mesma luminancia das casas do oceano.
	var jogo := await _montar(BATALHA_NAVAL)
	await wait_process_frames(1)
	assert_eq(jogo._fleet_hulls.get_child_count(), jogo.player_ships.size(), "um casco por navio")
	var casco: MeshInstance3D = jogo._fleet_hulls.get_child(0)
	var casco_lum: float = (casco.material_override as StandardMaterial3D).albedo_color.get_luminance()
	var oceano_lum: float = Color(0.10, 0.20, 0.34).get_luminance()
	assert_gt(casco_lum - oceano_lum, 0.4, "casco claro sobre oceano escuro")


func test_afundar_um_navio_inimigo_revela_o_casco_inteiro() -> void:
	# Antes o jogador so ficava com os pinos vermelhos e nunca via o que tinha
	# derrubado.
	var jogo := await _montar(BATALHA_NAVAL)
	var navio: Dictionary = jogo.ai_ships[0]
	assert_eq(jogo._radar_wrecks.get_child_count(), 0, "nenhum destroco antes de afundar")
	for casa in navio["cells"]:
		jogo.ai_grid.set_cell(casa.x, casa.y, 1)
	var ultima: Vector2i = navio["cells"][navio["cells"].size() - 1]
	for casa in navio["cells"]:
		if casa != ultima:
			jogo.ai_grid.set_cell(casa.x, casa.y, 3)
			navio["hits"] = int(navio["hits"]) + 1
	jogo.is_player_turn = true
	jogo._on_radar_cell_clicked(ultima.x, ultima.y)
	await wait_process_frames(1)
	assert_true(navio["sunk"], "o navio afundou")
	assert_gt(jogo._radar_wrecks.get_child_count(), 0, "o casco aparece no mapa de ataque")


# ------------------------------------------------------------ DragPicker3D

## Um arrasto de verdade pelo viewport: aperta, anda em tres passos, solta.
func _arrastar(de: Vector2, ate: Vector2) -> void:
	var aperta := InputEventMouseButton.new()
	aperta.button_index = MOUSE_BUTTON_LEFT
	aperta.pressed = true
	aperta.position = de
	aperta.global_position = de
	get_viewport().push_input(aperta, true)
	await wait_process_frames(1)
	var anterior := de
	for t in [0.3, 0.7, 1.0]:
		var ponto: Vector2 = de.lerp(ate, t)
		var anda := InputEventMouseMotion.new()
		anda.position = ponto
		anda.global_position = ponto
		anda.relative = ponto - anterior
		anda.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(anda, true)
		anterior = ponto
		await wait_process_frames(1)
	var solta := InputEventMouseButton.new()
	solta.button_index = MOUSE_BUTTON_LEFT
	solta.pressed = false
	solta.position = ate
	solta.global_position = ate
	get_viewport().push_input(solta, true)
	await wait_physics_frames(1)


func test_arrastar_a_esfera_do_resta_um_pelo_viewport_executa_o_salto() -> void:
	# O caminho inteiro do aparelho: o evento entra pelo viewport, atravessa a
	# HUD, cai no DragPicker3D e vira salto. Antes so os metodos internos da
	# cena eram exercitados, e uma camada por cima do picker passaria calada.
	var jogo := await _montar("res://games/solitario/PegSolitaireGame.tscn")
	var picker: DragPicker3D = jogo.picker
	assert_eq(PegSolitaireRules.count_pegs(jogo.grid_data), 32)
	await _arrastar(picker.screen_of(Vector2i(3, 1)), picker.screen_of(Vector2i(3, 3)))
	assert_eq(PegSolitaireRules.count_pegs(jogo.grid_data), 31, "a esfera saltou e a do meio saiu")
	assert_eq(jogo.grid_data.get_cell(3, 3), 1, "pousou no furo de destino")


func test_arrastar_uma_peca_das_damas_pelo_viewport_a_move() -> void:
	var jogo := await _montar(DAMAS)
	var origem := Vector2i(-1, -1)
	var destino := Vector2i(-1, -1)
	for r in CheckersRules.ROWS:
		for c in CheckersRules.COLS:
			var pos := Vector2i(r, c)
			if jogo.grid_data.get_cell(r, c) > 0:
				var jogadas: Array = CheckersRules.get_valid_moves_for_piece(jogo.grid_data, pos)
				if not jogadas.is_empty():
					origem = pos
					destino = jogadas[0]["to"]
					break
		if origem.x >= 0:
			break
	assert_ne(origem, Vector2i(-1, -1), "ha uma peca branca com jogada")
	var picker: DragPicker3D = jogo.picker
	await _arrastar(picker.screen_of(origem), picker.screen_of(destino))
	assert_eq(jogo.grid_data.get_cell(origem.x, origem.y), 0, "a origem esvaziou")
	assert_gt(jogo.grid_data.get_cell(destino.x, destino.y), 0, "a peca esta no destino")
	# A jogada dispara a busca da IA num WorkerThreadPool. Liberar a cena com a
	# tarefa no ar deixava a thread viva ate o fim do processo, e o Godot
	# abortava ao sair (SIGSEGV num mutex) -- a suite passava e o runner saia
	# com 134. Espera a vez voltar antes de encerrar.
	await wait_until(func() -> bool: return jogo.is_player_turn or jogo.game_over, 8.0)
	assert_true(jogo.is_player_turn or jogo.game_over, "a IA respondeu e a vez voltou")


## O picker e um Control de tela cheia com MOUSE_FILTER_STOP: adicionado por
## ultimo, ficava POR CIMA da HUD e engolia o toque dos botoes -- o Desfazer do
## Hanoi morreu assim. Ele agora se poe no indice 0, e este teste e o que
## impede a regressao de voltar calada.
func test_os_botoes_da_hud_recebem_o_toque_com_o_picker_na_cena() -> void:
	# Nem o botao de voltar, que navega de verdade e cuja transicao cobriria o
	# toque do jogo seguinte, nem o canto inferior direito, onde o rodape do
	# proprio GUT fica por cima da cena durante a suite.
	var alvos := {
		"res://games/hanoi/HanoiGame.tscn": "UI/Actions/BtnUndo",
		DAMAS: "GameShell/VBoxContainer/BtnRestart",
		"res://games/solitario/PegSolitaireGame.tscn": "UI/Actions/BtnRestart",
	}
	for caminho in alvos:
		var jogo := await _montar(caminho)
		assert_not_null(jogo.picker, "%s tem picker" % caminho.get_file())
		var botao: Button = jogo.get_node(alvos[caminho])
		botao.show()
		await wait_process_frames(1)
		assert_true(botao.is_visible_in_tree(), "%s: o botao esta na tela" % caminho.get_file())
		var apertado := [false]
		botao.button_down.connect(func() -> void: apertado[0] = true)
		await _tocar(botao.global_position + botao.size * 0.5)
		assert_true(apertado[0], "%s: o botao %s recebe o toque" % [caminho.get_file(), botao.name])


func test_arrastar_uma_peca_do_gamao_pelo_viewport_a_move() -> void:
	var jogo := await _montar("res://games/gamao/BackgammonGame.tscn")
	jogo._on_btn_roll_dice_pressed()
	await wait_until(func() -> bool: return jogo.has_rolled_dice and not jogo.is_animating, 5.0)
	assert_true(jogo.has_rolled_dice, "os dados rolaram")
	if not jogo.has_rolled_dice:
		return
	var legais: Array = BackgammonRules.get_all_legal_single_moves(jogo.game_state,
		jogo.current_player, jogo.available_moves)
	if legais.is_empty():
		pass_test("a rolagem nao deu jogada legal; nada a arrastar")
		return
	var jogada: Dictionary = legais[0]
	var de: int = int(jogada["from"])
	var ate: int = int(jogada["to"])
	var antes: int = int(jogo.game_state["board"][de])
	var picker: DragPicker3D = jogo.picker
	# Pelo picker, e nao pelo viewport: a metade de baixo da tela do runner e
	# a saida de texto do proprio GUT, que fica por cima da mesa e engole o
	# toque nas pontas -- ver o teste dos botoes da HUD.
	_arrastar_no_picker(picker, picker.screen_of(de), picker.screen_of(ate))
	await wait_process_frames(2)
	assert_ne(int(jogo.game_state["board"][de]), antes, "a origem perdeu uma peca")
	assert_eq(jogo.move_step_history.size(), 1, "uma jogada registrada no turno")


func test_arrastar_um_peao_do_ludo_ate_o_destino_o_move() -> void:
	var jogo := await _montar("res://games/ludo/LudoGame.tscn")
	jogo.players_pawns[0] = [3, 10, -1, -1]
	jogo._sync_pawns_positions(true)
	jogo._handle_player_roll(2)
	await wait_process_frames(1)
	var picker: DragPicker3D = jogo.picker
	assert_ne(picker.screen_of("dest_0"), Vector2.INF, "o destino do peao 1 esta projetado")
	_arrastar_no_picker(picker, picker.screen_of(0), picker.screen_of("dest_0"))
	await wait_process_frames(2)
	assert_eq(jogo.players_pawns[0][0], 5, "o peao andou duas casas pelo arrasto")


func test_tocar_uma_cova_do_mancala_semeia() -> void:
	var jogo := await _montar("res://games/mancala/MancalaGame.tscn")
	var picker: DragPicker3D = jogo.picker
	var ponto: Vector2 = picker.screen_of(0)
	assert_ne(ponto, Vector2.INF, "a cova 0 esta projetada")
	var aperta := InputEventMouseButton.new()
	aperta.button_index = MOUSE_BUTTON_LEFT
	aperta.pressed = true
	aperta.position = ponto
	aperta.global_position = ponto
	picker._on_gui_input(aperta)
	var solta := InputEventMouseButton.new()
	solta.button_index = MOUSE_BUTTON_LEFT
	solta.pressed = false
	solta.position = ponto
	solta.global_position = ponto
	picker._on_gui_input(solta)
	assert_eq(jogo.pits[0], 0, "a cova 0 foi semeada pelo toque na mesa")
	await wait_until(func() -> bool: return jogo.is_player_turn or jogo.game_over, 20.0)


func _arrastar_no_picker(picker: DragPicker3D, de: Vector2, ate: Vector2) -> void:
	var aperta := InputEventMouseButton.new()
	aperta.button_index = MOUSE_BUTTON_LEFT
	aperta.pressed = true
	aperta.position = de
	aperta.global_position = de
	picker._on_gui_input(aperta)
	for t in [0.3, 0.7, 1.0]:
		var anda := InputEventMouseMotion.new()
		anda.position = de.lerp(ate, t)
		anda.global_position = anda.position
		picker._on_gui_input(anda)
	var solta := InputEventMouseButton.new()
	solta.button_index = MOUSE_BUTTON_LEFT
	solta.pressed = false
	solta.position = ate
	solta.global_position = ate
	picker._on_gui_input(solta)
