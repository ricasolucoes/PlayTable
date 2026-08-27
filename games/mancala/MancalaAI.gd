class_name MancalaAI
extends RefCounted

## A cabeca da IA do Mancala (Kalah): negamax com poda alfa-beta.
##
## O que havia antes era `valid_pits.pick_random()` -- a IA sorteava a cova.
## Num jogo em que a jogada gulosa e uma linha de codigo ("terminar na propria
## Kalah da turno extra"), sortear significa jogar abaixo de qualquer jogador
## que tenha notado a regra na primeira partida.
##
## O turno extra e o que faz o Mancala valer uma busca de verdade: uma sequencia
## de covas bem escolhida encadeia varios turnos seguidos e esvazia meio
## tabuleiro antes de o outro lado tocar numa gema. Por isso o turno extra
## **nao troca o lado na busca** -- ele continua o mesmo no, com o mesmo sinal.
## Uma busca que trocasse o lado a cada jogada nunca enxergaria o encadeamento.
##
## Covas 0-5 do jogador, 6 e a Kalah do jogador; 7-12 da IA, 13 a Kalah da IA.
## A mesma numeracao que `MancalaGame` usa.

const COVAS := 14
const KALAH_JOGADOR := 6
const KALAH_IA := 13

## Vitoria/derrota. Longe o bastante de qualquer diferenca de gemas.
const VITORIA := 100000

## Gema na propria Kalah esta guardada: ninguem mais a captura.
const PESO_KALAH := 10

## Gema do proprio lado ainda pode ser semeada -- e capturada.
const PESO_LADO := 1

## Cova propria vazia com gema na cova oposta e captura esperando acontecer.
const PESO_CAPTURA_ARMADA := 2

## Perfil de cada degrau, no mesmo formato da `CheckersAI`. Quem para a busca e
## o orcamento de nos; `depth` e so um teto de seguranca.
const PERFIS := [
	{"depth": 1, "nos": 40, "erro": 0.80, "ruido": 14},       # 1
	{"depth": 2, "nos": 120, "erro": 0.55, "ruido": 10},      # 2
	{"depth": 3, "nos": 320, "erro": 0.38, "ruido": 7},       # 3
	{"depth": 4, "nos": 800, "erro": 0.25, "ruido": 5},       # 4
	{"depth": 6, "nos": 1800, "erro": 0.16, "ruido": 4},      # 5
	{"depth": 8, "nos": 3600, "erro": 0.10, "ruido": 3},      # 6
	{"depth": 10, "nos": 6500, "erro": 0.05, "ruido": 2},     # 7
	{"depth": 12, "nos": 11000, "erro": 0.02, "ruido": 0},    # 8
	{"depth": 14, "nos": 17000, "erro": 0.0, "ruido": 0},     # 9
	{"depth": 18, "nos": 26000, "erro": 0.0, "ruido": 0},     # 10
]


## Copia plana do tabuleiro da cena.
static func achatar(pits: Array) -> PackedInt32Array:
	var copia := PackedInt32Array()
	copia.resize(COVAS)
	for i in range(COVAS):
		copia[i] = int(pits[i])
	return copia


## As covas que `lado` pode semear. `lado` e 0 para o jogador, 1 para a IA.
static func gerar(pits: PackedInt32Array, lado: int) -> PackedInt32Array:
	var base := 0 if lado == 0 else 7
	var saida := PackedInt32Array()
	# Da cova mais adiantada para a mais atrasada: a que termina na Kalah e a
	# que costuma ser boa, e ve-la primeiro faz a poda fechar mais ramo.
	for i in range(5, -1, -1):
		if pits[base + i] > 0:
			saida.append(base + i)
	return saida


## Semeia a cova e devolve `true` se o lado ganhou turno extra.
##
## Cobre as tres regras que a IA antiga ignorava: pular a Kalah do adversario,
## turno extra ao terminar na propria Kalah, e captura ao terminar em cova
## propria vazia com gema na cova oposta.
static func semear(pits: PackedInt32Array, cova: int, lado: int) -> bool:
	var minha_kalah := KALAH_JOGADOR if lado == 0 else KALAH_IA
	var sua_kalah := KALAH_IA if lado == 0 else KALAH_JOGADOR
	var primeira := 0 if lado == 0 else 7
	var ultima := 5 if lado == 0 else 12

	var gemas := pits[cova]
	pits[cova] = 0
	var atual := cova
	while gemas > 0:
		atual = (atual + 1) % COVAS
		if atual == sua_kalah:
			continue
		pits[atual] += 1
		gemas -= 1

	if atual == minha_kalah:
		return true

	# Captura: ultima gema em cova propria que estava vazia, e a cova oposta
	# tem gema. A cova oposta de `i` e `12 - i`.
	if atual >= primeira and atual <= ultima and pits[atual] == 1:
		var oposta := 12 - atual
		if pits[oposta] > 0:
			pits[minha_kalah] += pits[oposta] + 1
			pits[oposta] = 0
			pits[atual] = 0

	return false


## Verdadeiro quando um dos lados ficou sem gema para semear.
static func acabou(pits: PackedInt32Array) -> bool:
	var jogador := 0
	var ia := 0
	for i in range(6):
		jogador += pits[i]
		ia += pits[7 + i]
	return jogador == 0 or ia == 0


