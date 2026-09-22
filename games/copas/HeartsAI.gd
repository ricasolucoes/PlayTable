class_name HeartsAI
extends RefCounted

## A maquina do Copas, por degrau (1..10).
##
## Nao ha busca: numa mao escondida de treze cartas por cadeira a arvore nao
## cabe no telefone e nem faz falta. O que separa um degrau do outro e o que a
## maquina SABE fazer -- e quanto ela erra de proposito:
##
##   - nos degraus baixos ha uma chance de jogar qualquer carta legal;
##   - do 3 em diante ela leva a vaza "de graca" quando e a ultima e nao ha
##     pontos na mesa, e descarta a dama e as espadas altas assim que fica
##     sem o naipe;
##   - do 5 em diante o passe abre vazios de naipe, guarda espadas baixas
##     para se proteger da dama e sai de espadas para forcar a dama alheia;
##   - do 8 em diante tenta atirar na lua quando a mao permite.
##
## Tudo e estatico e recebe o gerador de numeros por parametro: a partida em
## rede calcula a maquina so no anfitriao, e o gerador dela e separado do que
## embaralha, para nao desalinhar as distribuicoes entre os dois aparelhos.

const LEVEL_FREE_TRICK := 3
const LEVEL_VOIDS := 5
const LEVEL_MOON := 8


## Chance de a maquina largar a estrategia e jogar qualquer carta legal.
static func random_chance(level: int) -> float:
	match clampi(level, 1, 10):
		1:
			return 0.55
		2:
			return 0.40
		3:
			return 0.28
		4:
			return 0.15
		5:
			return 0.08
	return 0.0


# -------------------------------------------------------------------- passe

## As tres cartas a passar: as piores da mao, nos degraus que sabem o que e
## uma carta ruim.
static func choose_pass(hand: Array, level: int, rng: RandomNumberGenerator) -> Array[Card]:
	var saida: Array[Card] = []
	if hand.size() <= HeartsRules.PASS_COUNT:
		for c in hand:
			saida.append(c)
		return saida
	if rng.randf() < random_chance(level):
		var indices: Array = range(hand.size())
		MatchSync.shuffle_with(indices, rng)
		for i in HeartsRules.PASS_COUNT:
			saida.append(hand[indices[i]])
		return saida
	var contagem := suit_counts(hand)
	var pontuadas: Array = []
	for c in hand:
		pontuadas.append({"card": c, "score": pass_score(c, contagem, level)})
	pontuadas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]))
	for i in HeartsRules.PASS_COUNT:
		saida.append(pontuadas[i]["card"])
	return saida


## Quanto uma carta pesa na mao: a dama e as espadas altas em primeiro, depois
## as copas altas, depois as figuras. Do degrau 5 em diante um naipe curto
## vale mais ser passado inteiro (abre um vazio para descartar depois) e as
## espadas baixas valem ficar (seguram a dama longe).
static func pass_score(card: Card, counts: Dictionary, level: int) -> float:
	var f := float(HeartsRules.strength(card))
	var s := 0.0
	if HeartsRules.is_queen_of_spades(card):
		s = 100.0
	elif card.suit == Card.Suit.SPADES and f >= 13.0:
		s = 80.0 + f
	elif HeartsRules.is_heart(card):
		s = 40.0 + f * 3.0
	else:
		s = f * 3.0
	if level >= LEVEL_VOIDS:
		if card.suit != Card.Suit.SPADES and not HeartsRules.is_heart(card) \
				and int(counts.get(card.suit, 0)) <= 2:
			s += 25.0
		if card.suit == Card.Suit.SPADES and f < 12.0:
			s -= 30.0
	return s


static func suit_counts(hand: Array) -> Dictionary:
	var saida := {}
	for c in hand:
		if c is Card:
			saida[(c as Card).suit] = int(saida.get((c as Card).suit, 0)) + 1
	return saida


# ---------------------------------------------------------------------- lua

## A mao pede a lua? So no degrau alto, e so com copas e figuras de sobra:
## muitas copas com o as ou o rei entre elas, varios ases e reis, quase
## nenhuma carta baixa que perderia uma vaza cedo.
static func wants_moon(hand: Array, level: int) -> bool:
	if level < LEVEL_MOON:
		return false
	var copas := 0
	var altas := 0
	var baixas := 0
	var copas_de_cima := false
	for c in hand:
		if not (c is Card):
			continue
		var f := HeartsRules.strength(c)
		if HeartsRules.is_heart(c):
			copas += 1
			if f >= 13:
				copas_de_cima = true
		if f >= 13:
			altas += 1
		elif f <= 6 and not HeartsRules.is_heart(c):
			baixas += 1
	return copas >= 5 and copas_de_cima and altas >= 4 and baixas <= 2


## A lua ainda esta de pe: ninguem alem de `seat` levou ponto nesta mao.
static func moon_possible(ctx: Dictionary) -> bool:
	var taken: Array = ctx.get("taken", [])
	var seat := int(ctx.get("seat", -1))
	for s in taken.size():
		if s != seat and int(taken[s]) > 0:
			return false
	return true


# ------------------------------------------------------------------- jogada

## A carta a jogar, entre as `legal`. `ctx` traz o que a maquina "lembra":
## `seat`, `taken` (pontos por cadeira nesta mao), `played` (cartas ja
## jogadas nesta mao) e `moon` (esta cadeira tenta a lua).
static func choose_play(hand: Array, legal: Array, trick: TrickEngine, ctx: Dictionary,
		level: int, rng: RandomNumberGenerator) -> Card:
	if legal.is_empty():
		return null
	if legal.size() == 1:
		return legal[0]
	if rng.randf() < random_chance(level):
		return legal[rng.randi_range(0, legal.size() - 1)]
	var lua := bool(ctx.get("moon", false)) and moon_possible(ctx)
	if trick == null or not trick.has_started():
		return _lead(hand, legal, ctx, level, lua)
	if (legal[0] as Card).suit == trick.led_suit():
		return _follow(legal, trick, level, lua)
	return _discard(hand, legal, ctx, level, lua)


