extends Node

## Ponte com o Google Play Games Services v2.
##
## Do lado do Android quem fala com o SDK e o plugin `PlayTablePGS`
## (`android/pgs/`, compilado junto com o build customizado). Aqui fica so a
## politica: o que enviar, quando, e o que fazer quando nao da para enviar.
##
## Tres regras que a versao anterior nao tinha e por isso nada funcionava:
##
## 1. **Nao inventar id.** O Play Console gera ids opacos (`CgkI...EAQ`). O
##    codigo anterior caia num fallback que mandava a chave interna crua
##    ("ACH_FIRST_BLOOD") -- o servidor rejeita em silencio e o jogo acha que
##    deu certo. Aqui, id nao mapeado em `play_games_ids.json` nao e enviado, e
##    aparece no relatorio de diagnostico.
##
## 2. **Fila offline.** Conquista fechada no aviao tem que chegar no Play Games
##    quando a rede voltar. A fila e persistida em disco: fechar o app nao
##    perde nada.
##
## 3. **Degradar sem mentir.** Fora do Android (desktop, F-Droid, web) a
##    integracao simplesmente nao existe -- o jogo inteiro continua funcionando
##    porque a gamificacao e local. `is_available()` diz a verdade e a UI
##    esconde o que nao da para mostrar.

signal user_authenticated(player_id: String, player_name: String)
signal authentication_failed(error_message: String)
signal achievement_synced(achievement_id: String, ok: bool)
signal score_submitted(leaderboard_id: String, score: int)

const SINGLETON_NAME := "PlayTablePGS"
const IDS_PATH := "res://core/configs/play_games_ids.json"
const QUEUE_PATH := "user://pgs_queue.json"
const QUEUE_MAX := 256

var _plugin: Object = null
var _ids: Dictionary = {}
var _logged_in: bool = false
var _player_id: String = ""
var _player_name: String = ""
var _queue: Array = []
var _unmapped: Dictionary = {}


func _ready() -> void:
	_load_ids()
	_load_queue()
	_init_plugin()

	if GameEventBus:
		GameEventBus.achievement_unlocked.connect(_on_achievement_unlocked)
		GameEventBus.achievement_progressed.connect(_on_achievement_progressed)
		GameEventBus.score_updated.connect(_on_score_updated)
		GameEventBus.player_leveled_up.connect(_on_player_leveled_up)
		GameEventBus.match_completed.connect(_on_match_completed)
		GameEventBus.quest_completed.connect(_on_quest_completed)

	if is_available():
		# PGS v2 faz login automatico na abertura; o plugin so repassa o
		# resultado. Nao ha botao de "entrar" obrigatorio.
		_plugin.signInSilently()


# --------------------------------------------------------------- inicializacao

func _load_ids() -> void:
	if not FileAccess.file_exists(IDS_PATH):
		push_warning("PlayGamesManager: %s ausente; PGS ficara inerte." % IDS_PATH)
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(IDS_PATH)) != OK:
		push_error("PlayGamesManager: mapa de ids invalido (%s)" % json.get_error_message())
		return
	_ids = json.data


func _init_plugin() -> void:
	if not is_android():
		return
	if not Engine.has_singleton(SINGLETON_NAME):
		push_warning("PlayGamesManager: plugin %s ausente no APK." % SINGLETON_NAME)
		return
	_plugin = Engine.get_singleton(SINGLETON_NAME)
	_plugin.connect("pgs_signed_in", _on_plugin_signed_in)
	_plugin.connect("pgs_sign_in_failed", _on_plugin_sign_in_failed)
	_plugin.connect("pgs_achievement_result", _on_plugin_achievement_result)
	_plugin.connect("pgs_score_result", _on_plugin_score_result)


func is_android() -> bool:
	return OS.get_name() == "Android"


## Verdadeiro so quando o plugin existe de fato neste APK.
func is_available() -> bool:
	return _plugin != null


func is_logged_in() -> bool:
	return _logged_in


func player_name() -> String:
	return _player_name


## O Sidekick exige Android 13 (API 33) e aparelho com folga de memoria. Sem os
## dois, o overlay simplesmente nao abre -- e a UI do jogo nao deve prometer.
func is_sidekick_supported() -> bool:
	if not is_available():
		return false
	return _plugin.isSidekickSupported()


