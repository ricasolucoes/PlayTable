class_name ConnectFourAI
extends RefCounted

## A cabeca da IA do Quatro em Linha: negamax com poda alfa-beta.
##
## O que havia antes enxergava exatamente zero lances a frente: vencer agora,
## bloquear a vitoria de agora, e senao a primeira coluna livre da ordem fixa
## `[3, 2, 4, 1, 5, 0, 6]`. Isso perde para a linha padrao de vitoria do jogo
## -- montar duas ameacas ao mesmo tempo, porque bloquear uma abre a outra --
## e nunca via que ocupar uma casa entrega a casa de cima. Como a ordem era
## fixa e nao havia sorteio, a IA repetia a mesma partida: vista uma vez,
## decorada.
##
## A avaliacao conta janelas de quatro casas: janela com peca dos dois lados
## nao vale nada para ninguem, janela com tres minhas e uma vazia vale quase
## uma vitoria, e a coluna do meio vale a parte porque e a que participa de
## mais janelas.
##
## O degrau (1 a 10) do DifficultyManager vira orcamento de nos, chance de erro
## e ruido na nota, no mesmo formato da `CheckersAI` e da `ReversiAI`.

const ROWS := 6
const COLS := 7
const CASAS := ROWS * COLS

## Vitoria/derrota. Longe o bastante de qualquer nota de janela.
const VITORIA := 1000000

## Quanto vale cada janela de quatro casas em que so um lado tem peca.
const DOIS := 12
const UMA := 1

## Ameaca: casa vazia que completaria quatro para alguem.
##
## O que decide o Quatro em Linha nao e ter mais ameacas, e ter as ameacas na
## **paridade certa**. O tabuleiro tem 42 casas: quem abre a partida preenche
## as casas impares contadas de baixo para cima, quem responde preenche as
## pares. Uma ameaca numa fileira impar so pode ser alcancada depois de alguem
## encher a casa de baixo -- e no fim da partida quem e obrigado a fazer isso e
## o dono da paridade oposta. Por isso quem abre joga para ameaca impar e quem
## responde joga para ameaca par: a ameaca na paridade errada nunca chega a ser
## jogada.
##
## Sem isto a avaliacao saturava, e profundidade a mais so refinava ruido: a
## escada media em `tools/_forca_quatro.gd` nao subia do degrau 5 para cima.
const AMEACA_NA_PARIDADE := 130
const AMEACA_FORA_DA_PARIDADE := 22

## A coluna do meio participa de mais janelas de quatro que qualquer outra.
const CENTRO := 8

## Ordem em que a busca olha as colunas: do meio para as bordas. A poda fecha
## muito mais ramo quando a jogada boa e a primeira que ela ve.
const ORDEM := [3, 2, 4, 1, 5, 0, 6]

## Perfil de cada degrau. Quem para a busca e o orcamento de nos; `depth` e so
## um teto de seguranca, e so profundidade impar e usada (ver `choose_column`).
##
## O orcamento quase dobra a cada degrau para que o degrau de cima jogue melhor
## por construcao. `tools/_forca_quatro.gd` mede isso em partida, e o que ele
## mostra e:
##
##   - do degrau 1 ao 8 a escada separa com folga (o 5 ganha do 3 por 24 a 6, o
##     7 ganha do 5 por 26 a 4);
##   - **do 8 ao 10 ela empata dentro do ruido** (17 a 13 em 30 partidas). Nao
##     e orcamento faltando: e a avaliacao chegando ao teto dela. No do 8 para
##     cima a busca ja resolve toda a tatica que a nota sabe enxergar, e no
##     restante ela so refina posicao que a nota nao distingue.
##
## Aumentar o orcamento do topo nao muda isso e custa tempo de tela: o degrau
## 10 ja gasta 450 ms por jogada no computador, medido em
## `tools/_bench_quatro.gd`. Quem quiser separar os tres degraus de cima tem de
## melhorar a avaliacao, nao dar mais nos a ela.
const PERFIS := [
	{"depth": 1, "nos": 60, "erro": 0.80, "ruido": 60},       # 1
	{"depth": 3, "nos": 200, "erro": 0.55, "ruido": 40},      # 2
	{"depth": 3, "nos": 400, "erro": 0.38, "ruido": 28},      # 3
	{"depth": 5, "nos": 800, "erro": 0.25, "ruido": 20},      # 4
	{"depth": 5, "nos": 1600, "erro": 0.16, "ruido": 14},     # 5
	{"depth": 7, "nos": 3200, "erro": 0.10, "ruido": 9},      # 6
	{"depth": 9, "nos": 6000, "erro": 0.05, "ruido": 5},      # 7
	{"depth": 11, "nos": 9000, "erro": 0.02, "ruido": 0},     # 8
	{"depth": 13, "nos": 14000, "erro": 0.0, "ruido": 0},     # 9
	{"depth": 41, "nos": 22000, "erro": 0.0, "ruido": 0},     # 10
]

