class_name SpiderRules
extends RefCounted

## Regras puras da Paciência Spider.
##
## Uma sequência só pode ser carregada junta quando está virada para cima,
## desce sem saltos e usa o mesmo naipe. O destino, porém, aceita qualquer
## naipe: a cor só importa para decidir quais cartas podem viajar juntas.

static func is_descending_same_suit(cards: Array) -> bool:
	if cards.is_empty():
		return false
	for i in range(cards.size()):
		var card := cards[i] as Card
		if card == null or not card.is_face_up:
			return false
		if i == 0:
			continue
		var previous := cards[i - 1] as Card
		if previous == null or card.suit != previous.suit or card.value != previous.value - 1:
			return false
	return true


static func can_move_sequence(cards: Array) -> bool:
	return is_descending_same_suit(cards)


## Escolhe a maior sequência móvel no fim da coluna. O jogo permite tocar a
## coluna inteira; este método transforma esse toque em uma seleção natural,
## priorizando o bloco completo em vez de obrigar o jogador a acertar um pixel.
static func movable_start(pile: CardPile) -> int:
	if pile == null or pile.is_empty():
		return -1
	for start in range(pile.size()):
		if can_move_sequence(pile.get_all().slice(start)):
			return start
	return -1


static func can_place_sequence_on_tableau(cards: Array, target: CardPile) -> bool:
	if cards.is_empty() or not can_move_sequence(cards):
		return false
	var first := cards[0] as Card
	if target == null or target.is_empty():
		return first != null and first.value == 13
	var top := target.peek()
	return top != null and top.is_face_up and first.value == top.value - 1


static func is_complete_run(cards: Array) -> bool:
	if cards.size() != 13 or not can_move_sequence(cards):
		return false
	var first := cards[0] as Card
	return first != null and first.value == 13 and (cards[12] as Card).value == 1


static func can_deal_stock(tableau: Array) -> bool:
	for pile in tableau:
		if pile is CardPile and pile.is_empty():
			return false
	return true
