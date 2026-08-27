class_name TicTacToeRules
extends RefCounted

## Rules and logic for Jogo Da Velha.

const WIN_COMBOS = [
	[0, 1, 2], [3, 4, 5], [6, 7, 8], # Linhas
	[0, 3, 6], [1, 4, 7], [2, 5, 8], # Colunas
	[0, 4, 8], [2, 4, 6]             # Diagonais
]

static func check_win(grid: Grid2D, player_id: int) -> bool:
	return not get_winning_combo(grid, player_id).is_empty()

## A trinca que fecha a vitoria de `player_id`, ou vazia se nao ha vitoria.
##
## `check_win` responde sim ou nao; a cena precisa das tres casas para desenhar
## o risco por cima delas, e por isso mantinha a propria copia das WIN_COMBOS.
static func get_winning_combo(grid: Grid2D, player_id: int) -> Array[int]:
	for combo in WIN_COMBOS:
		if grid.cells[combo[0]] == player_id \
				and grid.cells[combo[1]] == player_id \
				and grid.cells[combo[2]] == player_id:
			var res: Array[int] = []
			res.append_array(combo)
			return res
	return [] as Array[int]

static func is_draw(grid: Grid2D) -> bool:
	for c in grid.cells:
		if c == 0: return false
	return not check_win(grid, 1) and not check_win(grid, 2)

static func get_empty_indices(grid: Grid2D) -> Array[int]:
	var list: Array[int] = []
	for i in range(grid.cells.size()):
		if grid.cells[i] == 0:
			list.append(i)
	return list

static func get_best_move(grid: Grid2D, ai_player_id: int) -> int:
	var human_id := 1 if ai_player_id == 2 else 2
	var empty := get_empty_indices(grid)
	if empty.is_empty(): return -1
	
	# 1. Tenta vencer na próxima jogada
	for idx in empty:
		grid.cells[idx] = ai_player_id
		if check_win(grid, ai_player_id):
			grid.cells[idx] = 0
			return idx
		grid.cells[idx] = 0
		
	# 2. Tenta bloquear a vitória do oponente
	for idx in empty:
		grid.cells[idx] = human_id
		if check_win(grid, human_id):
			grid.cells[idx] = 0
			return idx
		grid.cells[idx] = 0
		
	# 3. Prefere o centro (4)
	if 4 in empty:
		return 4
		
	# 4. Cantos (0, 2, 6, 8)
	var corners: Array = []
	for c in [0, 2, 6, 8]:
		if c in empty: corners.append(c)
	if not corners.is_empty():
		corners.shuffle()
		return corners[0]
		
	# 5. Aleatório
	empty.shuffle()
	return empty[0]


# ---------------------------------------------------------------------------
# Dificuldade
# ---------------------------------------------------------------------------

## Degraus de 1 a 10, os mesmos do DifficultyManager.
##
## `get_best_move` acima e uma heuristica: vencer, bloquear, centro, canto. Ela
## perde para a abertura classica de forquilha -- canto, canto oposto, e o
## jogador fecha duas linhas de uma vez. Do degrau 6 em diante quem joga e o
## minimax, que nao tem forquilha para explorar.
##
## Jogo da velha e um jogo resolvido: com os dois jogando bem, da empate. Por
## isso os degraus altos mexem em duas coisas alem da forca da busca:
##
##   - **quem abre.** Do degrau 8 em diante a IA sai na frente. Enquanto o
##     jogador abria sempre, contra minimax perfeito ele nao podia perder --
##     no maximo empatar -- e a escada travava para sempre no topo. Era esse o
##     "descobri como ganhar e nao perdi mais": nao havia derrota possivel.
##   - **variar entre jogadas igualmente boas.** O minimax devolvia sempre a
##     primeira da lista de preferencia, entao a partida inteira era decorada
##     depois de vista uma vez. Sortear entre as jogadas de mesma nota nao
##     enfraquece nada -- elas valem o mesmo -- e desmancha a linha decorada.

const MAX_LEVEL := 10
const MIN_LEVEL := 1

## Do degrau 8 para cima a IA abre a partida.
const NIVEL_IA_ABRE := 8

## Chance de o degrau jogar abaixo da propria forca, por degrau (indice 0 = 1).
## Nos degraus 1 a 4 o desvio e jogada ao acaso; de 6 a 8, cair na heuristica.
const DESVIO := [1.0, 0.60, 0.35, 0.15, 0.0, 0.45, 0.25, 0.10, 0.0, 0.0]

## Ordem de desempate do minimax: centro, cantos, laterais.
const PREFERENCE := [4, 0, 2, 6, 8, 1, 3, 5, 7]

