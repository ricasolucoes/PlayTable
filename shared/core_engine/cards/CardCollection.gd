class_name CardCollection
extends RefCounted

## Base das três coleções de cartas: CardPile, CardHand e Deck.
##
## As três guardavam `var cards: Array[Card]`, filtravam a lista inicial do
## mesmo jeito e repetiam `size()`, `count()`, `is_empty()`, `clear()` e
## `to_dict()` com corpos idênticos. `count()` era alias de `size()` dentro do
## próprio arquivo — a mesma função escrita duas vezes, em três arquivos, e
## nenhuma chamada a `count()` existia em `games/` ou em `tests/`. Saiu.
##
## O que difere continua em cada uma: a pilha empilha e desempilha pelo topo, a
## mão ordena e remove por carta, o baralho embaralha e compra.

var cards: Array[Card] = []


## Aceita `Array[Card]` ou `Array[Variant]`; o que não for carta é descartado.
func _init(initial_cards: Array = []) -> void:
	for c in initial_cards:
		if c is Card:
			cards.append(c)


func size() -> int:
	return cards.size()


func is_empty() -> bool:
	return cards.is_empty()


func clear() -> void:
	cards.clear()


## A lista viva, não uma cópia: quem mexe no retorno mexe na coleção.
func get_all() -> Array[Card]:
	return cards


func get_card(idx: int) -> Card:
	if idx < 0 or idx >= cards.size():
		return null
	return cards[idx]


func remove_at(idx: int) -> Card:
	if idx < 0 or idx >= cards.size():
		return null
	return cards.pop_at(idx)


func to_dict() -> Dictionary:
	var list := []
	for c in cards:
		list.append(c.to_dict())
	return {"cards": list}
