extends Node

## Perfil local do jogador: a fonte de verdade da gamificacao.
##
## Guarda XP, nivel, streak diaria, estatisticas agregadas e por jogo, as
## conquistas ja desbloqueadas e as flags de evento unico. Tudo local e
## offline; o `CloudSaveSync` sobe este mesmo estado para o Saved Games do
## Play Games quando ha login.
##
## Duas decisoes que valem explicacao:
##
## 1. `lifetime_xp` e monotonico e e o unico numero realmente guardado. Nivel e
##    progresso dentro do nivel sao *derivados* dele. A versao anterior subtraia
##    XP do total a cada nivel, entao mudar a curva de progressao corrompia
##    todos os perfis existentes e nao havia como ordenar um placar global de
##    XP. Agora a curva pode mudar que o perfil so recalcula.
##
## 2. Gravar em disco e debounced. Uma unica partida encosta em dezenas de
##    contadores (total, por jogo, diario, maestria, quests, 50 conquistas
##    avaliadas); com gravacao sincrona em cada `increment_stat` isso viravam
##    dezenas de escritas de ConfigFile no meio da animacao de vitoria.

signal profile_loaded()
signal level_changed(new_level: int)
signal stats_changed()

const SAVE_PATH := "user://player_profile.cfg"
const PROFILE_VERSION := 2

## Curva de progressao: XP para sair do nivel `l` para `l + 1`.
##
## Calibrada contra o que o jogo realmente paga. Um jogador engajado faz uns
## 2700 XP por dia (bonus de login + 8 partidas + missoes), e o catalogo inteiro
## de conquistas vale ~100k espalhados pela vida do perfil. Com estes numeros o
## acumulado ate o nivel 25 fica em ~176k: nivel 5 na primeira sessao, 10 na
## primeira semana, 25 em alguns meses.
##
## A primeira versao usava 400+150l e uma unica vitoria com duas conquistas
## grandes levava direto ao nivel 6 -- progressao que acaba antes do jogador
## entender que existia.
const XP_BASE := 1000
const XP_STEP := 550

## Teto de seguranca do recalculo de nivel. Nenhum jogador chega perto; existe
## para um save adulterado com XP absurdo nao travar o jogo num laco.
const MAX_LEVEL := 999

var level: int = 1
var lifetime_xp: int = 0
var current_streak: int = 0
var longest_streak: int = 0
var last_played_date: String = ""
var stats: Dictionary = {}
var per_game: Dictionary = {}
var unlocked_achievements: Array = []
var achievement_progress: Dictionary = {}
var flags: Array = []
var active_quests: Dictionary = {}
var claimed_rewards: Array = []

var _dirty: bool = false
var _flush_queued: bool = false

## XP acumulado dentro do nivel atual. Mantido como propriedade derivada porque
## a HUD e o toast falam em "350/1000 para o proximo nivel", nao em XP total.
var total_xp: int:
	get:
		return lifetime_xp - xp_total_for_level(level)


func _ready() -> void:
	load_profile()
	if GameEventBus:
		GameEventBus.xp_gained.connect(_on_xp_gained)
		GameEventBus.achievement_unlocked.connect(_on_achievement_unlocked)


func _notification(what: int) -> void:
	# Fechar o app pelo botao de home nao pode perder a partida que acabou de
	# ser jogada: o flush debounced ainda pode estar pendente.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush()


# ------------------------------------------------------------------ progressao

## XP necessario para sair do nivel `l`.
static func xp_for_level(l: int) -> int:
	return XP_BASE + maxi(0, l - 1) * XP_STEP


## XP acumulado necessario para *chegar* ao nivel `l`.
static func xp_total_for_level(l: int) -> int:
	var n := maxi(0, l - 1)
	return n * XP_BASE + XP_STEP * (n * (n - 1)) / 2


## XP que falta para o proximo nivel, e quanto o nivel atual custa no total.
func xp_progress() -> Vector2i:
	return Vector2i(total_xp, xp_for_level(level))


func _level_from_xp(xp: int) -> int:
	var l := 1
	while l < MAX_LEVEL and xp >= xp_total_for_level(l + 1):
		l += 1
	return l


func add_xp(amount: int) -> void:
	if amount == 0:
		return
	lifetime_xp = maxi(0, lifetime_xp + amount)
	var novo := _level_from_xp(lifetime_xp)
	if novo != level:
		var anterior := level
		level = novo
		_mark_dirty()
		level_changed.emit(level)
		if GameEventBus and novo > anterior:
			# Um unico aviso mesmo quando a recompensa atravessa varios niveis:
			# o toast enfileira por evento, e tres cartoes seguidos de "subiu de
			# nivel" e ruido, nao comemoracao.
			GameEventBus.player_leveled_up.emit(level)
	_mark_dirty()


