class_name WarRules
extends RefCounted

## Regras da Guerra: o mapa, o estado plano da partida e as jogadas.
##
## Tudo aqui e estatico e puro -- nenhum no, nenhum `tr()`. O estado da
## partida e um dicionario de arrays simples (dono e exercitos por
## territorio, fase, objetivos), o que o deixa igual nos dois aparelhos de
## uma partida em rede e barato de copiar para a IA pensar em cima.
##
## O mapa e ficticio, com 24 territorios em 6 continentes de 4, sobre uma
## grade hexagonal de 5 colunas por 6 fileiras cabivel numa tela de retrato.
## A coluna do meio das fileiras pares fica vazia: e o "rio" que separa o
## lado oeste do leste, com tres travessias (as fileiras impares). Vizinhanca
## sai da distancia entre centros, entao e simetrica por construcao.
##
## O que ficou de fora, de proposito: cartas de troca. Elas existem para
## alongar partidas de 42 territorios; aqui o mapa tem 24 e o jogo dura o que
## uma rodada de telefone aguenta. O reforco inicial tambem e automatico
## (sorteado com o gerador da partida) para a partida comecar na acao.

const N_TERR := 24
const MIN_JOGADORES := 3
const MAX_JOGADORES := 6
const JOGADORES_PADRAO := 4

## Territorios que cumprem o objetivo "conquistar N". No jogo de 42 sao 18
## (43%) ou 24 (57%); aqui 14 de 24 (58%) fica no mesmo espirito.
const OBJETIVO_TERRITORIOS := 14
## O objetivo "um continente inteiro mais N territorios no total".
const OBJETIVO_CONT1_TERR := 11

const MAX_DADOS_ATAQUE := 3
const MAX_DADOS_DEFESA := 2
const REFORCO_MINIMO := 3

## Exercitos extras alem do 1 por territorio, por mesa. Menos gente na mesa,
## mais territorios cada um -- e mais exercitos para os defender.
const REFORCO_INICIAL := {3: 8, 4: 6, 5: 5, 6: 4}

## Grade hexagonal: colunas a 1,2 de distancia, fileiras a 1,04 (1,2 x 0,866),
## fileiras impares deslocadas meia coluna. Todo vizinho fica a 1,2 do centro.
const ESPACO_X := 1.2
const ESPACO_Z := 1.04
const RAIO_HEX := 0.52
const DIST_VIZINHO := 1.3

const FASE_REFORCO := "reinforce"
const FASE_ATAQUE := "attack"
const FASE_REMANEJO := "fortify"
const FASE_FIM := "over"

const CONTINENTES := [
	{"key": "GUERRA_C_BOREAL", "bonus": 2, "color": Color(0.36, 0.48, 0.62)},
	{"key": "GUERRA_C_ORIENTE", "bonus": 2, "color": Color(0.58, 0.30, 0.30)},
	{"key": "GUERRA_C_OCIDENTE", "bonus": 3, "color": Color(0.44, 0.52, 0.26)},
	{"key": "GUERRA_C_ESTEPES", "bonus": 3, "color": Color(0.66, 0.50, 0.22)},
	{"key": "GUERRA_C_AUSTRAL", "bonus": 2, "color": Color(0.24, 0.46, 0.36)},
	{"key": "GUERRA_C_ILHAS", "bonus": 2, "color": Color(0.24, 0.46, 0.54)},
]

