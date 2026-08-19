## Controller for remote players.
class_name RemotePlayerController
extends IPlayerController

var is_waiting_remote: bool = false

func request_move(game_state: Dictionary) -> void:
	is_waiting_remote = true

func receive_remote_action(action: GameAction) -> void:
	is_waiting_remote = false
	move_decided.emit(action)

func receive_json(json_str: String) -> void:
	var action = GameAction.from_json(json_str)
	if action != null:
		receive_remote_action(action)

func cancel_request() -> void:
	is_waiting_remote = false
