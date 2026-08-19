class_name CardHand
extends RefCounted

const CardScript = preload("res://shared/core_engine/cards/Card.gd")

var cards: Array[Card] = []

func _init(initial_cards: Array = []):
	for c in initial_cards:
		if c is Card:
			cards.append(c)

func add(card: Card) -> void:
	if card != null:
		cards.append(card)

func add_many(new_cards: Array) -> void:
	for c in new_cards:
		if c is Card:
			cards.append(c)

func remove_at(idx: int) -> Card:
	if idx >= 0 and idx < cards.size():
		return cards.pop_at(idx)
	return null

func remove_card(card: Card) -> bool:
	var idx = cards.find(card)
	if idx != -1:
		cards.remove_at(idx)
		return true
	return false

func get_card(idx: int) -> Card:
	if idx >= 0 and idx < cards.size():
		return cards[idx]
	return null

func size() -> int:
	return cards.size()

func count() -> int:
	return cards.size()

func is_empty() -> bool:
	return cards.is_empty()

func clear() -> void:
	cards.clear()

func sort_by_value(ascending: bool = true) -> void:
	cards.sort_custom(func(a: Card, b: Card):
		if ascending:
			return a.value < b.value
		return a.value > b.value
	)

func sort_by_suit() -> void:
	cards.sort_custom(func(a: Card, b: Card):
		if a.suit != b.suit:
			return a.suit < b.suit
		return a.value < b.value
	)

func get_all() -> Array[Card]:
	return cards

func to_dict() -> Dictionary:
	var list = []
	for c in cards:
		list.append(c.to_dict())
	return {"cards": list}

static func from_dict(data: Dictionary) -> CardHand:
	var hand = CardHand.new()
	var list = data.get("cards", [])
	for item in list:
		hand.add(Card.from_dict(item))
	return hand
