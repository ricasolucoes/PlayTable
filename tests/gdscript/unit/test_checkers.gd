extends GutTest

## Damas — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestCheckers.
##
## Convencao do tabuleiro: 1 = peca branca (jogador), 2 = dama branca,
## -1 = peca preta (IA), -2 = dama preta, 0 = casa vazia.

const RulesScript = preload("res://games/damas/CheckersRules.gd")

const BRANCA := 1
const DAMA_BRANCA := 2
const PRETA := -1
const DAMA_PRETA := -2


func _vazio() -> Grid2D:
	return Grid2D.new(8, 8, 0)


func _conta(g: Grid2D, valor: int) -> int:
	var total := 0
	for cell in g.cells:
		if cell == valor:
			total += 1
	return total


func test_tabuleiro_inicial_tem_12_pecas_de_cada_lado() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	assert_eq(_conta(g, BRANCA), 12, "12 brancas")
	assert_eq(_conta(g, PRETA), 12, "12 pretas")
	assert_eq(_conta(g, 0), 40, "40 casas vazias")


func test_pecas_ficam_so_nas_casas_escuras() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	for r in range(8):
		for c in range(8):
			if (r + c) % 2 == 0:
				assert_eq(g.get_cell(r, c), 0, "casa clara (%d,%d) vazia" % [r, c])


func test_as_duas_fileiras_do_meio_comecam_vazias() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	for c in range(8):
		assert_eq(g.get_cell(3, c), 0, "linha 3 vazia")
		assert_eq(g.get_cell(4, c), 0, "linha 4 vazia")


func test_captura_simples_e_coroacao() -> void:
	var g := _vazio()
	g.set_cell(2, 2, BRANCA)
	g.set_cell(1, 1, PRETA)
	var caps: Array[Dictionary] = RulesScript.get_piece_captures(g, 2, 2)
	assert_eq(caps.size(), 1, "uma captura possivel")
	assert_eq(caps[0]["to"], Vector2i(0, 0), "aterrissa em (0,0)")
	assert_eq(caps[0]["captures"], [Vector2i(1, 1)], "come a peca de (1,1)")

	var r: Dictionary = RulesScript.execute_move(g, caps[0])
	assert_true(r["captured_any"], "houve captura")
	assert_true(r["promoted"], "chegou na ultima fileira e virou dama")
	assert_eq(g.get_cell(1, 1), 0, "peca capturada saiu do tabuleiro")
	assert_eq(g.get_cell(0, 0), DAMA_BRANCA, "dama branca coroada")
	assert_eq(g.get_cell(2, 2), 0, "casa de origem vazia")


func test_peca_preta_coroa_na_ultima_fileira() -> void:
	var g := _vazio()
	g.set_cell(6, 2, PRETA)
	var r: Dictionary = RulesScript.apply_move(g, Vector2i(6, 2), Vector2i(7, 3))
	assert_true(r["promoted"], "virou dama preta")
	assert_eq(g.get_cell(7, 3), DAMA_PRETA, "dama preta no lugar")


func test_peca_comum_so_anda_para_frente() -> void:
	var g := _vazio()
	g.set_cell(4, 4, BRANCA)
	var destinos: Array = []
	for m in RulesScript.get_piece_moves(g, 4, 4):
		destinos.append(m["to"])
	assert_eq(destinos.size(), 2, "duas diagonais para frente")
	for d in destinos:
		assert_eq(d.x, 3, "branca sobe uma linha")

	g.set_cell(4, 4, 0)
	g.set_cell(4, 4, PRETA)
	destinos.clear()
	for m in RulesScript.get_piece_moves(g, 4, 4):
		destinos.append(m["to"])
	assert_eq(destinos.size(), 2, "duas diagonais para frente")
	for d in destinos:
		assert_eq(d.x, 5, "preta desce uma linha")


