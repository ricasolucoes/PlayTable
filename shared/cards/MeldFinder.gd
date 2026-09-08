class_name MeldFinder
extends RefCounted

## Trincas e sequencias: o que Pife, Buraco e qualquer rummy chamam de "jogo".
##
## Uma trinca (`is_set`) e um grupo de cartas do mesmo valor; uma sequencia
## (`is_run`) e um grupo do mesmo naipe com valores seguidos. O as fecha as
## duas pontas (A-2-3 e Q-K-A) sem dar a volta. Curinga preenche o que falta
## em qualquer um dos dois, ate `max_wilds` por jogo -- no Buraco os 2 sao
## curinga e cabe um por jogo; no Pife nao ha curinga.
##
## Tudo estatico e sobre `Array` de `Card`: a mao e do jogo, aqui so se le.
## As opcoes andam num dicionario para nao virar dez parametros:
##
##   min_size        3      tamanho minimo do jogo
##   distinct_suits  true   trinca exige naipes diferentes (Pife) ou nao (Buraco)
##   is_wild         null   Callable(Card) -> bool: quais cartas sao curinga
##   max_wilds       1      curingas por jogo, quando `is_wild` existe

const DEFAULTS := {
	"min_size": 3,
	"distinct_suits": true,
	"is_wild": null,
	"max_wilds": 1,
}


## Valor de 1 (as) a 13 (rei), tratando o as alto (14) como as.
static func rank_of(card: Card) -> int:
	return 1 if card.value == 14 else card.value


static func _opt(opts: Dictionary, key: String) -> Variant:
	return opts.get(key, DEFAULTS[key])


static func is_wild(card: Card, opts: Dictionary = {}) -> bool:
	var f: Variant = _opt(opts, "is_wild")
	if f is Callable:
		return bool((f as Callable).call(card))
	return false


static func _split(cards: Array, opts: Dictionary) -> Dictionary:
	var naturais: Array[Card] = []
	var curingas: Array[Card] = []
	for c in cards:
		if not (c is Card):
			continue
		if is_wild(c, opts):
			curingas.append(c)
		else:
			naturais.append(c)
	return {"natural": naturais, "wild": curingas}


## Trinca: mesmo valor em todas as naturais, curingas dentro do limite.
static func is_set(cards: Array, opts: Dictionary = {}) -> bool:
	if cards.size() < int(_opt(opts, "min_size")):
		return false
	var partes := _split(cards, opts)
	var naturais: Array[Card] = partes["natural"]
	var curingas: Array[Card] = partes["wild"]
	if naturais.is_empty() or curingas.size() > int(_opt(opts, "max_wilds")):
		return false
	# Curinga demais para pouca carta natural nao e trinca: e um monte de coringa.
	if curingas.size() >= naturais.size() and curingas.size() > 0:
		return false
	var valor := rank_of(naturais[0])
	var naipes := {}
	for c in naturais:
		if rank_of(c) != valor:
			return false
		if bool(_opt(opts, "distinct_suits")):
			if naipes.has(c.suit):
				return false
			naipes[c.suit] = true
	return true


## Sequencia: mesmo naipe, valores seguidos, curingas tapando buracos. O as
## vale 1 ou 14, o que fechar a sequencia; nunca os dois ao mesmo tempo.
static func is_run(cards: Array, opts: Dictionary = {}) -> bool:
	if cards.size() < int(_opt(opts, "min_size")):
		return false
	var partes := _split(cards, opts)
	var naturais: Array[Card] = partes["natural"]
	var curingas: Array[Card] = partes["wild"]
	if naturais.size() < 2 or curingas.size() > int(_opt(opts, "max_wilds")):
		return false
	var naipe: int = naturais[0].suit
	for c in naturais:
		if c.suit != naipe:
			return false
	return _cabe_em_linha(naturais, curingas.size(), false) \
		or _cabe_em_linha(naturais, curingas.size(), true)


## As naturais, com o as baixo (1) ou alto (14), formam uma linha sem repeticao
## cujos buracos os curingas tapam?
static func _cabe_em_linha(naturais: Array[Card], curingas: int, ace_high: bool) -> bool:
	var valores: Array[int] = []
	for c in naturais:
		var v := rank_of(c)
		if v == 1 and ace_high:
			v = 14
		if valores.has(v):
			return false
		valores.append(v)
	valores.sort()
	var span: int = valores[valores.size() - 1] - valores[0] + 1
	if span > 14:
		return false
	var buracos: int = span - valores.size()
	# Curinga sobrando pode ir na ponta, desde que a sequencia nao passe do as.
	if buracos > curingas:
		return false
	var sobra := curingas - buracos
	var folga_baixo: int = valores[0] - 1
	var folga_cima: int = 14 - valores[valores.size() - 1]
	return sobra <= folga_baixo + folga_cima


static func is_meld(cards: Array, opts: Dictionary = {}) -> bool:
	return is_set(cards, opts) or is_run(cards, opts)


## Canastra do Buraco: jogo de sete ou mais. Limpa sem curinga, suja com.
static func is_canasta(cards: Array, opts: Dictionary = {}) -> bool:
	return cards.size() >= 7 and is_meld(cards, opts)


static func is_clean(cards: Array, opts: Dictionary = {}) -> bool:
	for c in cards:
		if c is Card and is_wild(c, opts):
			return false
	return true


