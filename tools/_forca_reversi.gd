extends SceneTree

## Confere que a escada do Reversi sobe: o degrau de cima tem de ganhar do de
## baixo, e qualquer degrau tem de ganhar da IA antiga (minimax de profundidade
## fixa 3, avaliacao so posicional, sem enxergar o fim de partida).
##
## Mesmo molde de `_forca_damas.gd`.

const PESOS_ANTIGOS := [
	[ 100, -20,  10,   5,   5,  10, -20, 100],
	[ -20, -50,  -2,  -2,  -2,  -2, -50, -20],
	[  10,  -2,   5,   1,   1,   5,  -2,  10],
	[   5,  -2,   1,   0,   0,   1,  -2,   5],
	[   5,  -2,   1,   0,   0,   1,  -2,   5],
	[  10,  -2,   5,   1,   1,   5,  -2,  10],
	[ -20, -50,  -2,  -2,  -2,  -2, -50, -20],
	[ 100, -20,  10,   5,   5,  10, -20, 100],
]


## A IA que existia antes, reconstruida aqui para servir de piso de comparacao.
func _jogada_antiga(cells: PackedByteArray, side: int) -> int:
	var jogadas := ReversiAI.gerar(cells, side)
	if jogadas.is_empty():
		return -1
	var melhor: int = jogadas[0]
	var melhor_nota := -999999
	for j in jogadas:
		var viradas := ReversiAI.aplicar(cells, j, side)
		var nota := -_antigo_minimax(cells, 3, -999999, 999999, 3 - side, side)
		ReversiAI.desfazer(cells, j, side, viradas)
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = j
	return melhor


func _antigo_minimax(cells: PackedByteArray, prof: int, alfa: int, beta: int, vez: int, ia: int) -> int:
	if prof == 0:
		return _antiga_nota(cells, ia) * (1 if vez == ia else -1)
	var jogadas := ReversiAI.gerar(cells, vez)
	if jogadas.is_empty():
		return _antiga_nota(cells, ia) * (1 if vez == ia else -1)
	var a := alfa
	var melhor := -999999
	for j in jogadas:
		var viradas := ReversiAI.aplicar(cells, j, vez)
		var nota := -_antigo_minimax(cells, prof - 1, -beta, -a, 3 - vez, ia)
		ReversiAI.desfazer(cells, j, vez, viradas)
		melhor = maxi(melhor, nota)
		a = maxi(a, melhor)
		if a >= beta:
			break
	return melhor


func _antiga_nota(cells: PackedByteArray, ia: int) -> int:
	var nota := 0
	for idx in range(64):
		var v: int = cells[idx]
		if v == 0:
			continue
		var peso: int = PESOS_ANTIGOS[idx / 8][idx % 8]
		nota += peso if v == ia else -peso
	return nota


## `pretas`/`brancas`: degrau 1..10, ou -1 para a IA antiga. Devolve 1 se as
## pretas venceram, 2 se as brancas, 0 no empate.
func _partida(pretas: int, brancas: int) -> int:
	var g: Grid2D = ReversiRules.create_initial_board()
	var cells := ReversiAI.achatar(g)
	var vez := 1
	var passes := 0

	while passes < 2:
		var jogadas := ReversiAI.gerar(cells, vez)
		if jogadas.is_empty():
			passes += 1
			vez = 3 - vez
			continue
		passes = 0
		var nivel := pretas if vez == 1 else brancas
		var idx := _jogada_antiga(cells, vez) if nivel < 0 else ReversiAI.choose_index(cells, vez, nivel)
		if idx >= 0:
			ReversiAI.aplicar(cells, idx, vez)
		vez = 3 - vez

	var p := 0
	var b := 0
	for v in cells:
		if v == 1:
			p += 1
		elif v == 2:
			b += 1
	if p > b:
		return 1
	if b > p:
		return 2
	return 0


func _duelo(a: int, b: int, partidas: int) -> void:
	var v := 0
	var d := 0
	var e := 0
	for i in range(partidas):
		# Alterna quem sai com as pretas: sair na frente pesa no Reversi.
		var r := _partida(a, b) if i % 2 == 0 else _partida(b, a)
		var venceu_a := (r == 1) if i % 2 == 0 else (r == 2)
		var venceu_b := (r == 2) if i % 2 == 0 else (r == 1)
		if r == 0:
			e += 1
		elif venceu_a:
			v += 1
		elif venceu_b:
			d += 1
	print("  %s vs %s -> %d vitorias, %d derrotas, %d empates" %
		[("antiga" if a < 0 else "degrau %d" % a), ("antiga" if b < 0 else "degrau %d" % b), v, d, e])


func _initialize() -> void:
	seed(2026)
	print("Escada sobe?")
	_duelo(3, 1, 12)
	_duelo(5, 3, 12)
	_duelo(7, 5, 12)
	_duelo(10, 7, 12)
	print("Contra a IA antiga (minimax 3, so posicional):")
	_duelo(1, -1, 12)
	_duelo(5, -1, 12)
	_duelo(8, -1, 12)
	_duelo(10, -1, 12)
	quit()
