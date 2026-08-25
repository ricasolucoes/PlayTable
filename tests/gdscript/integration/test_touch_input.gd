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
	"res://games/memoria/MemoryGame.tscn",
	"res://games/blackjack/BlackjackGame.tscn",
	"res://games/unolike/UnoLikeGame.tscn",
	"res://games/poker/PokerGame.tscn",
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
	var board: Board3D = jogo.board_3d
	var alvo := Vector2i(4, 4)
	assert_true(jogo.ai_grid.get_cell(alvo.x, alvo.y) in [0, 1], "coordenada ainda nao atacada")
	await _tocar(_na_tela(jogo, board.get_cell_position_3d(alvo.x, alvo.y, 0.02)))
	assert_true(jogo.ai_grid.get_cell(alvo.x, alvo.y) in [2, 3], "o tiro foi registrado")
	assert_true(jogo.markers_3d.has(alvo), "e o pino apareceu na casa")


func test_tocar_a_propria_frota_avisa_em_vez_de_calar() -> void:
	var jogo := await _montar(BATALHA_NAVAL)
	jogo.viewing_radar = false
	jogo._update_view_mode()
	await wait_process_frames(1)
	jogo._on_cell_clicked(0, 0)
	assert_string_contains(jogo.status_label.text, "Radar", "explica que se ataca pelo Radar")
	assert_true(jogo.ai_grid.get_cell(0, 0) in [0, 1], "e nao atira")


func test_a_frota_e_visivel_sobre_o_oceano() -> void:
	# O casco antigo tinha a mesma luminancia das casas do oceano.
	var jogo := await _montar(BATALHA_NAVAL)
	jogo.viewing_radar = false
	jogo._update_view_mode()
	await wait_process_frames(1)
	assert_eq(jogo.ships_root.get_child_count(), jogo.player_ships.size(), "um casco por navio")
	var casco: MeshInstance3D = jogo.ships_root.get_child(0)
	var casco_lum: float = (casco.material_override as StandardMaterial3D).albedo_color.get_luminance()
	var oceano_lum: float = Color(0.10, 0.20, 0.34).get_luminance()
	assert_gt(casco_lum - oceano_lum, 0.4, "casco claro sobre oceano escuro")