## `c` e o continente; `x`/`z` o centro na laje (o mapa e centrado na origem).
const TERRITORIOS := [
	{"key": "GUERRA_T_NEVOA", "c": 0, "x": -2.4, "z": -2.6},
	{"key": "GUERRA_T_GELO_ALTO", "c": 0, "x": -1.2, "z": -2.6},
	{"key": "GUERRA_T_FIORDE", "c": 0, "x": -1.8, "z": -1.56},
	{"key": "GUERRA_T_PINHEIRAL", "c": 0, "x": -0.6, "z": -1.56},
	{"key": "GUERRA_T_LOTUS", "c": 1, "x": 1.2, "z": -2.6},
	{"key": "GUERRA_T_SOL_NASCENTE", "c": 1, "x": 2.4, "z": -2.6},
	{"key": "GUERRA_T_JADE", "c": 1, "x": 0.6, "z": -1.56},
	{"key": "GUERRA_T_MONCAO", "c": 1, "x": 1.8, "z": -1.56},
	{"key": "GUERRA_T_CABO_BRAVO", "c": 2, "x": -2.4, "z": -0.52},
	{"key": "GUERRA_T_COLINAS_RUBRAS", "c": 2, "x": -1.2, "z": -0.52},
	{"key": "GUERRA_T_BAIA_CINZA", "c": 2, "x": -1.8, "z": 0.52},
	{"key": "GUERRA_T_LAGO_ESPELHO", "c": 2, "x": -0.6, "z": 0.52},
	{"key": "GUERRA_T_PEDRA_NEGRA", "c": 3, "x": 1.2, "z": -0.52},
	{"key": "GUERRA_T_TORRE_ALTA", "c": 3, "x": 2.4, "z": -0.52},
	{"key": "GUERRA_T_ENCRUZILHADA", "c": 3, "x": 0.6, "z": 0.52},
	{"key": "GUERRA_T_VENTO_LESTE", "c": 3, "x": 1.8, "z": 0.52},
	{"key": "GUERRA_T_VALE_VERDE", "c": 4, "x": -2.4, "z": 1.56},
	{"key": "GUERRA_T_SAVANA", "c": 4, "x": -1.2, "z": 1.56},
	{"key": "GUERRA_T_CABO_SUL", "c": 4, "x": -1.8, "z": 2.6},
	{"key": "GUERRA_T_DUNAS", "c": 4, "x": -0.6, "z": 2.6},
	{"key": "GUERRA_T_RECIFE", "c": 5, "x": 1.2, "z": 1.56},
	{"key": "GUERRA_T_FAROL", "c": 5, "x": 2.4, "z": 1.56},
	{"key": "GUERRA_T_ATOL", "c": 5, "x": 0.6, "z": 2.6},
	{"key": "GUERRA_T_CORAL", "c": 5, "x": 1.8, "z": 2.6},
]

## Pares de continentes dos objetivos "dois continentes inteiros".
const PARES_DE_CONTINENTES := [[0, 4], [1, 5], [0, 5], [1, 4], [0, 1], [4, 5]]

static var _vizinhos: Array = []


# ------------------------------------------------------------------ o mapa

static func position_of(i: int) -> Vector2:
	var t: Dictionary = TERRITORIOS[i]
	return Vector2(float(t["x"]), float(t["z"]))


static func continent_of(i: int) -> int:
	return int(TERRITORIOS[i]["c"])


static func territories_of(c: int) -> Array[int]:
	var saida: Array[int] = []
	for i in N_TERR:
		if continent_of(i) == c:
			saida.append(i)
	return saida


## Vizinhos de `i`. Calculados uma vez pela distancia entre centros: dois
## hexagonos a menos de `DIST_VIZINHO` se tocam.
static func neighbors(i: int) -> Array[int]:
	if _vizinhos.is_empty():
		_montar_vizinhos()
	var saida: Array[int] = []
	saida.assign(_vizinhos[i])
	return saida


static func are_adjacent(i: int, j: int) -> bool:
	if i == j or i < 0 or j < 0 or i >= N_TERR or j >= N_TERR:
		return false
	return j in neighbors(i)


static func _montar_vizinhos() -> void:
	_vizinhos.clear()
	for i in N_TERR:
		var lista: Array = []
		for j in N_TERR:
			if i != j and position_of(i).distance_to(position_of(j)) <= DIST_VIZINHO:
				lista.append(j)
		_vizinhos.append(lista)


## O retangulo que os centros ocupam, para a laje e o enquadramento.
static func map_bounds() -> Rect2:
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for i in N_TERR:
		var p := position_of(i)
		minimo = Vector2(minf(minimo.x, p.x), minf(minimo.y, p.y))
		maximo = Vector2(maxf(maximo.x, p.x), maxf(maximo.y, p.y))
	return Rect2(minimo, maximo - minimo)


# --------------------------------------------------------------- a partida

