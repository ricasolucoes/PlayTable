## Represents a deck of cards.
class_name Deck
extends RefCounted

const CardScript = preload("res://shared/core_engine/cards/Card.gd")

var cards: Array[Card] = []

func _init(initial_cards: Array[Card] = []) -> void:
	cards = initial_cards.duplicate()

func shuffle() -> void:
	cards.shuffle()

func draw() -> Card:
	if cards.is_empty():
		return null
	return cards.pop_back()

func draw_many(count: int) -> Array[Card]:
	var result: Array[Card] = []
	for i in range(count):
		var c = draw()
		if c != null:
			result.append(c)
	return result

func add_card(card: Card) -> void:
	if card != null:
		cards.append(card)

func add_cards(new_cards: Array[Variant]) -> void:
	for c in new_cards:
		if c is Card:
			cards.append(c)

func push_front(card: Card) -> void:
	if card != null:
		cards.push_front(card)

func recycle_from(source_cards: Array[Variant]) -> void:
	for c in source_cards:
		if c is Card:
			var copy = c.clone()
			copy.is_face_up = false
			cards.append(copy)
	shuffle()

func size() -> int:
	return cards.size()

func count() -> int:
	return cards.size()

func is_empty() -> bool:
	return cards.is_empty()

func clear() -> void:
	cards.clear()

static func create_standard_52(aces_high: bool = false) -> Deck:
	var deck = Deck.new()
	var suits = [Card.Suit.HEARTS, Card.Suit.DIAMONDS, Card.Suit.CLUBS, Card.Suit.SPADES]
	for s in suits:
		var col = Card.ColorType.RED if (s == Card.Suit.HEARTS or s == Card.Suit.DIAMONDS) else Card.ColorType.BLACK
		for v in range(1, 14):
			var final_val = 14 if (aces_high and v == 1) else v
			var card = Card.new(final_val, s, col, "standard")
			deck.add_card(card)
	return deck

static func create_uno_deck() -> Deck:
	var deck = Deck.new()
	var colors = [
		{"type": Card.ColorType.RED, "suit": Card.Suit.NONE},
		{"type": Card.ColorType.BLUE, "suit": Card.Suit.NONE},
		{"type": Card.ColorType.GREEN, "suit": Card.Suit.NONE},
		{"type": Card.ColorType.YELLOW, "suit": Card.Suit.NONE}
	]
	
	for col_info in colors:
		var c_type = col_info["type"]
		# Um '0' por cor
		deck.add_card(Card.new(0, Card.Suit.NONE, c_type, "number"))
		
		# Dois de 1 a 9 por cor
		for n in range(1, 10):
			deck.add_card(Card.new(n, Card.Suit.NONE, c_type, "number"))
			deck.add_card(Card.new(n, Card.Suit.NONE, c_type, "number"))
			
		# Duas cartas de ação por cor (+2, Inverter, Bloquear)
		for i in range(2):
			deck.add_card(Card.new(10, Card.Suit.NONE, c_type, "skip"))
			deck.add_card(Card.new(11, Card.Suit.NONE, c_type, "reverse"))
			deck.add_card(Card.new(12, Card.Suit.NONE, c_type, "draw2"))
			
	# Curingas (4 Wild, 4 Wild +4)
	for i in range(4):
		deck.add_card(Card.new(50, Card.Suit.NONE, Card.ColorType.WILD, "wild"))
		deck.add_card(Card.new(54, Card.Suit.NONE, Card.ColorType.WILD, "wild4"))
		
	return deck

static func create_memory_deck(custom_emojis: Array[String] = []) -> Deck:
	var deck = Deck.new()
	var emojis = custom_emojis
	if emojis.is_empty():
		emojis = ["🚀", "🦄", "🍕", "🎸", "💎", "🍄", "⭐", "🐱"]
		
	for i in range(emojis.size()):
		var emoji = emojis[i]
		var c1 = Card.new(i + 1, Card.Suit.NONE, Card.ColorType.NONE, "memory_pair", {"label": emoji, "pair_id": i})
		var c2 = Card.new(i + 1, Card.Suit.NONE, Card.ColorType.NONE, "memory_pair", {"label": emoji, "pair_id": i})
		c1.is_face_up = false
		c2.is_face_up = false
		deck.add_card(c1)
		deck.add_card(c2)
		
	return deck

func to_dict() -> Dictionary:
	var list = []
	for c in cards:
		list.append(c.to_dict())
	return {"cards": list}

static func from_dict(data: Dictionary) -> Deck:
	var deck = Deck.new()
	var list = data.get("cards", [])
	for item in list:
		deck.add_card(Card.from_dict(item))
	return deck
