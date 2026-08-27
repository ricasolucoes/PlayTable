extends SceneTree

## Confere que a escada sobe: o degrau de cima tem de ganhar do de baixo, e
## qualquer degrau tem de ganhar da IA antiga (a primeira jogada da lista).

func _jogada_antiga(g: Grid2D, lado: int) -> Dictionary:
	var moves := CheckersRules.get_all_valid_moves(g, lado)
	if moves.is_empty():
		return {}
	var m: Dictionary = moves[0]
	var caps: Array[Vector2i] = []
	if m.has("captures"):
		caps.assign(m["captures"])
	return {"from": m["from"], "to": m["to"], "captures": caps,
		"hops": [], "piece_after": g.cells[m["from"].x * 8 + m["from"].y]}

## `pretas`/`brancas`: degrau 1..10, ou -1 para a IA antiga.
func _partida(pretas: int, brancas: int) -> int:
	var g: Grid2D = CheckersRules.create_initial_board()
	var lado := -1
	for _i in range(300):
		var fim := CheckersRules.check_game_over(g)
		if fim != 0:
			return fim
		var nivel := pretas if lado == -1 else brancas
		var turno: Dictionary
		if nivel < 0:
			var m := _jogada_antiga(g, lado)
			if m.is_empty():
				return -lado
			CheckersRules.execute_move(g, {"from": m["from"], "to": m["to"], "captures": m["captures"]})
			lado = -lado
			continue
		turno = CheckersAI.choose_turn(g, lado, nivel)
		if turno.is_empty():
			return -lado
		CheckersAI.aplicar(g, turno)
		lado = -lado
	return 0   # estourou o limite: empate tecnico

func _duelo(a: int, b: int, partidas: int) -> void:
	var v := 0
	var d := 0
	var e := 0
	for i in range(partidas):
		# Alterna quem sai com as pretas: sair na frente pesa nas damas.
		var r := _partida(a, b) if i % 2 == 0 else _partida(b, a)
		var venceu_a := (r == -1) if i % 2 == 0 else (r == 1)
		var venceu_b := (r == 1) if i % 2 == 0 else (r == -1)
		if r == 0: e += 1
		elif venceu_a: v += 1
		elif venceu_b: d += 1
	print("  %s vs %s -> %d vitorias, %d derrotas, %d empates" %
		[("antiga" if a < 0 else "degrau %d" % a), ("antiga" if b < 0 else "degrau %d" % b), v, d, e])

func _initialize() -> void:
	seed(2026)
	print("Escada sobe?")
	_duelo(3, 1, 12)
	_duelo(5, 3, 10)
	_duelo(7, 5, 8)
	_duelo(10, 7, 6)
	print("Contra a IA antiga (moves[0]):")
	_duelo(1, -1, 12)
	_duelo(3, -1, 10)
	_duelo(5, -1, 8)
	_duelo(8, -1, 6)
	quit()
