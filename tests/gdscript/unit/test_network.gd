extends GutTest

## Partidas em rede: o NetworkManager (farol, assentos, sala) e os tres jogos
## que aceitam a jogada do outro aparelho por `_on_net_move()`.
##
## Nenhum teste abre dois peers de verdade: a suite roda num processo so e o
## SceneTree tem um MultiplayerAPI. O que se cobre e o protocolo (o texto do
## farol, quem e quem) e o lado do jogo, com `_test_activate()` no lugar do
## peer -- a jogada local vai para `sent_moves`, e a remota entra pelo mesmo
## sinal que o RPC dispara.

const VelhaScene = preload("res://games/jogo_da_velha/TicTacToeGame.tscn")
const QuatroScene = preload("res://games/quatro_em_linha/ConnectFourGame.tscn")
const ReversiScene = preload("res://games/reversi/ReversiGame.tscn")
const LobbyScene = preload("res://core/telas/LobbyScreen.tscn")


func after_each() -> void:
	NetworkManager.leave()


# ------------------------------------------------------------------ protocolo

func test_o_farol_vai_e_volta() -> void:
	var texto := NetworkManager.build_beacon("Rico", "jogo_da_velha")
	var info := NetworkManager.parse_beacon(texto)
	assert_eq(info.get("name", ""), "Rico", "o nome volta")
	assert_eq(info.get("game_id", ""), "jogo_da_velha", "o jogo volta")


func test_o_farol_recusa_lixo_outra_versao_e_jogo_desconhecido() -> void:
	assert_true(NetworkManager.parse_beacon("ola").is_empty(), "texto qualquer nao e sala")
	assert_true(NetworkManager.parse_beacon("PLAYTABLE!|999|jogo_da_velha|x").is_empty(), "outra versao do protocolo")
	assert_true(NetworkManager.parse_beacon("PLAYTABLE!|%d|xadrez_4d|x" % NetworkManager.PROTOCOL).is_empty(), "jogo que o catalogo nao tem")
	var pipe := NetworkManager.parse_beacon(NetworkManager.build_beacon("a|b", "reversi"))
	assert_eq(pipe.get("name", ""), "a b", "a barra do nome nao quebra o campo")


func test_os_assentos() -> void:
	NetworkManager._test_activate("jogo_da_velha", 1)
	assert_true(NetworkManager.is_active(), "em partida")
	assert_true(NetworkManager.is_host(), "assento 1 e quem abriu a sala")
	assert_eq(NetworkManager.remote_seat(), 2, "o outro e o 2")
	assert_true(NetworkManager.is_my_turn(1), "minha vez quando joga o 1")
	assert_false(NetworkManager.is_my_turn(2), "nao e minha vez quando joga o 2")
	NetworkManager.leave()
	assert_false(NetworkManager.is_active(), "sair fecha a partida")
	assert_eq(NetworkManager.local_seat, 0, "e o assento some")


func test_abrir_uma_sala_de_verdade_e_fechar() -> void:
	var ok := NetworkManager.host("reversi")
	assert_true(ok, "o servidor ENet abre na porta %d" % NetworkManager.PORT)
	assert_eq(NetworkManager.state, NetworkManager.State.HOSTING, "estado HOSTING")
	assert_eq(NetworkManager.game_id, "reversi", "a sala e do Reversi")
	assert_true(multiplayer.is_server(), "este aparelho e o servidor")
	NetworkManager.leave()
	assert_eq(NetworkManager.state, NetworkManager.State.OFFLINE, "fechou")


func test_os_jogos_em_rede_estao_no_catalogo() -> void:
	var ids: Array[String] = []
	for def in GameCatalog.get_net_games():
		ids.append(GameCatalog.game_id_of(def))
	assert_has(ids, "jogo_da_velha", "Jogo da Velha em rede")
	assert_has(ids, "quatro_em_linha", "Quatro em Linha em rede")
	assert_has(ids, "reversi", "Reversi em rede")
	for id in ids:
		var cena := load(GameCatalog.find_by_id(id).scene_path) as PackedScene
		var script: Script = cena.instantiate().get_script()
		assert_true(script.has_method("_on_net_move") or _tem_metodo_proprio(script, "_on_net_move"),
			"%s implementa _on_net_move" % id)


func _tem_metodo_proprio(script: Script, nome: String) -> bool:
	for m in script.get_script_method_list():
		if m["name"] == nome:
			return true
	return false