## As 69 janelas de quatro casas em linha do tabuleiro, achatadas em `69 * 4`
## indices. Montadas uma vez por processo: recalcular a geometria dentro da
## avaliacao era o custo que sobrava.
static var _janelas: PackedInt32Array = PackedInt32Array()

## As quatro direcoes de linha, em forma empacotada. Montar um `Array` de
## `Vector2i` dentro de `venceu()` custava uma alocacao por jogada aplicada --
## e `venceu()` roda uma vez por no da busca.
static var _dr: PackedInt32Array = PackedInt32Array([0, 1, 1, 1])
static var _dc: PackedInt32Array = PackedInt32Array([1, 0, 1, -1])


static func _tabelas() -> void:
	if not _janelas.is_empty():
		return
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, -1)]
	for r in range(ROWS):
		for c in range(COLS):
			for d in dirs:
				var fr: int = r + d.x * 3
				var fc: int = c + d.y * 3
				if fr < 0 or fr >= ROWS or fc < 0 or fc >= COLS:
					continue
				for i in range(4):
					_janelas.append((r + d.x * i) * COLS + (c + d.y * i))


# =============================================================== jogadas

## Copia plana do tabuleiro, com a altura de cada coluna ja contada.
##
## Devolve `[cells, alturas]`. Manter a altura evita procurar o fundo da coluna
## a cada jogada de cada no da busca.
static func achatar(grid: Grid2D) -> Array:
	var cells := PackedByteArray()
	cells.resize(CASAS)
	var alturas := PackedInt32Array()
	alturas.resize(COLS)
	for c in range(COLS):
		var altura := 0
		for r in range(ROWS):
			var v := int(grid.get_cell(r, c))
			cells[r * COLS + c] = v
			if v != 0:
				altura += 1
		alturas[c] = altura
	return [cells, alturas]


## As colunas em que ainda cabe peca, do meio para as bordas.
static func gerar(alturas: PackedInt32Array) -> PackedInt32Array:
	var saida := PackedInt32Array()
	for c in ORDEM:
		if alturas[c] < ROWS:
			saida.append(c)
	return saida


## Joga na coluna e devolve a linha em que a peca parou.
static func aplicar(cells: PackedByteArray, alturas: PackedInt32Array, col: int, side: int) -> int:
	var r := ROWS - 1 - alturas[col]
	cells[r * COLS + col] = side
	alturas[col] += 1
	return r


static func desfazer(cells: PackedByteArray, alturas: PackedInt32Array, col: int) -> void:
	alturas[col] -= 1
	cells[(ROWS - 1 - alturas[col]) * COLS + col] = 0


## Verdadeiro quando a peca em (`r`, `col`) fecha quatro.
static func venceu(cells: PackedByteArray, r: int, col: int, side: int) -> bool:
	for d in range(4):
		var dr: int = _dr[d]
		var dc: int = _dc[d]
		var total := 1

		var rr := r + dr
		var cc := col + dc
		while rr >= 0 and rr < ROWS and cc >= 0 and cc < COLS and cells[rr * COLS + cc] == side:
			total += 1
			rr += dr
			cc += dc

		rr = r - dr
		cc = col - dc
		while rr >= 0 and rr < ROWS and cc >= 0 and cc < COLS and cells[rr * COLS + cc] == side:
			total += 1
			rr -= dr
			cc -= dc

		if total >= 4:
			return true
	return false


# =============================================================== avaliacao

