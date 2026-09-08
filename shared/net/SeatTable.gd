class_name SeatTable
extends RefCounted

## Quem senta em cada cadeira da mesa.
##
## Os jogos de dois assentos resolviam isto com duas bandeiras (`vs_ai`,
## `em_rede`) e um `_meu()`. Uma mesa de Copas tem quatro cadeiras, uma de
## Guerra tem seis, e a pergunta que cada jogo faz a cada vez e a mesma:
## "quem produz a jogada desta cadeira -- a pessoa deste aparelho, o outro
## aparelho, a maquina, ou a pessoa ao lado que pega o telefone?".
##
## Convencao, valida para todos os jogos de mesa de N assentos:
##
##   - indice 0 e sempre a cadeira de baixo da mesa: em rede, e quem ABRIU a
##     sala (`NetworkManager.local_seat == 1`); fora da rede, e a pessoa
##     deste aparelho;
##   - em rede, indice 1 e quem ENTROU na sala (`local_seat == 2`). Nos dois
##     aparelhos a mesa e a MESMA: no aparelho do convidado o indice 0 e
##     REMOTE e o 1 e LOCAL;
##   - o que sobra e maquina (`AI`) ou, fora da rede e sem maquina, a pessoa
##     ao lado (`PASS`, passa-e-joga).
##
## A rede e de dois aparelhos (`NetworkManager`). Os assentos de maquina numa
## mesa em rede sao calculados SO no aparelho que abriu a sala e viajam como
## jogada (`MatchSync`); o convidado os aplica sem pensar. E o que
## `ai_runs_here()` e `expects_from_network()` respondem.

enum Kind {
	LOCAL,   ## A pessoa deste aparelho.
	REMOTE,  ## A pessoa do outro aparelho.
	AI,      ## A maquina.
	PASS,    ## Outra pessoa neste aparelho (passa-e-joga).
}

var count: int = 2
var kinds: Array[int] = []


## Monta a mesa para `seats` cadeiras.
##
## `net_active` e `net_seat` sao `BaseGame.net_active()` e `BaseGame.net_seat()`;
## `vs_ai` so importa fora da rede: falso poe pessoas ao lado nas cadeiras
## restantes em vez da maquina.
static func build(seats: int, net_active: bool, net_seat: int, vs_ai: bool = true) -> SeatTable:
	var mesa := SeatTable.new()
	mesa.count = maxi(seats, 1)
	mesa.kinds.resize(mesa.count)
	for i in mesa.count:
		mesa.kinds[i] = Kind.AI if vs_ai else Kind.PASS
	if net_active and mesa.count >= 2:
		mesa.kinds[0] = Kind.LOCAL if net_seat == 1 else Kind.REMOTE
		mesa.kinds[1] = Kind.REMOTE if net_seat == 1 else Kind.LOCAL
		# Em rede o que sobra e sempre maquina: nao ha terceira pessoa na mesa.
		for i in range(2, mesa.count):
			mesa.kinds[i] = Kind.AI
	else:
		mesa.kinds[0] = Kind.LOCAL
	return mesa


## Atalho para quem ja tem o jogo em maos: le a rede do proprio `BaseGame`.
static func for_game(game: BaseGame, seats: int, vs_ai: bool = true) -> SeatTable:
	return build(seats, game.net_active(), game.net_seat(), vs_ai)


func kind_of(i: int) -> int:
	if i < 0 or i >= count:
		return Kind.AI
	return kinds[i]


func is_local(i: int) -> bool:
	return kind_of(i) == Kind.LOCAL


func is_remote(i: int) -> bool:
	return kind_of(i) == Kind.REMOTE


func is_ai(i: int) -> bool:
	return kind_of(i) == Kind.AI


func is_pass(i: int) -> bool:
	return kind_of(i) == Kind.PASS


## Gente, em qualquer aparelho.
func is_human(i: int) -> bool:
	return not is_ai(i)


## A cadeira da pessoa deste aparelho.
func local_index() -> int:
	return kinds.find(Kind.LOCAL)


## A cadeira do outro aparelho, ou -1 fora da rede.
func remote_index() -> int:
	return kinds.find(Kind.REMOTE)


## Ha outro aparelho na mesa?
func online() -> bool:
	return remote_index() != -1


## Em rede, quem abriu a sala manda: e o unico que calcula a maquina e sorteia.
func is_host() -> bool:
	return online() and local_index() == 0


## Este aparelho pensa pela maquina desta cadeira? Fora da rede, sempre; em
## rede, so quem abriu a sala.
func ai_runs_here(i: int) -> bool:
	return is_ai(i) and (not online() or is_host())


## Este aparelho produz a jogada desta cadeira (pessoa daqui, pessoa ao lado
## ou maquina calculada aqui).
func acts_here(i: int) -> bool:
	return is_local(i) or is_pass(i) or ai_runs_here(i)


## A jogada desta cadeira chega pela rede, vinda do outro aparelho.
func expects_from_network(i: int) -> bool:
	return online() and not acts_here(i)


## Ha mais de uma pessoa neste aparelho (passa-e-joga)?
func pass_and_play() -> bool:
	return kinds.has(Kind.PASS)


func human_count() -> int:
	var n := 0
	for k in kinds:
		if k != Kind.AI:
			n += 1
	return n


## A proxima cadeira no sentido `dir` (+1 horario, -1 anti-horario).
func next(i: int, dir: int = 1) -> int:
	return posmod(i + (1 if dir >= 0 else -1), count)


## Cadeiras alternadas formam times: 0 e 2 contra 1 e 3.
func team_of(i: int) -> int:
	return i % 2


## O parceiro na mesa de quatro (0 <-> 2, 1 <-> 3); -1 quando nao ha duplas.
func partner_of(i: int) -> int:
	if count != 4:
		return -1
	return (i + 2) % count


func opponents_of(i: int) -> Array[int]:
	var saida: Array[int] = []
	for j in count:
		if j != i and (count != 4 or team_of(j) != team_of(i)):
			saida.append(j)
	return saida


## Chave de traducao do nome curto da cadeira, para HUD e placar. `NET_YOU` e a
## pessoa daqui; o outro aparelho usa o nome dele (`BaseGame.net_opponent_name`),
## por isso devolve vazio; a maquina e a pessoa ao lado usam chaves genericas
## que ja existem no CSV.
func label_key(i: int) -> String:
	match kind_of(i):
		Kind.LOCAL:
			return "NET_YOU"
		Kind.REMOTE:
			return ""
		Kind.PASS:
			return "SEAT_PLAYER_N"
		_:
			return "SEAT_AI_N"


## Descricao da cadeira ja traduzida: "Voce", o nome do outro aparelho,
## "Jogador 3", "IA 2". `numero` e o que aparece no rotulo generico.
func display_name(i: int, game: BaseGame) -> String:
	match kind_of(i):
		Kind.LOCAL:
			return game.tr("NET_YOU")
		Kind.REMOTE:
			return game.net_opponent_name()
		Kind.PASS:
			return game.tr("SEAT_PLAYER_N") % (i + 1)
		_:
			return game.tr("SEAT_AI_N") % _ai_ordinal(i)


## A maquina desta cadeira e a primeira, a segunda... contando so as maquinas.
func _ai_ordinal(i: int) -> int:
	var n := 0
	for j in range(i + 1):
		if is_ai(j):
			n += 1
	return n