## Estado novo para `n` jogadores. Os territorios sao sorteados com `rng` --
## o gerador da partida, o mesmo nos dois aparelhos -- e cada um recebe um
## exercito; o reforco inicial cai em territorios proprios ao acaso.
static func new_game(n: int, rng: RandomNumberGenerator) -> Dictionary:
	n = clampi(n, MIN_JOGADORES, MAX_JOGADORES)
	var owner: Array[int] = []
	var armies: Array[int] = []
	owner.resize(N_TERR)
	armies.resize(N_TERR)
	var ordem: Array = range(N_TERR)
	MatchSync.shuffle_with(ordem, rng)
	for k in N_TERR:
		owner[ordem[k]] = k % n
		armies[ordem[k]] = 1

	var alive: Array[bool] = []
	var eliminated_by: Array[int] = []
	for s in n:
		alive.append(true)
		eliminated_by.append(-1)

	var estado := {
		"n": n,
		"owner": owner,
		"armies": armies,
		"alive": alive,
		"eliminated_by": eliminated_by,
		"objectives": make_objectives(n, rng),
		"turn": 0,
		"phase": FASE_REFORCO,
		"pending": 0,
		"move": {},
		"fortify_pair": [],
		"winner": -1,
		"win_by": "",
		"round": 1,
		"turns": 0,
		"attacks": 0,
		"last": {},
	}

	var extra := int(REFORCO_INICIAL.get(n, 4))
	for s in n:
		var meus := territories_owned(estado, s)
		for _e in extra:
			var alvo: int = meus[rng.randi_range(0, meus.size() - 1)]
			armies[alvo] += 1

	estado["pending"] = reinforcements_for(estado, 0)
	return estado


## Um objetivo por cadeira, tirado de um baralho embaralhado com `rng`. Quem
## tira "eliminar a si mesmo" recebe o objetivo de territorios no lugar.
static func make_objectives(n: int, rng: RandomNumberGenerator) -> Array:
	var baralho: Array = [
		{"t": "terr", "n": OBJETIVO_TERRITORIOS},
		{"t": "terr", "n": OBJETIVO_TERRITORIOS},
	]
	for par in PARES_DE_CONTINENTES:
		baralho.append({"t": "cont2", "a": int(par[0]), "b": int(par[1])})
	for c in CONTINENTES.size():
		baralho.append({"t": "cont1", "c": c, "n": OBJETIVO_CONT1_TERR})
	for s in n:
		baralho.append({"t": "elim", "p": s})
	MatchSync.shuffle_with(baralho, rng)
	var saida: Array = []
	for s in n:
		var obj: Dictionary = (baralho[s] as Dictionary).duplicate()
		if str(obj["t"]) == "elim" and int(obj["p"]) == s:
			obj = {"t": "terr", "n": OBJETIVO_TERRITORIOS}
		saida.append(obj)
	return saida


static func territories_owned(state: Dictionary, seat: int) -> Array[int]:
	var saida: Array[int] = []
	var owner: Array = state["owner"]
	for i in N_TERR:
		if int(owner[i]) == seat:
			saida.append(i)
	return saida


static func count_territories(state: Dictionary, seat: int) -> int:
	return territories_owned(state, seat).size()


static func count_armies(state: Dictionary, seat: int) -> int:
	var total := 0
	var owner: Array = state["owner"]
	var armies: Array = state["armies"]
	for i in N_TERR:
		if int(owner[i]) == seat:
			total += int(armies[i])
	return total


static func owns_continent(state: Dictionary, seat: int, c: int) -> bool:
	var owner: Array = state["owner"]
	for i in territories_of(c):
		if int(owner[i]) != seat:
			return false
	return true


static func continents_owned(state: Dictionary, seat: int) -> Array[int]:
	var saida: Array[int] = []
	for c in CONTINENTES.size():
		if owns_continent(state, seat, c):
			saida.append(c)
	return saida


## Quantos exercitos a cadeira recebe no comeco da vez: um terco dos
## territorios (no minimo tres) mais o bonus de cada continente inteiro.
static func reinforcements_for(state: Dictionary, seat: int) -> int:
	var total: int = maxi(REFORCO_MINIMO, count_territories(state, seat) / 3)
	for c in continents_owned(state, seat):
		total += int(CONTINENTES[c]["bonus"])
	return total


