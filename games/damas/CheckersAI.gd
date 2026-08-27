class_name CheckersAI
extends RefCounted

## A cabeca da IA das Damas: busca negamax com poda alfa-beta.
##
## O que havia antes era `moves[0]` -- a primeira jogada da varredura do
## tabuleiro, de cima para baixo, da esquerda para a direita. Ela nunca via uma
## troca, nunca protegia a fileira de tras e entregava peca de graca sempre que
## a captura obrigatoria dela nao fosse a primeira da lista. Dava para vencer
## sem pensar.
##
## Tres coisas mudam isso:
##
##   1. **O turno inteiro e uma jogada so.** A captura em cadeia era resolvida
##      em pedacos, um salto de cada vez, e a busca nunca enxergava o fim da
##      sequencia. Aqui `generate_turns()` devolve a cadeia completa -- comer
##      tres pecas de uma vez e uma jogada, nao tres.
##   2. **Captura obrigatoria nao gasta profundidade.** Quando so ha um salto
##      possivel o lance e forcado; contar isso como um nivel de busca fazia a
##      IA parar de olhar bem no meio de uma troca e achar que estava ganhando
##      uma peca que ia devolver no lance seguinte.
##   3. **A avaliacao sabe o que vale um tabuleiro de damas** -- dama vale mais
##      que peca, peca adiantada vale mais que peca atrasada, fileira de tras
##      guardada impede a coroacao do outro, e quem esta na frente troca.
##
## O degrau (1 a 10) do DifficultyManager vira profundidade, chance de erro e
## ruido na avaliacao. No 1 a IA joga quase ao acaso; no 10 ela ve dez lances.

## Tabuleiro de 8x8. Repetidos aqui de proposito: `CheckersRules` chama de
## volta `CheckersAI.choose_turn()`, e uma constante de uma classe apontando
## para a outra fecharia o ciclo em tempo de parse. `test_checkers.gd` cobra
## que os dois pares continuem iguais.
const ROWS := 8
const COLS := 8

# ---------------------------------------------------------------- avaliacao

const PECA := 100
const DAMA := 175

## Quanto cada fileira andada em direcao a coroacao acrescenta a uma peca.
const AVANCO := 7

## Peca parada na propria fileira de tras: o outro lado nao coroa por ali.
const FILEIRA_DE_TRAS := 12

## Coluna da borda: a peca nunca pode ser capturada, mas tambem nao ataca.
const BORDA := 6

## Casas centrais valem mais -- de la a peca alcanca os dois lados.
const CENTRO := 4

## Estar na frente no material vale mais com o tabuleiro vazio: quem ganha,
## troca. Sem isto a IA com uma peca a mais evitava troca e o jogo nao andava.
const TROCA := 3

## No fim de partida a dama tem de ir atras da presa, senao a IA vencedora
## fica passeando para sempre e a partida nunca fecha.
const CACADA := 3
const PECAS_DE_FINAL := 6

## Vitoria/derrota. Longe o bastante de qualquer nota material.
const VITORIA := 1000000

# ----------------------------------------------------------------- degraus

## Perfil de cada degrau: quanto pode pensar, ate onde pode ir, com que chance
## joga abaixo da propria forca e quanto ruido soma a nota.
##
## **Quem manda e o orcamento de nos, nao a profundidade.** Na primeira versao
## era o contrario -- profundidade fixa e orcamento crescendo devagar -- e o
## degrau 7 perdia do 5: ele pedia profundidade 6, gastava o orcamento inteiro
## no aprofundamento e caia de volta na ultima profundidade que tinha fechado,
## a mesma do degrau 5. Degrau que pensa mais tem de jogar melhor, sempre; com
## o orcamento dobrando a cada degrau isso vale por construcao.
##
## `depth` e so um teto de seguranca: quem para a busca e o orcamento.
const PERFIS := [
	{"depth": 1, "nos": 200, "erro": 0.75, "ruido": 45},      # 1
	{"depth": 2, "nos": 400, "erro": 0.50, "ruido": 32},      # 2
	{"depth": 3, "nos": 800, "erro": 0.34, "ruido": 24},      # 3
	{"depth": 4, "nos": 1500, "erro": 0.22, "ruido": 18},     # 4
	{"depth": 6, "nos": 2600, "erro": 0.14, "ruido": 12},     # 5
	{"depth": 8, "nos": 4200, "erro": 0.08, "ruido": 8},      # 6
	{"depth": 10, "nos": 6500, "erro": 0.04, "ruido": 5},     # 7
	{"depth": 12, "nos": 9500, "erro": 0.015, "ruido": 0},    # 8
	{"depth": 14, "nos": 13000, "erro": 0.0, "ruido": 0},     # 9
	{"depth": 16, "nos": 17000, "erro": 0.0, "ruido": 0},     # 10
]

