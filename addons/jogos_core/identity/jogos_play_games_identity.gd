class_name JogosPlayGamesIdentity
extends JogosIdentityPort

## Adaptador Play Games Services v2 (Android). Delega ao plugin registrado
## como singleton da engine (`PlayTablePGS` no PlayTable; nome configurável)
## e só existe de verdade quando `Engine.has_singleton` confirma. Sem plugin:
## `is_available() == false` e o jogo segue local.
##
## Fonte: PlayTable/core/services/PlayGamesManager.gd (nomes dos métodos e
## sinais da ponte Java: signInSilently/signIn/unlockAchievement/submitScore/
## submitEvent/showAchievements/showLeaderboard; pgs_signed_in/
## pgs_sign_in_failed). Tirado: o mapa `play_games_ids.json` e a fila — os
## dois moram no autoload `Identity`, comuns a todos os provedores.

var singleton_name: String = "PlayTablePGS"
var _plugin: Object = null
var _signed_in: bool = false
var _player_id: String = ""
var _player_name: String = ""


func _init(plugin_singleton: String = "PlayTablePGS") -> void:
	singleton_name = plugin_singleton
	if OS.get_name() == "Android" and Engine.has_singleton(singleton_name):
		_plugin = Engine.get_singleton(singleton_name)
		_connect_if(_plugin, "pgs_signed_in", _on_signed_in)
		_connect_if(_plugin, "pgs_sign_in_failed", _on_sign_in_failed)


func provider_name() -> String:
	return "play_games"


func is_available() -> bool:
	return _plugin != null


func is_signed_in() -> bool:
	return _signed_in


func sign_in_silent() -> void:
	if _plugin != null and _plugin.has_method("signInSilently"):
		_plugin.call("signInSilently")


func sign_in() -> void:
	if _plugin != null and _plugin.has_method("signIn"):
		_plugin.call("signIn")


func sign_out() -> void:
	# PGS v2 não tem sign-out por app: a conta é do aparelho.
	pass


func player_id() -> String:
	return _player_id


func player_name() -> String:
	return _player_name


func unlock_achievement(achievement_id: String) -> bool:
	return _call("unlockAchievement", [achievement_id])


func increment_achievement(achievement_id: String, steps: int) -> bool:
	return _call("incrementAchievement", [achievement_id, steps])


func submit_score(board_id: String, value: int) -> bool:
	return _call("submitScore", [board_id, value])


func submit_event(event_id: String, amount: int) -> bool:
	return _call("submitEvent", [event_id, amount])


func show_leaderboard(board_id: String) -> bool:
	return _call("showLeaderboard", [board_id])


func show_achievements() -> bool:
	return _call("showAchievements", [])


func _call(method: String, args: Array) -> bool:
	if _plugin == null or not _signed_in or not _plugin.has_method(method):
		return false
	_plugin.callv(method, args)
	return true


func _on_signed_in(id: String, name: String) -> void:
	_signed_in = true
	_player_id = id
	_player_name = name
	signed_in_changed.emit(true, name)


func _on_sign_in_failed(_reason: String) -> void:
	_signed_in = false
	signed_in_changed.emit(false, "")


func _connect_if(obj: Object, signal_name: String, fn: Callable) -> void:
	if obj != null and obj.has_signal(signal_name) and not obj.is_connected(signal_name, fn):
		obj.connect(signal_name, fn)
