class_name MorrisAI
extends RefCounted

## A cabeca da IA da Trilha: negamax com poda alfa-beta sobre o estado plano
## de `MorrisRules` (24 bytes de tabuleiro e as pecas na mao).
##
## Um lance da busca e a vez INTEIRA -- colocar ou mover, mais a captura
## quando fecha trilha -- porque avaliar o tabuleiro entre a trilha e a
## captura mede um lance pela metade. A avaliacao pesa, nesta ordem:
##
##   - **pecas** em jogo: capturar e a unica coisa que a partida nao desfaz;
##   - **trilhas** fechadas e **linhas abertas** (duas suas e a terceira casa
##     vazia), que sao a ameaca de capturar no proximo lance;
##   - **dupla-trilha**: a peca que sai de uma trilha e fecha outra ao lado, e
##     volta -- captura a cada lance, e e o que decide partidas entre iguais;
##   - **mobilidade** e pecas presas, que e como se perde por bloqueio.
##
## O degrau (1 a 10) do DifficultyManager vira profundidade, orcamento de nos
## e chance de erro. Nos degraus baixos o erro e um lance legal qualquer, nao
## o pior de proposito: uma IA que erra sempre e tao previsivel quanto a que
## acerta sempre.

const VITORIA := 100000

## Perfil por degrau. `depth` em meias-jogadas; `nos` e o orcamento que trava
## a busca no telefone, `erro` a chance de jogar ao acaso.
const PERFIS := [
	{"depth": 1, "nos": 150, "erro": 0.45},    # 1
	{"depth": 1, "nos": 250, "erro": 0.32},    # 2
	{"depth": 2, "nos": 450, "erro": 0.22},    # 3
	{"depth": 2, "nos": 700, "erro": 0.15},    # 4
	{"depth": 2, "nos": 1200, "erro": 0.09},   # 5
	{"depth": 3, "nos": 2000, "erro": 0.05},   # 6
	{"depth": 3, "nos": 3200, "erro": 0.03},   # 7
	{"depth": 3, "nos": 5000, "erro": 0.01},   # 8
	{"depth": 4, "nos": 8000, "erro": 0.0},    # 9
	{"depth": 4, "nos": 12000, "erro": 0.0},   # 10
]

const PESO_PECA := 100
const PESO_MOINHO := 26
const PESO_ABERTA := 12
const PESO_DUPLA := 40
const PESO_MOBILIDADE := 6
const PESO_PRESA := 5
## Adversario sem lance nenhum na fase de movimento: quase vitoria.
const PESO_ADVERSARIO_PRESO := 400


# ================================================================= escolha

## O lance da IA como Vector3i(de, para, captura) -- ver `MorrisRules.lances`.
## (-1, -1, -1) quando nao ha lance.
static func escolher(cells: PackedByteArray, mao: PackedInt32Array, lado: int, level: int) -> Vector3i:
	var jogadas := MorrisRules.lances(cells, mao, lado)
	if jogadas.is_empty():
		return Vector3i(-1, -1, -1)
	if jogadas.size() == 1:
		return jogadas[0]

	var perfil: Dictionary = PERFIS[clampi(level, 1, PERFIS.size()) - 1]
	# Gerador proprio: a busca roda numa thread de trabalho, e o `randf()`
	# global nao e dela.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() < float(perfil["erro"]):
		return jogadas[rng.randi() % jogadas.size()]

	_ordenar(jogadas)
	var estado := {"nos": 0, "teto": int(perfil["nos"]), "estourou": false}

	# Aprofundamento iterativo: se o orcamento acabar no meio de uma
	# profundidade, vale a melhor jogada da ultima que fechou inteira.
	var melhores: Array[Vector3i] = [jogadas[0]]
	for profundidade in range(1, int(perfil["depth"]) + 1):
		var rodada := _raiz(cells, mao, lado, jogadas, profundidade, estado)
		if estado["estourou"] or rodada.is_empty():
			break
		melhores = rodada
		# A melhor da rodada abre a proxima: a poda corta mais quando a jogada
		# boa e a primeira que ela ve.
		var i := jogadas.find(melhores[0])
		if i > 0:
			jogadas.remove_at(i)
			jogadas.insert(0, melhores[0])

	return melhores[rng.randi() % melhores.size()]


## Ponte para o WorkerThreadPool: escreve o lance em `saida`. Estatica e sem
## referencia a cena, que pode ser fechada com a busca ainda rodando.
static func pensar_em_tarefa(cells: PackedByteArray, mao: PackedInt32Array, lado: int,
		level: int, saida: Array) -> void:
	saida.append(escolher(cells, mao, lado, level))


## Capturas primeiro: sao as jogadas que mais mudam a nota, e ve-las antes
## fecha a janela da poda cedo.
static func _ordenar(jogadas: Array[Vector3i]) -> void:
	jogadas.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return a.z >= 0 and b.z < 0)


# =================================================================== busca

## Todas as jogadas de melhor nota na raiz, para o sorteio de cima. Janela
## cheia em cada uma: com a janela estreitada a jogada refutada volta valendo
## exatamente `alfa` e empataria com a melhor.
static func _raiz(cells: PackedByteArray, mao: PackedInt32Array, lado: int,
		jogadas: Array[Vector3i], profundidade: int, estado: Dictionary) -> Array[Vector3i]:
	var melhores: Array[Vector3i] = []
	var melhor := -VITORIA * 10
	var outro := MorrisRules.adversario(lado)
	for l in jogadas:
		MorrisRules.aplicar_lance(cells, mao, lado, l)
		var nota := -_negamax(cells, mao, outro, profundidade - 1, -VITORIA * 10, VITORIA * 10, estado)
		MorrisRules.desfazer_lance(cells, mao, lado, l)
		if estado["estourou"]:
			return melhores
		if nota > melhor:
			melhor = nota
			melhores = [l]
		elif nota == melhor:
			melhores.append(l)
	return melhores