## Diagonais, ja prontas. Montar o Array dentro da funcao custava uma alocacao
## por peca por no -- com milhares de nos por jogada, era o maior custo isolado
## da busca.
const DIR_TODAS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]
const DIR_CIMA: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, 1)]
const DIR_BAIXO: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 1)]


# =============================================================== jogadas

## Todas as jogadas legais do lado, cada uma com a cadeia de capturas inteira.
##
## Formato: `{from, to, captures: [Vector2i...], hops: [{to, captured}...],
## piece_after: int}`. `hops` e o caminho que a cena anima, um salto por vez;
## `piece_after` ja considera a coroacao, inclusive a que acontece no meio da
## cadeia.
static func generate_turns(grid: Grid2D, side: int) -> Array[Dictionary]:
	var saltos: Array[Dictionary] = []
	var passeios: Array[Dictionary] = []
	var meu := side > 0

	for r in range(ROWS):
		for c in range(COLS):
			var p: int = grid.cells[r * COLS + c]
			if p == 0 or (p > 0) != meu:
				continue
			_expandir(grid, Vector2i(r, c), r, c, [], [], saltos)

	# Captura e obrigatoria: havendo salto, passeio nem entra na lista.
	if not saltos.is_empty():
		return saltos

	for r in range(ROWS):
		for c in range(COLS):
			var p: int = grid.cells[r * COLS + c]
			if p == 0 or (p > 0) != meu:
				continue
			for d in _direcoes(p):
				var nr := r + d.x
				var nc := c + d.y
				if nr < 0 or nr >= ROWS or nc < 0 or nc >= COLS:
					continue
				if grid.cells[nr * COLS + nc] != 0:
					continue
				var destino := Vector2i(nr, nc)
				passeios.append({
					"from": Vector2i(r, c),
					"to": destino,
					"captures": [] as Array[Vector2i],
					"hops": [{"to": destino, "captured": Vector2i(-1, -1)}],
					"piece_after": _coroar(p, nr),
				})

	return passeios


## Desdobra a cadeia de capturas a partir de (`r`, `c`), escrevendo e desfazendo
## no proprio tabuleiro. Cada salto tira uma peca do jogo, entao a recursao tem
## fundo garantido -- no maximo 12 saltos.
##
## A deteccao de captura e feita aqui, direto no vetor de casas, em vez de
## passar por `CheckersRules.get_piece_captures()`: aquela devolve um Dicionario
## de tres chaves por captura, e num no de busca isso e lixo puro. A regra e a
## mesma -- salta por cima de peca adversaria para casa vazia -- e
## `test_checkers.gd` compara as duas geracoes casa a casa.
static func _expandir(grid: Grid2D, origem: Vector2i, r: int, c: int,
		hops: Array, comidas: Array, saida: Array) -> void:
	var cells := grid.cells
	var peca: int = cells[r * COLS + c]
	var meu := peca > 0
	var dirs: Array[Vector2i] = DIR_TODAS if absi(peca) == 2 else (DIR_CIMA if meu else DIR_BAIXO)
	var achou := false

	for d in dirs:
		var lr := r + d.x * 2
		var lc := c + d.y * 2
		if lr < 0 or lr >= ROWS or lc < 0 or lc >= COLS:
			continue
		var i_meio := (r + d.x) * COLS + (c + d.y)
		var alvo: int = cells[i_meio]
		if alvo == 0 or (alvo > 0) == meu:
			continue
		var i_destino := lr * COLS + lc
		if cells[i_destino] != 0:
			continue

		achou = true
		var i_origem := r * COLS + c
		cells[i_origem] = 0
		cells[i_meio] = 0
		cells[i_destino] = _coroar(peca, lr)

		hops.append({"to": Vector2i(lr, lc), "captured": Vector2i(r + d.x, c + d.y)})
		comidas.append(Vector2i(r + d.x, c + d.y))
		_expandir(grid, origem, lr, lc, hops, comidas, saida)
		comidas.pop_back()
		hops.pop_back()

		cells[i_destino] = 0
		cells[i_meio] = alvo
		cells[i_origem] = peca

	# Ponta da cadeia: nao ha mais o que comer, o turno fecha aqui.
	if not achou and not hops.is_empty():
		var lista: Array[Vector2i] = []
		lista.assign(comidas)
		saida.append({
			"from": origem,
			"to": Vector2i(r, c),
			"captures": lista,
			"hops": hops.duplicate(true),
			"piece_after": peca,
		})


static func _direcoes(peca: int) -> Array[Vector2i]:
	if absi(peca) == 2:
		return DIR_TODAS
	return DIR_CIMA if peca > 0 else DIR_BAIXO