## Nota do tabuleiro pelos olhos de `side`. Positivo e bom para `side`.
##
## A paridade da ameaca e uma propriedade de **quem abriu a partida**, nao de
## quem esta jogando agora: o jogador 1 quer ameaca em fileira impar contada de
## baixo, o jogador 2 quer em fileira par. Por isso a conta e feita em termos
## dos dois jogadores e so no fim vira o sinal para `side`.
static func evaluate(cells: PackedByteArray, side: int) -> int:
	_tabelas()
	var nota_de_um := 0

	var i := 0
	while i < _janelas.size():
		var de_um := 0
		var de_dois := 0
		var vazia := -1
		for k in range(4):
			var idx: int = _janelas[i + k]
			var v: int = cells[idx]
			if v == 1:
				de_um += 1
			elif v == 2:
				de_dois += 1
			else:
				vazia = idx
		i += 4

		# Janela com peca dos dois lados esta morta: ninguem fecha quatro ali.
		if de_um > 0 and de_dois > 0:
			continue

		if de_um == 3:
			nota_de_um += _peso_ameaca(vazia, 1)
		elif de_um == 2:
			nota_de_um += DOIS
		elif de_um == 1:
			nota_de_um += UMA
		elif de_dois == 3:
			nota_de_um -= _peso_ameaca(vazia, 2)
		elif de_dois == 2:
			nota_de_um -= DOIS
		elif de_dois == 1:
			nota_de_um -= UMA

	for r in range(ROWS):
		var v: int = cells[r * COLS + 3]
		if v == 1:
			nota_de_um += CENTRO
		elif v == 2:
			nota_de_um -= CENTRO

	return nota_de_um if side == 1 else -nota_de_um


## Quanto vale a ameaca de `jogador` na casa `idx`.
##
## `idx / COLS` conta de cima para baixo, entao a fileira de baixo e a 5. A
## fileira impar contada de baixo -- 1, 3, 5 -- e a de indice impar aqui, e e
## dela que quem abriu a partida tira proveito.
static func _peso_ameaca(idx: int, jogador: int) -> int:
	if idx < 0:
		return AMEACA_FORA_DA_PARIDADE
	var impar := (idx / COLS) % 2 == 1
	var na_paridade := impar if jogador == 1 else not impar
	return AMEACA_NA_PARIDADE if na_paridade else AMEACA_FORA_DA_PARIDADE


# =================================================================== busca

## A coluna que a IA joga no degrau pedido, ou -1 se o tabuleiro esta cheio.
static func choose_column(cells: PackedByteArray, alturas: PackedInt32Array, side: int,
		level: int) -> int:
	var colunas := gerar(alturas)
	if colunas.is_empty():
		return -1
	if colunas.size() == 1:
		return colunas[0]

	var perfil: Dictionary = PERFIS[clampi(level, 1, PERFIS.size()) - 1]

	# O erro do degrau baixo e jogada qualquer, nao jogada ruim de proposito:
	# uma IA que escolhe a pior coluna e tao previsivel quanto a que acerta.
	if randf() < float(perfil["erro"]):
		return colunas[randi() % colunas.size()]

	var estado := {
		"nos": 0,
		"teto": int(perfil["nos"]),
		"estourou": false,
		"ruido": int(perfil["ruido"]),
	}

	var melhores: Array[int] = [colunas[0]]
	var alvo := int(perfil["depth"])
	# **So profundidade impar.** Com `depth` impar a busca fecha logo depois de
	# um lance da propria IA; com `depth` par ela fecha depois do lance do
	# adversario, e as duas leituras nao se comparam -- a mesma posicao vale
	# mais numa que na outra so pela paridade. Com o orcamento parando a busca
	# em profundidades diferentes conforme a posicao, a paridade ficava
	# oscilando: o degrau 5 perdia do 3 e o 7 perdia do 5, medido em
	# `tools/_forca_quatro.gd`. E o efeito impar/par classico do Quatro em
	# Linha, e alternar entre as duas leituras dentro da mesma escada e o que
	# impedia a escada de subir.
	for profundidade in range(1, alvo + 1, 2):
		var rodada := _raiz(cells, alturas, side, colunas, profundidade, estado)
		if estado["estourou"]:
			break
		melhores = rodada
		for i in range(colunas.size()):
			if colunas[i] == melhores[0]:
				if i > 0:
					colunas.remove_at(i)
					colunas.insert(0, melhores[0])
				break

	return _desempatar(melhores)


