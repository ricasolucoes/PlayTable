class_name JogosStubIdentity
extends JogosIdentityPort

## Provedor de identidade para editor, desktop e GUT. Por padrão indisponível
## (o jogo roda 100% local); os testes ligam `set_available(true)` e leem o
## que foi entregue em `unlocked`, `increments`, `scores`, `events`.

var _available: bool = false
var _signed_in: bool = false
var _name: String = "Dev Player"
var unlocked: Array[String] = []
var increments: Dictionary = {}
var scores: Dictionary = {}
var events: Dictionary = {}


func provider_name() -> String:
	return "stub"


func set_available(available: bool) -> void:
	_available = available
	if not available and _signed_in:
		_signed_in = false
		signed_in_changed.emit(false, "")


func is_available() -> bool:
	return _available


func is_signed_in() -> bool:
	return _signed_in


func sign_in_silent() -> void:
	sign_in()


func sign_in() -> void:
	if not _available or _signed_in:
		return
	_signed_in = true
	signed_in_changed.emit(true, _name)


func sign_out() -> void:
	if not _signed_in:
		return
	_signed_in = false
	signed_in_changed.emit(false, "")


func player_id() -> String:
	return "stub-player" if _signed_in else ""


func player_name() -> String:
	return _name if _signed_in else ""


func unlock_achievement(achievement_id: String) -> bool:
	if not _signed_in:
		return false
	if not unlocked.has(achievement_id):
		unlocked.append(achievement_id)
	return true


func increment_achievement(achievement_id: String, steps: int) -> bool:
	if not _signed_in:
		return false
	increments[achievement_id] = int(increments.get(achievement_id, 0)) + steps
	return true


func submit_score(board_id: String, value: int) -> bool:
	if not _signed_in:
		return false
	scores[board_id] = maxi(int(scores.get(board_id, 0)), value)
	return true


func submit_event(event_id: String, amount: int) -> bool:
	if not _signed_in:
		return false
	events[event_id] = int(events.get(event_id, 0)) + amount
	return true


func show_leaderboard(_board_id: String) -> bool:
	return _signed_in


func show_achievements() -> bool:
	return _signed_in