func test_dama_anda_nas_quatro_diagonais() -> void:
	var g := _vazio()
	g.set_cell(4, 4, DAMA_BRANCA)
	assert_eq(RulesScript.get_piece_moves(g, 4, 4).size(), 4, "as quatro diagonais")


func test_dama_captura_para_tras() -> void:
	var g := _vazio()
	g.set_cell(2, 2, DAMA_BRANCA)
	g.set_cell(3, 3, PRETA)
	var caps: Array[Dictionary] = RulesScript.get_piece_captures(g, 2, 2)
	assert_eq(caps.size(), 1, "uma captura para tras")
	assert_eq(caps[0]["to"], Vector2i(4, 4), "aterrissa em (4,4)")
	assert_eq(caps[0]["captures"], [Vector2i(3, 3)], "come a peca de (3,3)")


func test_peca_comum_nao_captura_para_tras() -> void:
	var g := _vazio()
	g.set_cell(2, 2, BRANCA)
	g.set_cell(3, 3, PRETA)
	assert_eq(RulesScript.get_piece_captures(g, 2, 2), [] as Array[Dictionary],
		"peca comum branca nao come descendo")


func test_nao_captura_peca_da_propria_cor() -> void:
	var g := _vazio()
	g.set_cell(2, 2, BRANCA)
	g.set_cell(1, 1, BRANCA)
	assert_eq(RulesScript.get_piece_captures(g, 2, 2), [] as Array[Dictionary], "sem fogo amigo")


func test_captura_bloqueada_por_casa_ocupada() -> void:
	var g := _vazio()
	g.set_cell(2, 2, BRANCA)
	g.set_cell(1, 1, PRETA)
	g.set_cell(0, 0, PRETA)
	assert_eq(RulesScript.get_piece_captures(g, 2, 2), [] as Array[Dictionary],
		"nao ha onde aterrissar")


func test_captura_para_fora_do_tabuleiro_nao_conta() -> void:
	var g := _vazio()
	g.set_cell(1, 1, BRANCA)
	g.set_cell(0, 0, PRETA)
	assert_eq(RulesScript.get_piece_captures(g, 1, 1), [] as Array[Dictionary],
		"a casa de destino cairia fora")


func test_casa_vazia_nao_gera_jogada() -> void:
	var g := _vazio()
	assert_eq(RulesScript.get_piece_captures(g, 4, 4), [] as Array[Dictionary])
	assert_eq(RulesScript.get_piece_moves(g, 4, 4), [] as Array[Dictionary])


func test_captura_e_obrigatoria() -> void:
	var g := _vazio()
	g.set_cell(4, 4, BRANCA)   # tem captura
	g.set_cell(3, 3, PRETA)
	g.set_cell(6, 0, BRANCA)   # so tem passeio
	var moves: Array[Dictionary] = RulesScript.get_all_valid_moves(g, 1)
	assert_eq(moves.size(), 1, "com captura disponivel, so ela e oferecida")
	assert_eq(moves[0]["from"], Vector2i(4, 4), "a peca que come")


func test_captura_em_cadeia_e_sinalizada() -> void:
	var g := _vazio()
	g.set_cell(4, 4, BRANCA)
	g.set_cell(3, 3, PRETA)
	g.set_cell(1, 3, PRETA)
	var r: Dictionary = RulesScript.apply_move(g, Vector2i(4, 4), Vector2i(2, 2), Vector2i(3, 3))
	assert_true(r["captured_any"], "primeira captura feita")
	assert_eq(r["further_captures"].size(), 1, "ha uma segunda captura encadeada")
	assert_false(r["promoted"], "ainda nao coroou")


func test_movimento_simples_nao_procura_cadeia() -> void:
	var g := _vazio()
	g.set_cell(4, 4, BRANCA)
	var r: Dictionary = RulesScript.apply_move(g, Vector2i(4, 4), Vector2i(3, 3))
	assert_false(r["captured_any"], "sem captura")
	assert_eq(r["further_captures"], [] as Array[Dictionary], "nao ha cadeia depois de passeio")


