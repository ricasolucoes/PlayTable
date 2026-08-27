class_name ReversiAI
extends RefCounted

## A cabeca da IA do Reversi: negamax com poda alfa-beta.
##
## O que havia antes era um minimax de profundidade fixa 3 com dois defeitos
## que se somavam e cegavam a busca justamente no fim da partida, que e onde o
## Reversi se decide:
##
##   1. **O no terminal era sempre empate.** A contagem de pecas era lida para
##      duas variaveis declaradas `bool`; 60 e 4 viravam `true` e `true`, e a
##      comparacao dava empate. A busca nao distinguia vencer de 60 a 4 de
##      perder de 4 a 60 -- as duas valiam zero.
##   2. **Passar a vez nunca era modelado.** No no do adversario, quem ficava
##      sem jogada era consultado de novo no lugar do outro lado, entao a busca
##      declarava fim de jogo com o tabuleiro ainda cheio de jogadas. Passar a
##      vez e rotina no Reversi, nao excecao.
##
## Alem de consertar os dois, esta versao troca a avaliacao so-posicional por
## uma que sabe em que fase do jogo esta:
##
##   - **mobilidade** (quantas jogadas cada lado tem) manda na abertura e no
##     meio. Quem fica sem jogada e obrigado a entregar o canto;
##   - **fronteira** (peca encostada em casa vazia) pesa contra: peca de
##     fronteira e o que da jogada ao adversario;
##   - **contagem de pecas** so passa a valer quando o tabuleiro esvazia, e no
##     ultimo lance vale tudo. Contar peca cedo e o erro classico de quem
##     aprende Othello.
##
## O degrau (1 a 10) do DifficultyManager vira orcamento de nos, chance de erro
## e ruido na nota, no mesmo formato da `CheckersAI`.
##
## **A busca nao aloca por jogada gerada.** A geracao devolve so os indices das
## casas legais, num `PackedInt32Array`; as pecas viradas so sao calculadas na
## jogada que a busca de fato desce. Como a poda descarta a maioria das jogadas
## sem abri-las, montar a lista de viradas de todas elas era lixo puro -- a
## mesma conta que o cabecalho da `CheckersAI` faz. E a varredura corre na
## ordem do valor da casa, entao a lista ja sai ordenada e nenhum no precisa
## ordenar nada.

const ROWS := 8
const COLS := 8
const CASAS := 64

## Vitoria/derrota. Longe o bastante de qualquer nota posicional.
const VITORIA := 1000000

# ---------------------------------------------------------------- avaliacao

## Tabela posicional. Canto vale muito, a casa que abre o canto vale negativo:
## quem ocupa a diagonal ao lado do canto costuma entregar o canto no lance
## seguinte.
const PESO_CASA := [
	120, -20,  20,   5,   5,  20, -20, 120,
	-20, -40,  -5,  -5,  -5,  -5, -40, -20,
	 20,  -5,  15,   3,   3,  15,  -5,  20,
	  5,  -5,   3,   3,   3,   3,  -5,   5,
	  5,  -5,   3,   3,   3,   3,  -5,   5,
	 20,  -5,  15,   3,   3,  15,  -5,  20,
	-20, -40,  -5,  -5,  -5,  -5, -40, -20,
	120, -20,  20,   5,   5,  20, -20, 120,
]

## Quanto vale cada jogada a mais que o adversario. A mobilidade e a heuristica
## mais forte do Othello: com o dobro de jogadas o lado escolhe, com nenhuma ele
## e obrigado a passar e o outro joga duas vezes seguidas.
const PESO_MOBILIDADE := 14

## Peca encostada em casa vazia. Menos fronteira e melhor -- por isso o sinal
## entra invertido em `evaluate()`.
const PESO_FRONTEIRA := 6

## Canto ja ocupado nunca mais vira; conta a parte da tabela posicional porque
## e o unico ponto do tabuleiro que a partida nao desfaz.
const PESO_CANTO := 45
const CANTOS := [0, 7, 56, 63]