func test_a_sala_de_espera_instancia_e_lista_os_jogos() -> void:
	var lobby = add_child_autofree(LobbyScene.instantiate())
	await get_tree().process_frame
	assert_not_null(lobby.find_child("BtnHost", true, false), "tem o botao de criar sala")
	assert_not_null(lobby.find_child("Jogo_reversi", true, false), "tem o chip do Reversi")
	assert_not_null(lobby.find_child("BtnOnlineHost", true, false), "tem a porta da internet")


# --------------------------------------------------------------- pela internet

func test_o_endereco_da_api_sai_do_ambiente_quando_ha_um() -> void:
	var antes := OS.get_environment("PLAYTABLE_API")
	OS.set_environment("PLAYTABLE_API", "")
	assert_eq(NetworkManager.api_base(), NetworkManager.API_BASE, "sem variavel, o endereco de producao")
	OS.set_environment("PLAYTABLE_API", "http://127.0.0.1:8099/api/v1")
	assert_eq(NetworkManager.api_base(), "http://127.0.0.1:8099/api/v1", "com variavel, o servidor de teste")
	OS.set_environment("PLAYTABLE_API", antes)


func test_servidor_fora_do_ar_derruba_so_o_online() -> void:
	# A porta 45999 nao tem ninguem ouvindo: e a recusa mais rapida que existe,
	# e para o jogador ela vale o mesmo que DNS que nao resolve (contrato, secao 4).
	var antes := OS.get_environment("PLAYTABLE_API")
	OS.set_environment("PLAYTABLE_API", "http://127.0.0.1:45999/api/v1")

	NetworkManager.connect_online("jogo_da_velha")
	assert_eq(NetworkManager.state, NetworkManager.State.JOINING, "pediu a sala")
	while NetworkManager.state == NetworkManager.State.JOINING:
		await wait_frames(1)

	assert_eq(NetworkManager.state, NetworkManager.State.ONLINE_UNAVAILABLE, "o online sai de cena")
	assert_false(NetworkManager.is_active(), "e ninguem fica em partida")

	# O que precisa continuar de pe: a rede local nao depende de servidor nenhum.
	assert_true(NetworkManager.host("reversi"), "a sala na rede local abre do mesmo jeito")
	NetworkManager.leave()
	OS.set_environment("PLAYTABLE_API", antes)


# ---------------------------------------------------------------- Jogo da Velha

func test_velha_em_rede_manda_a_propria_jogada_e_recebe_a_do_outro() -> void:
	NetworkManager._test_activate("jogo_da_velha", 1)
	var jogo = add_child_autofree(VelhaScene.instantiate())
	assert_true(jogo.em_rede, "a cena entra em rede")
	assert_false(jogo.vs_ai, "sem IA")
	assert_false(jogo.btn_mode_toggle.visible, "sem alternancia de modo")

	jogo._on_cell_pressed(4)
	assert_eq(jogo.board.cells[4], 1, "X no centro")
	assert_eq(NetworkManager.sent_moves.size(), 1, "a jogada foi enviada")
	assert_eq(int(NetworkManager.sent_moves[0]["idx"]), 4, "com a casa certa")

	jogo._on_cell_pressed(0)
	assert_eq(jogo.board.cells[0], 0, "na vez do outro, o toque local nao vale")
	assert_eq(NetworkManager.sent_moves.size(), 1, "e nada foi enviado")

	NetworkManager.move_received.emit({"idx": 0})
	assert_eq(jogo.board.cells[0], 2, "a jogada remota poe o O")
	assert_true(jogo.is_player_turn, "e a vez volta para ca")


func test_velha_convidado_espera_o_x_e_joga_o_o() -> void:
	NetworkManager._test_activate("jogo_da_velha", 2)
	var jogo = add_child_autofree(VelhaScene.instantiate())
	jogo._on_cell_pressed(4)
	assert_eq(jogo.board.cells[4], 0, "o convidado nao abre")
	NetworkManager.move_received.emit({"idx": 4})
	assert_eq(jogo.board.cells[4], 1, "o X do anfitriao entra")
	jogo._on_cell_pressed(0)
	assert_eq(jogo.board.cells[0], 2, "agora o convidado joga o O")
	assert_eq(int(NetworkManager.sent_moves[0]["idx"]), 0, "e a jogada sai")