func test_abertura_tem_sete_movimentos_para_cada_lado() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	assert_eq(RulesScript.get_all_valid_moves(g, 1).size(), 7, "brancas")
	assert_eq(RulesScript.get_all_valid_moves(g, -1).size(), 7, "pretas")


func test_variantes_formatadas_devolvem_captured_singular() -> void:
	var g := _vazio()
	g.set_cell(2, 2, BRANCA)
	g.set_cell(1, 1, PRETA)
	var caps: Array[Dictionary] = RulesScript.get_captures_for_piece(g, Vector2i(2, 2))
	assert_eq(caps.size(), 1)
	assert_eq(caps[0]["captured"], Vector2i(1, 1), "chave captured no singular")

	var g2 := _vazio()
	g2.set_cell(4, 4, BRANCA)
	var moves: Array[Dictionary] = RulesScript.get_valid_moves_for_piece(g2, Vector2i(4, 4))
	assert_eq(moves[0]["captured"], Vector2i(-1, -1), "passeio marca captured invalido")


func test_fim_de_jogo_quando_um_lado_fica_sem_pecas() -> void:
	assert_eq(RulesScript.check_game_over(RulesScript.create_initial_board()), 0, "abertura segue")

	var so_brancas := _vazio()
	so_brancas.set_cell(4, 4, BRANCA)
	assert_eq(RulesScript.check_game_over(so_brancas), 1, "brancas vencem")

	var so_pretas := _vazio()
	so_pretas.set_cell(4, 4, PRETA)
	assert_eq(RulesScript.check_game_over(so_pretas), -1, "pretas vencem")


func test_fim_de_jogo_quando_um_lado_fica_sem_jogada() -> void:
	# Branca encurralada na quina de cima: sem movimento, perde.
	var g := _vazio()
	g.set_cell(0, 0, BRANCA)
	g.set_cell(5, 5, PRETA)
	assert_eq(RulesScript.check_game_over(g), -1, "brancas travadas perdem")


func test_ia_escolhe_jogada_valida() -> void:
	var g: Grid2D = RulesScript.create_initial_board()
	var jogada: Dictionary = RulesScript.get_best_ai_move(g)
	assert_false(jogada.is_empty(), "IA tem jogada na abertura")
	assert_eq(g.get_cell(jogada["from"].x, jogada["from"].y), PRETA, "move uma peca preta")
	assert_eq(g.get_cell(jogada["to"].x, jogada["to"].y), 0, "para uma casa vazia")


func test_ia_sem_pecas_devolve_dicionario_vazio() -> void:
	var g := _vazio()
	g.set_cell(4, 4, BRANCA)
	assert_eq(RulesScript.get_best_ai_move(g), {}, "sem pretas nao ha jogada")


func test_partida_completa_termina() -> void:
	# Guarda contra deadlock: substitui test_e2e_checkers_simulation.
	for _partida in range(5):
		var g: Grid2D = RulesScript.create_initial_board()
		var lado := 1
		var jogadas := 0
		while RulesScript.check_game_over(g) == 0 and jogadas < 400:
			var moves: Array[Dictionary] = RulesScript.get_all_valid_moves(g, lado)
			assert_false(moves.is_empty(), "check_game_over prometeu jogada para o lado %d" % lado)
			moves.shuffle()
			RulesScript.execute_move(g, moves[0])
			jogadas += 1
			lado = -lado
		assert_true(jogadas > 0, "a partida andou")
		assert_true(jogadas < 400, "a partida terminou sem estourar o limite")
		assert_ne(RulesScript.check_game_over(g), 0, "houve um vencedor")


