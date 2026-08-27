extends Node

## Motivos para voltar amanha.
##
## As outras engines reagem ao que o jogador fez; esta cuida do que o traz de
## volta: bonus por abrir o app, congelamento de sequencia para nao perder 20
## dias por um dia corrido, e o "falta pouco" que a HUD mostra.
##
## O bonus de login e concedido na *abertura*, nao no fim da partida: recompensa
## que so chega depois de jogar nao ajuda quem abriu o app sem saber o que
## fazer.

## XP do bonus diario, por dia de sequencia. Depois do setimo repete o ultimo.
const BONUS_POR_DIA := [100, 150, 200, 300, 400, 500, 750]

## A cada tantos dias de sequencia, o jogador ganha um congelamento.
const DIAS_POR_FREEZE := 5
const MAX_FREEZES := 3

signal daily_bonus_granted(xp: int, streak: int)

var _bonus_de_hoje: int = 0


func _ready() -> void:
	# Espera um quadro: PlayerProfile precisa ter carregado, e as demais
	# engines precisam estar escutando o barramento antes do primeiro XP.
	_conceder_bonus_diario.call_deferred()


func _conceder_bonus_diario() -> void:
	var hoje := Time.get_date_string_from_system()
	if str(PlayerProfile.get_stat("last_bonus_date", "")) == hoje:
		return

	# Abrir o app ja conta como dia jogado: a sequencia nao deveria depender de
	# terminar uma partida, senao quem abriu para ver o perfil perde a streak.
	PlayerProfile.update_daily_streak()
	PlayerProfile.roll_daily_bucket()
	PlayerProfile.set_stat("last_bonus_date", hoje)

	var indice := clampi(PlayerProfile.current_streak - 1, 0, BONUS_POR_DIA.size() - 1)
	var xp: int = BONUS_POR_DIA[indice]
	_bonus_de_hoje = xp

	if RewardSystem:
		RewardSystem.grant_xp(xp, "daily_bonus")
	_talvez_conceder_freeze()
	daily_bonus_granted.emit(xp, PlayerProfile.current_streak)


## Congelamento de sequencia: um dia perdido nao apaga semanas. Concedido a
## cada `DIAS_POR_FREEZE` dias de sequencia, com teto para nao virar imunidade.
func _talvez_conceder_freeze() -> void:
	var streak := PlayerProfile.current_streak
	if streak <= 0 or streak % DIAS_POR_FREEZE != 0:
		return
	if int(PlayerProfile.get_stat("streak_freezes", 0)) >= MAX_FREEZES:
		return
	if RewardSystem and RewardSystem.claim_unique_reward("freeze_streak_%d" % streak, "streak_freeze"):
		pass


func bonus_de_hoje() -> int:
	return _bonus_de_hoje


func freezes_disponiveis() -> int:
	return int(PlayerProfile.get_stat("streak_freezes", 0))


# ------------------------------------------------------------------ "falta pouco"

## O proximo marco alcancavel, para a HUD dar um alvo concreto em vez de um
## numero solto. Devolve `{}` quando nao ha nada perto.
func proximo_marco() -> Dictionary:
	var candidatos: Array = []

	var prog := PlayerProfile.xp_progress()
	if prog.y > 0:
		candidatos.append({
			"tipo": "level",
			"texto_key": "NUDGE_LEVEL",
			"args": [prog.y - prog.x, PlayerProfile.level + 1],
			"frac": float(prog.x) / float(prog.y),
		})

	if LeagueSystem:
		var lp: Vector2i = LeagueSystem.league_progress()
		var proxima: Dictionary = LeagueSystem.next_league()
		if lp.y > 0 and not proxima.is_empty():
			candidatos.append({
				"tipo": "league",
				"texto_key": "NUDGE_LEAGUE",
				"args": [lp.y - lp.x, tr("LEAGUE_" + str(proxima["id"]).to_upper())],
				"frac": float(lp.x) / float(lp.y),
			})

	if AchievementEngine:
		for a in AchievementEngine.closest_to_unlock(1):
			candidatos.append({
				"tipo": "achievement",
				"texto_key": "NUDGE_ACHIEVEMENT",
				"args": [int(a["target"]) - int(a["progress"]), tr(str(a["id"]) + "_NAME")],
				"frac": float(a["frac"]),
			})

	if QuestEngine:
		for q in QuestEngine.quests_for_ui("daily"):
			if q["completed"]:
				continue
			candidatos.append({
				"tipo": "quest",
				"texto_key": "NUDGE_QUEST",
				"args": [int(q["target"]) - int(q["progress"]), tr(str(q["name_key"]))],
				"frac": float(q["progress"]) / float(maxi(1, int(q["target"]))),
			})

	if candidatos.is_empty():
		return {}
	candidatos.sort_custom(func(a, b): return a["frac"] > b["frac"])
	return _singularizar(candidatos[0])


## "Faltam 1 para Vitrine Cheia" é o que o jogador lê justamente no momento em
## que o marco está mais perto -- ou seja, na hora em que a frase mais importa.
## Os quatro recados têm forma singular própria; o primeiro argumento de todos é
## a quantidade que falta.
func _singularizar(marco: Dictionary) -> Dictionary:
	var args: Array = marco["args"]
	if args.is_empty() or int(args[0]) != 1:
		return marco
	marco["texto_key"] = str(marco["texto_key"]) + "_ONE"
	marco["args"] = args.slice(1)
	return marco


## Resumo do perfil para cabecalho de menu e tela de perfil.
func resumo() -> Dictionary:
	var prog := PlayerProfile.xp_progress()
	return {
		"level": PlayerProfile.level,
		"xp": prog.x,
		"xp_next": prog.y,
		"streak": PlayerProfile.current_streak,
		"longest_streak": PlayerProfile.longest_streak,
		"freezes": freezes_disponiveis(),
		"league": str(LeagueSystem.get_current_league()["id"]) if LeagueSystem else "bronze",
		"elo": LeagueSystem.current_elo if LeagueSystem else 0,
		"achievements": AchievementEngine.unlocked_count() if AchievementEngine else 0,
		"achievements_total": AchievementEngine.total_count() if AchievementEngine else 0,
		"quests_pending": QuestEngine.pending_count() if QuestEngine else 0,
		"matches": int(PlayerProfile.get_stat("total_matches", 0)),
		"wins": int(PlayerProfile.get_stat("total_wins", 0)),
		"games_played": PlayerProfile.games_played_count(),
		"games_total": GameCatalog.get_all_games().size(),
		"collection": CollectionSystem.get_completion_percentage() if CollectionSystem else 0.0,
	}