# ------------------------------------------------------------------- mapeamento

## Traduz chave interna -> id do Play Console. Vazio significa "nao mapeado".
func _map(kind: String, key: String) -> String:
	var tabela: Dictionary = _ids.get(kind, {})
	var id := str(tabela.get(key, ""))
	if id == "" and not _unmapped.has(kind + "/" + key):
		_unmapped[kind + "/" + key] = true
	return id


## Chaves que o jogo usa mas o Play Console ainda nao tem. Usado pelo relatorio
## de diagnostico e pelos testes -- e o que impede a integracao de "funcionar"
## mandando lixo.
func unmapped_keys() -> Array:
	return _unmapped.keys()


func mapped_count(kind: String) -> int:
	var n := 0
	for k in _ids.get(kind, {}).keys():
		if str(_ids[kind][k]) != "":
			n += 1
	return n


# ---------------------------------------------------------------- eventos do jogo

func _on_achievement_unlocked(internal_id: String) -> void:
	unlock_achievement(internal_id)


func _on_achievement_progressed(internal_id: String, current: int, target: int) -> void:
	# Conquista incremental do Play Console guarda passos; enviar o valor
	# absoluto evita divergir quando a fila offline reordena.
	set_achievement_steps(internal_id, current, target)


func _on_score_updated(game_id: String, score: int) -> void:
	var chave := _leaderboard_for_game(game_id)
	if chave != "":
		submit_score(chave, score)


func _on_player_leveled_up(_new_level: int) -> void:
	submit_event("EV_LEVEL_UP", 1)
	submit_score("LB_TOTAL_XP", PlayerProfile.lifetime_xp)


func _on_match_completed(_game_id: String, result: Dictionary) -> void:
	submit_event("EV_MATCH_PLAYED", 1)
	if bool(result.get("win", false)):
		submit_event("EV_MATCH_WON", 1)
		submit_score("LB_TOTAL_WINS", int(PlayerProfile.get_stat("total_wins", 0)))
	submit_score("LB_TOTAL_XP", PlayerProfile.lifetime_xp)
	submit_score("LB_STREAK", PlayerProfile.current_streak)
	if LeagueSystem:
		submit_score("LB_ELO", LeagueSystem.current_elo)


func _on_quest_completed(_quest_id: String) -> void:
	submit_event("EV_QUEST_DONE", 1)


## Placar especifico de um jogo, quando existe.
func _leaderboard_for_game(game_id: String) -> String:
	match game_id:
		"campo_minado": return "LB_MINESWEEPER_TIME"
		"memoria": return "LB_MEMORY_MOVES"
		"hanoi": return "LB_HANOI_MOVES"
		"poker": return "LB_POKER_BANKROLL"
		"solitario": return "LB_SOLITAIRE_PEGS"
		_: return ""


# ----------------------------------------------------------------------- envio

func unlock_achievement(internal_id: String) -> void:
	var id := _map("achievements", internal_id)
	if id == "":
		return
	_send({"op": "unlock", "id": id, "key": internal_id})


func set_achievement_steps(internal_id: String, steps: int, target: int) -> void:
	var id := _map("achievements", internal_id)
	if id == "" or target <= 1:
		return
	_send({"op": "steps", "id": id, "key": internal_id, "steps": steps})


func submit_score(internal_key: String, score: int) -> void:
	var id := _map("leaderboards", internal_key)
	if id == "" or score <= 0:
		return
	_send({"op": "score", "id": id, "key": internal_key, "score": score})


func submit_event(internal_key: String, amount: int = 1) -> void:
	var id := _map("events", internal_key)
	if id == "" or amount <= 0:
		return
	_send({"op": "event", "id": id, "key": internal_key, "amount": amount})


## Envia agora se der; senao guarda para quando o login chegar.
func _send(item: Dictionary) -> void:
	if not is_available() or not _logged_in:
		_enqueue(item)
		return
	_dispatch(item)