func _on_xp_gained(amount: int, _source: String) -> void:
	add_xp(amount)


# ------------------------------------------------------------------ estatistica

func get_stat(key: String, default_value: Variant = 0) -> Variant:
	return stats.get(key, default_value)


func set_stat(key: String, value: Variant) -> void:
	stats[key] = value
	_mark_dirty()


func increment_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(get_stat(key, 0)) + amount
	_mark_dirty()


## Marca `key` como no minimo `value` -- usado por recorde (menor tempo, maior
## pontuacao). Devolve true quando o recorde de fato mudou.
func record_max(key: String, value: int) -> bool:
	if value <= int(get_stat(key, 0)):
		return false
	stats[key] = value
	_mark_dirty()
	return true


## Idem para recordes onde menor e melhor (tempo, numero de jogadas).
func record_min(key: String, value: int) -> bool:
	var atual := int(get_stat(key, 0))
	if atual > 0 and value >= atual:
		return false
	if value <= 0:
		return false
	stats[key] = value
	_mark_dirty()
	return true


# ------------------------------------------------------------- estado por jogo

func game_stats(game_id: String) -> Dictionary:
	if not per_game.has(game_id):
		per_game[game_id] = {"matches": 0, "wins": 0, "losses": 0, "best_time": 0, "best_score": 0}
	return per_game[game_id]


func record_match(game_id: String, won: bool) -> void:
	var g := game_stats(game_id)
	g["matches"] = int(g.get("matches", 0)) + 1
	if won:
		g["wins"] = int(g.get("wins", 0)) + 1
	else:
		g["losses"] = int(g.get("losses", 0)) + 1
	_mark_dirty()


func games_played_count() -> int:
	var n := 0
	for id in per_game.keys():
		if int(per_game[id].get("matches", 0)) > 0:
			n += 1
	return n


func has_won(game_id: String) -> bool:
	return int(game_stats(game_id).get("wins", 0)) > 0


# -------------------------------------------------------------------- flags

## Flags sao eventos de acontecer uma vez ("fez royal flush", "jogou depois da
## meia-noite"). Guardadas para a conquista continuar valendo depois que o app
## fecha, e para o motor nao precisar re-observar o passado.
func has_flag(flag: String) -> bool:
	return flags.has(flag)


func set_flag(flag: String) -> bool:
	if flags.has(flag):
		return false
	flags.append(flag)
	_mark_dirty()
	return true


# --------------------------------------------------------------- dia e streak

## Zera os contadores do dia quando a data virou. Chamado no inicio de cada
## partida, antes de qualquer contador subir.
func roll_daily_bucket() -> void:
	var hoje := Time.get_date_string_from_system()
	if str(get_stat("daily_date", "")) != hoje:
		stats["daily_date"] = hoje
		stats["matches_today"] = 0
		stats["wins_today"] = 0
		_mark_dirty()


func update_daily_streak() -> void:
	var hoje := Time.get_date_string_from_system()
	if last_played_date == hoje:
		return

	if last_played_date == "":
		current_streak = 1
	else:
		var dias := days_between(last_played_date, hoje)
		if dias == 1:
			current_streak += 1
		elif dias > 1:
			var freezes := int(get_stat("streak_freezes", 0))
			if dias == 2 and freezes > 0:
				increment_stat("streak_freezes", -1)
				current_streak += 1
				if GameEventBus:
					GameEventBus.streak_freeze_used.emit(current_streak)
			else:
				if dias >= 14:
					set_flag("comeback")
					if GameEventBus:
						GameEventBus.achievement_unlocked.emit("ACH_COMEBACK")
				current_streak = 1

	longest_streak = maxi(longest_streak, current_streak)
	last_played_date = hoje
	_mark_dirty()
	if GameEventBus:
		GameEventBus.daily_streak_updated.emit(current_streak)


static func days_between(date1_str: String, date2_str: String) -> int:
	if date1_str == "" or date2_str == "":
		return 0
	var unix1 := Time.get_unix_time_from_datetime_string(date1_str + "T00:00:00")
	var unix2 := Time.get_unix_time_from_datetime_string(date2_str + "T00:00:00")
	return clampi(int(round((unix2 - unix1) / 86400.0)), 0, 99999)


# ------------------------------------------------------------------ conquistas

func _on_achievement_unlocked(id: String) -> void:
	if not unlocked_achievements.has(id):
		unlocked_achievements.append(id)
		_mark_dirty()