## A partir de quantas casas vazias a contagem de pecas comeca a pesar. Antes
## disso, ter mais peca no meio do jogo e sinal ruim: peca a mais e fronteira a
## mais, e fronteira a mais e jogada de graca para o outro lado.
const VAZIAS_PARA_CONTAR := 14
const PESO_CONTAGEM := 5

# ----------------------------------------------------------------- degraus

## Perfil de cada degrau, no mesmo formato da `CheckersAI`: quem para a busca e
## o orcamento de nos, `depth` e so um teto de seguranca. O orcamento quase
## dobra a cada degrau para que o degrau de cima jogue melhor por construcao --
## `tools/_forca_reversi.gd` cobra isso em partida, e `tools/_bench_reversi.gd`
## cobra que o degrau 10 caiba na pausa de encenacao.
const PERFIS := [
	{"depth": 1, "nos": 100, "erro": 0.75, "ruido": 40},      # 1
	{"depth": 2, "nos": 180, "erro": 0.50, "ruido": 28},      # 2
	{"depth": 3, "nos": 320, "erro": 0.34, "ruido": 20},      # 3
	{"depth": 4, "nos": 550, "erro": 0.22, "ruido": 15},      # 4
	{"depth": 5, "nos": 900, "erro": 0.14, "ruido": 10},      # 5
	{"depth": 6, "nos": 1500, "erro": 0.08, "ruido": 7},      # 6
	{"depth": 8, "nos": 2400, "erro": 0.04, "ruido": 4},      # 7
	{"depth": 10, "nos": 3800, "erro": 0.015, "ruido": 0},    # 8
	{"depth": 12, "nos": 5200, "erro": 0.0, "ruido": 0},      # 9
	{"depth": 16, "nos": 7000, "erro": 0.0, "ruido": 0},      # 10
]

## Deslocamento de indice de cada uma das oito direcoes.
const DELTA := [-9, -8, -7, -1, 1, 7, 8, 9]

## Quantas casas cabem a partir de cada casa em cada direcao, para a varredura
## nao precisar checar borda dentro do laco. `CASAS * 8` inteiros montados uma
## vez por processo -- num no de busca, calcular borda e o custo que sobra.
static var _passos: PackedInt32Array = PackedInt32Array()

## As mesmas tabelas em forma empacotada. Ler de um `const Array` passa por
## Variant a cada acesso; num laco que roda milhoes de vezes por jogada isso
## sozinho respondia por boa parte do tempo da busca.
static var _delta: PackedInt32Array = PackedInt32Array()
static var _peso: PackedInt32Array = PackedInt32Array()

## As 64 casas na ordem em que a busca deve olha-las: canto primeiro, casa que
## abre o canto por ultimo. Varrer nesta ordem faz a geracao ja sair ordenada e
## dispensa ordenar a lista a cada no -- e ordenar custava por no.
static var _ordem: PackedInt32Array = PackedInt32Array()


static func _tabelas() -> void:
	if not _passos.is_empty():
		return
	_delta = PackedInt32Array(DELTA)
	_peso = PackedInt32Array(PESO_CASA)

	var dirs: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1),
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)]
	_passos.resize(CASAS * 8)
	for idx in range(CASAS):
		var r := idx / COLS
		var c := idx % COLS
		for d in range(8):
			var n := 0
			var rr := r + dirs[d].x
			var cc := c + dirs[d].y
			while rr >= 0 and rr < ROWS and cc >= 0 and cc < COLS:
				n += 1
				rr += dirs[d].x
				cc += dirs[d].y
			_passos[idx * 8 + d] = n

	var casas: Array[int] = []
	for idx in range(CASAS):
		casas.append(idx)
	casas.sort_custom(func(a: int, b: int) -> bool: return int(PESO_CASA[a]) > int(PESO_CASA[b]))
	_ordem = PackedInt32Array(casas)


# =============================================================== jogadas

## Copia plana do tabuleiro. A busca trabalha num `PackedByteArray` de 64
## posicoes em vez de clonar o `Grid2D` a cada no: clonar era a maior despesa
## isolada da versao anterior, que alocava um tabuleiro novo por jogada.
static func achatar(grid: Grid2D) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(CASAS)
	for i in range(CASAS):
		cells[i] = int(grid.cells[i])
	return cells