func _dispatch(item: Dictionary) -> void:
	match str(item["op"]):
		"unlock":
			_plugin.unlockAchievement(str(item["id"]))
		"steps":
			_plugin.setAchievementSteps(str(item["id"]), int(item["steps"]))
		"score":
			_plugin.submitScore(str(item["id"]), int(item["score"]))
			score_submitted.emit(str(item["id"]), int(item["score"]))
		"event":
			_plugin.submitEvent(str(item["id"]), int(item["amount"]))


# ------------------------------------------------------------------ fila offline

func _enqueue(item: Dictionary) -> void:
	# Colapsa repeticao: dez partidas offline viram um placar com o maior valor
	# e um evento com a soma, nao vinte entradas.
	for existente in _queue:
		if existente["op"] != item["op"] or existente["id"] != item["id"]:
			continue
		match str(item["op"]):
			"unlock":
				return
			"steps":
				existente["steps"] = maxi(int(existente["steps"]), int(item["steps"]))
				return
			"score":
				existente["score"] = maxi(int(existente["score"]), int(item["score"]))
				return
			"event":
				existente["amount"] = int(existente["amount"]) + int(item["amount"])
				return

	_queue.append(item)
	if _queue.size() > QUEUE_MAX:
		_queue = _queue.slice(_queue.size() - QUEUE_MAX)
	_save_queue()


func _flush_queue() -> void:
	if _queue.is_empty() or not is_available() or not _logged_in:
		return
	var pendentes := _queue.duplicate(true)
	_queue.clear()
	_save_queue()
	for item in pendentes:
		_dispatch(item)
	if GameEventBus:
		GameEventBus.pgs_sync_finished.emit(true, "fila enviada: %d" % pendentes.size())


func queued_count() -> int:
	return _queue.size()


func _save_queue() -> void:
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_queue))


func _load_queue() -> void:
	if not FileAccess.file_exists(QUEUE_PATH):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(QUEUE_PATH)) == OK and json.data is Array:
		_queue = json.data


# ------------------------------------------------------------------- paineis

func show_achievements() -> void:
	if is_available() and _logged_in:
		_plugin.showAchievements()


func show_leaderboard(internal_key: String) -> void:
	var id := _map("leaderboards", internal_key)
	if is_available() and _logged_in and id != "":
		_plugin.showLeaderboard(id)


func show_all_leaderboards() -> void:
	if is_available() and _logged_in:
		_plugin.showAllLeaderboards()


func sign_in_interactive() -> void:
	if is_available():
		_plugin.signIn()


# ------------------------------------------------------------ retorno do plugin

func _on_plugin_signed_in(player_id: String, player_name_in: String) -> void:
	_logged_in = true
	_player_id = player_id
	_player_name = player_name_in
	user_authenticated.emit(player_id, player_name_in)
	if GameEventBus:
		GameEventBus.pgs_sign_in_changed.emit(true, player_name_in)
	_flush_queue()
	if CloudSaveSync:
		CloudSaveSync.on_signed_in()


func _on_plugin_sign_in_failed(message: String) -> void:
	_logged_in = false
	authentication_failed.emit(message)
	if GameEventBus:
		GameEventBus.pgs_sign_in_changed.emit(false, "")


func _on_plugin_achievement_result(id: String, ok: bool) -> void:
	achievement_synced.emit(id, ok)


func _on_plugin_score_result(id: String, ok: bool) -> void:
	if not ok:
		push_warning("PlayGamesManager: placar %s recusado pelo servidor." % id)


# --------------------------------------------------------------- diagnostico

## Estado da integracao em uma linha por item. A tela de perfil mostra isto no
## modo desenvolvedor, e o teste de fumaca compara com o esperado.
func diagnostics() -> Dictionary:
	return {
		"android": is_android(),
		"plugin": is_available(),
		"logged_in": _logged_in,
		"player": _player_name,
		"app_id": str(_ids.get("app_id", "")),
		"achievements_mapped": mapped_count("achievements"),
		"achievements_total": _ids.get("achievements", {}).size(),
		"leaderboards_mapped": mapped_count("leaderboards"),
		"events_mapped": mapped_count("events"),
		"queued": _queue.size(),
		"unmapped_seen": _unmapped.size(),
	}
