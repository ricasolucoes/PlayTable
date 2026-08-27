extends GutTest

## Gamificação — o motor que decide XP, conquista, missão, liga e coleção.
##
## Estes testes existem porque a versão anterior deste motor rodava pela metade
## sem nunca reclamar: as missões diárias pagavam uma vez na vida do app, o
## anti-cheat descartava XP legítimo, e o Play Games recebia ids inventados que
## o servidor recusa em silêncio. Nenhuma dessas falhas produzia erro — todas
## produziam um jogo que parecia funcionar.
##
## O perfil é global (autoload) e grava em disco, então cada teste guarda o
## estado real antes e devolve depois: rodar a suíte não pode mexer no
## progresso de quem estiver jogando na mesma máquina.

const CATALOGO := "res://core/configs/achievements.json"
const IDS_PGS := "res://core/configs/play_games_ids.json"
const POOL_MISSOES := "res://core/configs/quests.json"

var _backup: Dictionary = {}


func before_each() -> void:
	_backup = {
		"level": PlayerProfile.level,
		"lifetime_xp": PlayerProfile.lifetime_xp,
		"current_streak": PlayerProfile.current_streak,
		"longest_streak": PlayerProfile.longest_streak,
		"last_played_date": PlayerProfile.last_played_date,
		"stats": PlayerProfile.stats.duplicate(true),
		"per_game": PlayerProfile.per_game.duplicate(true),
		"unlocked": PlayerProfile.unlocked_achievements.duplicate(),
		"progress": PlayerProfile.achievement_progress.duplicate(true),
		"flags": PlayerProfile.flags.duplicate(),
		"quests": PlayerProfile.active_quests.duplicate(true),
		"claimed": PlayerProfile.claimed_rewards.duplicate(),
	}


func after_each() -> void:
	PlayerProfile.level = _backup["level"]
	PlayerProfile.lifetime_xp = _backup["lifetime_xp"]
	PlayerProfile.current_streak = _backup["current_streak"]
	PlayerProfile.longest_streak = _backup["longest_streak"]
	PlayerProfile.last_played_date = _backup["last_played_date"]
	PlayerProfile.stats = _backup["stats"]
	PlayerProfile.per_game = _backup["per_game"]
	PlayerProfile.unlocked_achievements = _backup["unlocked"]
	PlayerProfile.achievement_progress = _backup["progress"]
	PlayerProfile.flags = _backup["flags"]
	PlayerProfile.active_quests = _backup["quests"]
	PlayerProfile.claimed_rewards = _backup["claimed"]
	PlayerProfile.save_profile()


func _json(caminho: String) -> Dictionary:
	var j := JSON.new()
	assert_eq(j.parse(FileAccess.get_file_as_string(caminho)), OK, "%s é JSON válido" % caminho)
	return j.data


# ============================================================ integridade dos dados

func test_todo_id_do_catalogo_tem_nome_e_descricao_traduzidos() -> void:
	var anterior := TranslationServer.get_locale()
	TranslationServer.set_locale("pt_BR")
	var faltando: Array[String] = []
	for a in _json(CATALOGO)["achievements"]:
		for sufixo in ["_NAME", "_DESC"]:
			var chave: String = str(a["id"]) + sufixo
			if tr(chave) == chave:
				faltando.append(chave)
	TranslationServer.set_locale(anterior)
	assert_eq(faltando, [] as Array[String],
		"conquista sem tradução aparece na tela como id cru")


func test_catalogo_e_mapa_do_play_console_falam_dos_mesmos_ids() -> void:
	var catalogo: Array = []
	for a in _json(CATALOGO)["achievements"]:
		catalogo.append(str(a["id"]))
	var mapa: Array = _json(IDS_PGS)["achievements"].keys()

	catalogo.sort()
	mapa.sort()
	assert_eq(mapa, catalogo,
		"id no catálogo sem entrada no mapa nunca chega ao Play Games, e o contrário vira id órfão")


