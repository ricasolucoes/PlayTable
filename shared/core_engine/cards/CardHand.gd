## Manages a hand of cards for a player.
class_name CardHand
extends CardCollection

func add(card: Card) -> void:
	if card != null:
		cards.append(card)

func add_many(new_cards: Array[Variant]) -> void:
	for c in new_cards:
		if c is Card:
			cards.append(c)

func remove_card(card: Card) -> bool:
	var idx = cards.find(card)
	if idx != -1:
		cards.remove_at(idx)
		return true
	return false

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

static func from_dict(data: Dictionary) -> CardHand:
	var hand = CardHand.new()
	var list = data.get("cards", [])
	for item in list:
		hand.add(Card.from_dict(item))
	return hand
