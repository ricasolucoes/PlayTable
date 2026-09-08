class_name MatchSync
extends RefCounted

## Cola entre um jogo de N assentos e o `NetworkManager` de dois aparelhos.
##
## O que viaja pela rede e sempre um dicionario com `t`:
##
##   {"t": "deal", "seed": int}            quem abriu a sala sorteou a partida
##   {"t": "need_deal"}                    o convidado pede o sorteio de novo
##   {"t": "act", "seat": i, "a": {...}}   a jogada da cadeira `i`; `a` e do jogo
##
## A semente resolve o sorteio sem mandar baralho nenhum: os dois aparelhos
## embaralham com o MESMO `RandomNumberGenerator` (`shuffle()` daqui, nunca o
## `Array.shuffle()` da engine) e chegam a mesma distribuicao. As jogadas da
## maquina, que nao sao deterministas, viajam como `act` calculadas so no
## aparelho que abriu a sala (`SeatTable.ai_runs_here`).
##
## O convidado pode entrar na cena DEPOIS de o anfitriao ter sorteado -- os
## dois trocam de cena com um fade de 0,2 s cada -- e o primeiro `deal` se
## perderia. Por isso o convidado pede (`need_deal`) ate receber, e o
## anfitriao responde com a mesma semente quantas vezes for preciso.
##
## Uso, no `_start_new_game()` do jogo:
##
##     table = SeatTable.for_game(self, 4)
##     sync = MatchSync.new(self, table)
##     sync.start()
##     if sync.waiting_for_deal():
##         set_status(tr("NET_WAITING_DEAL"))
##         return                       # `_on_net_move` chama `_deal()` depois
##     _deal()
##
## e no `_on_net_move(payload)`:
##
##     var msg := sync.accept(payload)
##     match str(msg.get("t", "")):
##         "deal": _deal()
##         "act": _apply(int(msg["seat"]), msg["a"])
##
## Fora da rede tudo isto e inerte: `start()` sorteia a semente localmente e
## `send()` nao manda nada.

const RETRY_SECONDS := 1.0

var game: BaseGame
var table: SeatTable
var seed: int = 0
var rng := RandomNumberGenerator.new()

var _seeded: bool = false
var _asking: bool = false


func _init(p_game: BaseGame, p_table: SeatTable) -> void:
	game = p_game
	table = p_table


## Abre a partida: sorteia (ou espera o sorteio do outro aparelho).
func start() -> void:
	_seeded = false
	if table.online() and not table.is_host():
		seed = 0
		_pedir_sorteio()
		return
	_aplicar_semente(randi())
	if table.online():
		game.net_send({"t": "deal", "seed": seed})


## Verdadeiro enquanto o convidado espera a semente do anfitriao.
func waiting_for_deal() -> bool:
	return table.online() and not _seeded


func seeded() -> bool:
	return _seeded


## Manda a jogada da cadeira `seat`. So sai se a cadeira e produzida aqui: a
## pessoa daqui ou a maquina que este aparelho calcula.
func send(seat: int, action: Dictionary) -> void:
	if not table.online() or not table.acts_here(seat):
		return
	game.net_send({"t": "act", "seat": seat, "a": action.duplicate(true)})


## Interpreta o que chegou do outro aparelho. Devolve `{}` para o que nao
## interessa: jogada de uma cadeira que este aparelho controla, sorteio
## repetido, pedido de sorteio quando nao se e o anfitriao.
func accept(payload: Dictionary) -> Dictionary:
	if not table.online():
		return {}
	match str(payload.get("t", "")):
		"deal":
			if table.is_host() or _seeded:
				return {}
			_aplicar_semente(int(payload.get("seed", 0)))
			return {"t": "deal", "seed": seed}
		"need_deal":
			if table.is_host() and _seeded:
				game.net_send({"t": "deal", "seed": seed})
			return {}
		"act":
			var seat := int(payload.get("seat", -1))
			if not table.expects_from_network(seat):
				return {}
			var a: Variant = payload.get("a", {})
			return {"t": "act", "seat": seat, "a": a if a is Dictionary else {}}
	return {}


## Embaralha `arr` com o gerador da partida -- o mesmo nos dois aparelhos.
func shuffle(arr: Array) -> void:
	shuffle_with(arr, rng)


## Embaralha uma colecao de cartas (`Deck`, `CardHand`, `CardPile`).
func shuffle_cards(collection: CardCollection) -> void:
	shuffle_with(collection.cards, rng)


## Fisher-Yates com um gerador dado. `Array.shuffle()` usa o gerador global e
## por isso nao serve: dois aparelhos com a mesma semente sairiam diferentes.
static func shuffle_with(arr: Array, generator: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := generator.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _aplicar_semente(valor: int) -> void:
	seed = valor if valor != 0 else 1
	rng = RandomNumberGenerator.new()
	rng.seed = seed
	_seeded = true


## Pede a semente ao anfitriao ate ela chegar. Corrotina presa ao jogo: se a
## cena for fechada no meio, para sozinha.
func _pedir_sorteio() -> void:
	if _asking:
		return
	_asking = true
	while is_instance_valid(game) and game.is_inside_tree() and waiting_for_deal():
		game.net_send({"t": "need_deal"})
		var arvore := game.get_tree()
		if arvore == null:
			break
		await arvore.create_timer(RETRY_SECONDS).timeout
	_asking = false
