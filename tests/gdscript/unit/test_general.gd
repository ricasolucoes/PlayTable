extends GutTest

## General (dados): as regras puras, a maquina, a cena com a bandeja e a
## folha, e a partida em rede de dois aparelhos.
##
## A rede e a mesma da suite de rede: `_test_activate()` no lugar do peer. A
## jogada local vai para `sent_moves`; a remota entra pelo sinal que o RPC
## dispara. Os valores dos dados viajam dentro da acao.

const GameScene = preload("res://games/general/GeneralGame.tscn")

const TODOS_SOLTOS := [false, false, false, false, false]
const SOLO := 0
const IA := 1
const VERSUS := 2


func after_each() -> void:
	NetworkManager.leave()


func _jogo() -> Node:
	return add_child_autofree(GameScene.instantiate())


## A cena assentada: picker projetado, HUD medida, refit baixado.
func _cena() -> Node:
	var jogo := _jogo()
	await wait_process_frames(3)
	await wait_until(func() -> bool: return not jogo._refit_pending, 2.0)
	return jogo


func _rolar(jogo: Node, valores: Array, presos: Array = TODOS_SOLTOS) -> bool:
	return jogo._aplicar(jogo.vez, {"t": "roll", "values": valores, "held": presos})


func _marcar(jogo: Node, cat: String) -> bool:
	return jogo._aplicar(jogo.vez, {"t": "score", "cat": cat})


func _modo(jogo: Node, modo: int) -> void:
	jogo.mode_switch.definir_modo(modo)


func _esperar_giro(jogo: Node) -> void:
	await wait_until(func() -> bool: return not jogo._rolando, 4.0)


# ------------------------------------------------------------------- regras

func test_numeros_somam_so_os_dados_daquele_valor() -> void:
	assert_eq(GeneralRules.score_for("tres", [3, 3, 1, 3, 5]), 9, "tres treses")
	assert_eq(GeneralRules.score_for("seis", [6, 6, 2, 6, 6]), 24, "quatro seis")
	assert_eq(GeneralRules.score_for("um", [2, 3, 4, 5, 6]), 0, "nenhum um")
	assert_eq(GeneralRules.score_for("cinco", [5, 5, 5, 5, 5], true), 25, "de mao nao muda numero")


func test_sequencia_vale_20_e_25_de_mao_mesmo_fora_de_ordem() -> void:
	assert_eq(GeneralRules.score_for("sequencia", [5, 3, 1, 4, 2]), 20, "1-5 embaralhada")
	assert_eq(GeneralRules.score_for("sequencia", [5, 3, 1, 4, 2], true), 25, "de mao")
	assert_eq(GeneralRules.score_for("sequencia", [2, 6, 4, 3, 5]), 20, "2-6")
	assert_eq(GeneralRules.score_for("sequencia", [1, 2, 3, 4, 6]), 0, "com buraco nao")
	assert_eq(GeneralRules.score_for("sequencia", [1, 1, 2, 3, 4]), 0, "com repeticao nao")


func test_full_house_e_trinca_mais_par() -> void:
	assert_eq(GeneralRules.score_for("full", [2, 5, 2, 5, 5]), 30, "par de 2 e trinca de 5")
	assert_eq(GeneralRules.score_for("full", [2, 5, 2, 5, 5], true), 35, "de mao")
	assert_eq(GeneralRules.score_for("full", [5, 5, 5, 5, 5]), 0, "cinco iguais nao e full")
	assert_eq(GeneralRules.score_for("full", [2, 2, 3, 5, 5]), 0, "dois pares nao")


func test_quadra_e_general() -> void:
	assert_eq(GeneralRules.score_for("quadra", [4, 4, 1, 4, 4]), 40, "quadra")
	assert_eq(GeneralRules.score_for("quadra", [4, 4, 1, 4, 4], true), 45, "quadra de mao")
	assert_eq(GeneralRules.score_for("quadra", [6, 6, 6, 6, 6]), 40, "cinco iguais tambem e quadra")
	assert_eq(GeneralRules.score_for("quadra", [4, 4, 4, 1, 1]), 0, "trinca nao")
	assert_eq(GeneralRules.score_for("general", [6, 6, 6, 6, 6]), 50, "general")
	assert_eq(GeneralRules.score_for("general", [6, 6, 6, 6, 6], true), 100, "general de mao")
	assert_eq(GeneralRules.score_for("general", [6, 6, 6, 6, 1]), 0, "quatro nao")
	assert_true(GeneralRules.bonus_de_mao("quadra", [4, 4, 4, 4, 1]), "quadra de mao tem bonus")
	assert_false(GeneralRules.bonus_de_mao("seis", [6, 6, 6, 6, 6]), "numero de mao nao tem")
	assert_false(GeneralRules.bonus_de_mao("quadra", [1, 2, 3, 4, 5]), "combinacao zerada nao tem")


