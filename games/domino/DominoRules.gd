class_name DominoRules
extends RefCounted

static func generate_boneyard_28() -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	for a in range(7):
		for b in range(a, 7):
			tiles.append({"a": a, "b": b})
	return tiles

static func can_tile_fit(tile: Dictionary, left_end: int, right_end: int) -> bool:
	if left_end == -1 or right_end == -1: return true
	return tile["a"] == left_end or tile["b"] == left_end or tile["a"] == right_end or tile["b"] == right_end

static func can_play_tile(tile: Dictionary, left_end: int, right_end: int) -> bool:
	return can_tile_fit(tile, left_end, right_end)

static func has_any_playable(hand: Array, left_end: int, right_end: int) -> bool:
	for t in hand:
		if can_tile_fit(t, left_end, right_end):
			return true
	return false

static func has_any_valid_move(hand: Array, left_end: int, right_end: int) -> bool:
	return has_any_playable(hand, left_end, right_end)

static func find_ai_move(hand: Array, left_end: int, right_end: int) -> Dictionary:
	var playable = get_playable_indices(hand, left_end, right_end)
	if playable.is_empty():
		return {}
	var idx = playable[0]
	var tile = hand[idx]
	var side = "left" if (left_end == -1 or tile["a"] == left_end or tile["b"] == left_end) else "right"
	return {"tile_index": idx, "side": side}

static func get_playable_indices(hand: Array, left_end: int, right_end: int) -> Array[int]:
	var list: Array[int] = []
	for i in range(hand.size()):
		if can_tile_fit(hand[i], left_end, right_end):
			list.append(i)
	return list

static func orient_tile_for_side(tile: Dictionary, side: String, left_end: int, right_end: int) -> Dictionary:
	var oriented = tile.duplicate()
	var new_left = left_end
	var new_right = right_end
	
	if side == "left":
		if oriented["b"] == left_end:
			new_left = oriented["a"]
		else:
			oriented = {"a": tile["b"], "b": tile["a"]}
			new_left = oriented["a"]
	else:
		if oriented["a"] == right_end:
			new_right = oriented["b"]
		else:
			oriented = {"a": tile["b"], "b": tile["a"]}
			new_right = oriented["b"]
			
	return {
		"oriented_tile": oriented,
		"new_left_end": new_left,
		"new_right_end": new_right
	}

static func calculate_hand_points(hand: Array) -> int:
	var total = 0
	for t in hand:
		total += int(t.get("a", 0)) + int(t.get("b", 0))
	return total