static func alive_count(state: Dictionary) -> int:
	var n := 0
	for v in state["alive"]:
		if bool(v):
			n += 1
	return n


## A proxima cadeira viva depois de `seat`.
static func next_alive(state: Dictionary, seat: int) -> int:
	var n := int(state["n"])
	var alive: Array = state["alive"]
	for k in range(1, n + 1):
		var s := (seat + k) % n
		if bool(alive[s]):
			return s
	return seat


# ---------------------------------------------------------------- ataques

static func enemy_neighbors(state: Dictionary, i: int) -> Array[int]:
	var saida: Array[int] = []
	var owner: Array = state["owner"]
	for j in neighbors(i):
		if int(owner[j]) != int(owner[i]):
			saida.append(j)
	return saida


static func friendly_neighbors(state: Dictionary, i: int) -> Array[int]:
	var saida: Array[int] = []
	var owner: Array = state["owner"]
	for j in neighbors(i):
		if int(owner[j]) == int(owner[i]):
			saida.append(j)
	return saida


## Territorio proprio com dois ou mais exercitos e um inimigo ao lado.
static func can_attack_from(state: Dictionary, seat: int, i: int) -> bool:
	if i < 0 or i >= N_TERR or int(state["owner"][i]) != seat:
		return false
	if int(state["armies"][i]) < 2:
		return false
	return not enemy_neighbors(state, i).is_empty()


static func attack_sources(state: Dictionary, seat: int) -> Array[int]:
	var saida: Array[int] = []
	for i in territories_owned(state, seat):
		if can_attack_from(state, seat, i):
			saida.append(i)
	return saida


static func attack_dice_count(state: Dictionary, from: int) -> int:
	return clampi(int(state["armies"][from]) - 1, 0, MAX_DADOS_ATAQUE)


static func defend_dice_count(state: Dictionary, to: int) -> int:
	return clampi(int(state["armies"][to]), 0, MAX_DADOS_DEFESA)


## O confronto classico: maiores contra maiores, empate para o defensor.
static func resolve_dice(a: Array, d: Array) -> Dictionary:
	var atk: Array = a.duplicate()
	var def: Array = d.duplicate()
	atk.sort()
	atk.reverse()
	def.sort()
	def.reverse()
	var a_lost := 0
	var d_lost := 0
	for k in mini(atk.size(), def.size()):
		if int(atk[k]) > int(def[k]):
			d_lost += 1
		else:
			a_lost += 1
	return {"a_lost": a_lost, "d_lost": d_lost}


static func _dados_validos(v: Variant, esperado: int) -> bool:
	if not (v is Array) or (v as Array).size() != esperado:
		return false
	for x in v:
		if not (x is int or x is float) or int(x) < 1 or int(x) > 6:
			return false
	return true


static func _terr_valido(v: Variant) -> bool:
	return (v is int or v is float) and int(v) >= 0 and int(v) < N_TERR


# ----------------------------------------------------------------- jogadas

## Aplica uma jogada da cadeira `seat`. Devolve falso -- e nao mexe em nada --
## quando ela e ilegal: fora de vez, fora de fase, territorio alheio, dados
## a mais ou a menos. E a mesma funcao para a pessoa, a IA e o outro aparelho.
##
## `state["last"]` fica com o que aconteceu, para a cena animar e a
## gamificacao saber o que contar.
static func apply(state: Dictionary, seat: int, action: Dictionary) -> bool:
	if state.is_empty() or str(state["phase"]) == FASE_FIM:
		return false
	if seat != int(state["turn"]) or not bool(state["alive"][seat]):
		return false
	var fase := str(state["phase"])
	match str(action.get("t", "")):
		"reinforce":
			return _reforcar(state, seat, action, fase)
		"attack":
			return _atacar(state, seat, action, fase)
		"move":
			return _mover(state, seat, action, fase)
		"fortify":
			return _remanejar(state, seat, action, fase)
		"end":
			return _encerrar_fase(state, seat, fase)
	return false