## `CheckersAI._expandir` nao chama `CheckersRules.get_piece_captures`: repete a
## deteccao de captura direto no vetor de casas, porque aquela devolve um
## Dicionario de tres chaves por captura e num no de busca isso e lixo puro.
## Duas copias da mesma regra so ficam de pe com um teste que as compare.
##
## Toda cadeia de capturas comeca por uma das capturas simples da peca, entao os
## primeiros saltos que a IA gera para uma peca tem de dar exatamente o conjunto
## que as regras enxergam dali.
func test_a_ia_gera_as_mesmas_capturas_que_as_regras() -> void:
	seed(20260827)
	var AIScript := preload("res://games/damas/CheckersAI.gd")
	var pecas := [BRANCA, DAMA_BRANCA, PRETA, DAMA_PRETA]

	for _sorteio in range(200):
		var g := _vazio()
		for _p in range(12):
			var r := randi() % 8
			var c := randi() % 8
			if (r + c) % 2 == 0:
				continue
			g.set_cell(r, c, pecas[randi() % pecas.size()])

		for lado in [1, -1]:
			# O que a IA enxerga: primeiro salto de cada cadeia, por peca.
			var da_ia := {}
			for turno in AIScript.generate_turns(g, lado):
				if turno["captures"].is_empty():
					continue
				var primeiro: Dictionary = turno["hops"][0]
				var origem: Vector2i = turno["from"]
				if not da_ia.has(origem):
					da_ia[origem] = {}
				da_ia[origem]["%s>%s" % [primeiro["to"], primeiro["captured"]]] = true

			# O que as regras enxergam, peca a peca.
			var das_regras := {}
			for r in range(8):
				for c in range(8):
					var p: int = g.get_cell(r, c)
					if p == 0 or (p > 0) != (lado > 0):
						continue
					for cap in RulesScript.get_piece_captures(g, r, c):
						var origem := Vector2i(r, c)
						if not das_regras.has(origem):
							das_regras[origem] = {}
						das_regras[origem]["%s>%s" % [cap["to"], cap["captures"][0]]] = true

			assert_eq(da_ia, das_regras,
				"lado %d: as duas geracoes de captura discordam em\n%s" % [lado, g.cells])


# ------------------------------------------------------------------ IA (busca)

const AIScript = preload("res://games/damas/CheckersAI.gd")

## Degrau sem erro nem ruido: as escolhas abaixo tem de sair sempre iguais.
const CERTEIRO := 10


func _tabuleiro(pecas: Dictionary) -> Grid2D:
	var g := _vazio()
	for pos in pecas:
		g.set_cell(pos.x, pos.y, pecas[pos])
	return g


func test_as_constantes_de_tamanho_batem_com_as_regras() -> void:
	# `CheckersAI` repete ROWS/COLS em vez de apontar para `CheckersRules`:
	# constante de uma classe apontando para a outra fecharia ciclo de parse.
	assert_eq(AIScript.ROWS, RulesScript.ROWS, "mesmas linhas")
	assert_eq(AIScript.COLS, RulesScript.COLS, "mesmas colunas")


## A cadeia de capturas e UMA jogada, nao tres. Enquanto a busca so enxergava um
## salto de cada vez ela nunca via o fim da sequencia.
func test_a_cadeia_de_capturas_sai_como_uma_jogada_so() -> void:
	var g := _tabuleiro({
		Vector2i(1, 2): PRETA,
		Vector2i(2, 3): BRANCA, Vector2i(4, 5): BRANCA,
	})
	var turnos: Array[Dictionary] = AIScript.generate_turns(g, -1)
	assert_eq(turnos.size(), 1, "uma jogada possivel")
	assert_eq(turnos[0]["captures"].size(), 2, "as duas capturas na mesma jogada")
	assert_eq(turnos[0]["to"], Vector2i(5, 6), "termina na ponta da cadeia")
	assert_eq(turnos[0]["hops"].size(), 2, "dois saltos para a cena animar")


## Diante de duas capturas obrigatorias, a IA escolhe a que come mais.
func test_a_ia_escolhe_a_captura_maior() -> void:
	var g := _tabuleiro({
		Vector2i(1, 2): PRETA,
		Vector2i(2, 3): BRANCA, Vector2i(4, 5): BRANCA,   # cadeia de duas
		Vector2i(2, 1): BRANCA,                            # captura de uma so
	})
	var turno: Dictionary = AIScript.choose_turn(g, -1, CERTEIRO)
	assert_eq(turno["captures"].size(), 2, "comeu duas, nao uma")