## As casas em que `side` pode jogar, ja na ordem em que a poda quer ve-las.
##
## So os indices: as pecas viradas ficam para `aplicar()`, que so roda na
## jogada que a busca de fato desce.
static func gerar(cells: PackedByteArray, side: int) -> PackedInt32Array:
	_tabelas()
	var outro := 3 - side
	var saida := PackedInt32Array()

	for i in range(CASAS):
		var idx: int = _ordem[i]
		if cells[idx] != 0:
			continue
		for d in range(8):
			var passos: int = _passos[idx * 8 + d]
			if passos < 2:
				continue
			var passo: int = _delta[d]
			var j := idx + passo
			var n := 0
			while n < passos and cells[j] == outro:
				n += 1
				j += passo
			if n > 0 and n < passos and cells[j] == side:
				saida.append(idx)
				break

	return saida


## So quantas jogadas o lado tem. A avaliacao chama isto duas vezes por folha e
## nao precisa da lista: alocar o PackedInt32Array por folha seria lixo puro.
static func contar_jogadas(cells: PackedByteArray, side: int) -> int:
	_tabelas()
	var outro := 3 - side
	var total := 0

	for idx in range(CASAS):
		if cells[idx] != 0:
			continue
		for d in range(8):
			var passos: int = _passos[idx * 8 + d]
			if passos < 2:
				continue
			var passo: int = _delta[d]
			var j := idx + passo
			var n := 0
			while n < passos and cells[j] == outro:
				n += 1
				j += passo
			if n > 0 and n < passos and cells[j] == side:
				total += 1
				break

	return total


## Joga em `idx` e devolve as casas viradas, para `desfazer()` as devolver.
static func aplicar(cells: PackedByteArray, idx: int, side: int) -> PackedInt32Array:
	_tabelas()
	var outro := 3 - side
	var viradas := PackedInt32Array()

	for d in range(8):
		var passos: int = _passos[idx * 8 + d]
		if passos < 2:
			continue
		var passo: int = _delta[d]
		var j := idx + passo
		var n := 0
		while n < passos and cells[j] == outro:
			n += 1
			j += passo
		if n > 0 and n < passos and cells[j] == side:
			var k := idx + passo
			for _i in range(n):
				viradas.append(k)
				cells[k] = side
				k += passo

	cells[idx] = side
	return viradas


static func desfazer(cells: PackedByteArray, idx: int, side: int, viradas: PackedInt32Array) -> void:
	var outro := 3 - side
	cells[idx] = 0
	for k in viradas:
		cells[k] = outro


## As casas que a jogada viraria, sem mexer no tabuleiro.
static func viradas_de(cells: PackedByteArray, idx: int, side: int) -> PackedInt32Array:
	var copia := cells.duplicate()
	return aplicar(copia, idx, side)


# =============================================================== avaliacao

## Nota do tabuleiro pelos olhos de `side`. Positivo e bom para `side`.
static func evaluate(cells: PackedByteArray, side: int) -> int:
	_tabelas()
	var outro := 3 - side
	var nota := 0
	var minhas := 0
	var suas := 0
	var vazias := 0
	var minha_fronteira := 0
	var sua_fronteira := 0

	for idx in range(CASAS):
		var v: int = cells[idx]
		if v == 0:
			vazias += 1
			continue

		var meu := v == side
		if meu:
			minhas += 1
			nota += _peso[idx]
		else:
			suas += 1
			nota -= _peso[idx]

		# Fronteira: peca encostada em casa vazia. E ela que entrega jogada.
		for d in range(8):
			if _passos[idx * 8 + d] >= 1 and cells[idx + _delta[d]] == 0:
				if meu:
					minha_fronteira += 1
				else:
					sua_fronteira += 1
				break

	# Tabuleiro cheio ou sem jogada para ninguem: quem tem mais peca venceu, e
	# por quanto importa -- vencer de 40 a 24 vale mais que vencer de 33 a 31.
	var minha_mobilidade := 0
	var sua_mobilidade := 0
	if vazias > 0:
		minha_mobilidade = contar_jogadas(cells, side)
		sua_mobilidade = contar_jogadas(cells, outro)
	if vazias == 0 or (minha_mobilidade == 0 and sua_mobilidade == 0):
		if minhas > suas:
			return VITORIA + (minhas - suas)
		if suas > minhas:
			return -VITORIA + (minhas - suas)
		return 0

	# Canto ja ocupado e a unica vantagem que a partida nao desfaz.
	for idx in CANTOS:
		var v: int = cells[idx]
		if v == side:
			nota += PESO_CANTO
		elif v == outro:
			nota -= PESO_CANTO

	nota += PESO_MOBILIDADE * (minha_mobilidade - sua_mobilidade)
	nota += PESO_FRONTEIRA * (sua_fronteira - minha_fronteira)

	# Contagem de pecas so no fim: no meio do jogo ter mais peca e sinal ruim.
	if vazias <= VAZIAS_PARA_CONTAR:
		var peso := PESO_CONTAGEM * (VAZIAS_PARA_CONTAR - vazias + 1)
		nota += peso * (minhas - suas)

	return nota