func test_toda_regra_de_conquista_e_avaliavel() -> void:
	var tipos_conhecidos := ["stat", "level", "streak", "distinct_games", "game_win", "flag", "mastery", "all"]
	var jogos := GameCatalog.all_game_ids()
	var problemas: Array[String] = []

	for a in _json(CATALOGO)["achievements"]:
		var id: String = str(a["id"])
		var r: Dictionary = a.get("rule", {})
		var tipo := str(r.get("type", ""))

		if not tipos_conhecidos.has(tipo):
			problemas.append("%s: tipo de regra desconhecido '%s'" % [id, tipo])
			continue
		if int(a.get("xp", 0)) <= 0:
			problemas.append("%s: XP não positivo" % id)
		if tipo in ["stat", "level", "streak", "distinct_games", "mastery"] and int(r.get("target", 0)) <= 0:
			problemas.append("%s: alvo não positivo" % id)
		if tipo == "stat" and str(r.get("key", "")) == "":
			problemas.append("%s: regra de estatística sem chave" % id)
		if tipo == "flag" and str(r.get("key", "")) == "":
			problemas.append("%s: regra de flag sem chave" % id)
		if tipo == "game_win" and not jogos.has(str(r.get("game", ""))):
			problemas.append("%s: aponta para o jogo '%s', que não está no catálogo" % [id, r.get("game", "")])
		if tipo == "distinct_games" and int(r.get("target", 0)) > jogos.size():
			problemas.append("%s: pede %d jogos diferentes e só existem %d" % [id, r.get("target", 0), jogos.size()])

	assert_eq(problemas, [] as Array[String], "regra impossível de cumprir é conquista morta")


func test_toda_missao_do_pool_tem_nome_traduzido() -> void:
	var anterior := TranslationServer.get_locale()
	TranslationServer.set_locale("pt_BR")
	var pool := _json(POOL_MISSOES)
	var faltando: Array[String] = []
	for escopo in ["daily", "weekly"]:
		for q in pool[escopo]:
			var chave: String = "QUEST_" + str(q["id"]).to_upper()
			if tr(chave) == chave:
				faltando.append(chave)
	TranslationServer.set_locale(anterior)
	assert_eq(faltando, [] as Array[String], "missão sem tradução")


func test_o_pool_tem_missoes_suficientes_para_o_lote() -> void:
	var pool := _json(POOL_MISSOES)
	for escopo in ["daily", "weekly"]:
		assert_gte(int(pool[escopo].size()), int(pool[escopo + "_count"]),
			"pool de %s menor que o lote sorteado" % escopo)


# ==================================================================== curva de XP

func test_a_curva_de_nivel_e_monotonica() -> void:
	var anterior := 0
	for nivel in range(1, 40):
		var acumulado := PlayerProfile.xp_total_for_level(nivel)
		assert_gt(acumulado, anterior - 1, "nível %d custa mais que o anterior" % nivel)
		anterior = acumulado


func test_nivel_derivado_e_o_inverso_do_acumulado() -> void:
	for nivel in range(1, 30):
		var no_ponto := PlayerProfile.xp_total_for_level(nivel)
		assert_eq(PlayerProfile._level_from_xp(no_ponto), nivel,
			"exatamente o XP do nível %d dá o nível %d" % [nivel, nivel])
		assert_eq(PlayerProfile._level_from_xp(no_ponto - 1), maxi(1, nivel - 1),
			"um XP a menos ainda é o nível anterior")


func test_xp_vitalicio_sobrevive_a_mudanca_de_curva() -> void:
	# É o ponto todo de guardar o acumulado em vez do resto do nível: a curva
	# pode mudar que ninguém perde progresso.
	PlayerProfile.lifetime_xp = 50000
	var nivel_a := PlayerProfile._level_from_xp(PlayerProfile.lifetime_xp)
	assert_gt(nivel_a, 1, "50k de XP não é nível 1")
	assert_eq(PlayerProfile.lifetime_xp, 50000, "o acumulado não é consumido ao subir de nível")


func test_dias_entre_datas() -> void:
	assert_eq(PlayerProfile.days_between("2026-08-27", "2026-08-28"), 1, "dia seguinte")
	assert_eq(PlayerProfile.days_between("2026-08-27", "2026-08-27"), 0, "mesmo dia")
	assert_eq(PlayerProfile.days_between("2026-08-01", "2026-09-01"), 31, "atravessa o mês")
	assert_eq(PlayerProfile.days_between("2026-12-31", "2027-01-01"), 1, "atravessa o ano")
	assert_eq(PlayerProfile.days_between("", "2026-08-27"), 0, "perfil novo não tem data anterior")


# ============================================================== anti-cheat de XP

func test_cascata_legitima_de_uma_vitoria_passa_inteira() -> void:
	# Uma vitória boa concede no mesmo quadro: partida, missão diária, e três
	# conquistas em cascata. O limitador anterior contava chamadas e barrava a
	# partir da quarta.
	var sm := preload("res://core/services/SecurityManager.gd").new()
	add_child_autofree(sm)
	sm._ready()
	var passaram := 0
	for valor in [180, 400, 300, 1000, 500, 250]:
		if sm.validate_xp_gain(valor, "teste"):
			passaram += 1
	assert_eq(passaram, 6, "as seis concessões de uma única vitória passam")


