class_name TrickEngine
extends RefCounted

## Uma vaza por vez: quem saiu, o naipe puxado, quem esta na frente, quem leva.
##
## Copas, Sueca e Truco sao tres jogos de vazas com regras de FORCA diferentes
## (no Truco a manilha vale mais que tudo, na Sueca o 7 vale mais que o rei) e
## regras de OBRIGACAO diferentes (Copas e Sueca obrigam a seguir o naipe;
## Truco nao). O que e igual -- a ordem de jogar, o naipe puxado, o trunfo que
## corta, a comparacao para saber quem leva -- mora aqui, e cada jogo entrega
## so a funcao de forca.
##
##     var vaza := TrickEngine.new(4, SuecaRules.strength, trunfo, true)
##     vaza.begin(quem_sai)
##     for c in vaza.legal_cards(mao): ...
##     vaza.play(cadeira, carta)
##     if vaza.is_complete(): var leva := vaza.winner()
##
## `strength` recebe a carta e devolve um inteiro: maior ganha. O trunfo vence
## qualquer carta de outro naipe; entre cartas do naipe puxado vale a forca;
## carta de naipe que nao e o puxado nem trunfo nunca ganha.
##
## O Truco nao tem naipe puxado nem trunfo: passa `must_follow = false` e
## `Card.Suit.NONE`, e a forca sozinha decide. Ali duas cartas podem empatar
## (`tied()`), e o jogo trata o empate como manda a regra dele.

var players: int = 4
var trump: int = Card.Suit.NONE
var must_follow: bool = true
var strength: Callable

## As jogadas desta vaza, na ordem: `{"seat": int, "card": Card}`.
var plays: Array[Dictionary] = []

var _leader: int = 0


func _init(p_players: int, p_strength: Callable, p_trump: int = Card.Suit.NONE,
		p_must_follow: bool = true) -> void:
	players = maxi(p_players, 2)
	strength = p_strength
	trump = p_trump
	must_follow = p_must_follow


## Comeca uma vaza nova com `lead_seat` saindo.
func begin(lead_seat: int) -> void:
	_leader = posmod(lead_seat, players)
	plays.clear()


func leader() -> int:
	return _leader


## O naipe da primeira carta, ou NONE antes de alguem sair.
func led_suit() -> int:
	if plays.is_empty():
		return Card.Suit.NONE
	return (plays[0]["card"] as Card).suit


## A cadeira que joga agora.
func current_seat() -> int:
	return posmod(_leader + plays.size(), players)


func is_complete() -> bool:
	return plays.size() >= players


func has_started() -> bool:
	return not plays.is_empty()


## As cartas da mao que a regra deixa jogar agora. Com `must_follow`, quem tem
## o naipe puxado e obrigado a segui-lo; quem nao tem joga qualquer uma.
func legal_cards(hand: Array) -> Array[Card]:
	var saida: Array[Card] = []
	var puxado := led_suit()
	if must_follow and puxado != Card.Suit.NONE:
		for c in hand:
			if c is Card and (c as Card).suit == puxado:
				saida.append(c)
		if not saida.is_empty():
			return saida
	for c in hand:
		if c is Card:
			saida.append(c)
	return saida


## Registra a jogada. Recusa fora de vez e vaza fechada.
func play(seat: int, card: Card) -> bool:
	if card == null or is_complete() or seat != current_seat():
		return false
	plays.append({"seat": seat, "card": card})
	return true


## Valor de comparacao de uma carta nesta vaza: trunfo acima de tudo, depois o
## naipe puxado pela forca, e o resto nao concorre.
func rank_in_trick(card: Card) -> int:
	var forca := int(strength.call(card))
	if trump != Card.Suit.NONE and card.suit == trump:
		return 100000 + forca
	if not must_follow or led_suit() == Card.Suit.NONE or card.suit == led_suit():
		return forca
	return -1


## A jogada que esta ganhando agora (a primeira, em caso de empate).
func winning_play() -> Dictionary:
	var melhor: Dictionary = {}
	var melhor_valor := -2
	for p in plays:
		var v := rank_in_trick(p["card"])
		if v > melhor_valor:
			melhor_valor = v
			melhor = p
	return melhor


## Quem esta levando a vaza; -1 antes de alguem jogar.
func winner() -> int:
	var w := winning_play()
	return int(w.get("seat", -1))


## Duas ou mais cartas empatadas na frente (so acontece sem trunfo e com forca
## repetida -- o Truco).
func tied() -> bool:
	if plays.is_empty():
		return false
	var topo := rank_in_trick(winning_play()["card"])
	var n := 0
	for p in plays:
		if rank_in_trick(p["card"]) == topo:
			n += 1
	return n >= 2


## Todas as cartas da vaza, na ordem em que cairam.
func cards() -> Array[Card]:
	var saida: Array[Card] = []
	for p in plays:
		saida.append(p["card"])
	return saida


## Soma de pontos da vaza segundo `value_of(card) -> int`.
func points(value_of: Callable) -> int:
	var total := 0
	for p in plays:
		total += int(value_of.call(p["card"]))
	return total


## Forca padrao: o valor da carta com o as por cima (A=14, K=13 ... 2=2).
static func ace_high(card: Card) -> int:
	return 14 if card.value == 1 else card.value
