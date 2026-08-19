class_name MemoryRules
extends RefCounted

## Rules and logic for Memoria.

const CardScript = preload("res://shared/core_engine/cards/Card.gd")

static func is_match(card1: Card, card2: Card) -> bool:
	if card1 == null or card2 == null: return false
	if card1.custom_data.has("pair_id") and card2.custom_data.has("pair_id"):
		return card1.custom_data["pair_id"] == card2.custom_data["pair_id"]
	return card1.value == card2.value

static func is_game_won(pairs_found: int, total_pairs: int) -> bool:
	return pairs_found >= total_pairs and total_pairs > 0
