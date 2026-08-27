class_name ReversiRules
extends RefCounted

## Regras do Reversi. Quem escolhe a jogada da IA e a `ReversiAI`; a tabela
## posicional mora la, junto com a busca que a usa.

const ROWS = 8
const COLS = 8

static func create_initial_board() -> Grid2D:
	var grid := Grid2D.new(ROWS, COLS, 0)
	grid.set_cell(3, 3, 2) # White
	grid.set_cell(3, 4, 1) # Black
	grid.set_cell(4, 3, 1) # Black
	grid.set_cell(4, 4, 2) # White
	return grid

static func find_all_valid_moves(grid: Grid2D, piece: int) -> Dictionary:
	var moves: Dictionary = {}
	var opponent := 2 if piece == 1 else 1
	var directions := BoardCoord.ALL_8_DIRECTIONS
	
	for r in range(ROWS):
		for c in range(COLS):
			if grid.get_cell(r, c) != 0: continue
			var all_flips: Array[Vector2i] = []
			
			for d in directions:
				var current_flips: Array[Vector2i] = []
				var nr = r + d.x
				var nc = c + d.y
				
				while grid.is_valid(nr, nc) and grid.get_cell(nr, nc) == opponent:
					current_flips.append(Vector2i(nr, nc))
					nr += d.x
					nc += d.y
					
				if grid.is_valid(nr, nc) and grid.get_cell(nr, nc) == piece:
					if not current_flips.is_empty():
						all_flips.append_array(current_flips)
						
			if not all_flips.is_empty():
				moves[Vector2i(r, c)] = all_flips
				
	return moves

static func get_valid_moves(grid: Grid2D, piece: int) -> Array[Vector2i]:
	var moves := find_all_valid_moves(grid, piece)
	var list: Array[Vector2i] = []
	for p in moves.keys():
		list.append(p)
	return list

static func get_flipped_pieces(grid: Grid2D, pos: Vector2i, piece: int) -> Array[Vector2i]:
	var moves := find_all_valid_moves(grid, piece)
	if moves.has(pos):
		return moves[pos]
	return []

static func get_best_move(grid: Grid2D, ai_piece: int) -> Vector2i:
	return get_best_ai_move(grid, ai_piece)

static func get_winner(grid: Grid2D) -> Dictionary:
	var scores := count_scores(grid)
	if scores["black"] > scores["white"]:
		return {"winner": 1, "black": scores["black"], "white": scores["white"]}
	elif scores["white"] > scores["black"]:
		return {"winner": 2, "black": scores["black"], "white": scores["white"]}
	else:
		return {"winner": 0, "black": scores["black"], "white": scores["white"]}

static func apply_move(grid: Grid2D, pos: Vector2i, piece: int, flips: Array) -> void:
	grid.set_cell_pos(pos, piece)
	for f in flips:
		grid.set_cell_pos(f, piece)

static func count_scores(grid: Grid2D) -> Dictionary:
	var black := grid.count_matching(1)
	var white := grid.count_matching(2)
	return {"black": black, "white": white}

## A jogada da IA no degrau pedido. Quem pensa e a `ReversiAI`: negamax com
## poda alfa-beta, orcamento de nos por degrau e avaliacao que muda de fase
## junto com a partida.
##
## O minimax que morava aqui tinha profundidade fixa 3 e dois defeitos que se
## somavam: o no terminal lia a contagem de pecas para variaveis declaradas
## `bool` (60 e 4 viravam `true` e `true`, e a busca chamava de empate), e no
## no do adversario quem ficava sem jogada era consultado de novo no lugar do
## outro lado, entao passar a vez -- que no Reversi e rotina -- virava fim de
## jogo. Nos ultimos lances, que e onde o Reversi se decide na contagem, a
## busca dava zero para tudo.
static func get_move(grid: Grid2D, ai_piece: int, level: int = 10) -> Vector2i:
	return ReversiAI.choose_move(grid, ai_piece, level)


static func get_best_ai_move(grid: Grid2D, ai_piece: int) -> Vector2i:
	return ReversiAI.choose_move(grid, ai_piece, ReversiAI.PERFIS.size())