func test_velha_a_vitoria_e_de_quem_fechou_a_linha() -> void:
	NetworkManager._test_activate("jogo_da_velha", 2)
	var jogo = add_child_autofree(VelhaScene.instantiate())
	# X: 0, 1; O: 3, 4; X: 2 fecha a linha de cima.
	NetworkManager.move_received.emit({"idx": 0})
	jogo._on_cell_pressed(3)
	NetworkManager.move_received.emit({"idx": 1})
	jogo._on_cell_pressed(4)
	NetworkManager.move_received.emit({"idx": 2})
	assert_true(jogo.game_over, "acabou")
	assert_eq(jogo.score_x, 1, "o X venceu")
	assert_false(jogo.last_difficulty.is_empty(), "o resultado foi contado")


func test_quando_o_outro_sai_a_partida_trava_sem_mexer_na_escada() -> void:
	NetworkManager._test_activate("jogo_da_velha", 1)
	var jogo = add_child_autofree(VelhaScene.instantiate())
	var degrau: int = DifficultyManager.get_level("jogo_da_velha")
	NetworkManager._adversario_saiu()
	assert_true(jogo.game_over, "a partida trava")
	assert_eq(DifficultyManager.get_level("jogo_da_velha"), degrau, "a escada nao anda")
	assert_true(jogo.result_panel.is_showing(), "o cartao aparece")
	assert_false(jogo.result_panel.offers_next_level(), "sem proximo nivel")
	# Quem abandona nao empata: o cartao dizia "Empate!" para quem ficou na mesa.
	assert_eq(jogo.result_panel.title_text(), tr("RESULT_END_TITLE"), "o cartao diz fim de partida")
	assert_ne(jogo.result_panel.title_text(), tr("DRAW_TITLE"), "e nao diz empate")
	assert_false(NetworkManager.is_active(), "e a rede fechou")


# ---------------------------------------------------------------- Quatro em Linha

func test_quatro_em_rede_so_deixa_cair_na_propria_vez() -> void:
	NetworkManager._test_activate("quatro_em_linha", 2)
	var jogo = add_child_autofree(QuatroScene.instantiate())
	assert_true(jogo.em_rede, "em rede")
	jogo._on_col_pressed(3)
	assert_eq(int(jogo.board.get_cell(ConnectFourRules.ROWS - 1, 3)), 0, "o convidado espera o vermelho")
	NetworkManager.move_received.emit({"col": 3})
	assert_eq(int(jogo.board.get_cell(ConnectFourRules.ROWS - 1, 3)), 1, "a ficha vermelha do outro cai")


# ---------------------------------------------------------------------- Reversi

func test_reversi_em_rede_o_convidado_e_branco_e_espera() -> void:
	NetworkManager._test_activate("reversi", 2)
	var jogo = add_child_autofree(ReversiScene.instantiate())
	assert_true(jogo.em_rede, "em rede")
	assert_eq(jogo._meu(), 2, "o convidado joga de brancas")
	assert_false(jogo.is_player_turn, "e as pretas abrem")
	# Abertura classica das pretas: (2,3) flanqueia a branca de (3,3).
	NetworkManager.move_received.emit({"r": 2, "c": 3})
	assert_eq(int(jogo.grid_data.get_cell(2, 3)), 1, "a preta do outro pousou")
	assert_eq(int(jogo.grid_data.get_cell(3, 3)), 1, "e virou a branca do meio")
	assert_true(jogo.is_player_turn, "agora e a vez das brancas daqui")
	# Resposta das brancas: (2,2) flanqueia (3,3)? nao -- (2,4) flanqueia (3,4).
	jogo._on_cell_clicked(2, 4)
	assert_eq(int(jogo.grid_data.get_cell(2, 4)), 2, "a branca pousou")
	assert_eq(NetworkManager.sent_moves.size(), 1, "e a jogada foi enviada")
	assert_eq(int(NetworkManager.sent_moves[0]["r"]), 2, "linha certa")
	assert_eq(int(NetworkManager.sent_moves[0]["c"]), 4, "coluna certa")
	assert_false(jogo.is_player_turn, "e a vez e das pretas de novo")


func test_reversi_em_rede_recusa_jogada_remota_ilegal() -> void:
	NetworkManager._test_activate("reversi", 2)
	var jogo = add_child_autofree(ReversiScene.instantiate())
	NetworkManager.move_received.emit({"r": 0, "c": 0})
	assert_eq(int(jogo.grid_data.get_cell(0, 0)), 0, "o canto sem flanqueio nao entra")
	assert_false(jogo.is_player_turn, "e a vez continua com o outro")