func test_riscar_grava_zero_e_a_categoria_nao_volta() -> void:
	var folha := GeneralRules.nova_folha()
	assert_eq(GeneralRules.marcar(folha, "quadra", [1, 2, 3, 4, 6]), 0, "riscou a quadra")
	assert_false(GeneralRules.pode_marcar(folha, "quadra"), "usada nao volta")
	assert_eq(GeneralRules.marcar(folha, "quadra", [5, 5, 5, 5, 5]), -1, "marcar de novo e recusado")
	assert_eq(GeneralRules.riscadas(folha), 1, "uma riscada")
	assert_eq(GeneralRules.categorias_livres(folha).size(), 9, "nove livres")
	assert_false(GeneralRules.pode_marcar(folha, "bicho"), "categoria inventada nao")


func test_bonus_dos_numeros_a_partir_de_60() -> void:
	var folha := {"um": 3, "dois": 6, "tres": 9, "quatro": 12, "cinco": 15, "seis": 15}
	assert_eq(GeneralRules.soma_numeros(folha), 60, "soma 60")
	assert_eq(GeneralRules.bonus(folha), 30, "bonus de 30")
	assert_eq(GeneralRules.total(folha), 90, "total com bonus")
	folha["seis"] = 12
	assert_eq(GeneralRules.bonus(folha), 0, "59 nao da bonus")
	assert_eq(GeneralRules.total(folha), 57, "total sem bonus")


func test_partida_acaba_em_dez_marcacoes_e_o_maior_total_vence() -> void:
	var folha := GeneralRules.nova_folha()
	for cat in GeneralRules.CATEGORIAS:
		assert_false(GeneralRules.completa(folha), "ainda aberta")
		GeneralRules.marcar(folha, cat, [6, 6, 6, 6, 6])
	assert_true(GeneralRules.completa(folha), "dez marcacoes fecham")
	assert_eq(GeneralRules.turnos_jogados(folha), 10, "dez turnos")
	assert_eq(GeneralRules.vencedor([120, 90]), 0, "o primeiro")
	assert_eq(GeneralRules.vencedor([90, 120]), 1, "o segundo")
	assert_eq(GeneralRules.vencedor([100, 100]), -1, "empate e empate")


func test_best_category_prefere_o_que_rende_mais_e_risca_na_ordem() -> void:
	assert_eq(GeneralRules.best_category([6, 6, 6, 6, 6], {}), "general", "cinco iguais")
	assert_eq(GeneralRules.best_category([3, 3, 3, 2, 2], {}), "full", "full antes dos treses")
	assert_eq(GeneralRules.best_category([6, 6, 1, 2, 3], {}), "seis", "par de seis")
	var folha := {"um": 0, "dois": 0, "tres": 0, "quatro": 0, "cinco": 0, "seis": 0}
	assert_eq(GeneralRules.best_category([1, 2, 3, 4, 6], folha), "general",
		"nada rende: risca o general antes da sequencia")
	assert_eq(GeneralRules.categoria_para_riscar({}), "um", "com tudo livre risca os uns")
	assert_eq(GeneralRules.categoria_para_riscar({"um": 0}), "dois", "depois os dois")


func test_meta_solo_sobe_com_o_degrau() -> void:
	assert_eq(GeneralRules.meta_solo(1), 105, "primeiro degrau")
	assert_eq(GeneralRules.meta_solo(3), 135, "terceiro")
	assert_eq(GeneralRules.meta_solo(10), 240, "decimo")


# ------------------------------------------------------------------ maquina

