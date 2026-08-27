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

## Niveis da IA. O jogo sobe um degrau a cada vitoria do jogador.
##
## `get_best_move` acima e uma heuristica: vencer, bloquear, centro, canto. Ela
## perde para a abertura classica de forquilha -- canto, canto oposto, e o
## jogador fecha duas linhas de uma vez -- e era sempre a mesma IA, partida
## apos partida. Do nivel 4 em diante quem joga e o minimax, que nao tem
## forquilha para explorar: no nivel 5 o melhor resultado possivel e o empate.
enum Level { EASY = 1, MEDIUM = 2, HARD = 3, EXPERT = 4, PERFECT = 5 }

const MAX_LEVEL := Level.PERFECT

## Chance de o nivel EXPERT jogar fora do minimax. E o degrau entre "quase
## sempre acerta" e "nunca erra": sem ele o salto do 3 para o 5 e brusco demais.
const EXPERT_SLIP := 0.22

## Ordem de desempate quando varias jogadas valem o mesmo para o minimax:
## centro, cantos, laterais. Sem isto a IA perfeita abre sempre na casa 0.
const PREFERENCE := [4, 0, 2, 6, 8, 1, 3, 5, 7]


static func level_name(level: int) -> String:
	match clampi(level, Level.EASY, MAX_LEVEL):
		Level.EASY: return "TTT_LEVEL_EASY"
		Level.MEDIUM: return "TTT_LEVEL_MEDIUM"
		Level.HARD: return "TTT_LEVEL_HARD"
		Level.EXPERT: return "TTT_LEVEL_EXPERT"
		_: return "TTT_LEVEL_PERFECT"


## A jogada da IA no nivel pedido, ou -1 se o tabuleiro esta cheio.
static func get_move(grid: Grid2D, ai_player_id: int, level: int) -> int:
	var empty := get_empty_indices(grid)
	if empty.is_empty():
		return -1
	var lvl := clampi(level, Level.EASY, MAX_LEVEL)

	match lvl:
		Level.EASY:
			empty.shuffle()
			return empty[0]
		Level.MEDIUM:
			var win_now := _find_immediate(grid, ai_player_id, empty)
			if win_now != -1:
				return win_now
			empty.shuffle()
			return empty[0]
		Level.HARD:
			return get_best_move(grid, ai_player_id)
		Level.EXPERT:
			if randf() < EXPERT_SLIP:
				return get_best_move(grid, ai_player_id)
			return minimax_move(grid, ai_player_id)
		_:
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
static func minimax_move(grid: Grid2D, ai_player_id: int) -> int:
	var human_id := 1 if ai_player_id == 2 else 2
	var melhor := -1
	var melhor_nota := -100

	for idx in PREFERENCE:
		if grid.cells[idx] != 0:
			continue
		grid.cells[idx] = ai_player_id
		var nota := _minimax(grid, ai_player_id, human_id, false, 1, -100, 100)
		grid.cells[idx] = 0
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = idx

	return melhor


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
