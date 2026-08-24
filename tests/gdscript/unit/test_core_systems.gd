extends GutTest

## Sistemas centrais — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_core_systems.py, que testava mocks
## Python de SaveManager, Grid2D, Deck, TurnManager e GameAction. Aqui os
## alvos sao os autoloads e as classes de shared/core_engine que os jogos de
## fato usam -- TurnManager e GameAction sairam junto com o framework de
## jogadores e rede, que nenhum dos 16 jogos chegou a instanciar.

# ------------------------------------------------------------------ SaveManager

func before_each() -> void:
	_backup_settings = SaveManager.settings.duplicate(true)

func after_each() -> void:
	SaveManager.settings = _backup_settings
	SaveManager.save_data()

var _backup_settings: Dictionary = {}

func test_configuracoes_padrao() -> void:
	SaveManager.settings = {"master_volume": 1.0, "theme_dark": true}
	assert_eq(SaveManager.get_setting("master_volume"), 1.0, "volume cheio")
	assert_eq(SaveManager.get_setting("theme_dark"), true, "tema escuro")

func test_chave_inexistente_devolve_o_padrao_pedido() -> void:
	assert_eq(SaveManager.get_setting("chave_que_nao_existe", "valor_padrao"), "valor_padrao")
	assert_null(SaveManager.get_setting("chave_que_nao_existe"), "sem padrao devolve null")

func test_gravar_e_reler_do_disco() -> void:
	SaveManager.set_setting("master_volume", 0.75)
	SaveManager.set_setting("theme_dark", false)
	# Zera a memoria e recarrega do arquivo, como faz um novo boot.
	SaveManager.settings = {}
	SaveManager.load_data()
	assert_eq(SaveManager.get_setting("master_volume"), 0.75, "volume persistido")
	assert_eq(SaveManager.get_setting("theme_dark"), false, "tema persistido")

func test_arquivo_de_configuracao_fica_em_user() -> void:
	SaveManager.set_setting("master_volume", 0.5)
	assert_true(FileAccess.file_exists(SaveManager.SAVE_PATH),
		"arquivo criado em %s" % SaveManager.SAVE_PATH)

# ----------------------------------------------------------------------- Grid2D

func test_grid_respeita_os_limites() -> void:
	var g := Grid2D.new(5, 5, 0)
	assert_eq(g.rows, 5, "5 linhas")
	assert_eq(g.cols, 5, "5 colunas")
	assert_eq(g.cells.size(), 25, "25 celulas")
	assert_true(g.is_valid(0, 0), "quina superior esquerda")
	assert_true(g.is_valid(4, 4), "quina inferior direita")
	assert_false(g.is_valid(5, 5), "fora por baixo")
	assert_false(g.is_valid(-1, 0), "fora por cima")

func test_leitura_e_escrita_de_celula() -> void:
	var g := Grid2D.new(5, 5, 0)
	g.set_cell(2, 2, 99)
	assert_eq(g.get_cell(2, 2), 99, "valor gravado")
	assert_null(g.get_cell(9, 9), "fora do grid devolve null")
	g.set_cell(9, 9, 42)
	assert_eq(g.count_matching(42), 0, "escrita fora do grid e ignorada")

func test_indice_e_coordenada_sao_inversos() -> void:
	var g := Grid2D.new(6, 7, 0)
	for r in range(6):
		for c in range(7):
			var idx := g.get_index(r, c)
			assert_eq(g.get_coord(idx), Vector2i(r, c), "ida e volta de (%d,%d)" % [r, c])

func test_vizinhos_ortogonais_e_diagonais() -> void:
	var g := Grid2D.new(5, 5, 0)
	assert_eq(g.get_orthogonal_neighbors(0, 0).size(), 2, "quina tem 2 vizinhos ortogonais")
	assert_eq(g.get_orthogonal_neighbors(2, 2).size(), 4, "centro tem 4")
	assert_eq(g.get_all_neighbors(2, 2).size(), 8, "centro tem 8 no total")
	assert_eq(g.get_all_neighbors(0, 0).size(), 3, "quina tem 3 no total")