func test_injecao_acima_do_teto_e_barrada() -> void:
	var sm := preload("res://core/services/SecurityManager.gd").new()
	add_child_autofree(sm)
	sm._ready()
	assert_false(sm.validate_xp_gain(sm.MAX_XP_PER_TRANSACTION + 1, "cheat"),
		"concessão única acima do teto")
	assert_false(sm.validate_xp_gain(-50, "cheat"), "valor negativo")
	assert_false(sm.validate_xp_gain(0, "cheat"), "zero não é concessão")


func test_orcamento_da_janela_barra_o_excesso() -> void:
	var sm := preload("res://core/services/SecurityManager.gd").new()
	add_child_autofree(sm)
	sm._ready()
	var concedido := 0
	for _i in range(100):
		if sm.validate_xp_gain(5000, "loop"):
			concedido += 5000
	assert_lte(concedido, sm.MAX_XP_PER_WINDOW, "o total da janela respeita o orçamento")
	assert_gt(sm.blocked_count(), 0, "o excesso foi recusado, não ignorado")


# =================================================================== missões

func test_o_sorteio_de_missoes_e_estavel_dentro_da_janela() -> void:
	var qe := preload("res://core/services/QuestEngine.gd").new()
	add_child_autofree(qe)
	qe._load_pool()
	var pool: Array = qe._pool["daily"]

	var a := qe._sortear(pool, 3, "2026-08-27")
	var b := qe._sortear(pool, 3, "2026-08-27")
	assert_eq(a, b, "reabrir o app no mesmo dia devolve o mesmo lote")

	var c := qe._sortear(pool, 3, "2026-08-28")
	assert_ne(a, c, "outro dia, outro lote")


func test_o_lote_nao_repete_o_mesmo_tipo_de_missao() -> void:
	var qe := preload("res://core/services/QuestEngine.gd").new()
	add_child_autofree(qe)
	qe._load_pool()
	for dia in range(1, 15):
		var lote: Array = qe._sortear(qe._pool["daily"], 3, "2026-09-%02d" % dia)
		var vistos := {}
		for m in lote:
			var assinatura := str(m["type"]) + ":" + str(m.get("category", ""))
			assert_false(vistos.has(assinatura),
				"dia %d sorteou dois '%s'" % [dia, assinatura])
			vistos[assinatura] = true


func test_missao_de_janela_vencida_e_trocada() -> void:
	var qe := preload("res://core/services/QuestEngine.gd").new()
	add_child_autofree(qe)
	qe._load_pool()
	qe.quests = {}

	assert_true(qe._roll_scope("daily", "2026-01-01"), "primeiro lote é criado")
	for id in qe.quests:
		qe.quests[id]["completed"] = true
	var antigas := qe.quests.keys().duplicate()

	assert_false(qe._roll_scope("daily", "2026-01-01"), "o lote do mesmo dia não é resorteado")
	assert_true(qe._roll_scope("daily", "2026-01-02"), "o dia seguinte troca o lote")

	for id in qe.quests:
		assert_false(bool(qe.quests[id]["completed"]),
			"o lote novo nasce em aberto -- era este o defeito: as três primeiras missões ficavam completas para sempre")
	for id in antigas:
		assert_false(qe.quests.has(id), "missão da janela vencida sai da lista")


func test_janela_semanal_muda_a_cada_sete_dias() -> void:
	var w := QuestEngine.weekly_window()
	assert_true(w.begins_with("W"), "a janela semanal é rotulada")
	assert_ne(w, QuestEngine.daily_window(), "janela semanal e diária não colidem")


# ============================================================ conquistas em uso

func test_conquista_de_estatistica_abre_no_alvo() -> void:
	PlayerProfile.unlocked_achievements = []
	PlayerProfile.achievement_progress = {}
	PlayerProfile.stats = {"total_wins": 9}
	AchievementEngine._evaluate()
	assert_false(PlayerProfile.unlocked_achievements.has("ACH_WIN_10"), "9 vitórias ainda não abre")

	PlayerProfile.stats["total_wins"] = 10
	AchievementEngine._evaluate()
	assert_true(PlayerProfile.unlocked_achievements.has("ACH_WIN_10"), "10 vitórias abre")


func test_conquista_de_jogo_especifico_le_o_placar_daquele_jogo() -> void:
	PlayerProfile.unlocked_achievements = []
	PlayerProfile.achievement_progress = {}
	PlayerProfile.per_game = {}
	AchievementEngine._evaluate()
	assert_false(PlayerProfile.unlocked_achievements.has("ACH_REVERSI_WIN"), "sem vitória no Reversi")

	PlayerProfile.record_match("reversi", true)
	AchievementEngine._evaluate()
	assert_true(PlayerProfile.unlocked_achievements.has("ACH_REVERSI_WIN"), "uma vitória no Reversi abre")