static func _reforcar(state: Dictionary, seat: int, action: Dictionary, fase: String) -> bool:
	if fase != FASE_REFORCO:
		return false
	var terr: Variant = action.get("terr", -1)
	var n := int(action.get("n", 0))
	if not _terr_valido(terr) or int(state["owner"][int(terr)]) != seat:
		return false
	if n < 1 or n > int(state["pending"]):
		return false
	state["armies"][int(terr)] += n
	state["pending"] = int(state["pending"]) - n
	state["last"] = {"t": "reinforce", "terr": int(terr), "n": n}
	return true


static func _atacar(state: Dictionary, seat: int, action: Dictionary, fase: String) -> bool:
	if fase != FASE_ATAQUE:
		return false
	var from_v: Variant = action.get("from", -1)
	var to_v: Variant = action.get("to", -1)
	if not _terr_valido(from_v) or not _terr_valido(to_v):
		return false
	var from := int(from_v)
	var to := int(to_v)
	var owner: Array = state["owner"]
	var armies: Array = state["armies"]
	if int(owner[from]) != seat or int(owner[to]) == seat or not are_adjacent(from, to):
		return false
	if int(armies[from]) < 2:
		return false
	var a: Variant = action.get("a", [])
	var d: Variant = action.get("d", [])
	if not _dados_validos(a, attack_dice_count(state, from)):
		return false
	if not _dados_validos(d, defend_dice_count(state, to)):
		return false

	var r := resolve_dice(a, d)
	state["attacks"] = int(state.get("attacks", 0)) + 1
	armies[from] = int(armies[from]) - int(r["a_lost"])
	armies[to] = int(armies[to]) - int(r["d_lost"])
	state["move"] = {}
	var defensor := int(owner[to])
	var conquistou := int(armies[to]) <= 0
	var eliminado := -1
	var fechou := -1
	var movidos := 0
	if conquistou:
		owner[to] = seat
		# A regra classica: entram pelo menos tantos exercitos quantos dados
		# rolaram, sempre deixando um atras.
		movidos = clampi((a as Array).size(), 1, int(armies[from]) - 1)
		armies[to] = movidos
		armies[from] = int(armies[from]) - movidos
		state["move"] = {"from": from, "to": to}
		if owns_continent(state, seat, continent_of(to)):
			fechou = continent_of(to)
		if count_territories(state, defensor) == 0:
			state["alive"][defensor] = false
			state["eliminated_by"][defensor] = seat
			eliminado = defensor
		if count_territories(state, seat) == N_TERR or alive_count(state) == 1:
			_vencer(state, seat, "domination")
	state["last"] = {
		"t": "attack", "from": from, "to": to,
		"a": (a as Array).duplicate(), "d": (d as Array).duplicate(),
		"a_lost": int(r["a_lost"]), "d_lost": int(r["d_lost"]),
		"conquered": conquistou, "moved": movidos,
		"defender": defensor, "eliminated": eliminado, "closed_continent": fechou,
	}
	return true


## Depois da conquista, leva mais exercitos para o territorio tomado. So vale
## enquanto nenhuma outra jogada foi feita.
static func _mover(state: Dictionary, seat: int, action: Dictionary, fase: String) -> bool:
	if fase != FASE_ATAQUE:
		return false
	var move: Dictionary = state["move"]
	if move.is_empty():
		return false
	var from := int(action.get("from", -1))
	var to := int(action.get("to", -1))
	var n := int(action.get("n", 0))
	if from != int(move["from"]) or to != int(move["to"]):
		return false
	var armies: Array = state["armies"]
	if int(state["owner"][from]) != seat or int(state["owner"][to]) != seat:
		return false
	if n < 1 or n > int(armies[from]) - 1:
		return false
	armies[from] = int(armies[from]) - n
	armies[to] = int(armies[to]) + n
	state["last"] = {"t": "move", "from": from, "to": to, "n": n}
	return true


