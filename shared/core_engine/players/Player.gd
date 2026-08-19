class_name Player
extends RefCounted

enum PlayerType {
	HUMAN_LOCAL = 0,
	AI = 1,
	REMOTE_ONLINE = 2
}

var id: int = 0
var name: String = ""
var type: PlayerType = PlayerType.HUMAN_LOCAL
var score: int = 0
var custom_data: Dictionary = {}

func _init(p_id: int = 0, p_name: String = "", p_type: PlayerType = PlayerType.HUMAN_LOCAL, p_custom: Dictionary = {}):
	id = p_id
	name = p_name
	type = p_type
	custom_data = p_custom.duplicate(true)

func is_human() -> bool:
	return type == PlayerType.HUMAN_LOCAL

func is_ai() -> bool:
	return type == PlayerType.AI

func is_remote() -> bool:
	return type == PlayerType.REMOTE_ONLINE

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": int(type),
		"score": score,
		"custom_data": custom_data.duplicate(true)
	}

static func from_dict(data: Dictionary) -> Player:
	var p = Player.new(
		int(data.get("id", 0)),
		str(data.get("name", "")),
		data.get("type", PlayerType.HUMAN_LOCAL) as PlayerType,
		data.get("custom_data", {})
	)
	p.score = int(data.get("score", 0))
	return p
