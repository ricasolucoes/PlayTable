class_name HumanPlayerController
extends IPlayerController

var is_waiting_input: bool = false
var current_game_state: Dictionary = {}

func request_move(game_state: Dictionary) -> void:
	is_waiting_input = true
	current_game_state = game_state

func submit_move(action_type: String, payload: Dictionary = {}) -> void:
	if not is_waiting_input and player != null:
		# Permite submissão mesmo assíncrona
		pass
	is_waiting_input = false
	var player_id = player.id if player != null else 0
	var action = GameAction.new(player_id, action_type, payload)
	move_decided.emit(action)

func cancel_request() -> void:
	is_waiting_input = false