func test_sequencia_bidirecional() -> void:
	var g := Grid2D.new(6, 7, 0)
	for c in range(1, 5):
		g.set_cell(5, c, 1)
	assert_eq(g.count_streak_bidirectional(Vector2i(5, 2), Vector2i(0, 1), 1), 4,
		"quatro seguidas na horizontal")
	assert_eq(g.count_consecutive(Vector2i(5, 2), Vector2i(0, 1), 1), 2, "duas a direita")

func test_clone_e_copia_profunda() -> void:
	var g := Grid2D.new(6, 7, 0)
	g.set_cell(5, 2, 1)
	var copia: Grid2D = g.clone()
	assert_eq(copia.get_cell(5, 2), 1, "copia carrega o valor")
	copia.set_cell(5, 2, 2)
	assert_eq(g.get_cell(5, 2), 1, "o original nao muda junto")

func test_serializacao_do_grid() -> void:
	var g := Grid2D.new(3, 3, 0)
	g.set_cell(1, 1, 7)
	var restaurado: Grid2D = Grid2D.from_dict(g.to_dict())
	assert_eq(restaurado.rows, g.rows, "linhas")
	assert_eq(restaurado.cols, g.cols, "colunas")
	assert_eq(restaurado.cells, g.cells, "celulas iguais")

func test_is_full_e_count_matching() -> void:
	var g := Grid2D.new(2, 2, 0)
	assert_true(g.is_full(null), "nenhuma celula e null")
	assert_false(g.is_full(0), "todas sao 0")
	g.fill(1)
	assert_true(g.is_full(0), "nenhuma celula e 0")
	assert_eq(g.count_matching(1), 4, "quatro celulas com 1")
	assert_eq(g.find_all_matching(1).size(), 4, "quatro posicoes achadas")

# ------------------------------------------------------------------- Card/Deck

func test_baralho_frances_tem_52_cartas_metade_vermelha() -> void:
	var baralho: Deck = Deck.create_standard_52()
	assert_eq(baralho.size(), 52, "52 cartas")
	var vermelhas := 0
	var pretas := 0
	for c in baralho.cards:
		if c.is_red():
			vermelhas += 1
		elif c.is_black():
			pretas += 1
	assert_eq(vermelhas, 26, "26 vermelhas")
	assert_eq(pretas, 26, "26 pretas")

func test_baralho_com_as_alto() -> void:
	var baralho: Deck = Deck.create_standard_52(true)
	var ases := 0
	for c in baralho.cards:
		if c.value == 14:
			ases += 1
		assert_ne(c.value, 1, "nao sobra as valendo 1")
	assert_eq(ases, 4, "quatro ases valendo 14")

func test_baralho_uno_tem_108_cartas() -> void:
	assert_eq(Deck.create_uno_deck().size(), 108, "108 cartas")

func test_comprar_cartas_esvazia_o_baralho() -> void:
	var baralho: Deck = Deck.create_standard_52()
	assert_eq(baralho.draw_many(5).size(), 5, "5 cartas na mao")
	assert_eq(baralho.size(), 47, "47 no baralho")
	baralho.draw_many(100)
	assert_true(baralho.is_empty(), "baralho esgotado")
	assert_null(baralho.draw(), "comprar de baralho vazio devolve null")

func test_serializacao_de_carta() -> void:
	var c := Card.new(12, Card.Suit.HEARTS)
	var copia: Card = c.clone()
	assert_eq(copia.value, 12, "valor")
	assert_eq(copia.suit, Card.Suit.HEARTS, "naipe")
	assert_eq(copia.color_type, Card.ColorType.RED, "copas e vermelho")
	assert_eq(copia.get_short_name(), "Q♥", "nome curto")
