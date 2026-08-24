## Represents a pile of cards.
class_name CardPile
extends CardCollection

func push(card: Card) -> void:
	if card != null:
		cards.append(card)

func push_many(new_cards: Array[Variant]) -> void:
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

func slice_from(start_idx: int) -> Array[Card]:
	var result: Array[Card] = []
	if start_idx >= 0 and start_idx < cards.size():
		for i in range(start_idx, cards.size()):
			result.append(cards[i])
		cards.resize(start_idx)
	return result

static func from_dict(data: Dictionary) -> CardPile:
	var pile = CardPile.new()
	var list = data.get("cards", [])
	for item in list:
		pile.push(Card.from_dict(item))
	return pile
