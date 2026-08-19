## Represents a game action or move.
class_name GameAction
extends RefCounted

var player_id: int = 0
var action_type: String = "" # Ex: "drop_piece", "play_card", "fire_shot", "jump_peg", "move_checker", "draw_tile"
var payload: Dictionary = {}
var timestamp: float = 0.0

func _init(p_player_id: int = 0, p_type: String = "", p_payload: Dictionary = {}, p_timestamp: float = 0.0) -> void:
	player_id = p_player_id
	action_type = p_type
	payload = p_payload.duplicate(true)
	timestamp = p_timestamp if p_timestamp > 0.0 else Time.get_unix_time_from_system()

func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"action_type": action_type,
		"payload": payload.duplicate(true),
		"timestamp": timestamp
	}

static func from_dict(data: Dictionary) -> GameAction:
	return GameAction.new(
		int(data.get("player_id", 0)),
		str(data.get("action_type", "")),
		data.get("payload", {}),
		float(data.get("timestamp", 0.0))
	)

func to_json() -> String:
	return JSON.stringify(to_dict())

static func from_json(json_str: String) -> GameAction:
	var json = JSON.new()
	var err = json.parse(json_str)
	if err == OK and json.data is Dictionary:
		return from_dict(json.data)
	return null
