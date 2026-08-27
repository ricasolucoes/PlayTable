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

## Perfil de cada degrau: ate onde busca, com que chance joga qualquer coisa e
## quanto ruido soma a nota (empata jogadas parecidas e evita partida decorada).
const PERFIS := [
	{"depth": 1, "erro": 0.75, "ruido": 45},   # 1
	{"depth": 2, "erro": 0.50, "ruido": 32},   # 2
	{"depth": 2, "erro": 0.34, "ruido": 24},   # 3
	{"depth": 3, "erro": 0.22, "ruido": 18},   # 4
	{"depth": 4, "erro": 0.14, "ruido": 12},   # 5
	{"depth": 5, "erro": 0.08, "ruido": 8},    # 6
	{"depth": 6, "erro": 0.04, "ruido": 5},    # 7
	{"depth": 7, "erro": 0.015, "ruido": 0},   # 8
	{"depth": 8, "erro": 0.0, "ruido": 0},     # 9
	{"depth": 10, "erro": 0.0, "ruido": 0},    # 10
]

## Teto de nos por jogada. A busca e cortada por orcamento, nao por relogio:
## o resultado tem de ser o mesmo no aparelho rapido e no lento, senao o teste
## passa aqui e a IA joga diferente no celular.
const NOS_BASE := 1200
const NOS_POR_DEGRAU := 1500


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
			_expandir(grid, Vector2i(r, c), Vector2i(r, c), [], [], saltos)

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


## Desdobra a cadeia de capturas a partir de `pos`, escrevendo e desfazendo no
## proprio tabuleiro. Cada salto tira uma peca do jogo, entao a recursao tem
## fundo garantido -- no maximo 12 saltos.
static func _expandir(grid: Grid2D, origem: Vector2i, pos: Vector2i,
		hops: Array, comidas: Array, saida: Array) -> void:
	var caps: Array[Dictionary] = CheckersRules.get_piece_captures(grid, pos.x, pos.y)

	if caps.is_empty():
		if not hops.is_empty():
			var lista: Array[Vector2i] = []
			lista.assign(comidas)
			saida.append({
				"from": origem,
				"to": pos,
				"captures": lista,
				"hops": hops.duplicate(true),
				"piece_after": grid.cells[pos.x * COLS + pos.y],
			})
		return

	var peca: int = grid.cells[pos.x * COLS + pos.y]
	for cap in caps:
		var comida: Vector2i = cap["captures"][0]
		var destino: Vector2i = cap["to"]
		var vitima: int = grid.cells[comida.x * COLS + comida.y]

		grid.cells[pos.x * COLS + pos.y] = 0
		grid.cells[comida.x * COLS + comida.y] = 0
		grid.cells[destino.x * COLS + destino.y] = _coroar(peca, destino.x)

		hops.append({"to": destino, "captured": comida})
		comidas.append(comida)
		_expandir(grid, origem, destino, hops, comidas, saida)
		comidas.pop_back()
		hops.pop_back()

		grid.cells[destino.x * COLS + destino.y] = 0
		grid.cells[comida.x * COLS + comida.y] = vitima
		grid.cells[pos.x * COLS + pos.y] = peca


static func _direcoes(peca: int) -> Array:
	if absi(peca) == 2:
		return [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]
	if peca > 0:
		return [Vector2i(-1, -1), Vector2i(-1, 1)]
	return [Vector2i(1, -1), Vector2i(1, 1)]


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
		"teto": NOS_BASE + NOS_POR_DEGRAU * clampi(level, 1, PERFIS.size()),
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


static func _raiz(grid: Grid2D, side: int, turnos: Array[Dictionary],
		profundidade: int, estado: Dictionary) -> Dictionary:
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
	turnos.sort_custom(func(x, y):
		var px: int = x["captures"].size() * 4 + (2 if absi(x["piece_after"]) == 2 else 0)
		var py: int = y["captures"].size() * 4 + (2 if absi(y["piece_after"]) == 2 else 0)
		return px > py)