## A mesma coroacao que `CheckersRules.execute_move` aplica: a peca que chega na
## ultima fileira vira dama, inclusive no meio de uma cadeia de capturas.
static func _coroar(peca: int, linha: int) -> int:
	if peca == 1 and linha == 0:
		return 2
	if peca == -1 and linha == ROWS - 1:
		return -2
	return peca


## Escreve o turno inteiro no tabuleiro e devolve o que preciso para desfazer.
static func aplicar(grid: Grid2D, turno: Dictionary) -> Array:
	var desfazer: Array = []
	var de: Vector2i = turno["from"]
	var para: Vector2i = turno["to"]

	var i_de := de.x * COLS + de.y
	desfazer.append([i_de, grid.cells[i_de]])
	grid.cells[i_de] = 0

	for cap in turno["captures"]:
		var i_cap: int = cap.x * COLS + cap.y
		desfazer.append([i_cap, grid.cells[i_cap]])
		grid.cells[i_cap] = 0

	var i_para := para.x * COLS + para.y
	desfazer.append([i_para, grid.cells[i_para]])
	grid.cells[i_para] = turno["piece_after"]

	return desfazer


## Desfaz na ordem inversa: a cadeia pode voltar a casa de origem, e ai a
## ordem e a unica coisa que separa restaurar de apagar.
static func desfazer(grid: Grid2D, marcas: Array) -> void:
	for i in range(marcas.size() - 1, -1, -1):
		grid.cells[marcas[i][0]] = marcas[i][1]


# =============================================================== avaliacao

## Nota do tabuleiro pelos olhos de `side`. Positivo e bom para `side`.
static func evaluate(grid: Grid2D, side: int) -> int:
	var nota := 0
	var meu_material := 0
	var seu_material := 0
	var total := 0
	var minhas_damas: Array[int] = []
	var suas_pecas: Array[int] = []

	for idx in range(ROWS * COLS):
		var p: int = grid.cells[idx]
		if p == 0:
			continue
		total += 1
		var r: int = idx / COLS
		var c: int = idx % COLS
		var meu := (p > 0) == (side > 0)
		var s := 0

		if absi(p) == 2:
			s = DAMA
			# Dama no centro alcanca as duas metades do tabuleiro.
			s += CENTRO * (3 - absi(r * 2 - 7) / 2) + CENTRO * (3 - absi(c * 2 - 7) / 2)
			if meu:
				minhas_damas.append(idx)
		else:
			s = PECA
			# Fileiras andadas em direcao a coroacao.
			var avancou := (ROWS - 1 - r) if p > 0 else r
			s += AVANCO * avancou
			# A fileira de tras guardada e o que impede o outro lado de coroar.
			if (p > 0 and r == ROWS - 1) or (p < 0 and r == 0):
				s += FILEIRA_DE_TRAS
			if c >= 2 and c <= 5:
				s += CENTRO

		if c == 0 or c == COLS - 1:
			s += BORDA

		if meu:
			nota += s
			meu_material += DAMA if absi(p) == 2 else PECA
		else:
			nota -= s
			seu_material += DAMA if absi(p) == 2 else PECA
			suas_pecas.append(idx)

	# Quem esta na frente troca: com o tabuleiro esvaziando a vantagem pesa mais.
	var vantagem := meu_material - seu_material
	if vantagem != 0:
		nota += signi(vantagem) * (24 - total) * TROCA

	# Final de partida: a dama tem de ir atras da presa.
	if total <= PECAS_DE_FINAL and vantagem > 0 and not suas_pecas.is_empty():
		for i_dama in minhas_damas:
			var perto := 99
			for i_presa in suas_pecas:
				var d := absi(i_dama / COLS - i_presa / COLS) + absi(i_dama % COLS - i_presa % COLS)
				perto = mini(perto, d)
			nota -= CACADA * perto

	return nota


# =================================================================== busca

## A jogada que a IA escolhe no degrau pedido, ou `{}` se nao ha jogada.
static func choose_turn(grid: Grid2D, side: int, level: int) -> Dictionary:
	var turnos := generate_turns(grid, side)
	if turnos.is_empty():
		return {}
	if turnos.size() == 1:
		return turnos[0]

	var perfil: Dictionary = PERFIS[clampi(level, 1, PERFIS.size()) - 1]
	turnos.shuffle()   # duas partidas iguais nao devem ter a mesma abertura

	# O erro do degrau baixo e jogada qualquer, nao jogada ruim de proposito:
	# uma IA que escolhe a pior jogada e tao previsivel quanto a que acerta.
	if randf() < float(perfil["erro"]):
		return turnos[randi() % turnos.size()]

	var estado := {
		"nos": 0,
		"teto": int(perfil["nos"]),
		"estourou": false,
		"ruido": int(perfil["ruido"]),
	}

	# Aprofundamento iterativo: se o orcamento acabar no meio, vale a melhor
	# jogada da ultima profundidade que fechou -- nunca uma busca pela metade.
	var melhor: Dictionary = turnos[0]
	var alvo := int(perfil["depth"])
	for profundidade in range(1, alvo + 1):
		var candidata := _raiz(grid, side, turnos, profundidade, estado)
		if estado["estourou"]:
			break
		melhor = candidata
	return melhor


