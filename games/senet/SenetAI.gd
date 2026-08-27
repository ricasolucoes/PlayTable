class_name SenetAI
extends RefCounted

## A cabeca da IA do Senet: avaliacao do tabuleiro que a jogada deixa.
##
## O que havia antes era `ai_moves.pick_random()` -- a IA sorteava a jogada
## entre as legais. Ela afogava a propria peca na Casa da Agua de graca, deixava
## peca sozinha ao alcance do adversario e trocava de lugar com quem estava
## atras quando podia trocar com quem estava na frente.
##
## Nao ha busca aqui, e de proposito: o lance do Senet depende das varetas, que
## sao sorteadas. Buscar dois lances a frente sobre um dado que ainda nao caiu
## e gastar tempo para adivinhar. O que decide a partida e escolher bem entre
## as jogadas de agora, e para isso basta avaliar o tabuleiro que cada uma
## deixa -- que e o que esta classe faz.
##
## Casas numeradas de 1 a 30; 31 e a saida do tabuleiro. A mesma numeracao que
## `SenetGame` usa.

const CASAS := 30
const SAIDA := 31

## Casa da Agua: quem para nela afoga e volta para o Renascimento (15) ou para
## a primeira casa livre antes dele.
const AGUA := 27
const RENASCIMENTO := 15

## Sair do tabuleiro e o unico progresso que a partida nao desfaz.
const PESO_SAIDA := 260

## Cada casa andada em direcao a saida.
const PESO_AVANCO := 4

## Peca com vizinha da mesma cor nao pode ser trocada de lugar: e a unica
## defesa que o Senet tem.
const PESO_PROTEGIDA := 14

## Peca sozinha com adversario atras dela, ao alcance de um lance de 1 a 5.
const PESO_EXPOSTA := 11

## Trocar de lugar com o adversario: ele recua para onde a minha peca estava.
const PESO_TROCA := 9

## Afogar na Casa da Agua custa todo o caminho andado ate ali.
const PESO_AFOGAMENTO := 130

## As tres casas finais so liberam a saida com o lance exato; parar nelas cedo
## demais e ficar preso esperando o numero certo.
const PESO_CASA_FINAL := 8

## Perfil de cada degrau: chance de largar a avaliacao e sortear a jogada, e
## ruido somado a nota. Sem busca nao ha orcamento de nos para dosar.
const PERFIS := [
	{"erro": 0.85, "ruido": 90},   # 1
	{"erro": 0.70, "ruido": 70},   # 2
	{"erro": 0.55, "ruido": 55},   # 3
	{"erro": 0.42, "ruido": 42},   # 4
	{"erro": 0.30, "ruido": 30},   # 5
	{"erro": 0.20, "ruido": 20},   # 6
	{"erro": 0.12, "ruido": 12},   # 7
	{"erro": 0.06, "ruido": 6},    # 8
	{"erro": 0.02, "ruido": 0},    # 9
	{"erro": 0.0, "ruido": 0},     # 10
]


## Copia plana do tabuleiro da cena (`Dictionary` de 1 a 30).
static func achatar(board: Dictionary) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(CASAS + 2)   # indice 0 nao usado, 31 e a saida
	for sq in range(1, CASAS + 1):
		cells[sq] = int(board.get(sq, 0))
	return cells


## As jogadas legais de `lado` com o lance `passos`.
##
## Mesma regra que `SenetGame._get_valid_moves()`: casa vazia aceita, casa do
## adversario aceita como troca a menos que ele tenha vizinha da propria cor.
static func gerar(cells: PackedByteArray, lado: int, passos: int) -> Array[Dictionary]:
	var outro := 3 - lado
	var moves: Array[Dictionary] = []
	for sq in range(1, CASAS + 1):
		if cells[sq] != lado:
			continue
		var alvo := sq + passos
		if alvo == SAIDA:
			moves.append({"from": sq, "to": SAIDA})
		elif alvo < SAIDA:
			if cells[alvo] == 0:
				moves.append({"from": sq, "to": alvo})
			elif cells[alvo] == outro:
				var protegida := false
				if alvo > 1 and cells[alvo - 1] == outro:
					protegida = true
				if alvo < CASAS and cells[alvo + 1] == outro:
					protegida = true
				if not protegida:
					moves.append({"from": sq, "to": alvo})
	return moves


