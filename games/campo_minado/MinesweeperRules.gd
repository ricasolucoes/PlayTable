class_name MinesweeperRules
extends RefCounted

## Regras do Campo Minado, sobre um `Grid2D` de qualquer tamanho.
##
## As funcoes leem `grid.rows` e `grid.cols`: o tabuleiro cresce com o degrau
## da escada, e nenhuma regra pode supor o 9x9. As constantes abaixo sao so o
## tabuleiro classico de entrada, que `create_empty_grid()` monta sem argumento.

const ROWS = 9
const COLS = 9
const MINES_COUNT = 10
const TOTAL_MINES = 10

## O que cada degrau da escada do DifficultyManager monta: [linhas, colunas,
## minas]. O Campo Minado nao tem adversario, entao o tabuleiro e a densidade
## sao a dificuldade.
##
## Ate aqui so o numero de minas mudava, sempre no mesmo 9x9, e o jogador nao
## via degrau nenhum: ganhar sete vezes levava ao topo da escada e ao dobro de
## XP pelo mesmo tabuleiro. Agora o campo cresce em altura (a tela do telefone
## e alta), as colunas param em 10 para a casa continuar cabendo no dedo, e a
## densidade sobe de 9% a 22% -- a do nivel "expert" classico.
const DEGRAUS := [
	[8, 8, 6],
	[9, 9, 8],
	[9, 9, 10],
	[10, 9, 13],
	[11, 9, 16],
	[12, 9, 19],
	[13, 10, 23],
	[14, 10, 27],
	[15, 10, 31],
	[16, 10, 36],
]

## Compatibilidade: quantas minas cada degrau espalha.
const MINAS_POR_DEGRAU := [6, 8, 10, 13, 16, 19, 23, 27, 31, 36]


## Linhas e colunas do degrau, como Vector2i(linhas, colunas).
static func dimensoes_do_degrau(level: int) -> Vector2i:
	var d: Array = DEGRAUS[clampi(level, 1, DEGRAUS.size()) - 1]
	return Vector2i(int(d[0]), int(d[1]))


## Quantas minas o degrau vale.
static func minas_do_degrau(level: int) -> int:
	var d: Array = DEGRAUS[clampi(level, 1, DEGRAUS.size()) - 1]
	return int(d[2])


static func count_flagged(grid: Grid2D) -> int:
	var count: int = 0
	for r in range(grid.rows):
		for c in range(grid.cols):
			var cell: Dictionary = grid.get_cell(r, c)
			if cell != null and cell.get("is_flagged", false):
				count += 1
	return count


static func create_empty_grid(rows: int = ROWS, cols: int = COLS) -> Grid2D:
	var grid := Grid2D.new(rows, cols)
	for r in range(rows):
		for c in range(cols):
			grid.set_cell(r, c, {
				"is_mine": false,
				"is_revealed": false,
				"is_flagged": false,
				"adjacent_mines": 0
			})
	return grid


static func generate_mines(grid: Grid2D, safe_r: int, safe_c: int, count: int = MINES_COUNT) -> void:
	# Nunca pede mais minas do que ha casas fora da zona segura do primeiro
	# toque: o laco de sorteio nao terminaria.
	var livres := grid.rows * grid.cols - 9
	count = mini(count, maxi(livres, 0))
	var placed: int = 0
	while placed < count:
		var r := randi() % grid.rows
		var c := randi() % grid.cols
		# Não coloca na célula do primeiro clique nem nas 8 vizinhas
		if abs(r - safe_r) <= 1 and abs(c - safe_c) <= 1:
			continue

		var cell: Dictionary = grid.get_cell(r, c)
		if not cell["is_mine"]:
			cell["is_mine"] = true
			placed += 1

	# Calcula vizinhos
	for r in range(grid.rows):
		for c in range(grid.cols):
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
	for r in range(grid.rows):
		for c in range(grid.cols):
			var cell: Dictionary = grid.get_cell(r, c)
			if not cell["is_mine"] and not cell["is_revealed"]:
				return false
	return true
