class_name UnoRules
extends RefCounted

const CardScript = preload("res://shared/core_engine/cards/Card.gd")

static func is_valid_play(card: Card, active_color: Card.ColorType, top_card: Card) -> bool:
	if card == null: return false
	if card.color_type == Card.ColorType.WILD:
		return true
	if card.color_type == active_color:
		return true
	if top_card != null:
		if card.card_type == top_card.card_type and card.value == top_card.value:
			return true
	return false

static func get_playable_cards(hand_cards: Array, active_color: Card.ColorType, top_card: Card) -> Array[int]:
	var indices: Array[int] = []
	for i in range(hand_cards.size()):
		var c = hand_cards[i]
		if is_valid_play(c, active_color, top_card):
			indices.append(i)
	return indices

static func pick_best_color_for_hand(hand_cards: Array) -> Card.ColorType:
	var counts = {
		Card.ColorType.RED: 0,
		Card.ColorType.BLUE: 0,
		Card.ColorType.GREEN: 0,
		Card.ColorType.YELLOW: 0
	}
	for c in hand_cards:
		if c is Card and counts.has(c.color_type):
			counts[c.color_type] += 1
			
	var best_color = Card.ColorType.RED
	var max_count = -1
	for col in counts:
		if counts[col] > max_count:
			max_count = counts[col]
			best_color = col
	return best_color
