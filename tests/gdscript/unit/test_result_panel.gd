extends GutTest

## O cartao de fim de partida (shared/ui/ResultPanel.gd) e a ligacao dele com o
## BaseGame: o que a pessoa ve quando a partida acaba, e o que pode fazer.

const HanoiScene = preload("res://games/hanoi/HanoiGame.tscn")

var _degrau_anterior: int = DifficultyManager.DEFAULT_LEVEL


func before_each() -> void:
	_degrau_anterior = DifficultyManager.get_level("hanoi")


func after_each() -> void:
	DifficultyManager.set_level("hanoi", _degrau_anterior)


func _jogo() -> BaseGame:
	var jogo := BaseGame.new()
	add_child_autofree(jogo)
	return jogo


func test_todo_jogo_ganha_o_cartao_ao_entrar_na_arvore() -> void:
	var jogo := _jogo()
	assert_not_null(jogo.result_panel, "o BaseGame pendura o ResultPanel sozinho")
	assert_true(jogo.result_panel is CanvasLayer, "numa camada propria, acima da HUD")
	assert_false(jogo.result_panel.is_showing(), "escondido ate a partida acabar")


func test_vitoria_que_sobe_a_escada_oferece_o_proximo_nivel() -> void:
	var painel := ResultPanel.new()
	add_child_autofree(painel)
	painel.present_now(true, false, 4, 1, "🏆")
	assert_true(painel.is_showing(), "o cartao aparece")
	assert_true(painel.offers_next_level(), "vitoria com a escada subindo e proximo nivel")
	assert_eq(painel.primary_text(), tr("BTN_NEXT_LEVEL"), "o botao principal diz proximo nivel")
	assert_eq(painel.title_text(), tr("WIN_TITLE"), "o titulo e o de vitoria")
	assert_eq(painel.difficulty_text(), tr("DIFF_UP") % [4, DifficultyManager.MAX_LEVEL],
		"a linha do degrau conta que a escada subiu")


func test_derrota_oferece_jogar_de_novo_e_diz_que_o_degrau_caiu() -> void:
	var painel := ResultPanel.new()
	add_child_autofree(painel)
	painel.present_now(false, false, 2, -1)
	assert_false(painel.offers_next_level(), "derrota nao e proximo nivel")
	assert_eq(painel.primary_text(), tr("BTN_RESTART"), "o botao principal e jogar de novo")
	assert_eq(painel.title_text(), tr("RESULT_END_TITLE"), "o titulo e o de fim de partida")
	assert_eq(painel.difficulty_text(), tr("DIFF_DOWN") % [2, DifficultyManager.MAX_LEVEL],
		"a linha do degrau conta que a escada caiu")


func test_empate_no_topo_mostra_o_degrau_em_que_ficou() -> void:
	var painel := ResultPanel.new()
	add_child_autofree(painel)
	painel.present_now(false, true, DifficultyManager.MAX_LEVEL, 0)
	assert_eq(painel.title_text(), tr("DRAW_TITLE"), "o titulo e o de empate")
	assert_string_contains(painel.difficulty_text(), "%d/%d" % [DifficultyManager.MAX_LEVEL, DifficultyManager.MAX_LEVEL],
		"sem mudanca, o cartao diz em que degrau a partida foi jogada")


func test_o_botao_principal_recomeca_a_partida_e_esconde_o_cartao() -> void:
	var jogo := _jogo()
	watch_signals(jogo.result_panel)
	jogo.result_panel.present_now(true, false, 3, 1)
	jogo.result_panel.primary_pressed.emit()
	assert_false(jogo.result_panel.is_showing(), "o cartao some ao recomecar")
	assert_false(jogo.game_over, "e a partida recomeca")


func test_tocar_fora_do_cartao_o_esconde_sem_recomecar() -> void:
	var jogo := _jogo()
	jogo.game_over = true
	jogo.result_panel.present_now(true, false, 3, 1)
	var toque := InputEventScreenTouch.new()
	toque.pressed = true
	jogo.result_panel._on_veu_input(toque)
	assert_false(jogo.result_panel.is_showing(), "tocar fora esconde o cartao para ver a mesa")
	assert_true(jogo.game_over, "sem recomecar a partida")