func test_ia_escolhe_general_com_cinco_iguais_em_qualquer_degrau() -> void:
	var rng := RandomNumberGenerator.new()
	for nivel in range(1, 11):
		for tentativa in 5:
			rng.seed = nivel * 100 + tentativa
			assert_eq(GeneralAI.choose_category([4, 4, 4, 4, 4], {}, false, nivel, rng), "general",
				"degrau %d nao deixa passar cinco iguais" % nivel)


func test_ia_segura_a_trinca_e_continua_rolando() -> void:
	var presos := GeneralAI.choose_holds([3, 1, 3, 5, 3], {}, 10)
	assert_eq(presos, [true, false, true, false, true] as Array[bool], "segura os tres treses")
	assert_false(GeneralAI.should_stop([3, 1, 3, 5, 3], {}, 1, 10), "trinca nao e motivo para parar")
	assert_eq(GeneralAI.choose_holds([5, 5, 2, 3, 6], {}, 10), [true, true, false, false, false] as Array[bool],
		"segura o par")


func test_ia_para_e_grava_com_full_ou_quadra() -> void:
	assert_true(GeneralAI.should_stop([2, 2, 5, 5, 5], {}, 1, 10), "full de mao: para")
	assert_eq(GeneralAI.choose_category([2, 2, 5, 5, 5], {}, true, 10), "full", "e grava o full")
	assert_true(GeneralAI.should_stop([4, 4, 4, 4, 1], {}, 2, 10), "quadra: para")
	assert_eq(GeneralAI.choose_category([4, 4, 4, 4, 1], {}, false, 10), "quadra", "e grava a quadra")
	assert_false(GeneralAI.should_stop([2, 2, 5, 5, 5], {"full": 30}, 1, 10), "full usado: segue")
	assert_true(GeneralAI.should_stop([1, 2, 3, 4, 6], {}, 3, 10), "terceira rolagem sempre para")


func test_ia_segura_a_sequencia_aberta() -> void:
	assert_eq(GeneralAI.choose_holds([1, 2, 3, 4, 4], {}, 10), [true, true, true, true, false] as Array[bool],
		"quatro seguidos: solta o 4 repetido")
	assert_eq(GeneralAI.maior_corrida([1, 2, 3, 5, 6]), [1, 2, 3] as Array[int], "a maior corrida")
	assert_eq(GeneralAI.choose_holds([1, 2, 3, 4, 4], {"sequencia": 20}, 10),
		[false, false, false, true, true] as Array[bool], "sequencia usada: segura o par")


func test_ia_risca_quando_nada_rende() -> void:
	var folha := {"um": 0, "dois": 0, "tres": 0, "quatro": 0, "cinco": 0, "seis": 0}
	assert_eq(GeneralAI.choose_category([1, 2, 3, 4, 6], folha, false, 10), "general", "risca o general")
	folha["general"] = 0
	assert_eq(GeneralAI.choose_category([1, 2, 3, 4, 6], folha, false, 10), "sequencia", "depois a sequencia")


func test_ia_joga_legal_em_todos_os_degraus() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for nivel in range(1, 11):
		var folha := GeneralRules.nova_folha()
		for turno in GeneralRules.TURNOS:
			var dados := DiceTray3D.random_values(5, rng)
			var presos := GeneralAI.choose_holds(dados, folha, nivel, rng)
			assert_eq(presos.size(), 5, "um bool por dado")
			var cat := GeneralAI.choose_category(dados, folha, true, nivel, rng)
			assert_true(GeneralRules.pode_marcar(folha, cat), "degrau %d turno %d: categoria livre" % [nivel, turno])
			GeneralRules.marcar(folha, cat, dados, true)
		assert_true(GeneralRules.completa(folha), "degrau %d fecha a folha" % nivel)
	assert_almost_eq(GeneralAI.chance_de_erro(10), 0.0, 0.001, "o decimo degrau nao erra")
	assert_gt(GeneralAI.chance_de_erro(1), 0.3, "o primeiro erra bastante")


# --------------------------------------------------------------------- cena

