extends Node

## Autoload `GameEventBus` (CONTRACTS.md §4.5): os jogos publicam fatos
## ("a partida acabou e o jogador venceu"); gamificação, HUD, som e loja
## reagem. Nenhum jogo conhece XP ou conquista; nenhuma engine conhece regra
## de jogo.
##
## Extraído de PlayTable `core/services/GameEventBus.gd` (sinais de partida e
## progressão, helpers `emit_*`), TWFS `client/autoload/events.gd` (contrato do
## `toast_requested`, `net_online/offline`) e VOLTA `src/core/event_bus.gd`
## (limitador que avisa emissão por quadro em debug). Tirados: os sinais de
## gamificação específicos do PlayTable (missão, liga, maestria, Play Games)
## — cada jogo declara os seus no próprio bus ou estende este.

signal match_started(game_id: String, mode: String)
## `result`: dicionário de `JogosMatchResult.to_dict()` — `win` obrigatório.
signal match_completed(game_id: String, result: Dictionary)
signal score_updated(game_id: String, score: int)
signal xp_gained(amount: int, source: String)
signal level_up(new_level: int)
signal achievement_unlocked(achievement_id: String)
signal item_collected(item_id: String, amount: int)
## `{tone: "success"|"warning"|"danger"|"reward", title_key, detail_key?, args?}`
signal toast_requested(payload: Dictionary)
signal net_online
signal net_offline
signal locale_changed(locale: String)
signal settings_changed(key: String, value: Variant)
signal identity_changed(signed_in: bool, player_name: String)

## Este barramento é para eventos raros. Emitir por quadro é bug, e em debug
## ele avisa em vez de deixar passar.
const MAX_EMISSIONS_PER_SECOND: int = 5

var _emission_timestamps: Dictionary = {}


func emit_match_started(game_id: String, mode: String = "solo") -> void:
	_track_emission("match_started")
	match_started.emit(game_id, mode)


func emit_match_completed(game_id: String, result: Dictionary) -> void:
	_track_emission("match_completed")
	if not result.has("win"):
		JogosLocator.log("warn", "events", "match_result_without_win", {"game_id": game_id})
	match_completed.emit(game_id, result)


func emit_score(game_id: String, score: int) -> void:
	score_updated.emit(game_id, score)


func emit_xp_gained(amount: int, source: String) -> void:
	_track_emission("xp_gained")
	xp_gained.emit(amount, source)


func emit_level_up(new_level: int) -> void:
	_track_emission("level_up")
	level_up.emit(new_level)


func emit_achievement_unlocked(achievement_id: String) -> void:
	_track_emission("achievement_unlocked")
	achievement_unlocked.emit(achievement_id)


func emit_item_collected(item_id: String, amount: int = 1) -> void:
	item_collected.emit(item_id, amount)


func emit_toast(tone: String, title_key: String, detail_key: String = "", args: Dictionary = {}) -> void:
	_track_emission("toast_requested")
	var payload: Dictionary = {"tone": tone, "title_key": title_key}
	if not detail_key.is_empty():
		payload["detail_key"] = detail_key
	if not args.is_empty():
		payload["args"] = args
	toast_requested.emit(payload)


func emit_net_state(online: bool) -> void:
	if online:
		net_online.emit()
	else:
		net_offline.emit()


func emit_locale_changed(locale: String) -> void:
	locale_changed.emit(locale)


func emit_identity_changed(signed_in: bool, player_name: String) -> void:
	identity_changed.emit(signed_in, player_name)


func get_recent_emission_count(signal_name: String) -> int:
	return (_emission_timestamps.get(signal_name, []) as Array).size()


func _track_emission(signal_name: String) -> void:
	if not JogosBuild.is_debug():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var timestamps: Array = _emission_timestamps.get(signal_name, [])
	timestamps.append(now)
	timestamps = timestamps.filter(func(t: float) -> bool: return now - t <= 1.0)
	_emission_timestamps[signal_name] = timestamps
	if timestamps.size() > MAX_EMISSIONS_PER_SECOND:
		JogosLocator.log("warn", "events", "event_bus_rate_exceeded", {"signal": signal_name, "count": timestamps.size()})
