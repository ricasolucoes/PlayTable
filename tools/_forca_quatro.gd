extends SceneTree

## Confere que a escada do Quatro em Linha sobe: o degrau de cima tem de ganhar
## do de baixo, e qualquer degrau tem de ganhar da IA antiga (vencer agora,
## bloquear agora, e senao a primeira coluna livre da ordem fixa).
##
## Mesmo molde de `_forca_damas.gd` e `_forca_reversi.gd`.

const ORDEM_ANTIGA := [3, 2, 4, 1, 5, 0, 6]


## A IA que existia antes, reconstruida aqui para servir de piso de comparacao.
func _jogada_antiga(cells: PackedByteArray, alturas: PackedInt32Array, side: int) -> int:
	var outro := 3 - side
	var livres := ConnectFourAI.gerar(alturas)
	if livres.is_empty():
		return -1

	for col in livres:
		var r := ConnectFourAI.aplicar(cells, alturas, col, side)
		var fecha := ConnectFourAI.venceu(cells, r, col, side)
		ConnectFourAI.desfazer(cells, alturas, col)
		if fecha:
			return col

	for col in livres:
		var r := ConnectFourAI.aplicar(cells, alturas, col, outro)
		var fecha := ConnectFourAI.venceu(cells, r, col, outro)
		ConnectFourAI.desfazer(cells, alturas, col)
		if fecha:
			return col

	for col in ORDEM_ANTIGA:
		if alturas[col] < ConnectFourAI.ROWS:
			return col
	return livres[0]


## `um`/`dois`: degrau 1..10, ou -1 para a IA antiga. Devolve 1, 2 ou 0.
func _partida(um: int, dois: int) -> int:
	var g := Grid2D.new(6, 7, 0)
	var plano := ConnectFourAI.achatar(g)
	var cells: PackedByteArray = plano[0]
	var alturas: PackedInt32Array = plano[1]
	var vez := 1

	for _lance in range(42):
		var nivel := um if vez == 1 else dois
		var col := _jogada_antiga(cells, alturas, vez) if nivel < 0 \
			else ConnectFourAI.choose_column(cells, alturas, vez, nivel)
		if col < 0:
			return 0
		var r := ConnectFourAI.aplicar(cells, alturas, col, vez)
		if ConnectFourAI.venceu(cells, r, col, vez):
			return vez
		vez = 3 - vez
	return 0


func _duelo(a: int, b: int, partidas: int) -> void:
	var v := 0
	var d := 0
	var e := 0
	for i in range(partidas):
		# Alterna quem abre: abrir pesa muito no Quatro em Linha.
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
	# Os degraus de baixo sorteiam muito a jogada -- no degrau 1 sao 80% de
	# jogada ao acaso -- entao 12 partidas nao separam ruido de defeito. Eles
	# tambem sao baratos, e por isso a amostra la e maior.
	print("Escada sobe?")
	_duelo(2, 1, 40)
	_duelo(3, 2, 40)
	_duelo(5, 3, 30)
	_duelo(7, 5, 30)
	_duelo(8, 7, 30)
	_duelo(10, 8, 30)
	print("Contra a IA antiga (vencer/bloquear/ordem fixa):")
	_duelo(1, -1, 24)
	_duelo(5, -1, 24)
	_duelo(10, -1, 16)
	quit()