static func _negamax(cells: PackedByteArray, mao: PackedInt32Array, lado: int,
		profundidade: int, alfa: int, beta: int, estado: Dictionary) -> int:
	estado["nos"] = int(estado["nos"]) + 1
	if int(estado["nos"]) > int(estado["teto"]):
		estado["estourou"] = true
		return 0
	# Quem tem a vez com menos de tres pecas, ou sem lance, perdeu. Perder mais
	# cedo (profundidade restante maior) e pior: a busca prefere adiar a
	# derrota e apressar a vitoria.
	if MorrisRules.contar(cells, lado) + mao[lado] < 3:
		return -(VITORIA + profundidade)
	var jogadas := MorrisRules.lances(cells, mao, lado)
	if jogadas.is_empty():
		return -(VITORIA + profundidade)
	if profundidade <= 0:
		return avaliar(cells, mao, lado)

	_ordenar(jogadas)
	var outro := MorrisRules.adversario(lado)
	var melhor := -VITORIA * 10
	for l in jogadas:
		MorrisRules.aplicar_lance(cells, mao, lado, l)
		var nota := -_negamax(cells, mao, outro, profundidade - 1, -beta, -alfa, estado)
		MorrisRules.desfazer_lance(cells, mao, lado, l)
		if estado["estourou"]:
			return 0
		if nota > melhor:
			melhor = nota
		if nota > alfa:
			alfa = nota
		if alfa >= beta:
			break
	return melhor


# ================================================================ avaliacao

## Nota do tabuleiro pelos olhos de `lado`, que e quem tem a vez. Positivo e
## bom para `lado`.
static func avaliar(cells: PackedByteArray, mao: PackedInt32Array, lado: int) -> int:
	var outro := MorrisRules.adversario(lado)
	var minhas := MorrisRules.contar(cells, lado) + mao[lado]
	var suas := MorrisRules.contar(cells, outro) + mao[outro]
	if minhas < 3:
		return -VITORIA
	if suas < 3:
		return VITORIA

	var nota := PESO_PECA * (minhas - suas)

	# Uma varredura das 16 linhas da trilhas fechadas, linhas abertas e os
	# pontos vazios que fechariam DUAS linhas de uma vez (dupla por colocacao).
	var moinhos := [0, 0, 0]
	var abertas := [0, 0, 0]
	var fecha_em := PackedByteArray()
	fecha_em.resize(MorrisRules.PONTOS * 3)
	for tri in MorrisRules.MOINHOS:
		for quem in [lado, outro]:
			var n := 0
			var vazio := -1
			var alheia := false
			for p in tri:
				var v: int = cells[p]
				if v == quem:
					n += 1
				elif v == MorrisRules.VAZIO:
					vazio = p
				else:
					alheia = true
			if n == 3:
				moinhos[quem] += 1
			elif n == 2 and not alheia and vazio >= 0:
				abertas[quem] += 1
				fecha_em[quem * MorrisRules.PONTOS + vazio] += 1

	var duplas := [0, 0, 0]
	for quem in [lado, outro]:
		for p in MorrisRules.PONTOS:
			if fecha_em[quem * MorrisRules.PONTOS + p] >= 2:
				duplas[quem] += 1

	# Mobilidade, pecas presas e a trilha corrente -- so de quem ja colocou
	# tudo: na colocacao qualquer ponto vazio serve.
	var mobilidade := [0, 0, 0]
	var presas := [0, 0, 0]
	for quem in [lado, outro]:
		if mao[quem] > 0:
			continue
		var voando := MorrisRules.contar(cells, quem) == 3
		for p in MorrisRules.PONTOS:
			if cells[p] != quem:
				continue
			var livres := 0
			if voando:
				livres = 3
			else:
				for q in MorrisRules.ADJ[p]:
					if cells[q] == MorrisRules.VAZIO:
						livres += 1
			mobilidade[quem] += livres
			if livres == 0:
				presas[quem] += 1
			# Peca de uma trilha fechada que, andando uma casa, fecha outra: e a
			# dupla-trilha corrente, que captura a cada lance.
			if not voando and MorrisRules.moinhos_fechados(cells, p, quem) > 0:
				for q in MorrisRules.ADJ[p]:
					if cells[q] != MorrisRules.VAZIO:
						continue
					cells[p] = MorrisRules.VAZIO
					cells[q] = quem
					if MorrisRules.moinhos_fechados(cells, q, quem) > 0:
						duplas[quem] += 1
					cells[q] = MorrisRules.VAZIO
					cells[p] = quem

	nota += PESO_MOINHO * (moinhos[lado] - moinhos[outro])
	nota += PESO_ABERTA * (abertas[lado] - abertas[outro])
	nota += PESO_DUPLA * (duplas[lado] - duplas[outro])
	nota += PESO_MOBILIDADE * (mobilidade[lado] - mobilidade[outro])
	nota -= PESO_PRESA * (presas[lado] - presas[outro])
	if mao[outro] == 0 and mobilidade[outro] == 0:
		nota += PESO_ADVERSARIO_PRESO
	return nota
