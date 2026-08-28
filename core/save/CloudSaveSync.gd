extends Node

## Sincronizacao do perfil com o Saved Games do Play Games.
##
## Um jogador que troca de aparelho nao pode perder trezentas partidas de
## progresso. O snapshot carrega o perfil inteiro em JSON.
##
## Conflito acontece de verdade: dois aparelhos offline no mesmo dia. A
## resolucao aqui e *merge*, nao "escolhe um e joga o outro fora" -- para
## contador vale o maior, para conjunto (conquistas, flags, itens) vale a
## uniao. Ninguem perde uma conquista por ter jogado no tablet.

signal cloud_save_loaded(success: bool)
signal cloud_save_saved(success: bool)
signal sync_conflict_resolved()

const SNAPSHOT_NAME := "PlayTable_Progress"
## Descricao do slot, que o seletor de jogos salvos do Play Games mostra ao
## jogador -- por isso e chave, e a traducao e lida na hora de salvar.
const SAVE_DESCRIPTION := "CLOUD_SAVE_DESCRIPTION"
const SCHEMA := 2

var _plugin: Object = null
var _sync_pendente: bool = false


func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton(PlayGamesManager.SINGLETON_NAME):
		return
	_plugin = Engine.get_singleton(PlayGamesManager.SINGLETON_NAME)
	_plugin.connect("pgs_snapshot_loaded", _on_snapshot_loaded)
	_plugin.connect("pgs_snapshot_saved", _on_snapshot_saved)
	_plugin.connect("pgs_snapshot_conflict", _on_snapshot_conflict)

	if GameEventBus:
		# Salvar a cada partida seria abusivo com a cota do Saved Games; salvar
		# so ao fechar o app perde progresso quando o sistema mata o processo.
		# O meio-termo: marca pendente e grava quando o app perde o foco.
		GameEventBus.match_completed.connect(_on_match_completed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _sync_pendente:
			save_to_cloud()


func _on_match_completed(_game_id: String, _result: Dictionary) -> void:
	_sync_pendente = true


func is_available() -> bool:
	return _plugin != null and PlayGamesManager.is_logged_in()


## Chamado pelo PlayGamesManager assim que o login resolve: puxa a nuvem antes
## de sobrescrever, senao o aparelho novo publicaria um perfil zerado.
func on_signed_in() -> void:
	load_from_cloud()


# ------------------------------------------------------------------ serializacao

func serialize_profile() -> Dictionary:
	return {
		"schema": SCHEMA,
		"saved_at": int(Time.get_unix_time_from_system()),
		"lifetime_xp": PlayerProfile.lifetime_xp,
		"level": PlayerProfile.level,
		"current_streak": PlayerProfile.current_streak,
		"longest_streak": PlayerProfile.longest_streak,
		"last_played_date": PlayerProfile.last_played_date,
		"stats": PlayerProfile.stats,
		"per_game": PlayerProfile.per_game,
		"achievements": PlayerProfile.unlocked_achievements,
		"achievement_progress": PlayerProfile.achievement_progress,
		"flags": PlayerProfile.flags,
		"claimed": PlayerProfile.claimed_rewards,
	}


## Aplica um perfil vindo da nuvem sobre o local, sempre por merge.
func apply_remote(remoto: Dictionary) -> void:
	if int(remoto.get("schema", 0)) <= 0:
		return

	PlayerProfile.lifetime_xp = maxi(PlayerProfile.lifetime_xp, int(remoto.get("lifetime_xp", 0)))
	PlayerProfile.longest_streak = maxi(PlayerProfile.longest_streak, int(remoto.get("longest_streak", 0)))

	# Streak diaria segue a data mais recente, nao o maior numero: um aparelho
	# parado ha uma semana nao deve ressuscitar uma sequencia ja quebrada.
	var data_remota := str(remoto.get("last_played_date", ""))
	if PlayerProfile.days_between(PlayerProfile.last_played_date, data_remota) > 0:
		PlayerProfile.last_played_date = data_remota
		PlayerProfile.current_streak = int(remoto.get("current_streak", PlayerProfile.current_streak))

	_merge_contadores(remoto.get("stats", {}))
	_merge_per_game(remoto.get("per_game", {}))
	_merge_conjunto(PlayerProfile.unlocked_achievements, remoto.get("achievements", []))
	_merge_conjunto(PlayerProfile.flags, remoto.get("flags", []))
	_merge_conjunto(PlayerProfile.claimed_rewards, remoto.get("claimed", []))

	for id in remoto.get("achievement_progress", {}).keys():
		PlayerProfile.achievement_progress[id] = maxi(
			int(PlayerProfile.achievement_progress.get(id, 0)),
			int(remoto["achievement_progress"][id]))

	PlayerProfile.level = PlayerProfile._level_from_xp(PlayerProfile.lifetime_xp)
	PlayerProfile.save_profile()
	if CollectionSystem:
		CollectionSystem.evaluate_unlocks()


## Contador acumulado: vale o maior dos dois. Chave de texto (data, liga, item
## equipado) fica com a local -- somar nao faz sentido e a local e a que o
## jogador acabou de ver na tela.
func _merge_contadores(remotos: Dictionary) -> void:
	for chave in remotos.keys():
		var valor = remotos[chave]
		if valor is float or valor is int:
			PlayerProfile.stats[chave] = maxi(int(PlayerProfile.get_stat(chave, 0)), int(valor))
		elif valor is Array and not PlayerProfile.stats.has(chave):
			PlayerProfile.stats[chave] = valor
		elif not PlayerProfile.stats.has(chave):
			PlayerProfile.stats[chave] = valor


func _merge_per_game(remotos: Dictionary) -> void:
	for game_id in remotos.keys():
		var r: Dictionary = remotos[game_id]
		var l := PlayerProfile.game_stats(game_id)
		for chave in ["matches", "wins", "losses", "best_score"]:
			l[chave] = maxi(int(l.get(chave, 0)), int(r.get(chave, 0)))
		# Recorde onde menor e melhor: zero significa "sem recorde".
		for chave in ["best_time", "best_moves"]:
			var a := int(l.get(chave, 0))
			var b := int(r.get(chave, 0))
			l[chave] = b if a == 0 else (a if b == 0 else mini(a, b))


static func _merge_conjunto(local: Array, remoto: Variant) -> void:
	if not remoto is Array:
		return
	for item in remoto:
		if not local.has(item):
			local.append(item)


# ------------------------------------------------------------------- transporte

func save_to_cloud() -> void:
	if not is_available():
		return
	_sync_pendente = false
	var dados := JSON.stringify(serialize_profile()).to_utf8_buffer()
	_plugin.saveSnapshot(SNAPSHOT_NAME, tr(SAVE_DESCRIPTION), Marshalls.raw_to_base64(dados))


func load_from_cloud() -> void:
	if not is_available():
		return
	_plugin.loadSnapshot(SNAPSHOT_NAME)


func _decode(base64: String) -> Dictionary:
	if base64 == "":
		return {}
	var bytes := Marshalls.base64_to_raw(base64)
	if bytes.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {}
	return json.data


func _on_snapshot_loaded(base64: String) -> void:
	var remoto := _decode(base64)
	if remoto.is_empty():
		cloud_save_loaded.emit(false)
		# Primeiro login neste aparelho e nuvem vazia: publica o local.
		save_to_cloud()
		return
	apply_remote(remoto)
	cloud_save_loaded.emit(true)
	if GameEventBus:
		GameEventBus.pgs_sync_finished.emit(true, "perfil restaurado da nuvem")


func _on_snapshot_saved(ok: bool, message: String) -> void:
	cloud_save_saved.emit(ok)
	if not ok:
		push_warning("CloudSaveSync: falha ao gravar snapshot -- %s" % message)


func _on_snapshot_conflict(conflict_id: String, base64_local: String, base64_server: String) -> void:
	# Aplica os dois lados sobre o perfil e reenvia o resultado do merge: e o
	# unico desfecho em que nenhum dos aparelhos perde o que fez.
	apply_remote(_decode(base64_local))
	apply_remote(_decode(base64_server))
	var resolvido := JSON.stringify(serialize_profile()).to_utf8_buffer()
	_plugin.resolveSnapshotConflict(conflict_id, Marshalls.raw_to_base64(resolvido))
	sync_conflict_resolved.emit()