## Quantos curingas ha num grupo.
static func wild_count(cards: Array, opts: Dictionary = {}) -> int:
	var n := 0
	for c in cards:
		if c is Card and is_wild(c, opts):
			n += 1
	return n


## Todas as trincas possiveis de exatamente `size` cartas (sem curinga), por valor.
static func find_sets(cards: Array, size: int = 3, opts: Dictionary = {}) -> Array:
	var por_valor := {}
	for c in cards:
		if c is Card and not is_wild(c, opts):
			var v := rank_of(c)
			if not por_valor.has(v):
				por_valor[v] = []
			(por_valor[v] as Array).append(c)
	var saida: Array = []
	for v in por_valor:
		var grupo: Array = por_valor[v]
		if grupo.size() < size:
			continue
		for comb in _combinacoes(grupo, size):
			if is_set(comb, opts):
				saida.append(comb)
	return saida


## Todas as sequencias possiveis de exatamente `size` cartas (sem curinga).
static func find_runs(cards: Array, size: int = 3, opts: Dictionary = {}) -> Array:
	var por_naipe := {}
	for c in cards:
		if c is Card and not is_wild(c, opts):
			if not por_naipe.has(c.suit):
				por_naipe[c.suit] = []
			(por_naipe[c.suit] as Array).append(c)
	var saida: Array = []
	for naipe in por_naipe:
		var grupo: Array = por_naipe[naipe]
		if grupo.size() < size:
			continue
		for comb in _combinacoes(grupo, size):
			if is_run(comb, opts):
				saida.append(comb)
	return saida


## Divide TODAS as cartas em jogos de `meld_size` cartas, ou devolve `[]` se
## nao da. E a pergunta do Pife: nove cartas viram tres jogos de tres?
##
## Busca com retrocesso: a primeira carta tem de estar em algum jogo, entao
## tenta cada combinacao das restantes com ela. Nove cartas sao 28 tentativas
## por nivel; quinze ainda cabem num quadro.
static func partition(cards: Array, meld_size: int = 3, opts: Dictionary = {}) -> Array:
	var lista: Array = []
	for c in cards:
		if c is Card:
			lista.append(c)
	if lista.size() % meld_size != 0:
		return []
	var o := opts.duplicate()
	o["min_size"] = meld_size
	return _particionar(lista, meld_size, o)


static func _particionar(restantes: Array, tamanho: int, opts: Dictionary) -> Array:
	if restantes.is_empty():
		return []
	var primeira: Card = restantes[0]
	var outras: Array = restantes.slice(1)
	for comb in _combinacoes(outras, tamanho - 1):
		var jogo: Array = [primeira]
		jogo.append_array(comb)
		if not is_meld(jogo, opts):
			continue
		var sobra: Array = []
		for c in outras:
			if not comb.has(c):
				sobra.append(c)
		var resto := _particionar(sobra, tamanho, opts)
		if sobra.is_empty() or not resto.is_empty():
			var saida: Array = [jogo]
			saida.append_array(resto)
			return saida
	return []


## Verdadeiro quando a mao inteira fecha em jogos de `meld_size`.
static func can_go_out(cards: Array, meld_size: int = 3, opts: Dictionary = {}) -> bool:
	return not partition(cards, meld_size, opts).is_empty() or cards.is_empty()


## Escolha gulosa de jogos que nao compartilham carta, maior cobertura
## primeiro. Serve a IA (o que baixar) e a dica (o que segurar). Devolve
## `{"melds": Array[Array], "deadwood": Array[Card]}`.
static func best_melds(cards: Array, opts: Dictionary = {}) -> Dictionary:
	var minimo := int(_opt(opts, "min_size"))
	var candidatos: Array = []
	for tamanho in range(minimo, maxi(minimo, cards.size()) + 1):
		candidatos.append_array(find_sets(cards, tamanho, opts))
		candidatos.append_array(find_runs(cards, tamanho, opts))
	candidatos.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	var usados := {}
	var jogos: Array = []
	for comb in candidatos:
		var livre := true
		for c in comb:
			if usados.has(c):
				livre = false
				break
		if not livre:
			continue
		for c in comb:
			usados[c] = true
		jogos.append(comb)
	var sobra: Array = []
	for c in cards:
		if c is Card and not usados.has(c):
			sobra.append(c)
	return {"melds": jogos, "deadwood": sobra}


## As cartas que nao entram em jogo nenhum de `melds`.
static func deadwood(cards: Array, melds: Array) -> Array:
	var usados := {}
	for jogo in melds:
		for c in jogo:
			usados[c] = true
	var sobra: Array = []
	for c in cards:
		if not usados.has(c):
			sobra.append(c)
	return sobra


## Combinacoes de `k` elementos de `itens`, na ordem.
static func _combinacoes(itens: Array, k: int) -> Array:
	var saida: Array = []
	if k <= 0:
		saida.append([])
		return saida
	if k > itens.size():
		return saida
	_combinar(itens, k, 0, [], saida)
	return saida


static func _combinar(itens: Array, k: int, inicio: int, atual: Array, saida: Array) -> void:
	if atual.size() == k:
		saida.append(atual.duplicate())
		return
	for i in range(inicio, itens.size()):
		atual.append(itens[i])
		_combinar(itens, k, i + 1, atual, saida)
		atual.pop_back()
