extends GutTest

## Integridade do catalogo — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_all_games_catalog.py, que so conferia
## se os arquivos existiam no disco. Aqui cada cena e de fato instanciada:
## um .tscn presente mas quebrado passava no teste Python e falha aqui.

const JOGOS_DE_TABULEIRO := [
	"res://games/jogo_da_velha/TicTacToeGame.tscn",
	"res://games/damas/CheckersGame.tscn",
	"res://games/batalha_naval/BattleshipGame.tscn",
	"res://games/quatro_em_linha/ConnectFourGame.tscn",
	"res://games/solitario/PegSolitaireGame.tscn",
	"res://games/campo_minado/MinesweeperGame.tscn",
	"res://games/domino/DominoGame.tscn",
	"res://games/ludo/LudoGame.tscn",
	"res://games/reversi/ReversiGame.tscn",
	"res://games/mancala/MancalaGame.tscn",
	"res://games/senet/SenetGame.tscn",
]

const JOGOS_DE_CARTAS := [
	"res://games/paciencia/KlondikeGame.tscn",
	"res://games/memoria/MemoryGame.tscn",
	"res://games/blackjack/BlackjackGame.tscn",
	"res://games/unolike/UnoLikeGame.tscn",
	"res://games/poker/PokerGame.tscn",
]

const MENUS := [
	"res://core/telas/MainMenu.tscn",
	"res://core/telas/MenuTabuleiro.tscn",
	"res://core/telas/MenuCartas.tscn",
]

const COMPONENTES_3D := [
	"res://shared/3d/Board3D.tscn",
	"res://shared/3d/Dice3D.tscn",
	"res://shared/3d/Token3D.tscn",
	"res://shared/3d/Card3D.tscn",
	"res://shared/3d/TabletopEnvironment3D.tscn",
]


# ------------------------------------------------------------ project.godot

func test_configuracao_do_projeto() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name", ""), "PlayTable", "nome do app")
	assert_eq(ProjectSettings.get_setting("application/run/main_scene", ""),
		"res://core/telas/MainMenu.tscn", "cena inicial")


func test_os_quatro_autoloads_estao_vivos() -> void:
	var root := get_tree().root
	for nome in ["SaveManager", "LocaleManager", "SceneManager", "AudioManager"]:
		var no := root.get_node_or_null(NodePath(nome))
		assert_not_null(no, "autoload %s ausente" % nome)
		if no != null:
			assert_true(no.get_script() != null, "autoload %s tem script" % nome)


# ------------------------------------------------------------------- Catalogo

func test_catalogo_lista_16_jogos() -> void:
	assert_eq(GameCatalog.get_board_games().size(), 11, "11 jogos de tabuleiro")
	assert_eq(GameCatalog.get_card_games().size(), 5, "5 jogos de cartas")
	assert_eq(GameCatalog.get_all_games().size(), 16, "16 no total")


func test_catalogo_bate_com_os_arquivos_esperados() -> void:
	var no_catalogo: Array[String] = []
	for def in GameCatalog.get_board_games():
		no_catalogo.append(def.scene_path)
		assert_eq(def.category, &"board", "%s classificado como tabuleiro" % def.title)
	for esperado in JOGOS_DE_TABULEIRO:
		assert_true(esperado in no_catalogo, "%s esta no catalogo" % esperado)

	var cartas_no_catalogo: Array[String] = []
	for def in GameCatalog.get_card_games():
		cartas_no_catalogo.append(def.scene_path)
		assert_eq(def.category, &"cards", "%s classificado como cartas" % def.title)
	for esperado in JOGOS_DE_CARTAS:
		assert_true(esperado in cartas_no_catalogo, "%s esta no catalogo" % esperado)


func test_cada_entrada_do_catalogo_tem_titulo_icone_e_descricao() -> void:
	for def in GameCatalog.get_all_games():
		assert_ne(def.title, "", "titulo preenchido")
		assert_ne(def.icon, "", "icone preenchido em %s" % def.title)
		assert_ne(def.description, "", "chave de descricao em %s" % def.title)
		assert_true(def.is_implemented, "%s marcado como implementado" % def.title)


## ACHADO (documentado no CHANGELOG, nao corrigido aqui): o catalogo aponta
## para chaves GAME_DESC_* que NAO existem em core/i18n/translations.csv, e o
## CSV tem 16 chaves GAME_* com o nome de cada jogo que NINGUEM usa — os menus
## montam o botao com game.title, que e texto fixo em portugues. Ou seja, os
## nomes dos jogos nunca sao traduzidos e as descricoes nunca aparecem.
## Escolher qual dos dois lados muda e decisao do dono; o teste abaixo tranca
## o que hoje esta certo: existe uma chave de nome traduzida para cada jogo.