func set_achievement_progress(id: String, atual: int) -> void:
	if int(achievement_progress.get(id, -1)) == atual:
		return
	achievement_progress[id] = atual
	_mark_dirty()


# --------------------------------------------------------------- quests/rewards

func get_active_quests() -> Dictionary:
	return active_quests


func save_active_quests(quests: Dictionary) -> void:
	active_quests = quests
	_mark_dirty()


func get_claimed_rewards() -> Array:
	return claimed_rewards


func save_claimed_rewards(rewards: Array) -> void:
	claimed_rewards = rewards
	_mark_dirty()


# --------------------------------------------------------------- persistencia

## Marca o perfil como sujo e agenda uma unica gravacao para o fim do quadro.
func _mark_dirty() -> void:
	_dirty = true
	stats_changed.emit()
	if _flush_queued:
		return
	_flush_queued = true
	# `call_deferred` junta todas as alteracoes de uma partida numa gravacao so.
	flush.call_deferred()


func flush() -> void:
	_flush_queued = false
	if not _dirty:
		return
	save_profile()


## Compatibilidade: chamadores antigos gravavam explicitamente.
func save_profile() -> void:
	_dirty = false
	_flush_queued = false
	var config := ConfigFile.new()
	config.set_value("Meta", "version", PROFILE_VERSION)
	config.set_value("Progression", "level", level)
	config.set_value("Progression", "lifetime_xp", lifetime_xp)
	config.set_value("Engagement", "current_streak", current_streak)
	config.set_value("Engagement", "longest_streak", longest_streak)
	config.set_value("Engagement", "last_played_date", last_played_date)
	config.set_value("Stats", "metrics", stats)
	config.set_value("Stats", "per_game", per_game)
	config.set_value("Achievements", "unlocked", unlocked_achievements)
	config.set_value("Achievements", "progress", achievement_progress)
	config.set_value("Achievements", "flags", flags)
	config.set_value("Quests", "active", active_quests)
	config.set_value("Rewards", "claimed", claimed_rewards)
	config.save(SAVE_PATH)


func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		_initialize_new_profile()
		profile_loaded.emit()
		return

	var versao := int(config.get_value("Meta", "version", 1))
	current_streak = int(config.get_value("Engagement", "current_streak", 0))
	longest_streak = int(config.get_value("Engagement", "longest_streak", current_streak))
	last_played_date = str(config.get_value("Engagement", "last_played_date", ""))
	stats = config.get_value("Stats", "metrics", {})
	per_game = config.get_value("Stats", "per_game", {})
	unlocked_achievements = config.get_value("Achievements", "unlocked", [])
	achievement_progress = config.get_value("Achievements", "progress", {})
	flags = config.get_value("Achievements", "flags", [])
	active_quests = config.get_value("Quests", "active", {})
	claimed_rewards = config.get_value("Rewards", "claimed", [])

	if versao >= 2:
		lifetime_xp = int(config.get_value("Progression", "lifetime_xp", 0))
		level = _level_from_xp(lifetime_xp)
	else:
		_migrate_v1(config)

	profile_loaded.emit()


## Perfil v1 guardava `total_xp` como resto do nivel, sob a curva `nivel * 1000`.
## Converte para XP vitalicio pela curva antiga -- ninguem perde progresso -- e
## deixa o nivel ser recalculado pela curva nova.
func _migrate_v1(config: ConfigFile) -> void:
	var nivel_antigo := int(config.get_value("Progression", "level", 1))
	var resto := int(config.get_value("Progression", "total_xp", 0))
	var acumulado := 0
	for l in range(1, nivel_antigo):
		acumulado += l * 1000
	lifetime_xp = acumulado + resto
	level = _level_from_xp(lifetime_xp)
	_reconstruct_per_game()
	_dirty = true
	save_profile()


## v1 nao guardava estatistica por jogo, mas guardava maestria por jogo. Da para
## recuperar quem ja foi jogado a partir dela -- senao o veterano abriria a tela
## de perfil e veria 19 jogos zerados depois de meses jogando.
func _reconstruct_per_game() -> void:
	var maestria: Dictionary = stats.get("game_mastery", {})
	for game_id in maestria.keys():
		if per_game.has(game_id):
			continue
		per_game[game_id] = {
			"matches": 1, "wins": 0, "losses": 0, "best_time": 0, "best_score": 0,
		}


func _initialize_new_profile() -> void:
	level = 1
	lifetime_xp = 0
	current_streak = 0
	longest_streak = 0
	last_played_date = ""
	stats = {}
	per_game = {}
	unlocked_achievements = []
	achievement_progress = {}
	flags = []
	active_quests = {}
	claimed_rewards = []
	save_profile()