## Um remanejamento por vez: o par de origem e destino fica travado depois
## do primeiro movimento, mas pode receber mais exercitos ate sobrar um.
static func _remanejar(state: Dictionary, seat: int, action: Dictionary, fase: String) -> bool:
	if fase != FASE_REMANEJO:
		return false
	var from_v: Variant = action.get("from", -1)
	var to_v: Variant = action.get("to", -1)
	if not _terr_valido(from_v) or not _terr_valido(to_v):
		return false
	var from := int(from_v)
	var to := int(to_v)
	var n := int(action.get("n", 0))
	var owner: Array = state["owner"]
	var armies: Array = state["armies"]
	if int(owner[from]) != seat or int(owner[to]) != seat or not are_adjacent(from, to):
		return false
	if n < 1 or n > int(armies[from]) - 1:
		return false
	var par: Array = state["fortify_pair"]
	if not par.is_empty() and (int(par[0]) != from or int(par[1]) != to):
		return false
	armies[from] = int(armies[from]) - n
	armies[to] = int(armies[to]) + n
	state["fortify_pair"] = [from, to]
	state["last"] = {"t": "fortify", "from": from, "to": to, "n": n}
	return true


## Fecha a fase corrente: reforco -> ataque (com tudo colocado), ataque ->
## remanejo, remanejo -> a vez passa. E no fim da propria vez que o objetivo
## e conferido.
static func _encerrar_fase(state: Dictionary, seat: int, fase: String) -> bool:
	match fase:
		FASE_REFORCO:
			if int(state["pending"]) > 0:
				return false
			state["phase"] = FASE_ATAQUE
		FASE_ATAQUE:
			state["phase"] = FASE_REMANEJO
			state["move"] = {}
		FASE_REMANEJO:
			_encerrar_vez(state, seat)
		_:
			return false
	state["last"] = {"t": "end", "phase": str(state["phase"])}
	return true


static func _encerrar_vez(state: Dictionary, seat: int) -> void:
	state["turns"] = int(state["turns"]) + 1
	if objective_met(state, seat):
		_vencer(state, seat, "objective")
		return
	var proximo := next_alive(state, seat)
	if proximo <= seat:
		state["round"] = int(state["round"]) + 1
	state["turn"] = proximo
	state["phase"] = FASE_REFORCO
	state["fortify_pair"] = []
	state["move"] = {}
	state["attacks"] = 0
	state["pending"] = reinforcements_for(state, proximo)


static func _vencer(state: Dictionary, seat: int, como: String) -> void:
	state["winner"] = seat
	state["win_by"] = como
	state["phase"] = FASE_FIM


# --------------------------------------------------------------- objetivos

## O objetivo como ele vale AGORA: "eliminar" alguem que outra pessoa ja
## eliminou vira o objetivo de territorios, como no jogo de mesa.
static func objective_effective(state: Dictionary, seat: int) -> Dictionary:
	var obj: Dictionary = state["objectives"][seat]
	if str(obj["t"]) == "elim":
		var p := int(obj["p"])
		if not bool(state["alive"][p]) and int(state["eliminated_by"][p]) != seat:
			return {"t": "terr", "n": OBJETIVO_TERRITORIOS}
	return obj


static func objective_met(state: Dictionary, seat: int) -> bool:
	var obj := objective_effective(state, seat)
	var meus := count_territories(state, seat)
	match str(obj["t"]):
		"terr":
			return meus >= int(obj["n"])
		"cont2":
			return owns_continent(state, seat, int(obj["a"])) and owns_continent(state, seat, int(obj["b"]))
		"cont1":
			return owns_continent(state, seat, int(obj["c"])) and meus >= int(obj["n"])
		"elim":
			var p := int(obj["p"])
			return not bool(state["alive"][p]) and int(state["eliminated_by"][p]) == seat
	return false


## Continentes que o objetivo pede, para a IA e para os aneis de dica.
static func objective_continents(state: Dictionary, seat: int) -> Array[int]:
	var obj := objective_effective(state, seat)
	var saida: Array[int] = []
	match str(obj["t"]):
		"cont2":
			saida.append(int(obj["a"]))
			saida.append(int(obj["b"]))
		"cont1":
			saida.append(int(obj["c"]))
	return saida


## A cadeira que o objetivo manda eliminar, ou -1.
static func objective_target(state: Dictionary, seat: int) -> int:
	var obj := objective_effective(state, seat)
	if str(obj["t"]) == "elim":
		return int(obj["p"])
	return -1


## Copia profunda o bastante para a IA simular sem sujar a partida.
static func clone(state: Dictionary) -> Dictionary:
	return state.duplicate(true)
