extends SceneTree

## Mede o custo por jogada da busca do Reversi em cada degrau.

func _initialize() -> void:
	seed(12345)
	for nivel in [1, 3, 5, 7, 8, 9, 10]:
		var g: Grid2D = ReversiRules.create_initial_board()
		var cells := ReversiAI.achatar(g)
		var vez := 1
		var passes := 0
		var jogadas := 0
		var soma := 0
		var pior := 0
		while passes < 2 and jogadas < 70:
			var possiveis := ReversiAI.gerar(cells, vez)
			if possiveis.is_empty():
				passes += 1
				vez = 3 - vez
				continue
			passes = 0
			var t1 := Time.get_ticks_usec()
			var idx := ReversiAI.choose_index(cells, vez, nivel if vez == 2 else 3)
			if vez == 2:
				var dt := Time.get_ticks_usec() - t1
				soma += dt
				pior = maxi(pior, dt)
			if idx >= 0:
				ReversiAI.aplicar(cells, idx, vez)
			jogadas += 1
			vez = 3 - vez
		var n := maxi(1, jogadas / 2)
		print("degrau %2d | jogadas=%3d | media=%6.1fms | pior=%6.1fms" %
			[nivel, jogadas, soma / 1000.0 / n, pior / 1000.0])
	quit()
