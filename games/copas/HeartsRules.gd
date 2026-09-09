class_name HeartsRules
extends RefCounted

## As regras do Copas (Hearts), puras: sem no, sem tr(), sem estado.
##
## Quatro cadeiras, baralho de 52, treze cartas cada. Antes de cada mao
## passam-se tres cartas (esquerda, direita, frente, sem passe, e repete). Sai
## quem tem o 2 de paus. E obrigatorio seguir o naipe; nao ha trunfo; a mais
## alta do naipe puxado leva a vaza (o as por cima). Cada copas vale 1 ponto e
## a dama de espadas vale 13; quem leva os 26 de uma vez "atirou na lua" e sao
## os outros tres que ganham 26. Vence quem tem MENOS pontos quando alguem
## chega ao limite.
##
## A vaza em si (quem sai, naipe puxado, quem leva) e do `TrickEngine`; aqui
## moram so as restricoes proprias do Copas: a primeira vaza sem pontos, copas
## so depois de quebrada, o 2 de paus a sair.

const PLAYERS := 4
const HAND_SIZE := 13
const TRICKS_PER_HAND := 13
const PASS_COUNT := 3
const HEART_POINTS := 1
const QUEEN_POINTS := 13
const MOON_POINTS := 26

## No telefone uma partida ate 100 leva meia hora. Nos degraus baixos a
## partida fecha em 50; do `LIMIT_LEVEL_HIGH` em diante vale o classico 100.
const LIMIT_LOW := 50
const LIMIT_HIGH := 100
const LIMIT_LEVEL_HIGH := 6

enum Pass { LEFT, RIGHT, ACROSS, NONE }

## Motivos de recusa, para a tela explicar por que a carta tremeu.
const REASON_TWO_OF_CLUBS := "two_of_clubs"
const REASON_FOLLOW := "follow"
const REASON_HEARTS := "hearts"
const REASON_FIRST_TRICK := "first_trick"

## Ordem dos naipes no leque: cores alternadas, copas por ultimo.
const SUIT_ORDER := {
	Card.Suit.CLUBS: 0,
	Card.Suit.DIAMONDS: 1,
	Card.Suit.SPADES: 2,
	Card.Suit.HEARTS: 3,
}


# ------------------------------------------------------------------- cartas

static func strength(card: Card) -> int:
	return TrickEngine.ace_high(card)


static func new_trick() -> TrickEngine:
	return TrickEngine.new(PLAYERS, TrickEngine.ace_high, Card.Suit.NONE, true)


static func is_heart(card: Card) -> bool:
	return card != null and card.suit == Card.Suit.HEARTS


static func is_queen_of_spades(card: Card) -> bool:
	return card != null and card.suit == Card.Suit.SPADES and card.value == 12


static func is_two_of_clubs(card: Card) -> bool:
	return card != null and card.suit == Card.Suit.CLUBS and card.value == 2


static func card_points(card: Card) -> int:
	if is_queen_of_spades(card):
		return QUEEN_POINTS
	if is_heart(card):
		return HEART_POINTS
	return 0


static func trick_points(cards: Array) -> int:
	var total := 0
	for c in cards:
		if c is Card:
			total += card_points(c)
	return total


static func has_points(cards: Array) -> bool:
	return trick_points(cards) > 0


static func has_suit(hand: Array, suit: int) -> bool:
	for c in hand:
		if c is Card and (c as Card).suit == suit:
			return true
	return false


static func find_by_id(hand: Array, id: String) -> Card:
	for c in hand:
		if c is Card and (c as Card).id == id:
			return c
	return null


static func contains_queen(cards: Array) -> bool:
	for c in cards:
		if is_queen_of_spades(c):
			return true
	return false


## Copia ordenada do leque: naipe por naipe, da menor para a maior.
static func sort_hand(hand: Array) -> Array:
	var saida := hand.duplicate()
	saida.sort_custom(func(a: Card, b: Card) -> bool:
		if a.suit != b.suit:
			return int(SUIT_ORDER.get(a.suit, 9)) < int(SUIT_ORDER.get(b.suit, 9))
		return strength(a) < strength(b))
	return saida


# ------------------------------------------------------------- distribuicao

## Treze cartas a cada cadeira, na ordem em que o baralho (ja embaralhado
## por quem chamou) as entrega.
static func deal(deck: Deck) -> Array:
	var hands: Array = []
	for s in PLAYERS:
		hands.append([])
	var i := 0
	while not deck.is_empty():
		(hands[i % PLAYERS] as Array).append(deck.draw())
		i += 1
	return hands


static func holder_of_two_of_clubs(hands: Array) -> int:
	for s in hands.size():
		for c in hands[s]:
			if is_two_of_clubs(c):
				return s
	return -1


# -------------------------------------------------------------------- passe

## A direcao do passe da mao `hand_number` (a primeira e 0): esquerda,
## direita, frente, nenhum, e recomeca.
static func pass_direction(hand_number: int) -> int:
	return posmod(hand_number, 4)


