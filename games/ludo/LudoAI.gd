class_name LudoAI
extends RefCounted

## A cabeca das tres IAs do Ludo: avaliacao do tabuleiro que a jogada deixa.
##
## O que havia antes era `movable.pick_random()` -- e valia para os TRES
## adversarios. Elas passavam ao lado de captura de graca, deixavam peao
## parado na largada de outra cor e adiantavam o peao errado.
##
## Nao ha busca aqui, e de proposito: o Ludo anda por dado, e buscar dois
## lances a frente sobre um numero que ainda nao caiu e adivinhar. O que decide
## a partida e escolher bem entre as jogadas de agora.
##
## Posicoes: -1 e a base, 0..27 e a pista compartilhada, 28..32 e a reta final
## de cada cor. A mesma numeracao que `LudoGame` usa; peao em 32 chegou.

const TRACK_LENGTH := 28
const RETA_FINAL := 28
const CHEGADA := 32
const PEOES := 2

## Mandar peao adversario para a base vale o caminho inteiro que ele andou.
const PESO_CAPTURA := 30

## Cada casa andada em direcao a chegada.
const PESO_AVANCO := 3

## Peao que entrou na reta final nao pode mais ser capturado.
const PESO_RETA_FINAL := 45

## Peao que chegou. Ninguem o tira de la.
const PESO_CHEGADA := 90

## Peao ainda na base nao anda e nao ameaca: tirar um da base vale mais que
## adiantar quem ja esta na pista.
const PESO_SAIR_DA_BASE := 22

## Peao na pista ao alcance de um dado (1 a 6) de um adversario atras dele.
const PESO_AMEACADO := 12

## Perfil de cada degrau: chance de sortear a jogada, e ruido na nota.
const PERFIS := [
	{"erro": 0.85, "ruido": 70},   # 1
	{"erro": 0.70, "ruido": 55},   # 2
	{"erro": 0.55, "ruido": 42},   # 3
	{"erro": 0.42, "ruido": 32},   # 4
	{"erro": 0.30, "ruido": 24},   # 5
	{"erro": 0.20, "ruido": 16},   # 6
	{"erro": 0.12, "ruido": 10},   # 7
	{"erro": 0.06, "ruido": 5},    # 8
	{"erro": 0.02, "ruido": 0},    # 9
	{"erro": 0.0, "ruido": 0},     # 10
]


## Casa absoluta da pista em que o peao esta, ou -1 se ele nao esta na pista.
##
## Cada cor larga de um ponto diferente da mesma pista, e e por isso que dois
## peoes com a mesma posicao relativa podem estar em casas diferentes.
static func casa_absoluta(pos: int, jogador: int, offsets: Array) -> int:
	if pos < 0 or pos >= RETA_FINAL:
		return -1
	return (pos + int(offsets[jogador])) % TRACK_LENGTH


## Os peoes de `jogador` que podem andar `dado` casas.
##
## Mesma regra que `LudoGame`: sai da base so com 6, e nenhum peao passa da
## casa 32.
static func gerar(pawns: Array, jogador: int, dado: int) -> Array[int]:
	var moveis: Array[int] = []
	for idx in range(PEOES):
		var pos: int = int(pawns[jogador][idx])
		if pos == -1 and dado == 6:
			moveis.append(idx)
		elif pos >= 0 and pos + dado <= CHEGADA:
			moveis.append(idx)
	return moveis


## Onde o peao para depois de andar `dado`.
static func destino(pos: int, dado: int) -> int:
	return 0 if pos == -1 else pos + dado


## Quantos peoes adversarios a jogada manda para a base.
static func capturas(pawns: Array, jogador: int, idx: int, dado: int, offsets: Array) -> int:
	var alvo := destino(int(pawns[jogador][idx]), dado)
	var casa := casa_absoluta(alvo, jogador, offsets)
	if casa < 0:
		return 0
	var total := 0
	for outro in range(pawns.size()):
		if outro == jogador:
			continue
		for j in range(PEOES):
			var p: int = int(pawns[outro][j])
			if p >= 0 and p < RETA_FINAL and casa_absoluta(p, outro, offsets) == casa:
				total += 1
	return total


## Nota do tabuleiro pelos olhos de `jogador`. Positivo e bom para ele.
static func evaluate(pawns: Array, jogador: int, offsets: Array) -> int:
	var nota := 0
	for quem in range(pawns.size()):
		var meu := quem == jogador
		for idx in range(PEOES):
			var pos: int = int(pawns[quem][idx])
			var s := 0
			if pos == CHEGADA:
				# O bonus da chegada entra SOMADO ao da reta final e ao avanco:
				# sozinho ele ficava abaixo do peao parado na penultima casa, e
				# a IA preferia nao chegar.
				s = PESO_CHEGADA + PESO_RETA_FINAL + PESO_AVANCO * pos
			elif pos >= RETA_FINAL:
				s = PESO_RETA_FINAL + PESO_AVANCO * pos
			elif pos >= 0:
				s = PESO_SAIR_DA_BASE + PESO_AVANCO * pos
				# Adversario atras, ao alcance de um dado: sem casa segura, o
				# Ludo so tem distancia.
				var casa := casa_absoluta(pos, quem, offsets)
				for outro in range(pawns.size()):
					if outro == quem:
						continue
					for j in range(PEOES):
						var p: int = int(pawns[outro][j])
						if p < 0 or p >= RETA_FINAL:
							continue
						var dif := (casa - casa_absoluta(p, outro, offsets) + TRACK_LENGTH) % TRACK_LENGTH
						if dif >= 1 and dif <= 6:
							s -= PESO_AMEACADO
							break

			nota += s if meu else -s
	return nota


## O peao que a IA move no degrau pedido, ou -1 se nenhum pode andar.
static func choose_pawn(pawns: Array, jogador: int, dado: int, offsets: Array, level: int) -> int:
	var moveis := gerar(pawns, jogador, dado)
	if moveis.is_empty():
		return -1
	if moveis.size() == 1:
		return moveis[0]

	var perfil: Dictionary = PERFIS[clampi(level, 1, PERFIS.size()) - 1]
	if randf() < float(perfil["erro"]):
		return moveis[randi() % moveis.size()]

	var ruido := int(perfil["ruido"])
	var melhores: Array[int] = []
	var melhor_nota := -0x7FFFFFFF

	for idx in moveis:
		var copia := _copiar(pawns)
		var comeu := capturas(pawns, jogador, idx, dado, offsets)
		var alvo := destino(int(pawns[jogador][idx]), dado)
		copia[jogador][idx] = alvo
		if comeu > 0:
			var casa := casa_absoluta(alvo, jogador, offsets)
			for outro in range(copia.size()):
				if outro == jogador:
					continue
				for j in range(PEOES):
					var p: int = int(copia[outro][j])
					if p >= 0 and p < RETA_FINAL and casa_absoluta(p, outro, offsets) == casa:
						copia[outro][j] = -1

		var nota := evaluate(copia, jogador, offsets) + PESO_CAPTURA * comeu
		if ruido > 0:
			nota += randi_range(-ruido, ruido)

		if nota > melhor_nota:
			melhor_nota = nota
			melhores = [idx]
		elif nota == melhor_nota:
			melhores.append(idx)

	return melhores[randi() % melhores.size()]


static func _copiar(pawns: Array) -> Array:
	var copia: Array = []
	for lista in pawns:
		copia.append((lista as Array).duplicate())
	return copia