func test_a_cena_instancia_com_cinco_dados_e_a_folha_de_dez() -> void:
	var jogo := await _cena()
	assert_eq(jogo.tray.count(), 5, "cinco dados")
	assert_eq(jogo.celulas.size(), 10, "dez categorias")
	assert_gte(jogo.btn_rolar.custom_minimum_size.y, 88.0, "botao de rolar com 88 px")
	for cat in GeneralRules.CATEGORIAS:
		assert_gte((jogo.celulas[cat]["btn"] as Button).custom_minimum_size.y, 88.0, "celula %s com 88 px" % cat)
	assert_false(jogo.game_over, "partida aberta")
	assert_eq(jogo.folhas.size(), 2, "duas folhas contra a maquina")
	assert_true(jogo.table.is_ai(1), "a cadeira 1 e a maquina")
	assert_false(jogo.btn_rolar.disabled, "pode rolar")
	assert_ne(jogo.picker.screen_of(0), Vector2.INF, "o primeiro dado e alvo do picker")
	assert_ne(jogo.picker.screen_of(4), Vector2.INF, "o ultimo tambem")


func test_a_folha_e_medida_como_hud_e_a_mesa_cabe_acima_dela() -> void:
	var jogo := await _cena()
	var vp := jogo.get_viewport_rect().size
	var r: Rect2 = jogo.rodape.get_global_rect()
	assert_gte(r.size.y, 5.0 * 88.0 + 88.0, "cinco linhas mais o botao")
	assert_lte(r.end.y, vp.y, "nada sai pelo pe da tela")
	var bandas: Vector2 = jogo.measure_hud_bands()
	assert_gte(bandas.y, r.size.y, "a faixa de baixo cobre a folha inteira")
	assert_gte(jogo._fit_size.x, jogo.tray.content_size().x, "a camera conhece a largura da bandeja")


func test_rolar_tres_vezes_no_maximo() -> void:
	var jogo := _jogo()
	assert_true(_rolar(jogo, [1, 2, 3, 4, 5]), "primeira")
	assert_eq(jogo.dados, [1, 2, 3, 4, 5], "os valores vieram da acao")
	assert_true(_rolar(jogo, [2, 2, 2, 2, 2]), "segunda")
	assert_true(_rolar(jogo, [3, 3, 3, 3, 3]), "terceira")
	assert_eq(jogo.rolagem, 3, "tres rolagens")
	assert_false(_rolar(jogo, [4, 4, 4, 4, 4]), "a quarta nao existe")
	assert_eq(jogo.dados, [3, 3, 3, 3, 3], "e nao mexeu nos dados")
	assert_false(jogo._pode_rolar_agora(), "o botao fecha")


func test_segurar_dado_mantem_o_valor_na_proxima_rolagem() -> void:
	var jogo := _jogo()
	assert_true(_rolar(jogo, [1, 2, 3, 4, 5]), "primeira")
	assert_true(_rolar(jogo, [6, 6, 6, 6, 6], [true, false, false, true, false]), "segunda com dois presos")
	assert_eq(jogo.dados, [1, 6, 6, 4, 6], "o 1 e o 4 ficaram")
	assert_true(jogo.tray.held[0] and jogo.tray.held[3], "a bandeja marca os presos")
	assert_eq(jogo.tray.halos.color_of(0), Tokens3D.COLOR_SELECTED, "com o anel de selecionado")


func test_na_primeira_rolagem_nada_fica_preso() -> void:
	var jogo := _jogo()
	assert_true(_rolar(jogo, [6, 6, 6, 6, 6], [true, true, true, true, true]), "rolou")
	assert_eq(jogo.dados, [6, 6, 6, 6, 6], "tudo rolou")
	assert_true(jogo.tray.held_indices().is_empty(), "ninguem preso")


func test_tocar_o_dado_segura_e_solta_so_entre_rolagens() -> void:
	var jogo := await _cena()
	jogo._on_dado_tocado(0)
	assert_false(jogo.tray.held[0], "antes de rolar nao ha o que segurar")
	jogo._on_rolar()
	assert_eq(jogo.rolagem, 1, "rolou pelo botao")
	await _esperar_giro(jogo)
	assert_eq(jogo.tray.halos.color_of(2), Tokens3D.COLOR_VALID, "os dados acendem para o toque")
	jogo._on_dado_tocado(2)
	assert_true(jogo.tray.held[2], "tocou: preso")
	jogo._on_dado_puxado(1)
	assert_true(jogo.tray.held[1], "puxou: preso tambem")
	jogo._on_dado_tocado(2)
	assert_false(jogo.tray.held[2], "tocou de novo: solto")
	jogo._on_rolar()
	jogo._on_rolar()
	assert_eq(jogo.rolagem, 2, "com a bandeja girando o segundo toque nao rola")
	await _esperar_giro(jogo)
	jogo._on_rolar()
	await _esperar_giro(jogo)
	assert_eq(jogo.rolagem, 3, "terceira")
	jogo._on_dado_tocado(0)
	assert_false(jogo.tray.held[0], "depois da terceira nao se segura mais")
	assert_true(jogo.btn_rolar.disabled, "e o botao fecha")


