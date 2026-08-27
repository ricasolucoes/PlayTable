class_name DominoRules
extends RefCounted

## Rules and logic for Domino.

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

## A jogada mais forte que a IA sabe jogar. Quem escolhe e a `DominoAI`.
##
## O que morava aqui devolvia `playable[0]` -- a primeira pedra jogavel na
## ordem em que ela caiu na mao -- e sempre a ponta esquerda quando a pedra
## batia com ela, mesmo que a direita valesse muito mais. Nada de peso da
## pedra, nada de flexibilidade, nada do que os passes do adversario
## denunciavam.
static func find_ai_move(hand: Array, left_end: int, right_end: int,
		memoria: Dictionary = {}, level: int = 10) -> Dictionary:
	var mem := memoria if memoria.has("vazios") else DominoAI.nova_memoria()
	return DominoAI.escolher(hand, left_end, right_end, mem, level)

static func get_playable_indices(hand: Array, left_end: int, right_end: int) -> Array[int]:
	var list: Array[int] = []
	for i in range(hand.size()):
		if can_tile_fit(hand[i], left_end, right_end):
			list.append(i)
	return list

static func orient_tile_for_side(tile: Dictionary, side: String, left_end: int, right_end: int) -> Dictionary:
	var oriented := tile.duplicate()
	var new_left := left_end
	var new_right := right_end
	
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
	var total: int = 0
	for t in hand:
		total += int(t.get("a", 0)) + int(t.get("b", 0))
	return total