# =================================================================== busca

## A jogada da IA no degrau pedido, como indice de 0 a 63, ou -1 se nao ha
## jogada.
static func choose_index(cells: PackedByteArray, side: int, level: int) -> int:
	var jogadas := gerar(cells, side)
	if jogadas.is_empty():
		return -1
	if jogadas.size() == 1:
		return jogadas[0]

	var perfil: Dictionary = PERFIS[clampi(level, 1, PERFIS.size()) - 1]

	# O erro do degrau baixo e jogada qualquer, nao jogada ruim de proposito:
	# uma IA que escolhe a pior jogada e tao previsivel quanto a que acerta.
	if randf() < float(perfil["erro"]):
		return jogadas[randi() % jogadas.size()]

	var estado := {
		"nos": 0,
		"teto": int(perfil["nos"]),
		"estourou": false,
		"ruido": int(perfil["ruido"]),
	}

	# Aprofundamento iterativo: se o orcamento acabar no meio, vale a melhor
	# jogada da ultima profundidade que fechou -- nunca uma busca pela metade.
	var melhores: Array[int] = [jogadas[0]]
	var alvo := int(perfil["depth"])
	for profundidade in range(1, alvo + 1):
		var rodada := _raiz(cells, side, jogadas, profundidade, estado)
		if estado["estourou"]:
			break
		melhores = rodada
		# A melhor da rodada abre a proxima: a poda fecha muito mais ramo
		# quando a jogada boa e a primeira que ela ve.
		for i in range(jogadas.size()):
			if jogadas[i] == melhores[0]:
				if i > 0:
					jogadas.remove_at(i)
					jogadas.insert(0, melhores[0])
				break

	return _desempatar(melhores)


## Entre jogadas de mesma nota, o sorteio fica so entre as de casa mais
## valiosa.
##
## Sortear entre todas parecia de graca -- para a busca elas valem o mesmo --
## mas dentro do horizonte dela um canto e a casa que abre o canto empatam com
## frequencia, e fora do horizonte o canto nunca mais vira. O desempate pela
## tabela posicional resolve isso sem tirar a variedade: casas de mesmo valor
## continuam sorteando entre si.
static func _desempatar(melhores: Array[int]) -> int:
	var fortes: Array[int] = []
	var melhor_peso := -9999
	for idx in melhores:
		var peso: int = _peso[idx]
		if peso > melhor_peso:
			melhor_peso = peso
			fortes = [idx]
		elif peso == melhor_peso:
			fortes.append(idx)
	return fortes[randi() % fortes.size()]


## A jogada da IA como coordenada do tabuleiro, ou (-1, -1) se nao ha jogada.
static func choose_move(grid: Grid2D, side: int, level: int) -> Vector2i:
	var idx := choose_index(achatar(grid), side, level)
	if idx < 0:
		return Vector2i(-1, -1)
	return Vector2i(idx / COLS, idx % COLS)