## Recolhe as gemas que sobraram para a Kalah de quem ainda as tem. E a regra
## de fechamento do Kalah -- sem ela a nota do fim de partida esta errada.
static func varrer(pits: PackedInt32Array) -> void:
	var jogador := 0
	var ia := 0
	for i in range(6):
		jogador += pits[i]
		ia += pits[7 + i]
	if jogador > 0 and ia > 0:
		return
	for i in range(6):
		pits[KALAH_JOGADOR] += pits[i]
		pits[i] = 0
		pits[KALAH_IA] += pits[7 + i]
		pits[7 + i] = 0


## Nota do tabuleiro pelos olhos de `lado`. Positivo e bom para `lado`.
static func evaluate(pits: PackedInt32Array, lado: int) -> int:
	var minha_kalah := KALAH_JOGADOR if lado == 0 else KALAH_IA
	var sua_kalah := KALAH_IA if lado == 0 else KALAH_JOGADOR
	var primeira := 0 if lado == 0 else 7
	var sua_primeira := 7 if lado == 0 else 0

	if acabou(pits):
		var fim := pits.duplicate()
		varrer(fim)
		var d := fim[minha_kalah] - fim[sua_kalah]
		if d > 0:
			return VITORIA + d
		if d < 0:
			return -VITORIA + d
		return 0

	var nota := PESO_KALAH * (pits[minha_kalah] - pits[sua_kalah])

	for i in range(6):
		nota += PESO_LADO * (pits[primeira + i] - pits[sua_primeira + i])
		# Cova minha vazia com gema na frente do adversario: captura armada.
		if pits[primeira + i] == 0 and pits[12 - (primeira + i)] > 0:
			nota += PESO_CAPTURA_ARMADA
		if pits[sua_primeira + i] == 0 and pits[12 - (sua_primeira + i)] > 0:
			nota -= PESO_CAPTURA_ARMADA

	return nota


## A cova que a IA semeia no degrau pedido, ou -1 se nao ha jogada.
static func choose_pit(pits: PackedInt32Array, lado: int, level: int) -> int:
	var covas := gerar(pits, lado)
	if covas.is_empty():
		return -1
	if covas.size() == 1:
		return covas[0]

	var perfil: Dictionary = PERFIS[clampi(level, 1, PERFIS.size()) - 1]
	if randf() < float(perfil["erro"]):
		return covas[randi() % covas.size()]

	var estado := {
		"nos": 0,
		"teto": int(perfil["nos"]),
		"estourou": false,
		"ruido": int(perfil["ruido"]),
	}

	var melhores: Array[int] = [covas[0]]
	var alvo := int(perfil["depth"])
	for profundidade in range(1, alvo + 1):
		var rodada := _raiz(pits, lado, covas, profundidade, estado)
		if estado["estourou"]:
			break
		melhores = rodada

	return melhores[randi() % melhores.size()]


## Ponte para o WorkerThreadPool: escreve a cova em `saida`.
static func pensar_em_tarefa(pits: PackedInt32Array, lado: int, level: int, saida: Array) -> void:
	saida.append(choose_pit(pits, lado, level))


static func _raiz(pits: PackedInt32Array, lado: int, covas: PackedInt32Array,
		profundidade: int, estado: Dictionary) -> Array[int]:
	var melhores: Array[int] = [covas[0]]
	var melhor_nota := -VITORIA * 2
	var alfa := -VITORIA * 2

	for cova in covas:
		var antes := pits.duplicate()
		var extra := semear(pits, cova, lado)
		var nota := 0
		if acabou(pits):
			nota = evaluate(pits, lado)
		elif extra:
			# Turno extra: continua o mesmo lado, sem trocar o sinal.
			nota = _buscar(pits, lado, profundidade - 1, alfa, VITORIA * 2, 1, estado)
		else:
			nota = -_buscar(pits, 1 - lado, profundidade - 1, -VITORIA * 2, -alfa, 1, estado)
		_restaurar(pits, antes)
		if estado["estourou"]:
			break
		if int(estado["ruido"]) > 0:
			nota += randi_range(-int(estado["ruido"]), int(estado["ruido"]))
		if nota > melhor_nota:
			melhor_nota = nota
			melhores = [cova]
			alfa = maxi(alfa, nota)
		elif nota == melhor_nota:
			melhores.append(cova)

	return melhores


static func _buscar(pits: PackedInt32Array, lado: int, profundidade: int, alfa: int, beta: int,
		ply: int, estado: Dictionary) -> int:
	estado["nos"] = int(estado["nos"]) + 1
	if int(estado["nos"]) >= int(estado["teto"]):
		estado["estourou"] = true
		return evaluate(pits, lado)

	if acabou(pits):
		return evaluate(pits, lado)
	if profundidade <= 0:
		return evaluate(pits, lado)

	var covas := gerar(pits, lado)
	if covas.is_empty():
		return evaluate(pits, lado)

	var a := alfa
	var melhor := -VITORIA * 2
	for cova in covas:
		var antes := pits.duplicate()
		var extra := semear(pits, cova, lado)
		var nota := 0
		if acabou(pits):
			nota = evaluate(pits, lado)
		elif extra:
			nota = _buscar(pits, lado, profundidade - 1, a, beta, ply + 1, estado)
		else:
			nota = -_buscar(pits, 1 - lado, profundidade - 1, -beta, -a, ply + 1, estado)
		_restaurar(pits, antes)
		if estado["estourou"]:
			return melhor if melhor > -VITORIA * 2 else nota
		melhor = maxi(melhor, nota)
		a = maxi(a, melhor)
		if a >= beta:
			break
	return melhor


static func _restaurar(pits: PackedInt32Array, antes: PackedInt32Array) -> void:
	for i in range(COVAS):
		pits[i] = antes[i]
