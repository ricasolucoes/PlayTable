extends SceneTree

## Mede o custo por jogada da busca das Damas em cada degrau.

func _initialize() -> void:
	seed(12345)
	for nivel in [1, 3, 5, 7, 8, 9, 10]:
		var g: Grid2D = CheckersRules.create_initial_board()
		var lado := -1
		var jogadas := 0
		var soma := 0
		var pior := 0
		while CheckersRules.check_game_over(g) == 0 and jogadas < 120:
			var t1 := Time.get_ticks_usec()
			var turno: Dictionary = CheckersAI.choose_turn(g, lado, nivel if lado == -1 else 3)
			if turno.is_empty():
				break
			if lado == -1:
				var dt := Time.get_ticks_usec() - t1
				soma += dt
				pior = maxi(pior, dt)
			CheckersAI.aplicar(g, turno)
			jogadas += 1
			lado = -lado
		var n := maxi(1, jogadas / 2)
		print("degrau %2d | jogadas=%3d | media=%6.1fms | pior=%6.1fms" %
			[nivel, jogadas, soma / 1000.0 / n, pior / 1000.0])
	quit()
