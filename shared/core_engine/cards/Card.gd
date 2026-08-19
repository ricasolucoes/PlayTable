## Represents a playing card.
class_name Card
extends RefCounted

enum Suit {
	NONE = 0,
	HEARTS = 1,   # Copas ♥
	DIAMONDS = 2, # Ouros ♦
	CLUBS = 3,    # Paus ♣
	SPADES = 4    # Espadas ♠
}

enum ColorType {
	NONE = 0,
	RED = 1,
	BLACK = 2,
	BLUE = 3,
	GREEN = 4,
	YELLOW = 5,
	WILD = 6
}

enum SpecialType {
	NONE = 0,
	SKIP = 1,
	REVERSE = 2,
	DRAW_TWO = 3,
	WILD = 4,
	WILD_DRAW_FOUR = 5
}

const SUIT_SYMBOLS = {
	Suit.NONE: "",
	Suit.HEARTS: "♥",
	Suit.DIAMONDS: "♦",
	Suit.CLUBS: "♣",
	Suit.SPADES: "♠"
}

const SUIT_NAMES = {
	Suit.NONE: "Nenhum",
	Suit.HEARTS: "Copas",
	Suit.DIAMONDS: "Ouros",
	Suit.CLUBS: "Paus",
	Suit.SPADES: "Espadas"
}

const COLOR_NAMES = {
	ColorType.NONE: "Sem Cor",
	ColorType.RED: "Vermelho",
	ColorType.BLACK: "Preto",
	ColorType.BLUE: "Azul",
	ColorType.GREEN: "Verde",
	ColorType.YELLOW: "Amarelo",
	ColorType.WILD: "Curinga"
}

const VALUE_NAMES_STANDARD = {
	1: "A",
	2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8", 9: "9", 10: "10",
	11: "J",
	12: "Q",
	13: "K",
	14: "A" # Para poker onde Ás pode ser 14
}

var id: String = ""
var value: int = 0
var suit: Suit = Suit.NONE
var color_type: ColorType = ColorType.NONE
var card_type: String = "standard" # "standard", "number", "skip", "reverse", "draw2", "wild", "wild4", "custom"
var special_type: SpecialType = SpecialType.NONE
var is_face_up: bool = true
var custom_data: Dictionary = {}

func _init(p_val: int = 0, p_suit: Suit = Suit.NONE, p_color: ColorType = ColorType.NONE, p_type: String = "standard", p_custom: Dictionary = {}) -> void:
	value = p_val
	suit = p_suit
	color_type = p_color
	card_type = p_type
	custom_data = p_custom
	
	match card_type:
		"skip": special_type = SpecialType.SKIP
		"reverse": special_type = SpecialType.REVERSE
		"draw2": special_type = SpecialType.DRAW_TWO
		"wild": special_type = SpecialType.WILD
		"wild4": special_type = SpecialType.WILD_DRAW_FOUR
		_: special_type = SpecialType.NONE
	
	# Auto-determina cor padrão para baralho francês caso não seja passada
	if color_type == ColorType.NONE and suit != Suit.NONE:
		if suit == Suit.HEARTS or suit == Suit.DIAMONDS:
			color_type = ColorType.RED
		else:
			color_type = ColorType.BLACK
			
	id = "%s_%d_%d" % [card_type, int(suit), value]
	if custom_data.has("id_suffix"):
		id += "_" + str(custom_data["id_suffix"])

func get_display_value() -> String:
	if custom_data.has("label"):
		return str(custom_data["label"])
	if card_type == "skip": return "🚫"
	if card_type == "reverse": return "🔁"
	if card_type == "draw2": return "+2"
	if card_type == "wild": return "🌈"
	if card_type == "wild4": return "🌈+4"
	if VALUE_NAMES_STANDARD.has(value):
		return VALUE_NAMES_STANDARD[value]
	return str(value)

func get_suit_symbol() -> String:
	return SUIT_SYMBOLS.get(suit, "")

func get_suit_name() -> String:
	return SUIT_NAMES.get(suit, "")

func get_color_name() -> String:
	return COLOR_NAMES.get(color_type, "")

func is_red() -> bool:
	return color_type == ColorType.RED

func is_black() -> bool:
	return color_type == ColorType.BLACK

func get_short_name() -> String:
	var sym = get_suit_symbol()
	var val = get_display_value()
	if sym != "":
		return "%s%s" % [val, sym]
	return val

func to_dict() -> Dictionary:
	return {
		"id": id,
		"value": value,
		"suit": int(suit),
		"color_type": int(color_type),
		"card_type": card_type,
		"is_face_up": is_face_up,
		"custom_data": custom_data.duplicate()
	}

static func from_dict(data: Dictionary) -> Card:
	var c = Card.new(
		int(data.get("value", 0)),
		data.get("suit", Suit.NONE) as Suit,
		data.get("color_type", ColorType.NONE) as ColorType,
		str(data.get("card_type", "standard")),
		data.get("custom_data", {})
	)
	c.id = str(data.get("id", c.id))
	c.is_face_up = bool(data.get("is_face_up", true))
	return c

func clone() -> Card:
	return Card.from_dict(to_dict())