## Casas de onde saem as forquilhas: o centro e os quatro cantos.
##
## O minimax da nota 0 as nove aberturas -- com jogo perfeito dos dois lados
## toda partida empata, entao pela nota tanto faz. Mas "tanto faz" so vale
## contra quem nao erra: abrir numa lateral nao ameaca nada e deixa o outro
## lado empatar sem pensar, enquanto centro e canto montam forquilha na
## primeira desatencao. O sorteio entre jogadas de mesma nota fica restrito a
## estas casas -- variedade sem jogar de graca.
const CASAS_FORTES := [4, 0, 2, 6, 8]


static func clamp_level(level: int) -> int:
	return clampi(level, MIN_LEVEL, MAX_LEVEL)


## Verdadeiro quando e a IA que faz a primeira jogada da partida.
static func ai_opens(level: int) -> bool:
	return clamp_level(level) >= NIVEL_IA_ABRE


## A jogada da IA no degrau pedido, ou -1 se o tabuleiro esta cheio.
static func get_move(grid: Grid2D, ai_player_id: int, level: int) -> int:
	var empty := get_empty_indices(grid)
	if empty.is_empty():
		return -1

	var lvl := clamp_level(level)
	var desvio: float = DESVIO[lvl - 1]

	if lvl <= 5:
		# Degraus de baixo: heuristica com chance de jogar qualquer coisa.
		if randf() < desvio:
			empty.shuffle()
			return empty[0]
		if lvl <= 2:
			var fecha := _find_immediate(grid, ai_player_id, empty)
			if fecha != -1:
				return fecha
			empty.shuffle()
			return empty[0]
		return get_best_move(grid, ai_player_id)

	# Degraus de cima: minimax, com chance de escorregar para a heuristica.
	if desvio > 0.0 and randf() < desvio:
		return get_best_move(grid, ai_player_id)
	return minimax_move(grid, ai_player_id)


## A casa que fecha a linha de `player_id` agora, ou -1.
static func _find_immediate(grid: Grid2D, player_id: int, empty: Array[int]) -> int:
	for idx in empty:
		grid.cells[idx] = player_id
		var venceu := check_win(grid, player_id)
		grid.cells[idx] = 0
		if venceu:
			return idx
	return -1


## Minimax completo. Cabe inteiro: sao no maximo 9! = 362.880 folhas e a poda
## alfa-beta corta a maior parte, entao roda em fracao de milissegundo.
##
## Entre as jogadas de melhor nota, sorteia. Todas valem o mesmo para a busca,
## entao a forca nao muda -- so para de ser a mesma partida toda vez.
static func minimax_move(grid: Grid2D, ai_player_id: int) -> int:
	var human_id := 1 if ai_player_id == 2 else 2
	var melhores: Array[int] = []
	var melhor_nota := -100

	for idx in PREFERENCE:
		if grid.cells[idx] != 0:
			continue
		grid.cells[idx] = ai_player_id
		var nota := _minimax(grid, ai_player_id, human_id, false, 1, -100, 100)
		grid.cells[idx] = 0
		if nota > melhor_nota:
			melhor_nota = nota
			melhores = [idx] as Array[int]
		elif nota == melhor_nota:
			melhores.append(idx)

	if melhores.is_empty():
		return -1

	var fortes: Array[int] = []
	for idx in melhores:
		if idx in CASAS_FORTES:
			fortes.append(idx)
	var sorteio := fortes if not fortes.is_empty() else melhores
	return sorteio[randi() % sorteio.size()]


## Nota da posicao pelos olhos de `ai_id`. Vitoria mais rapida vale mais que
## vitoria demorada -- sem o `depth` a IA adia o xeque-mate indefinidamente.
static func _minimax(grid: Grid2D, ai_id: int, human_id: int, maximizando: bool,
		depth: int, alfa: int, beta: int) -> int:
	if check_win(grid, ai_id):
		return 10 - depth
	if check_win(grid, human_id):
		return depth - 10

	var livres := get_empty_indices(grid)
	if livres.is_empty():
		return 0

	var a := alfa
	var b := beta
	if maximizando:
		var melhor := -100
		for idx in livres:
			grid.cells[idx] = ai_id
			melhor = maxi(melhor, _minimax(grid, ai_id, human_id, false, depth + 1, a, b))
			grid.cells[idx] = 0
			a = maxi(a, melhor)
			if b <= a:
				break
		return melhor

	var pior := 100
	for idx in livres:
		grid.cells[idx] = human_id
		pior = mini(pior, _minimax(grid, ai_id, human_id, true, depth + 1, a, b))
		grid.cells[idx] = 0
		b = mini(b, pior)
		if b <= a:
			break
	return pior
