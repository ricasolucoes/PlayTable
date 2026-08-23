extends GutTest

## Batalha Naval — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_board_games.py::TestBattleship.
##
## Estados de celula: 0 agua oculta, 1 navio, 2 tiro na agua, 3 tiro certeiro.

const RulesScript = preload("res://games/batalha_naval/BattleshipRules.gd")

const TAMANHO := 10
const CASAS_DE_NAVIO := 17  # 5 + 4 + 3 + 3 + 2


func _frota() -> Array:
	var g: Grid2D = RulesScript.create_empty_grid()
	var frota: Array = RulesScript.place_all_ships_randomly(g)
	return [g, frota]


func test_grade_comeca_com_100_casas_de_agua() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	assert_eq(g.rows, TAMANHO, "10 linhas")
	assert_eq(g.cols, TAMANHO, "10 colunas")
	assert_eq(g.count_matching(0), 100, "tudo agua")


func test_a_frota_tem_cinco_navios_com_os_tamanhos_certos() -> void:
	for _tentativa in range(20):
		var par := _frota()
		var frota: Array = par[1]
		assert_eq(frota.size(), 5, "5 navios posicionados")
		var tamanhos: Array = []
		for s in frota:
			tamanhos.append(s["size"])
			assert_eq(s["cells"].size(), s["size"], "%s ocupa %d casas" % [s["name"], s["size"]])
			assert_eq(s["hits"], 0, "navio intacto")
			assert_false(s["sunk"], "navio flutuando")
		tamanhos.sort()
		assert_eq(tamanhos, [2, 3, 3, 4, 5], "tamanhos da frota classica")


func test_navios_nao_se_sobrepoem() -> void:
	for _tentativa in range(20):
		var par := _frota()
		var g: Grid2D = par[0]
		var frota: Array = par[1]
		assert_eq(g.count_matching(1), CASAS_DE_NAVIO, "17 casas ocupadas, nenhuma sobreposta")
		var vistas := {}
		for s in frota:
			for cell in s["cells"]:
				assert_false(vistas.has(cell), "casa %s usada por dois navios" % str(cell))
				vistas[cell] = true
				assert_eq(g.get_cell(cell.x, cell.y), 1, "casa marcada na grade")


func test_navios_ficam_dentro_do_tabuleiro_e_em_linha_reta() -> void:
	for _tentativa in range(20):
		var par := _frota()
		var frota: Array = par[1]
		for s in frota:
			var cells: Array = s["cells"]
			var horizontal: bool = cells[0].x == cells[cells.size() - 1].x
			for i in range(cells.size()):
				assert_between(cells[i].x, 0, TAMANHO - 1, "linha dentro do tabuleiro")
				assert_between(cells[i].y, 0, TAMANHO - 1, "coluna dentro do tabuleiro")
				if horizontal:
					assert_eq(cells[i], Vector2i(cells[0].x, cells[0].y + i), "casas contiguas na horizontal")
				else:
					assert_eq(cells[i], Vector2i(cells[0].x + i, cells[0].y), "casas contiguas na vertical")


func test_tiro_certeiro_marca_a_grade_e_conta_o_acerto() -> void:
	var par := _frota()
	var g: Grid2D = par[0]
	var frota: Array = par[1]
	var alvo: Vector2i = frota[0]["cells"][0]
	var r: Dictionary = RulesScript.register_shot(g, alvo, frota)
	assert_true(r["valid"], "tiro aceito")
	assert_true(r["is_hit"], "acertou")
	assert_eq(g.get_cell(alvo.x, alvo.y), 3, "casa marcada como acerto")
	assert_eq(frota[0]["hits"], 1, "navio contou o dano")
	assert_null(r["sunk_ship"], "porta-avioes de 5 casas nao afunda com 1 tiro")


func test_tiro_na_agua_marca_a_grade() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	var frota: Array = RulesScript.place_all_ships_randomly(g)
	var agua := Vector2i(-1, -1)
	for r in range(TAMANHO):
		for c in range(TAMANHO):
			if agua.x == -1 and g.get_cell(r, c) == 0:
				agua = Vector2i(r, c)
	var res: Dictionary = RulesScript.register_shot(g, agua, frota)
	assert_true(res["valid"], "tiro aceito")
	assert_false(res["is_hit"], "errou")
	assert_eq(g.get_cell(agua.x, agua.y), 2, "casa marcada como agua")


func test_tiro_repetido_e_recusado() -> void:
	var par := _frota()
	var g: Grid2D = par[0]
	var frota: Array = par[1]
	var alvo: Vector2i = frota[0]["cells"][0]
	RulesScript.register_shot(g, alvo, frota)
	var repetido: Dictionary = RulesScript.register_shot(g, alvo, frota)
	assert_false(repetido["valid"], "tiro repetido recusado")
	assert_false(repetido["is_hit"], "e nao conta como acerto")
	assert_eq(frota[0]["hits"], 1, "o dano nao dobra")