## Aplica a jogada no tabuleiro plano, com afogamento e renascimento.
##
## Mesma sequencia que `SenetGame._execute_move()`: troca de lugar quando cai
## sobre o adversario, e quem para na Casa da Agua volta para o Renascimento.
static func aplicar(cells: PackedByteArray, de: int, para: int, lado: int) -> void:
	var outro := 3 - lado
	if para == SAIDA:
		cells[de] = 0
		return

	if cells[para] == outro:
		cells[de] = outro
		cells[para] = lado
	else:
		cells[de] = 0
		cells[para] = lado

	if para == AGUA:
		cells[para] = 0
		var renascer := RENASCIMENTO
		while cells[renascer] != 0 and renascer > 1:
			renascer -= 1
		cells[renascer] = lado


## Nota do tabuleiro pelos olhos de `lado`. Positivo e bom para `lado`.
##
## `fora` e quantas pecas cada lado ja retirou -- a avaliacao nao consegue
## deduzir isso do tabuleiro, porque peca retirada simplesmente some dele.
static func evaluate(cells: PackedByteArray, lado: int, fora_meu: int, fora_seu: int) -> int:
	var outro := 3 - lado
	var nota := PESO_SAIDA * (fora_meu - fora_seu)

	for sq in range(1, CASAS + 1):
		var v: int = cells[sq]
		if v == 0:
			continue
		var meu := v == lado
		var s := PESO_AVANCO * sq

		# Vizinha da mesma cor protege as duas: o adversario nao troca de lugar.
		var protegida := false
		if sq > 1 and cells[sq - 1] == v:
			protegida = true
		if sq < CASAS and cells[sq + 1] == v:
			protegida = true
		if protegida:
			s += PESO_PROTEGIDA
		else:
			# Sozinha e com adversario atras, ao alcance de um lance: o Senet
			# nao tem casa segura, so vizinhanca.
			var alcancavel := false
			for d in range(1, 6):
				var atras := sq - d
				if atras >= 1 and cells[atras] == (outro if meu else lado):
					alcancavel = true
					break
			if alcancavel:
				s -= PESO_EXPOSTA

		# Casas 28, 29 e 30 so liberam a saida com o lance exato (3, 2 e 1).
		if sq >= 28:
			s -= PESO_CASA_FINAL

		nota += s if meu else -s

	return nota


## A jogada da IA no degrau pedido, ou `{}` se nao ha jogada.
static func choose_move(cells: PackedByteArray, lado: int, passos: int,
		fora_meu: int, fora_seu: int, level: int) -> Dictionary:
	var moves := gerar(cells, lado, passos)
	if moves.is_empty():
		return {}
	if moves.size() == 1:
		return moves[0]

	var perfil: Dictionary = PERFIS[clampi(level, 1, PERFIS.size()) - 1]
	if randf() < float(perfil["erro"]):
		return moves[randi() % moves.size()]

	var ruido := int(perfil["ruido"])
	var melhores: Array[Dictionary] = []
	var melhor_nota := -0x7FFFFFFF

	for m in moves:
		var copia := cells.duplicate()
		var de: int = m["from"]
		var para: int = m["to"]
		var afogou := para == AGUA
		aplicar(copia, de, para, lado)

		var nota := evaluate(copia, lado, fora_meu + (1 if para == SAIDA else 0), fora_seu)
		if afogou:
			nota -= PESO_AFOGAMENTO
		# Trocar de lugar manda o adversario para tras: vale o caminho que ele
		# perde, nao um bonus fixo.
		if para < SAIDA and cells[para] == 3 - lado:
			nota += PESO_TROCA
		if ruido > 0:
			nota += randi_range(-ruido, ruido)

		if nota > melhor_nota:
			melhor_nota = nota
			melhores = [m]
		elif nota == melhor_nota:
			melhores.append(m)

	return melhores[randi() % melhores.size()]
