class_name CardPile
extends RefCounted

const CardScript = preload("res://shared/core_engine/cards/Card.gd")

var cards: Array[Card] = []

func _init(initial_cards: Array = []):
	for c in initial_cards:
		if c is Card:
			cards.append(c)

func push(card: Card) -> void:
	if card != null:
		cards.append(card)

func push_many(new_cards: Array) -> void:
	for c in new_cards:
		if c is Card:
			cards.append(c)

func pop() -> Card:
	if cards.is_empty():
		return null
	return cards.pop_back()

func peek() -> Card:
	if cards.is_empty():
		return null
	return cards.back()

func get_card(idx: int) -> Card:
	if idx >= 0 and idx < cards.size():
		return cards[idx]
	return null

func remove_at(idx: int) -> Card:
	if idx >= 0 and idx < cards.size():
		return cards.pop_at(idx)
	return null

func slice_from(start_idx: int) -> Array[Card]:
	var result: Array[Card] = []
	if start_idx >= 0 and start_idx < cards.size():
		for i in range(start_idx, cards.size()):
			result.append(cards[i])
		cards.resize(start_idx)
	return result

func size() -> int:
	return cards.size()

func count() -> int:
	return cards.size()

func is_empty() -> bool:
	return cards.is_empty()

func clear() -> void:
	cards.clear()

func get_all() -> Array[Card]:
	return cards

func to_dict() -> Dictionary:
	var list = []
	for c in cards:
		list.append(c.to_dict())
	return {"cards": list}

static func from_dict(data: Dictionary) -> CardPile:
	var pile = CardPile.new()
	var list = data.get("cards", [])
	for item in list:
		pile.push(Card.from_dict(item))
	return pile