## Saindo. Atras da lua, a mais alta. Fora isso, a menor carta de um naipe
## que nao seja copas -- e, no degrau que sabe disso, uma espada baixa para
## arrancar a dama de quem a tem.
static func _lead(hand: Array, legal: Array, ctx: Dictionary, level: int, lua: bool) -> Card:
	if lua:
		return highest(legal)
	if level >= LEVEL_VOIDS and queen_out(ctx, hand):
		var espadas_baixas := _filter(legal, func(c: Card) -> bool:
			return c.suit == Card.Suit.SPADES and HeartsRules.strength(c) < 12)
		if not espadas_baixas.is_empty():
			return lowest(espadas_baixas)
	var pool := _filter(legal, func(c: Card) -> bool: return not HeartsRules.is_heart(c))
	if pool.is_empty():
		pool = legal
	# Com a dama na mao, sair de espadas e pedir para ela cair em cima de si.
	if level >= 4 and HeartsRules.contains_queen(hand):
		var sem_espadas := _filter(pool, func(c: Card) -> bool: return c.suit != Card.Suit.SPADES)
		if not sem_espadas.is_empty():
			pool = sem_espadas
	return lowest(pool)


## Seguindo o naipe. Baixo quando da para ficar por baixo de quem esta
## ganhando; alto quando se e o ultimo e a vaza nao tem ponto; e quando nao
## ha como escapar, a menor que passa por cima.
static func _follow(legal: Array, trick: TrickEngine, level: int, lua: bool) -> Card:
	var vencedora: Card = trick.winning_play()["card"]
	var topo := HeartsRules.strength(vencedora)
	var ultima := trick.plays.size() == HeartsRules.PLAYERS - 1
	var pontos_na_mesa := trick.points(HeartsRules.card_points)
	var abaixo := _filter(legal, func(c: Card) -> bool: return HeartsRules.strength(c) < topo)
	var acima := _filter(legal, func(c: Card) -> bool: return HeartsRules.strength(c) > topo)
	if lua:
		return highest(acima) if not acima.is_empty() else lowest(legal)
	if ultima and pontos_na_mesa == 0 and not acima.is_empty() and level >= LEVEL_FREE_TRICK:
		var sem_dama := _filter(acima, func(c: Card) -> bool: return not HeartsRules.is_queen_of_spades(c))
		if not sem_dama.is_empty():
			return highest(sem_dama)
	if not abaixo.is_empty():
		# Por baixo do rei ou do as de espadas, a dama vai embora de graca.
		for c in abaixo:
			if HeartsRules.is_queen_of_spades(c):
				return c
		return highest(abaixo)
	if ultima:
		var sem_dama := _filter(legal, func(c: Card) -> bool: return not HeartsRules.is_queen_of_spades(c))
		return highest(sem_dama if not sem_dama.is_empty() else legal)
	var candidatas := _filter(acima, func(c: Card) -> bool: return not HeartsRules.is_queen_of_spades(c))
	return lowest(candidatas if not candidatas.is_empty() else acima)


## Sem o naipe puxado: a dama primeiro, depois as espadas altas enquanto a
## dama anda solta, depois a copas mais alta, depois a carta mais alta do
## naipe mais curto.
static func _discard(hand: Array, legal: Array, ctx: Dictionary, level: int, lua: bool) -> Card:
	if lua:
		return lowest(legal)
	for c in legal:
		if HeartsRules.is_queen_of_spades(c):
			return c
	if level >= LEVEL_FREE_TRICK and queen_out(ctx, hand):
		var espadas_altas := _filter(legal, func(c: Card) -> bool:
			return c.suit == Card.Suit.SPADES and HeartsRules.strength(c) >= 13)
		if not espadas_altas.is_empty():
			return highest(espadas_altas)
	var copas := _filter(legal, func(c: Card) -> bool: return HeartsRules.is_heart(c))
	if not copas.is_empty():
		return highest(copas)
	if level >= LEVEL_VOIDS:
		var contagem := suit_counts(hand)
		var ordenadas := legal.duplicate()
		ordenadas.sort_custom(func(a: Card, b: Card) -> bool:
			var na := int(contagem.get(a.suit, 0))
			var nb := int(contagem.get(b.suit, 0))
			if na != nb:
				return na < nb
			return HeartsRules.strength(a) > HeartsRules.strength(b))
		return ordenadas[0]
	return highest(legal)


# ---------------------------------------------------------------- auxiliares

## A dama de espadas ainda nao apareceu e nao esta nesta mao.
static func queen_out(ctx: Dictionary, hand: Array) -> bool:
	if HeartsRules.contains_queen(hand):
		return false
	return not HeartsRules.contains_queen(ctx.get("played", []))


static func lowest(cards: Array) -> Card:
	var melhor: Card = null
	for c in cards:
		if melhor == null or HeartsRules.strength(c) < HeartsRules.strength(melhor):
			melhor = c
	return melhor


static func highest(cards: Array) -> Card:
	var melhor: Card = null
	for c in cards:
		if melhor == null or HeartsRules.strength(c) > HeartsRules.strength(melhor):
			melhor = c
	return melhor


static func _filter(cards: Array, pred: Callable) -> Array:
	var saida: Array = []
	for c in cards:
		if pred.call(c):
			saida.append(c)
	return saida