## Ponte para o WorkerThreadPool: escreve a jogada em `saida`.
##
## Estatica de proposito, como a das Damas: a tarefa nao pode segurar
## referencia para a cena, que pode ser fechada com a busca ainda rodando.
static func pensar_em_tarefa(cells: PackedByteArray, side: int, level: int, saida: Array) -> void:
	saida.append(choose_index(cells, side, level))


## Devolve todas as jogadas de melhor nota da rodada, para o sorteio de cima.
static func _raiz(cells: PackedByteArray, side: int, jogadas: PackedInt32Array,
		profundidade: int, estado: Dictionary) -> Array[int]:
	# **Janela cheia em toda jogada da raiz.** Com a janela estreitada por
	# `alfa`, a poda devolve LIMITE, nao nota exata: a jogada refutada volta
	# valendo exatamente `alfa` e empatava com a melhor, entrando no sorteio de
	# desempate. Quanto mais funda a busca, mais corte -- e mais jogada ruim
	# entrando no empate. Medido em `tools/_forca_reversi.gd`: com erro e ruido
	# zerados, o mesmo defeito estava aqui. A raiz tem poucas jogadas; abrir todas com janela cheia
	# custa pouco e faz toda nota do empate ser comparavel.
	var melhores: Array[int] = [jogadas[0]]
	var melhor_nota := -VITORIA * 2

	for idx in jogadas:
		var viradas := aplicar(cells, idx, side)
		var nota := -_buscar(cells, 3 - side, profundidade - 1, -VITORIA * 2, VITORIA * 2, 1, estado)
		desfazer(cells, idx, side, viradas)
		if estado["estourou"]:
			break
		if int(estado["ruido"]) > 0:
			nota += randi_range(-int(estado["ruido"]), int(estado["ruido"]))
		if nota > melhor_nota:
			melhor_nota = nota
			melhores = [idx]
		elif nota == melhor_nota:
			melhores.append(idx)

	return melhores


static func _buscar(cells: PackedByteArray, side: int, profundidade: int, alfa: int, beta: int,
		ply: int, estado: Dictionary) -> int:
	estado["nos"] = int(estado["nos"]) + 1
	if int(estado["nos"]) >= int(estado["teto"]):
		estado["estourou"] = true
		return evaluate(cells, side)

	# Folha: `evaluate()` ja reconhece o fim de partida sozinho, entao gerar as
	# jogadas aqui seria gerar por gerar -- e a folha e a maioria dos nos.
	if profundidade <= 0:
		return evaluate(cells, side)

	var jogadas := gerar(cells, side)

	# Sem jogada, passa a vez -- nao e fim de jogo. So quando os DOIS lados
	# ficam sem jogada a partida acaba, e ai quem tem mais peca venceu.
	if jogadas.is_empty():
		if contar_jogadas(cells, 3 - side) == 0:
			return _placar_final(cells, side, ply)
		return -_buscar(cells, 3 - side, profundidade - 1, -beta, -alfa, ply + 1, estado)

	var a := alfa
	var melhor := -VITORIA * 2
	for idx in jogadas:
		var viradas := aplicar(cells, idx, side)
		var nota := -_buscar(cells, 3 - side, profundidade - 1, -beta, -a, ply + 1, estado)
		desfazer(cells, idx, side, viradas)
		if estado["estourou"]:
			return melhor if melhor > -VITORIA * 2 else nota
		melhor = maxi(melhor, nota)
		a = maxi(a, melhor)
		if a >= beta:
			break
	return melhor


## Partida encerrada: conta as pecas. `ply` faz a derrota longe doer menos que
## a perto, para a IA prolongar a partida perdida e fechar a ganha o quanto
## antes.
static func _placar_final(cells: PackedByteArray, side: int, ply: int) -> int:
	var minhas := 0
	var suas := 0
	for idx in range(CASAS):
		var v: int = cells[idx]
		if v == side:
			minhas += 1
		elif v != 0:
			suas += 1
	if minhas > suas:
		return VITORIA - ply + (minhas - suas)
	if suas > minhas:
		return -VITORIA + ply + (minhas - suas)
	return 0
