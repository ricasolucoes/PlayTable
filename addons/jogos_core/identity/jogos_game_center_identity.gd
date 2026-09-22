class_name JogosGameCenterIdentity
extends JogosIdentityPort

## Adaptador Game Center (iOS) sobre o plugin oficial do Godot
## (`Engine.get_singleton("GameCenter")`: authenticate, award_achievement,
## post_score, show_game_center, is_authenticated, eventos pendentes).
## Só existe quando o singleton está no build; fora dele, indisponível.
##
## Fonte: Woof Honey/docs/STACK.md (Game Center como porta iOS; PGS não roda
## no iPhone). Esqueleto: a verificação de assinatura para o servidor
## (`request_identity_verification_signature`) fica para quando houver
## servidor.

var singleton_name: String = "GameCenter"
var _plugin: Object = null
var _signed_in: bool = false
var _player_id: String = ""
var _player_name: String = ""


func _init(plugin_singleton: String = "GameCenter") -> void:
	singleton_name = plugin_singleton
	if OS.get_name() == "iOS" and Engine.has_singleton(singleton_name):
		_plugin = Engine.get_singleton(singleton_name)


func provider_name() -> String:
	return "game_center"


func is_available() -> bool:
	return _plugin != null


func is_signed_in() -> bool:
	return _signed_in


func sign_in_silent() -> void:
	sign_in()


func sign_in() -> void:
	if _plugin == null or not _plugin.has_method("authenticate"):
		return
	_plugin.call("authenticate")
	poll_events()


## O plugin do Game Center entrega resultados por fila, não por sinal: o jogo
## chama isto por quadro (ou por timer) enquanto há evento pendente.
func poll_events() -> void:
	if _plugin == null or not _plugin.has_method("get_pending_event_count"):
		return
	while int(_plugin.call("get_pending_event_count")) > 0:
		var event: Variant = _plugin.call("pop_pending_event")
		if not (event is Dictionary):
			continue
		var d: Dictionary = event as Dictionary
		if String(d.get("type", "")) == "authentication":
			var ok: bool = String(d.get("result", "")) == "ok"
			_signed_in = ok
			_player_id = String(d.get("player_id", "")) if ok else ""
			_player_name = String(d.get("alias", "")) if ok else ""
			signed_in_changed.emit(ok, _player_name)


func sign_out() -> void:
	pass


func player_id() -> String:
	return _player_id


func player_name() -> String:
	return _player_name


func unlock_achievement(achievement_id: String) -> bool:
	return _call("award_achievement", [{"name": achievement_id, "progress": 100.0}])


func increment_achievement(achievement_id: String, steps: int) -> bool:
	return _call("award_achievement", [{"name": achievement_id, "progress": float(steps)}])


func submit_score(board_id: String, value: int) -> bool:
	return _call("post_score", [{"score": value, "category": board_id}])


func submit_event(_event_id: String, _amount: int) -> bool:
	return _signed_in


func show_leaderboard(board_id: String) -> bool:
	return _call("show_game_center", [{"view": "leaderboards", "leaderboard_name": board_id}])


func show_achievements() -> bool:
	return _call("show_game_center", [{"view": "achievements"}])


func _call(method: String, args: Array) -> bool:
	if _plugin == null or not _signed_in or not _plugin.has_method(method):
		return false
	_plugin.callv(method, args)
	return true