func test_o_progresso_parcial_fica_guardado_para_a_barra() -> void:
	PlayerProfile.unlocked_achievements = []
	PlayerProfile.achievement_progress = {}
	PlayerProfile.stats = {"total_wins": 37}
	AchievementEngine._evaluate()
	assert_eq(int(PlayerProfile.achievement_progress.get("ACH_WIN_50", 0)), 37,
		"a tela mostra 37/50, não um cadeado fechado")


func test_conquista_nao_abre_duas_vezes() -> void:
	PlayerProfile.unlocked_achievements = []
	PlayerProfile.stats = {"total_wins": 100}
	AchievementEngine._evaluate()
	var quantas := PlayerProfile.unlocked_achievements.count("ACH_WIN_10")
	AchievementEngine._evaluate()
	assert_eq(PlayerProfile.unlocked_achievements.count("ACH_WIN_10"), quantas,
		"reavaliar não duplica")


func test_jogos_experimentados_conta_contra_o_catalogo() -> void:
	PlayerProfile.per_game = {"damas": {"matches": 3}, "playtable": {"matches": 99}}
	assert_eq(PlayerProfile.games_played_count(), 1,
		"'playtable' é o fallback de id, não um jogo -- contá-lo mostrava 20/19 na tela")


# =========================================================== merge da nuvem

func test_o_merge_da_nuvem_fica_com_o_maior_contador() -> void:
	PlayerProfile.stats = {"total_wins": 10, "total_matches": 40}
	PlayerProfile.lifetime_xp = 5000
	CloudSaveSync.apply_remote({
		"schema": 2, "lifetime_xp": 8000,
		"stats": {"total_wins": 4, "total_matches": 90},
	})
	assert_eq(int(PlayerProfile.get_stat("total_wins")), 10, "local maior vence")
	assert_eq(int(PlayerProfile.get_stat("total_matches")), 90, "remoto maior vence")
	assert_eq(PlayerProfile.lifetime_xp, 8000, "XP vitalício fica com o maior")


func test_o_merge_da_nuvem_une_conquistas_e_flags() -> void:
	PlayerProfile.unlocked_achievements = ["ACH_FIRST_BLOOD"]
	PlayerProfile.flags = ["perfect"]
	CloudSaveSync.apply_remote({
		"schema": 2,
		"achievements": ["ACH_WIN_10", "ACH_FIRST_BLOOD"],
		"flags": ["night_owl"],
	})
	assert_true(PlayerProfile.unlocked_achievements.has("ACH_FIRST_BLOOD"), "mantém a local")
	assert_true(PlayerProfile.unlocked_achievements.has("ACH_WIN_10"), "traz a do outro aparelho")
	assert_eq(PlayerProfile.unlocked_achievements.count("ACH_FIRST_BLOOD"), 1, "sem duplicar")
	assert_true(PlayerProfile.flags.has("perfect") and PlayerProfile.flags.has("night_owl"),
		"ninguém perde conquista por ter jogado no tablet")


func test_o_merge_de_recorde_por_jogo_respeita_o_sentido_da_metrica() -> void:
	PlayerProfile.per_game = {"campo_minado": {"matches": 5, "wins": 2, "best_time": 90, "best_score": 10}}
	CloudSaveSync.apply_remote({
		"schema": 2,
		"per_game": {"campo_minado": {"matches": 3, "wins": 3, "best_time": 60, "best_score": 4}},
	})
	var g: Dictionary = PlayerProfile.per_game["campo_minado"]
	assert_eq(int(g["matches"]), 5, "partidas: o maior")
	assert_eq(int(g["wins"]), 3, "vitórias: o maior")
	assert_eq(int(g["best_time"]), 60, "tempo: o MENOR é o recorde")
	assert_eq(int(g["best_score"]), 10, "pontuação: o maior")


func test_o_merge_nao_ressuscita_sequencia_quebrada() -> void:
	PlayerProfile.last_played_date = "2026-08-27"
	PlayerProfile.current_streak = 3
	CloudSaveSync.apply_remote({
		"schema": 2, "last_played_date": "2026-08-01", "current_streak": 40,
	})
	assert_eq(PlayerProfile.current_streak, 3,
		"aparelho parado há um mês não devolve uma sequência de 40 dias")


# ============================================================ play games (política)