func test_o_csv_tem_um_nome_traduzido_para_cada_um_dos_16_jogos() -> void:
	var chaves := [
		"GAME_CONNECT4", "GAME_TICTACTOE", "GAME_REVERSI", "GAME_BATTLESHIP",
		"GAME_CHECKERS", "GAME_MANCALA", "GAME_SOLITAIRE", "GAME_MINESWEEPER",
		"GAME_DOMINO", "GAME_LUDO", "GAME_SENET", "GAME_MEMORY",
		"GAME_KLONDIKE", "GAME_BLACKJACK", "GAME_UNOLIKE", "GAME_POKER",
	]
	assert_eq(chaves.size(), GameCatalog.get_all_games().size(), "uma chave por jogo")
	var antes := LocaleManager.current_locale
	for idioma in ["pt_BR", "en", "es"]:
		LocaleManager.set_locale(idioma)
		for chave in chaves:
			assert_ne(tr(chave), chave, "%s sem traducao em %s" % [chave, idioma])
	LocaleManager.set_locale(antes)


# -------------------------------------------------------------- Cenas de fato

func _instancia(caminho: String) -> void:
	assert_true(ResourceLoader.exists(caminho), "%s existe" % caminho)
	var cena := load(caminho) as PackedScene
	assert_not_null(cena, "%s carrega como PackedScene" % caminho)
	if cena == null:
		return
	var no := cena.instantiate()
	assert_not_null(no, "%s instancia" % caminho)
	add_child_autofree(no)


func test_os_onze_jogos_de_tabuleiro_instanciam() -> void:
	for caminho in JOGOS_DE_TABULEIRO:
		_instancia(caminho)


func test_os_cinco_jogos_de_cartas_instanciam() -> void:
	for caminho in JOGOS_DE_CARTAS:
		_instancia(caminho)


func test_os_tres_menus_instanciam() -> void:
	for caminho in MENUS:
		_instancia(caminho)


func test_os_componentes_3d_compartilhados_instanciam() -> void:
	for caminho in COMPONENTES_3D:
		_instancia(caminho)


func test_o_tema_da_interface_carrega() -> void:
	var tema: String = ProjectSettings.get_setting("gui/theme/custom", "")
	assert_ne(tema, "", "tema configurado")
	assert_true(ResourceLoader.exists(tema), "%s existe" % tema)
	assert_true(load(tema) is Theme, "%s e um Theme" % tema)


# --------------------------------------------------- Ciclo de vida compartilhado

## O ciclo que os 16 jogos repetiam mora em shared/BaseGame.gd desde a v0.4.0.
## Os dois testes abaixo trancam isso pelo lado de fora: que todo jogo de fato
## herda a classe, e que nenhum voltou a escrever a propria copia.

const CICLO_COMPARTILHADO := [
	"func _on_btn_back_pressed",
	"func _on_back_pressed",
	"func _on_btn_restart_pressed",
	"func _on_restart_pressed",
	"var game_over",
]


func _scripts_dos_jogos() -> Array[String]:
	var achados: Array[String] = []
	var jogos := DirAccess.open("res://games")
	assert_not_null(jogos, "res://games abre")
	if jogos == null:
		return achados
	for pasta in jogos.get_directories():
		var dir := DirAccess.open("res://games".path_join(pasta))
		if dir == null:
			continue
		for arquivo in dir.get_files():
			if arquivo.ends_with(".gd"):
				achados.append("res://games".path_join(pasta).path_join(arquivo))
	return achados


func test_cada_jogo_volta_para_o_menu_da_sua_categoria() -> void:
	var esperado := {}
	for definicao in GameCatalog.get_board_games():
		esperado[definicao.scene_path] = BaseGame.MENU_TABULEIRO
	for definicao in GameCatalog.get_card_games():
		esperado[definicao.scene_path] = BaseGame.MENU_CARTAS
	assert_eq(esperado.size(), 16, "os 16 jogos do catalogo")

	for caminho in esperado:
		var jogo: Node = add_child_autofree((load(caminho) as PackedScene).instantiate())
		assert_true(jogo is BaseGame, "%s herda BaseGame" % caminho)
		if jogo is BaseGame:
			assert_eq((jogo as BaseGame).menu_scene_path, esperado[caminho],
				"%s volta para o menu da categoria" % caminho)


func test_nenhum_jogo_reescreve_o_ciclo_de_vida() -> void:
	var scripts := _scripts_dos_jogos()
	assert_gt(scripts.size(), 16, "um script por jogo, no minimo")
	for caminho in scripts:
		var codigo := FileAccess.get_file_as_string(caminho)
		assert_ne(codigo, "", "%s foi lido" % caminho)
		for assinatura in CICLO_COMPARTILHADO:
			assert_false(codigo.contains(assinatura),
				"%s redeclara '%s' — o ciclo mora em shared/BaseGame.gd" % [caminho, assinatura])