func test_marcar_categoria_grava_e_passa_a_vez() -> void:
	var jogo := _jogo()
	_modo(jogo, VERSUS)
	assert_true(jogo.table.pass_and_play(), "dois no aparelho")
	assert_false(_marcar(jogo, "quadra"), "sem rolar nao se marca")
	assert_true(_rolar(jogo, [4, 4, 4, 4, 1]), "rolou")
	assert_eq(jogo.celulas["quadra"]["valor"].text, "45", "a folha mostra o que a quadra daria de mao")
	assert_true(_marcar(jogo, "quadra"), "marcou")
	assert_eq(jogo.folhas[0]["quadra"], 45, "quadra de mao gravada")
	assert_true(jogo.de_mao_feito[0], "conta a jogada de mao")
	assert_eq(jogo.vez, 1, "a vez passou")
	assert_eq(jogo.rolagem, 0, "e a rodada recomecou")
	assert_true(jogo.tray.held_indices().is_empty(), "sem dado preso")
	assert_eq(jogo.celulas["quadra"]["valor"].text, "", "a folha agora e da outra cadeira")


func test_categoria_usada_nao_aceita_de_novo() -> void:
	var jogo := _jogo()
	_modo(jogo, VERSUS)
	_rolar(jogo, [4, 4, 4, 4, 1])
	_marcar(jogo, "quadra")
	_rolar(jogo, [1, 1, 1, 1, 1])
	_marcar(jogo, "um")
	assert_eq(jogo.vez, 0, "voltou a primeira cadeira")
	_rolar(jogo, [5, 5, 5, 5, 1])
	assert_false(_marcar(jogo, "quadra"), "a quadra ja foi")
	assert_true(_marcar(jogo, "cinco"), "outra livre entra")
	assert_eq(jogo.folhas[0]["cinco"], 20, "vinte nos cincos")


func test_partida_inteira_termina_com_finish_game_e_as_bandeiras() -> void:
	var jogo := _jogo()
	_modo(jogo, VERSUS)
	for turno in GeneralRules.TURNOS:
		for cadeira in 2:
			assert_eq(jogo.vez, cadeira, "turno %d cadeira %d" % [turno, cadeira])
			assert_true(_rolar(jogo, [6, 6, 6, 6, 6] if cadeira == 0 else [1, 1, 1, 1, 2]), "rolou")
			var cat := GeneralRules.best_category(jogo.dados, jogo.folhas[cadeira], true)
			assert_true(_marcar(jogo, cat), "marcou %s" % cat)
	assert_true(jogo.game_over, "acabou")
	assert_true(jogo.last_difficulty.has("level"), "a escada fechou")
	assert_true(GeneralRules.completa(jogo.folhas[0]) and GeneralRules.completa(jogo.folhas[1]), "duas folhas cheias")
	assert_eq(GeneralRules.total(jogo.folhas[0]), 175, "general 100 + quadra 45 + seis 30")
	var extra: Dictionary = jogo.ultimo_resultado
	assert_eq(str(extra.get("mode", "")), "versus", "modo de dois no aparelho")
	assert_eq(int(extra.get("score", 0)), 175, "o placar da cadeira daqui")
	assert_true(bool(extra.get("perfect", false)), "fez general")
	assert_has(extra.get("flags", []), "general_general", "bandeira do general")
	assert_has(extra.get("flags", []), "general_de_mao", "bandeira do de mao")
	assert_does_not_have(extra.get("flags", []), "general_sem_riscar", "riscou varias")
	assert_does_not_have(extra.get("flags", []), "general_200", "ficou abaixo de 200")
	assert_false(_rolar(jogo, [1, 2, 3, 4, 5]), "partida fechada nao rola")


