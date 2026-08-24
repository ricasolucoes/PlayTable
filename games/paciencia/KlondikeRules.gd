class_name KlondikeRules
extends RefCounted

## Rules and logic for Paciencia.

const CardScript = preload("res://shared/core_engine/cards/Card.gd")

## `required_suit` e o naipe que a fundacao guarda. Com -1 a fundacao aceita o as
## de qualquer naipe -- so use assim quando a pilha ainda nao tem dono.
static func can_place_on_foundation(card: Card, foundation_pile, required_suit: int = -1) -> bool:
	if card == null: return false
	var top = foundation_pile.peek() if (foundation_pile != null and foundation_pile.has_method("peek") and not foundation_pile.is_empty()) else null
	if top == null:
		# Fundacao vazia so abre com as, e so com o as do naipe que ela guarda.
		return card.value == 1 and (required_suit == -1 or card.suit == required_suit)
	return card.suit == top.suit and card.value == top.value + 1

static func can_place_on_tableau(card: Card, tableau_pile) -> bool:
	if card == null: return false
	var top = tableau_pile.peek() if (tableau_pile != null and tableau_pile.has_method("peek") and not tableau_pile.is_empty()) else null
	if top == null:
		return card.value == 13
	if not top.is_face_up:
		return false
	return (card.value == top.value - 1) and (card.color_type != top.color_type)

static func can_add_to_foundation(card: Card, target_suit: Card.Suit, top_foundation_card: Card) -> bool:
	if card == null: return false
	if card.suit != target_suit:
		return false
	if top_foundation_card == null:
		return card.value == 1 # Ás
	return card.value == top_foundation_card.value + 1

static func can_add_to_tableau(card: Card, top_tableau_card: Card) -> bool:
	if card == null: return false
	if top_tableau_card == null:
		return card.value == 13 # Apenas Rei na coluna vazia
	if not top_tableau_card.is_face_up:
		return false
	return (card.value == top_tableau_card.value - 1) and (card.color_type != top_tableau_card.color_type)

static func find_auto_foundation_index(card: Card, foundation_piles: Array, suits_order: Array) -> int:
	if card == null: return -1
	for i in range(suits_order.size()):
		var target_suit = suits_order[i]
		var top_card = foundation_piles[i].peek() if (i < foundation_piles.size() and foundation_piles[i] != null) else null
		if can_add_to_foundation(card, target_suit, top_card):
			return i
	return -1

static func is_game_won(foundation_piles: Array) -> bool:
	var count: int = 0
	for pile in foundation_piles:
		count += pile.size()
	return count == 52