## Ponte para o WorkerThreadPool: escreve a jogada em `saida`.
##
## A busca sai da linha principal porque no degrau 10 ela chega a meio segundo
## no computador -- num telefone, mais. Meio segundo de tela travada e defeito.
## A funcao e estatica de proposito: a tarefa nao pode segurar referencia para
## a cena, que pode ser fechada com a busca ainda rodando.
static func pensar_em_tarefa(copia: Grid2D, side: int, level: int, saida: Array) -> void:
	saida.append(choose_turn(copia, side, level))


static func _raiz(grid: Grid2D, side: int, turnos: Array[Dictionary],
		profundidade: int, estado: Dictionary) -> Dictionary:
	if profundidade == 1:
		_ordenar(turnos)
	var melhor: Dictionary = turnos[0]
	var melhor_nota := -VITORIA * 2
	var alfa := -VITORIA * 2

	for turno in turnos:
		var marcas := aplicar(grid, turno)
		var nota := -_buscar(grid, -side, profundidade - 1, -VITORIA * 2, -alfa, 1,
			profundidade + 8, estado)
		desfazer(grid, marcas)
		if estado["estourou"]:
			break
		if int(estado["ruido"]) > 0:
			nota += randi_range(-int(estado["ruido"]), int(estado["ruido"]))
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = turno
			alfa = maxi(alfa, nota)

	# A melhor da rodada abre a proxima: a poda fecha muito mais ramo quando a
	# jogada boa e a primeira que ela ve, e o aprofundamento paga por isso.
	var i := turnos.find(melhor)
	if i > 0:
		turnos.remove_at(i)
		turnos.insert(0, melhor)
	return melhor


static func _buscar(grid: Grid2D, side: int, profundidade: int, alfa: int, beta: int,
		ply: int, teto_ply: int, estado: Dictionary) -> int:
	estado["nos"] = int(estado["nos"]) + 1
	if int(estado["nos"]) >= int(estado["teto"]):
		estado["estourou"] = true
		return evaluate(grid, side)

	var turnos := generate_turns(grid, side)
	if turnos.is_empty():
		# Sem jogada, perdeu. `ply` faz a derrota longe doer menos que a perto:
		# assim a IA prolonga a partida perdida e fecha a ganha o quanto antes.
		return -VITORIA + ply

	var forcado: bool = not turnos[0]["captures"].is_empty()

	if profundidade <= 0:
		# Parar com captura obrigatoria pendente e ler um material que nao
		# existe: o horizonte da busca cortaria a troca no meio.
		if not (forcado and ply < teto_ply):
			return evaluate(grid, side)

	# Lance unico e forcado nao consome profundidade -- ele nao e uma escolha.
	var proxima := profundidade - 1
	if forcado and turnos.size() == 1 and ply < teto_ply:
		proxima = profundidade

	_ordenar(turnos)
	var a := alfa
	var melhor := -VITORIA * 2
	for turno in turnos:
		var marcas := aplicar(grid, turno)
		var nota := -_buscar(grid, -side, proxima, -beta, -a, ply + 1, teto_ply, estado)
		desfazer(grid, marcas)
		if estado["estourou"]:
			return melhor if melhor > -VITORIA * 2 else nota
		melhor = maxi(melhor, nota)
		a = maxi(a, melhor)
		if a >= beta:
			break
	return melhor


## Captura grande primeiro, coroacao depois: quanto antes a poda encontrar a
## jogada boa, menos ramo ela precisa abrir.
static func _ordenar(turnos: Array[Dictionary]) -> void:
	if turnos.size() < 2 or turnos[0]["captures"].is_empty():
		return   # sem captura nao ha o que ordenar, e ordenar custa por no
	turnos.sort_custom(_antes)


static func _antes(x: Dictionary, y: Dictionary) -> bool:
	var px: int = x["captures"].size() * 4 + (2 if absi(x["piece_after"]) == 2 else 0)
	var py: int = y["captures"].size() * 4 + (2 if absi(y["piece_after"]) == 2 else 0)
	return px > py