func test_finish_game_guarda_o_fechamento_da_escada_para_o_cartao() -> void:
	var jogo := _jogo()
	# `BaseGame.new()` nao tem cena, entao o game_id e "playtable": um id que
	# nenhum jogo usa e cuja escada a suite pode mexer a vontade.
	var antes: int = DifficultyManager.get_level("playtable")
	DifficultyManager.set_level("playtable", 5)
	jogo.finish_game("fim", true)
	assert_eq(int(jogo.last_difficulty.get("level", 0)), 6, "a escada subiu para 6")
	assert_eq(int(jogo.last_difficulty.get("delta", 0)), 1, "e o cartao sabe que subiu um degrau")
	DifficultyManager.set_level("playtable", antes)


func test_jogo_com_modal_proprio_pode_desligar_o_cartao() -> void:
	var jogo := _jogo()
	jogo.uses_result_panel = false
	jogo.finish_game("fim", true)
	jogo.result_panel.present_now(true, false, 1, 0)  # so para provar que o desligado nao apresenta
	jogo.result_panel.dismiss()
	jogo._apresentar_resultado("fim", true, false)
	assert_false(jogo.result_panel.is_showing(), "com uses_result_panel=false o finish_game nao apresenta")


# --------------------------------------------------------------------- Hanoi

## A Torre de Hanoi era o caso que motivou o cartao: "depois que ganhei nao deu
## pra fazer mais nada". Um disco a mais por degrau, e a vitoria leva ao proximo.
func test_na_torre_cada_degrau_e_um_disco_a_mais_ate_oito() -> void:
	var GameScript = load("res://games/hanoi/HanoiGame.gd")
	assert_eq(GameScript.discos_do_degrau(1), 3, "degrau 1: 3 discos")
	assert_eq(GameScript.discos_do_degrau(2), 4, "degrau 2: 4 discos")
	assert_eq(GameScript.discos_do_degrau(6), 8, "degrau 6: 8 discos")
	assert_eq(GameScript.discos_do_degrau(10), 8, "degrau 10 continua em 8, o maximo das regras")
	assert_eq(GameScript.degrau_dos_discos(5), 3, "5 discos e o degrau 3")


func test_vencer_a_torre_abre_o_cartao_com_o_proximo_nivel_e_mais_um_disco() -> void:
	DifficultyManager.set_level("hanoi", 2)
	var jogo = add_child_autofree(HanoiScene.instantiate())
	assert_eq(jogo.disk_count, 4, "degrau 2 monta 4 discos")
	# Torre pronta no destino: e o estado de vitoria que a cena verifica.
	jogo.pegs = HanoiRules.create_initial_pegs(4)
	jogo.pegs[HanoiRules.PEG_DESTINO] = jogo.pegs[HanoiRules.PEG_ORIGEM]
	jogo.pegs[HanoiRules.PEG_ORIGEM] = []
	jogo._check_game_over()
	assert_true(jogo.game_over, "a torre reconhece a vitoria")
	assert_eq(DifficultyManager.get_level("hanoi"), 3, "a escada subiu um degrau")
	jogo.result_panel.present_now(true, false, 3, 1)
	assert_true(jogo.result_panel.offers_next_level(), "o cartao oferece o proximo nivel")
	jogo.result_panel.primary_pressed.emit()
	assert_eq(jogo.disk_count, 5, "o proximo nivel e a torre de 5 discos")
	assert_false(jogo.game_over, "e a partida ja esta aberta")


func test_a_demonstracao_automatica_nao_conta_como_vitoria() -> void:
	DifficultyManager.set_level("hanoi", 1)
	var jogo = add_child_autofree(HanoiScene.instantiate())
	jogo.is_auto_solving = true
	jogo.pegs = HanoiRules.create_initial_pegs(3)
	jogo.pegs[HanoiRules.PEG_DESTINO] = jogo.pegs[HanoiRules.PEG_ORIGEM]
	jogo.pegs[HanoiRules.PEG_ORIGEM] = []
	jogo._check_game_over()
	assert_eq(DifficultyManager.get_level("hanoi"), 1, "a escada nao anda com a demonstracao")
	assert_false(jogo.is_auto_solving, "a demonstracao termina")
	assert_true(jogo.game_over, "e a partida fica fechada ate reiniciar")