## Para quem a cadeira `seat` passa; -1 quando nao ha passe. As cadeiras
## andam no sentido horario, entao a esquerda e a proxima.
static func pass_target(seat: int, direction: int) -> int:
	match direction:
		Pass.LEFT:
			return posmod(seat + 1, PLAYERS)
		Pass.RIGHT:
			return posmod(seat - 1, PLAYERS)
		Pass.ACROSS:
			return posmod(seat + 2, PLAYERS)
	return -1


## De quem a cadeira `seat` recebe; -1 quando nao ha passe.
static func pass_source(seat: int, direction: int) -> int:
	match direction:
		Pass.LEFT:
			return posmod(seat - 1, PLAYERS)
		Pass.RIGHT:
			return posmod(seat + 1, PLAYERS)
		Pass.ACROSS:
			return posmod(seat + 2, PLAYERS)
	return -1


# ------------------------------------------------------------------ jogadas

## As cartas da mao que podem ser jogadas agora.
##
## Saindo: na primeira vaza so o 2 de paus; copas so depois de quebrada (ou
## quando so ha copas). Seguindo: o naipe puxado, se houver; sem ele, qualquer
## carta -- menos copas e a dama na primeira vaza, a nao ser que so haja
## isso na mao.
static func legal_cards(hand: Array, trick: TrickEngine, first_trick: bool, hearts_broken: bool) -> Array[Card]:
	var saida: Array[Card] = []
	if trick == null or not trick.has_started():
		if first_trick:
			for c in hand:
				if is_two_of_clubs(c):
					saida.append(c)
			if not saida.is_empty():
				return saida
		if not hearts_broken:
			for c in hand:
				if c is Card and not is_heart(c):
					saida.append(c)
			if not saida.is_empty():
				return saida
		for c in hand:
			if c is Card:
				saida.append(c)
		return saida

	var seguindo := trick.legal_cards(hand)
	if has_suit(hand, trick.led_suit()):
		return seguindo
	if first_trick:
		for c in seguindo:
			if card_points(c) == 0:
				saida.append(c)
		if not saida.is_empty():
			return saida
	return seguindo


static func is_legal(hand: Array, card: Card, trick: TrickEngine, first_trick: bool, hearts_broken: bool) -> bool:
	return card != null and legal_cards(hand, trick, first_trick, hearts_broken).has(card)


## Por que esta carta nao pode ser jogada agora; "" quando pode.
static func illegal_reason(hand: Array, card: Card, trick: TrickEngine, first_trick: bool, hearts_broken: bool) -> String:
	if is_legal(hand, card, trick, first_trick, hearts_broken):
		return ""
	if trick == null or not trick.has_started():
		if first_trick and not is_two_of_clubs(card):
			return REASON_TWO_OF_CLUBS
		if is_heart(card) and not hearts_broken:
			return REASON_HEARTS
		return REASON_FOLLOW
	if has_suit(hand, trick.led_suit()) and card.suit != trick.led_suit():
		return REASON_FOLLOW
	if first_trick and card_points(card) > 0:
		return REASON_FIRST_TRICK
	return REASON_FOLLOW


# ------------------------------------------------------------------- pontos

## A cadeira que atirou na lua (levou os 26 pontos da mao); -1 se ninguem.
static func moon_shooter(taken: Array) -> int:
	for s in taken.size():
		if int(taken[s]) >= MOON_POINTS:
			return s
	return -1


## O que cada cadeira soma ao placar no fim da mao: os pontos que levou, ou,
## quando alguem atirou na lua, 26 para cada um dos outros e zero para ela.
static func hand_scores(taken: Array) -> Array[int]:
	var saida: Array[int] = []
	var lua := moon_shooter(taken)
	for s in taken.size():
		if lua == -1:
			saida.append(int(taken[s]))
		else:
			saida.append(0 if s == lua else MOON_POINTS)
	return saida


static func game_limit(level: int) -> int:
	return LIMIT_HIGH if level >= LIMIT_LEVEL_HIGH else LIMIT_LOW


static func is_game_over(totals: Array, limit: int) -> bool:
	for t in totals:
		if int(t) >= limit:
			return true
	return false


## Quem tem menos pontos. Mais de uma cadeira quando empatam.
static func winners(totals: Array) -> Array[int]:
	var saida: Array[int] = []
	if totals.is_empty():
		return saida
	var menor := int(totals[0])
	for t in totals:
		menor = mini(menor, int(t))
	for s in totals.size():
		if int(totals[s]) == menor:
			saida.append(s)
	return saida


## O menor total entre as outras cadeiras -- o adversario a bater.
static func lowest_rival(totals: Array, seat: int) -> int:
	var menor := -1
	for s in totals.size():
		if s == seat:
			continue
		if menor == -1 or int(totals[s]) < menor:
			menor = int(totals[s])
	return maxi(menor, 0)