func test_navio_afunda_quando_todas_as_casas_sao_atingidas() -> void:
	var par := _frota()
	var g: Grid2D = par[0]
	var frota: Array = par[1]
	var navio: Dictionary = frota[4]  # Destroyer, o menor
	var ultimo: Dictionary = {}
	for cell in navio["cells"]:
		ultimo = RulesScript.register_shot(g, cell, frota)
	assert_true(navio["sunk"], "navio afundado")
	assert_eq(ultimo["sunk_ship"], navio, "o ultimo tiro anuncia o afundamento")
	assert_eq(RulesScript.count_sunk_ships(frota), 1, "1 navio abatido")
	assert_false(ultimo["all_sunk"], "os outros 4 seguem")


func test_check_ship_sunk_confirma_pela_grade() -> void:
	var par := _frota()
	var g: Grid2D = par[0]
	var frota: Array = par[1]
	var navio: Dictionary = frota[4]
	for i in range(navio["cells"].size() - 1):
		g.set_cell(navio["cells"][i].x, navio["cells"][i].y, 3)
	var parcial: Vector2i = navio["cells"][0]
	assert_eq(RulesScript.check_ship_sunk(frota, g, parcial.x, parcial.y), {},
		"ainda falta uma casa")
	var ultima: Vector2i = navio["cells"][navio["cells"].size() - 1]
	g.set_cell(ultima.x, ultima.y, 3)
	assert_eq(RulesScript.check_ship_sunk(frota, g, ultima.x, ultima.y), navio, "agora afundou")


func test_check_ship_sunk_em_casa_sem_navio() -> void:
	var par := _frota()
	var g: Grid2D = par[0]
	var frota: Array = par[1]
	var agua := Vector2i(-1, -1)
	for r in range(TAMANHO):
		for c in range(TAMANHO):
			if agua.x == -1 and g.get_cell(r, c) == 0:
				agua = Vector2i(r, c)
	assert_eq(RulesScript.check_ship_sunk(frota, g, agua.x, agua.y), {}, "nenhum navio ali")


func test_frota_inteira_afundada_encerra_a_partida() -> void:
	var par := _frota()
	var g: Grid2D = par[0]
	var frota: Array = par[1]
	assert_false(RulesScript.check_all_sunk(frota), "frota inteira de pe")
	var ultimo: Dictionary = {}
	for s in frota:
		for cell in s["cells"]:
			ultimo = RulesScript.register_shot(g, cell, frota)
	assert_true(RulesScript.check_all_sunk(frota), "frota destruida")
	assert_true(ultimo["all_sunk"], "o ultimo tiro anuncia o fim")
	assert_eq(RulesScript.count_sunk_ships(frota), 5, "5 navios abatidos")


func test_ia_sobre_grade_nunca_repete_tiro() -> void:
	var g: Grid2D = RulesScript.create_empty_grid()
	var frota: Array = RulesScript.place_all_ships_randomly(g)
	for _tiro in range(100):
		var pos: Vector2i = RulesScript.get_ai_shot(g)
		var antes = g.get_cell(pos.x, pos.y)
		assert_true(antes == 0 or antes == 1, "IA so mira casa nao atirada")
		RulesScript.register_shot(g, pos, frota)
	assert_eq(g.count_matching(0) + g.count_matching(1), 0, "as 100 casas foram atacadas")


func test_ia_com_pilha_de_caca_prioriza_o_alvo() -> void:
	var pilha: Array = [Vector2i(4, 4)]
	assert_eq(RulesScript.get_ai_shot(pilha, [] as Array), Vector2i(4, 4), "atira no alvo da pilha")


func test_ia_ignora_alvos_ja_atirados_e_fora_do_tabuleiro() -> void:
	var pilha: Array = [Vector2i(9, 9), Vector2i(-1, 5), Vector2i(3, 3)]
	var disparados: Array = [Vector2i(3, 3)]
	var pos: Vector2i = RulesScript.get_ai_shot(pilha, disparados)
	assert_ne(pos, Vector2i(3, 3), "nao repete o tiro")
	assert_ne(pos, Vector2i(-1, 5), "nao mira fora do tabuleiro")


func test_ia_sem_pilha_usa_paridade_de_tabuleiro_de_xadrez() -> void:
	for _tiro in range(30):
		var pos: Vector2i = RulesScript.get_ai_shot([] as Array, [] as Array)
		assert_eq((pos.x + pos.y) % 2, 0, "casa de paridade par")


func test_partida_completa_da_ia_afunda_a_frota() -> void:
	# Guarda contra deadlock: substitui test_e2e_battleship_simulation.
	for _partida in range(5):
		var g: Grid2D = RulesScript.create_empty_grid()
		var frota: Array = RulesScript.place_all_ships_randomly(g)
		var disparados: Array = []
		var tiros := 0
		while not RulesScript.check_all_sunk(frota) and tiros < 100:
			var pos: Vector2i = RulesScript.get_ai_shot([] as Array, disparados)
			disparados.append(pos)
			var r: Dictionary = RulesScript.register_shot(g, pos, frota)
			assert_true(r["valid"], "a IA nunca repete tiro")
			tiros += 1
		assert_true(RulesScript.check_all_sunk(frota), "frota afundada em no maximo 100 tiros")
		assert_true(tiros >= CASAS_DE_NAVIO, "precisou de ao menos 17 tiros")
