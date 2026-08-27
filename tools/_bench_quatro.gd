extends SceneTree

## Mede o custo por jogada da busca do Quatro em Linha em cada degrau.

func _initialize() -> void:
	seed(12345)
	for nivel in [1, 3, 5, 7, 8, 9, 10]:
		var g := Grid2D.new(6, 7, 0)
		var plano := ConnectFourAI.achatar(g)
		var cells: PackedByteArray = plano[0]
		var alturas: PackedInt32Array = plano[1]
		var vez := 1
		var jogadas := 0
		var soma := 0
		var pior := 0
		while jogadas < 42:
			var t1 := Time.get_ticks_usec()
			var col := ConnectFourAI.choose_column(cells, alturas, vez, nivel if vez == 2 else 3)
			if col < 0:
				break
			if vez == 2:
				var dt := Time.get_ticks_usec() - t1
				soma += dt
				pior = maxi(pior, dt)
			var r := ConnectFourAI.aplicar(cells, alturas, col, vez)
			jogadas += 1
			if ConnectFourAI.venceu(cells, r, col, vez):
				break
			vez = 3 - vez
		var n := maxi(1, jogadas / 2)
		print("degrau %2d | jogadas=%3d | media=%6.1fms | pior=%6.1fms" %
			[nivel, jogadas, soma / 1000.0 / n, pior / 1000.0])
	quit()
