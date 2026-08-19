## Base class for a board game piece.
class_name Piece
extends RefCounted

var player_id: int = 0
var piece_type: String = "standard" # "standard", "king", "ship", "peg", etc.
var state: Dictionary = {}

func _init(p_player: int = 0, p_type: String = "standard", p_state: Dictionary = {}) -> void:
	player_id = p_player
	piece_type = p_type
	state = p_state.duplicate()

func is_player(target_id: int) -> bool:
	return player_id == target_id

func is_king() -> bool:
	return piece_type == "king"

func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"piece_type": piece_type,
		"state": state.duplicate()
	}

static func from_dict(data: Dictionary) -> Piece:
	return Piece.new(
		int(data.get("player_id", 0)),
		str(data.get("piece_type", "standard")),
		data.get("state", {})
	)

func clone() -> Piece:
	return Piece.from_dict(to_dict())