func test_solo_vence_pela_meta_do_degrau() -> void:
	var jogo := _jogo()
	DifficultyManager.set_level("general", 1)
	_modo(jogo, SOLO)
	assert_eq(jogo.table.count, 1, "uma cadeira so")
	assert_eq(jogo.folhas.size(), 1, "uma folha")
	assert_eq(GeneralRules.meta_solo(jogo.ai_level), 105, "meta do primeiro degrau")
	for turno in GeneralRules.TURNOS:
		assert_true(_rolar(jogo, [6, 6, 6, 6, 6]), "rolou")
		assert_true(_marcar(jogo, GeneralRules.best_category(jogo.dados, jogo.folhas[0], true)), "marcou")
	assert_true(jogo.game_over, "acabou em dez rodadas")
	assert_eq(str(jogo.ultimo_resultado.get("mode", "")), "solo", "modo solo")
	assert_eq(int(jogo.ultimo_resultado.get("score", 0)), 175, "175 pontos")
	assert_true(jogo.last_difficulty.has("level"), "a escada fechou")
	assert_true(jogo.status_label.text.contains("175"), "o aviso traz o total")


func test_o_modo_cicla_entre_solo_ia_e_dois_e_some_em_rede() -> void:
	var jogo := _jogo()
	assert_eq(jogo.mode_switch.modo, IA, "comeca contra a maquina")
	jogo.mode_switch._on_pressed()
	assert_eq(jogo.mode_switch.modo, VERSUS, "depois dois no aparelho")
	assert_true(jogo.table.pass_and_play(), "e a mesa acompanha")
	jogo.mode_switch._on_pressed()
	assert_eq(jogo.mode_switch.modo, SOLO, "depois solo")
	assert_eq(jogo.table.count, 1, "uma cadeira")
	jogo.mode_switch._on_pressed()
	assert_eq(jogo.mode_switch.modo, IA, "e volta")
	assert_true(jogo.mode_switch.visible, "visivel fora da rede")

	NetworkManager._test_activate("general", 1)
	var em_rede := _jogo()
	assert_false(em_rede.mode_switch.visible, "em rede nao ha modo a escolher")
	assert_true(em_rede.table.online(), "mesa em rede")


func test_contra_a_maquina_ela_joga_a_vez_dela_sozinha() -> void:
	var jogo := await _cena()
	assert_true(_rolar(jogo, [4, 4, 4, 4, 1]), "rolei")
	assert_true(_marcar(jogo, "quadra"), "marquei")
	assert_eq(jogo.vez, 1, "vez da maquina")
	await wait_until(func() -> bool: return jogo.vez == 0 or jogo.game_over, 20.0)
	assert_eq(jogo.vez, 0, "a maquina rolou, gravou e devolveu a vez")
	assert_eq(GeneralRules.turnos_jogados(jogo.folhas[1]), 1, "com uma categoria na folha dela")
	assert_true(GeneralRules.completa(jogo.folhas[1]) or jogo.rolagem == 0, "a rodada recomecou")


# --------------------------------------------------------------------- rede

func test_rede_anfitriao_manda_a_semente_e_a_rolagem_com_os_valores() -> void:
	NetworkManager._test_activate("general", 1)
	var jogo := await _cena()
	assert_true(jogo.table.is_host(), "abri a sala")
	assert_true(jogo.table.is_remote(1), "o outro esta na cadeira 1")
	assert_eq(str(NetworkManager.sent_moves[0]["t"]), "deal", "a semente sai primeiro")
	jogo._on_rolar()
	assert_eq(jogo.rolagem, 1, "rolei")
	assert_eq(NetworkManager.sent_moves.size(), 2, "e a rolagem viajou")
	var act: Dictionary = NetworkManager.sent_moves[1]
	assert_eq(str(act["t"]), "act", "como acao")
	assert_eq(int(act["seat"]), 0, "da minha cadeira")
	assert_eq(str(act["a"]["t"]), "roll", "de rolar")
	assert_eq((act["a"]["values"] as Array).size(), 5, "com os cinco valores dentro")
	assert_eq(Array(act["a"]["values"]), jogo.dados, "os mesmos que estao na mesa")
	await _esperar_giro(jogo)
	var cat := GeneralRules.best_category(jogo.dados, jogo.folhas[0], true)
	jogo._on_categoria(cat)
	assert_eq(NetworkManager.sent_moves.size(), 3, "a marcacao viajou")
	assert_eq(str(NetworkManager.sent_moves[2]["a"]["cat"]), cat, "com a categoria")
	assert_eq(jogo.vez, 1, "e a vez foi para o outro aparelho")
	jogo._on_rolar()
	assert_eq(NetworkManager.sent_moves.size(), 3, "na vez dele nada sai daqui")