## Sem isto a IA entrega peca de graca -- era metade do "esta facil demais".
func test_a_ia_nao_entrega_peca_quando_tem_casa_segura() -> void:
	var g := _tabuleiro({
		Vector2i(3, 4): PRETA,
		Vector2i(5, 6): BRANCA,   # come em (4,5) e aterrissa em (3,4)
		Vector2i(7, 0): BRANCA,
	})
	var turno: Dictionary = AIScript.choose_turn(g, -1, CERTEIRO)
	assert_eq(turno["to"], Vector2i(4, 3), "foi para a casa que ninguem alcanca")


## A coroacao no meio da cadeia tem de estar na jogada: e ela que decide se a
## peca segue comendo para tras.
func test_a_peca_que_coroa_no_caminho_ja_sai_dama() -> void:
	var g := _tabuleiro({Vector2i(5, 2): PRETA, Vector2i(6, 3): BRANCA})
	var turnos: Array[Dictionary] = AIScript.generate_turns(g, -1)
	assert_eq(turnos.size(), 1)
	assert_eq(turnos[0]["to"], Vector2i(7, 4), "chegou na ultima fileira")
	assert_eq(turnos[0]["piece_after"], DAMA_PRETA, "a jogada ja sai coroada")


## Contrato entre a busca e a cena: a cena anima `hops` um a um chamando
## `CheckersRules.apply_move`, e o tabuleiro que sobra tem de ser exatamente o
## que a busca calculou. Se as duas contas divergirem, a IA joga uma partida e a
## tela mostra outra.
func test_a_cena_reproduz_a_jogada_que_a_busca_calculou() -> void:
	seed(20260827)
	for _partida in range(20):
		var g: Grid2D = RulesScript.create_initial_board()
		var lado := -1
		for _jogada in range(40):
			if RulesScript.check_game_over(g) != 0:
				break
			var turno: Dictionary = AIScript.choose_turn(g, lado, 3)
			if turno.is_empty():
				break

			# Caminho da busca.
			var pela_busca := g.clone()
			AIScript.aplicar(pela_busca, turno)

			# Caminho da cena: salto a salto.
			var pela_cena := g.clone()
			var pos: Vector2i = turno["from"]
			for hop in turno["hops"]:
				RulesScript.apply_move(pela_cena, pos, hop["to"], hop["captured"])
				pos = hop["to"]

			assert_eq(pela_cena.cells, pela_busca.cells,
				"busca e cena discordam depois de %s" % str(turno["hops"]))
			g = pela_busca
			lado = -lado


## A escada tem de subir de verdade: degrau alto ganha de degrau baixo. Sem esta
## trava, mexer no orcamento de nos volta a inverter a ordem sem ninguem notar
## -- foi o que aconteceu com o degrau 7, que perdia do 5.
func test_o_degrau_alto_ganha_do_degrau_baixo() -> void:
	seed(20260827)
	var vitorias := 0
	for i in range(4):
		# Alterna quem sai na frente: sair primeiro pesa nas damas.
		var forte := -1 if i % 2 == 0 else 1
		var g: Grid2D = RulesScript.create_initial_board()
		var lado := -1
		var fim := 0
		for _jogada in range(220):
			fim = RulesScript.check_game_over(g)
			if fim != 0:
				break
			var turno: Dictionary = AIScript.choose_turn(g, lado, 5 if lado == forte else 1)
			if turno.is_empty():
				fim = -lado
				break
			AIScript.aplicar(g, turno)
			lado = -lado
		if fim == forte:
			vitorias += 1
	assert_true(vitorias >= 3, "degrau 5 venceu so %d de 4 partidas contra o degrau 1" % vitorias)
