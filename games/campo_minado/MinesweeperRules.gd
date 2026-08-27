class_name MinesweeperRules
extends RefCounted

## Rules and logic for Campo Minado.

const ROWS = 9
const COLS = 9
const MINES_COUNT = 10
const TOTAL_MINES = 10

## Quantas minas cada degrau da escada do DifficultyManager espalha no 9x9.
##
## O Campo Minado nao tem adversario: o numero de minas e a unica alavanca de
## dificuldade que ele tem. Ate aqui o tabuleiro era fixo em 10 minas e a
## escada andava do mesmo jeito -- vencer sete vezes no mesmo 9x9 levava ao
## degrau 10 e passava a pagar o dobro de XP pelo mesmo jogo. Agora o degrau
## muda o jogo.
##
## As pontas: 6 minas em 81 casas e um passeio; 22 e a densidade do nivel
## "expert" classico (99 em 480 casas), que num 9x9 quase sempre exige chute.
const MINAS_POR_DEGRAU := [6, 8, 10, 12, 13, 15, 16, 18, 20, 22]


## Quantas minas o degrau vale.
static func minas_do_degrau(level: int) -> int:
	var lvl := clampi(level, 1, MINAS_POR_DEGRAU.size())
	return int(MINAS_POR_DEGRAU[lvl - 1])

static func count_flagged(grid: Grid2D) -> int:
	var count: int = 0
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = grid.get_cell(r, c)
			if cell != null and cell.get("is_flagged", false):
				count += 1
	return count

static func create_empty_grid() -> Grid2D:
	var grid := Grid2D.new(ROWS, COLS)
	for r in range(ROWS):
		for c in range(COLS):
			grid.set_cell(r, c, {
				"is_mine": false,
				"is_revealed": false,
				"is_flagged": false,
				"adjacent_mines": 0
			})
	return grid

static func generate_mines(grid: Grid2D, safe_r: int, safe_c: int, count: int = MINES_COUNT) -> void:
	var placed: int = 0
	while placed < count:
		var r := randi() % ROWS
		var c := randi() % COLS
		# Não coloca na célula do primeiro clique nem nas 8 vizinhas
		if abs(r - safe_r) <= 1 and abs(c - safe_c) <= 1:
			continue
			
		var cell: Dictionary = grid.get_cell(r, c)
		if not cell["is_mine"]:
			cell["is_mine"] = true
			placed += 1
			
	# Calcula vizinhos
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = grid.get_cell(r, c)
			if cell["is_mine"]: continue
			
			var mine_count: int = 0
			var neighbors := grid.get_all_neighbors(r, c)
			for n in neighbors:
				if grid.get_cell(n.x, n.y)["is_mine"]:
					mine_count += 1
			cell["adjacent_mines"] = mine_count

static func reveal_cell(grid: Grid2D, start_r: int, start_c: int) -> Array[Vector2i]:
	var revealed_positions: Array[Vector2i] = []
	var queue: Array[Vector2i] = [Vector2i(start_r, start_c)]
	
	while not queue.is_empty():
		var pos = queue.pop_front()
		if not grid.is_valid(pos.x, pos.y): continue
		
		var cell: Dictionary = grid.get_cell(pos.x, pos.y)
		if cell["is_revealed"] or cell["is_flagged"] or cell["is_mine"]:
			continue
			
		cell["is_revealed"] = true
		revealed_positions.append(pos)
		
		if cell["adjacent_mines"] == 0:
			var neighbors := grid.get_all_neighbors(pos.x, pos.y)
			for n in neighbors:
				var n_cell: Dictionary = grid.get_cell(n.x, n.y)
				if not n_cell["is_revealed"] and not n_cell["is_flagged"] and not n_cell["is_mine"]:
					queue.append(n)
					
	return revealed_positions

static func check_win(grid: Grid2D) -> bool:
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = grid.get_cell(r, c)
			if not cell["is_mine"] and not cell["is_revealed"]:
				return false
	return true
