class_name ConnectFourRules
extends RefCounted

## Rules and logic for Quatro Em Linha.

const BoardCoordScript = preload("res://shared/core_engine/board/BoardCoord.gd")

const ROWS = 6
const COLS = 7

static func can_drop(grid: Grid2D, col: int) -> bool:
	if col < 0 or col >= COLS: return false
	return grid.get_cell(0, col) == 0

static func drop_piece(grid: Grid2D, col: int, player_id: int) -> int:
	if not can_drop(grid, col): return -1
	for r in range(ROWS - 1, -1, -1):
		if grid.get_cell(r, col) == 0:
			grid.set_cell(r, col, player_id)
			return r
	return -1

static func check_win(grid: Grid2D, row: int, col: int, player_id: int) -> bool:
	var pos := Vector2i(row, col)
	for dir in BoardCoord.CONNECT_4_DIRECTIONS:
		if grid.count_streak_bidirectional(pos, dir, player_id) >= 4:
			return true
	return false

## As casas que formam a sequencia vencedora passando por (row, col).
##
## Devolve (linha, coluna), a convencao do Grid2D e do resto desta classe. Vazio
## quando a jogada nao fecha quatro. Vivia so em ConnectFourBoard.
static func get_winning_cells(grid: Grid2D, row: int, col: int, player_id: int) -> Array[Vector2i]:
	var origem := Vector2i(row, col)
	for dir in BoardCoordScript.CONNECT_4_DIRECTIONS:
		var celulas: Array[Vector2i] = [origem]
		for sentido in [1, -1]:
			var passo: Vector2i = dir * sentido
			var p: Vector2i = origem + passo
			while grid.is_valid_pos(p) and grid.get_cell_pos(p) == player_id:
				celulas.append(p)
				p += passo
		if celulas.size() >= 4:
			return celulas
	return [] as Array[Vector2i]

static func is_full(grid: Grid2D) -> bool:
	for c in range(COLS):
		if grid.get_cell(0, c) == 0:
			return false
	return true

static func get_valid_cols(grid: Grid2D) -> Array[int]:
	var list: Array[int] = []
	for c in range(COLS):
		if can_drop(grid, c):
			list.append(c)
	return list

## A jogada da IA no degrau pedido. Quem pensa e a `ConnectFourAI`: negamax com
## poda alfa-beta e orcamento de nos por degrau.
##
## O que morava aqui enxergava zero lances a frente -- vencer agora, bloquear a
## vitoria de agora, e senao a primeira coluna livre de uma ordem fixa. Perdia
## para a armadilha dupla, que e a linha padrao de vitoria do jogo, e como nao
## havia sorteio nenhum a partida era sempre a mesma.
static func get_move(grid: Grid2D, ai_player_id: int, level: int = 10) -> int:
	return ConnectFourAI.choose_move(grid, ai_player_id, level)


## A jogada mais forte que a IA sabe jogar. Atalho para `get_move()` no degrau
## do topo, onde nao ha chance de erro nem ruido na nota.
static func get_best_move(grid: Grid2D, ai_player_id: int) -> int:
	return get_move(grid, ai_player_id, ConnectFourAI.PERFIS.size())