func test_rede_convidado_recebe_a_rolagem_e_a_aplica() -> void:
	NetworkManager._test_activate("general", 2)
	var jogo := await _cena()
	assert_true(jogo.sync.waiting_for_deal(), "espera a semente")
	assert_true(jogo.btn_rolar.disabled, "sem semente nao se rola")
	NetworkManager.move_received.emit({"t": "deal", "seed": 123})
	assert_false(jogo.sync.waiting_for_deal(), "a semente entrou")
	assert_eq(jogo.vez, 0, "comeca quem abriu a sala")
	jogo._on_rolar()
	assert_eq(jogo.rolagem, 0, "na vez do outro o meu toque nao vale")

	NetworkManager.move_received.emit({"t": "act", "seat": 0,
		"a": {"t": "roll", "values": [6, 6, 6, 6, 6], "held": TODOS_SOLTOS}})
	assert_eq(jogo.dados, [6, 6, 6, 6, 6], "os valores dele entraram")
	assert_eq(jogo.rolagem, 1, "uma rolagem")
	NetworkManager.move_received.emit({"t": "act", "seat": 0, "a": {"t": "score", "cat": "general"}})
	assert_eq(jogo.folhas[0]["general"], 100, "general de mao gravado para ele")
	assert_eq(jogo.vez, 1, "agora e a minha vez")
	await _esperar_giro(jogo)
	var antes := NetworkManager.sent_moves.size()
	jogo._on_rolar()
	assert_eq(jogo.rolagem, 1, "rolei")
	assert_eq(NetworkManager.sent_moves.size(), antes + 1, "e a minha rolagem viajou")
	assert_eq(int(NetworkManager.sent_moves[antes]["seat"]), 1, "da cadeira 1")


func test_rede_ignora_jogada_ilegal_ou_fora_de_vez() -> void:
	NetworkManager._test_activate("general", 2)
	var jogo := _jogo()
	NetworkManager.move_received.emit({"t": "deal", "seed": 7})
	NetworkManager.move_received.emit({"t": "act", "seat": 1,
		"a": {"t": "roll", "values": [2, 2, 2, 2, 2], "held": TODOS_SOLTOS}})
	assert_eq(jogo.rolagem, 0, "a minha cadeira nao entra pela rede")
	NetworkManager.move_received.emit({"t": "act", "seat": 0,
		"a": {"t": "roll", "values": [9, 2, 2, 2, 2], "held": TODOS_SOLTOS}})
	assert_eq(jogo.rolagem, 0, "dado de nove faces nao existe")
	NetworkManager.move_received.emit({"t": "act", "seat": 0, "a": {"t": "score", "cat": "quadra"}})
	assert_true(jogo.folhas[0].is_empty(), "marcar sem rolar nao vale")
	for i in 4:
		NetworkManager.move_received.emit({"t": "act", "seat": 0,
			"a": {"t": "roll", "values": [3, 3, 3, 3, 1], "held": TODOS_SOLTOS}})
	assert_eq(jogo.rolagem, 3, "a quarta rolagem e ignorada")
	NetworkManager.move_received.emit({"t": "act", "seat": 0, "a": {"t": "score", "cat": "bicho"}})
	assert_eq(jogo.vez, 0, "categoria inventada nao passa a vez")
	NetworkManager.move_received.emit({"t": "act", "seat": 0, "a": {"t": "score", "cat": "quadra"}})
	assert_eq(jogo.folhas[0]["quadra"], 40, "a quadra legal entra")
	assert_eq(jogo.vez, 1, "e passa a vez")