## Entre colunas de mesma nota, o sorteio fica so entre as igualmente centrais.
##
## Sortear entre todas parecia de graca -- para a busca elas valem o mesmo --
## mas no tabuleiro vazio a busca empata as sete colunas dentro do horizonte
## dela, e a coluna do meio e a unica abertura que ganha com jogo perfeito dos
## dois lados. Sorteio puro abria na lateral em metade das partidas.
static func _desempatar(melhores: Array[int]) -> int:
	var centrais: Array[int] = []
	var melhor_centro := -99
	for col in melhores:
		var centro := -absi(col - 3)
		if centro > melhor_centro:
			melhor_centro = centro
			centrais = [col]
		elif centro == melhor_centro:
			centrais.append(col)
	return centrais[randi() % centrais.size()]


## A coluna que a IA joga, a partir do tabuleiro da cena.
static func choose_move(grid: Grid2D, side: int, level: int) -> int:
	var plano := achatar(grid)
	return choose_column(plano[0], plano[1], side, level)


## Ponte para o WorkerThreadPool: escreve a coluna em `saida`.
static func pensar_em_tarefa(cells: PackedByteArray, alturas: PackedInt32Array, side: int,
		level: int, saida: Array) -> void:
	saida.append(choose_column(cells, alturas, side, level))


static func _raiz(cells: PackedByteArray, alturas: PackedInt32Array, side: int,
		colunas: PackedInt32Array, profundidade: int, estado: Dictionary) -> Array[int]:
	# **Janela cheia em toda jogada da raiz.** Com a janela estreitada por
	# `alfa`, a poda devolve LIMITE, nao nota exata: a jogada refutada volta
	# valendo exatamente `alfa` e empatava com a melhor, entrando no sorteio de
	# desempate. Quanto mais funda a busca, mais corte -- e mais jogada ruim
	# entrando no empate. Medido em `tools/_forca_quatro.gd`: com erro e ruido
	# zerados, a busca de profundidade 5 perdia de 3 a 27 para a de
	# profundidade 3. A raiz tem poucas jogadas; abrir todas com janela cheia
	# custa pouco e faz toda nota do empate ser comparavel.
	var melhores: Array[int] = [colunas[0]]
	var melhor_nota := -VITORIA * 2

	for col in colunas:
		var r := aplicar(cells, alturas, col, side)
		var nota := 0
		if venceu(cells, r, col, side):
			nota = VITORIA - 1
		else:
			nota = -_buscar(cells, alturas, 3 - side, profundidade - 1,
				-VITORIA * 2, VITORIA * 2, 1, estado)
		desfazer(cells, alturas, col)
		if estado["estourou"]:
			break
		if int(estado["ruido"]) > 0 and absi(nota) < VITORIA / 2:
			nota += randi_range(-int(estado["ruido"]), int(estado["ruido"]))
		if nota > melhor_nota:
			melhor_nota = nota
			melhores = [col]
		elif nota == melhor_nota:
			melhores.append(col)

	return melhores


static func _buscar(cells: PackedByteArray, alturas: PackedInt32Array, side: int,
		profundidade: int, alfa: int, beta: int, ply: int, estado: Dictionary) -> int:
	estado["nos"] = int(estado["nos"]) + 1
	if int(estado["nos"]) >= int(estado["teto"]):
		estado["estourou"] = true
		return evaluate(cells, side)

	var colunas := gerar(alturas)
	if colunas.is_empty():
		return 0   # tabuleiro cheio: empate

	if profundidade <= 0:
		return evaluate(cells, side)

	var a := alfa
	var melhor := -VITORIA * 2
	for col in colunas:
		var r := aplicar(cells, alturas, col, side)
		var nota := 0
		# Vitoria perto vale mais que vitoria longe: sem o `ply` a IA adia o
		# lance que fecha a partida e deixa o outro lado se recuperar.
		if venceu(cells, r, col, side):
			nota = VITORIA - ply
		else:
			nota = -_buscar(cells, alturas, 3 - side, profundidade - 1, -beta, -a, ply + 1, estado)
		desfazer(cells, alturas, col)
		if estado["estourou"]:
			return melhor if melhor > -VITORIA * 2 else nota
		melhor = maxi(melhor, nota)
		a = maxi(a, melhor)
		if a >= beta:
			break
	return melhor