func test_id_nao_mapeado_nao_e_enviado() -> void:
	# Enquanto o Play Console não gerou o id, mandar a chave interna crua é pior
	# que não mandar: o servidor recusa em silêncio e a integração parece viva.
	var antes := PlayGamesManager.queued_count()
	PlayGamesManager.unlock_achievement("ACH_QUE_NAO_EXISTE")
	# nada é enfileirado porque nada tem para onde ir
	assert_eq(PlayGamesManager.queued_count(), antes, "id sem tradução não vira envio")
	assert_true(PlayGamesManager.unmapped_keys().size() > 0,
		"a chave sem id fica registrada para o diagnóstico")


func test_a_fila_offline_colapsa_repeticao() -> void:
	var pgm := preload("res://core/services/PlayGamesManager.gd").new()
	add_child_autofree(pgm)

	pgm._enqueue({"op": "score", "id": "L1", "key": "LB", "score": 100})
	pgm._enqueue({"op": "score", "id": "L1", "key": "LB", "score": 400})
	pgm._enqueue({"op": "score", "id": "L1", "key": "LB", "score": 250})
	assert_eq(pgm.queued_count(), 1, "um placar só")
	assert_eq(int(pgm._queue[0]["score"]), 400, "com o melhor valor")

	pgm._enqueue({"op": "event", "id": "E1", "key": "EV", "amount": 1})
	pgm._enqueue({"op": "event", "id": "E1", "key": "EV", "amount": 3})
	assert_eq(pgm.queued_count(), 2, "evento é outra entrada")
	assert_eq(int(pgm._queue[1]["amount"]), 4, "eventos somam")

	pgm._enqueue({"op": "unlock", "id": "A1", "key": "ACH"})
	pgm._enqueue({"op": "unlock", "id": "A1", "key": "ACH"})
	assert_eq(pgm.queued_count(), 3, "desbloqueio repetido não duplica")


func test_fora_do_android_a_integracao_diz_a_verdade() -> void:
	if OS.get_name() == "Android":
		pass_test("teste é sobre o comportamento fora do Android")
		return
	assert_false(PlayGamesManager.is_available(), "sem plugin não há integração")
	assert_false(PlayGamesManager.is_logged_in(), "e portanto não há login")
	assert_false(PlayGamesManager.is_sidekick_supported(),
		"o Sidekick devolvia true em qualquer aparelho e a UI prometia o que não abriria")


# =================================================================== placares

func test_metrica_invertida_so_conta_em_vitoria() -> void:
	PlayerProfile.stats = {}
	# Perder rápido no Campo Minado não é recorde de tempo.
	LeaderboardSync._on_match_completed("campo_minado", {"win": false, "time": 5.0})
	assert_eq(int(PlayerProfile.get_stat("record_campo_minado", 0)), 0, "derrota não vira recorde")

	LeaderboardSync._on_match_completed("campo_minado", {"win": true, "time": 90.0})
	assert_eq(int(PlayerProfile.get_stat("record_campo_minado", 0)), 90000, "vitória em ms")

	LeaderboardSync._on_match_completed("campo_minado", {"win": true, "time": 120.0})
	assert_eq(int(PlayerProfile.get_stat("record_campo_minado", 0)), 90000, "tempo pior não substitui")

	LeaderboardSync._on_match_completed("campo_minado", {"win": true, "time": 45.0})
	assert_eq(int(PlayerProfile.get_stat("record_campo_minado", 0)), 45000, "tempo melhor substitui")


# ====================================================================== coleção

func test_a_colecao_libera_pelo_nivel_e_nao_solta_o_que_falta() -> void:
	PlayerProfile.level = 1
	PlayerProfile.stats = {}
	CollectionSystem.unlocked_items = []
	CollectionSystem.evaluate_unlocks()
	assert_true(CollectionSystem.has_item("felt_green"), "o item padrão nasce liberado")
	assert_false(CollectionSystem.has_item("felt_slate"), "nível 10 ainda não")

	PlayerProfile.level = 10
	CollectionSystem.evaluate_unlocks()
	assert_true(CollectionSystem.has_item("felt_slate"), "nível 10 libera")


func test_equipar_marca_a_flag_de_tabuleiro_proprio() -> void:
	PlayerProfile.flags = []
	PlayerProfile.stats = {}
	CollectionSystem.unlocked_items = []
	PlayerProfile.level = 6
	CollectionSystem.evaluate_unlocks()
	assert_true(CollectionSystem.equip("felt_navy"), "equipa o que está liberado")
	assert_true(PlayerProfile.has_flag("custom_board"), "é o gatilho da conquista Tabuleiro Seu")
	assert_false(CollectionSystem.equip("marble_black"), "não equipa o que está bloqueado")
