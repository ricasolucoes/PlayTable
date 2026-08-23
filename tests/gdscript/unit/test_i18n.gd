extends GutTest

## Internacionalizacao — exercita o GDScript de producao.
##
## Especificacao herdada de tests/test_i18n.py, que testava um mock Python do
## LocaleManager. Aqui o alvo e o autoload real e o CSV que o Godot importa.

const CSV_PATH := "res://core/i18n/translations.csv"
const IDIOMAS := ["pt_BR", "en", "es"]

var _locale_original: String = ""


func before_each() -> void:
	_locale_original = LocaleManager.current_locale


func after_each() -> void:
	LocaleManager.set_locale(_locale_original)


func _linhas_do_csv() -> Array:
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	var linhas: Array = []
	while f != null and not f.eof_reached():
		var linha: PackedStringArray = f.get_csv_line()
		if linha.size() > 1 or (linha.size() == 1 and linha[0] != ""):
			linhas.append(linha)
	if f != null:
		f.close()
	return linhas


# ------------------------------------------------------------------------- CSV

func test_csv_existe_com_as_quatro_colunas() -> void:
	assert_true(FileAccess.file_exists(CSV_PATH), "translations.csv presente")
	var linhas := _linhas_do_csv()
	assert_true(linhas.size() > 20, "mais de 20 chaves traduzidas, achou %d" % (linhas.size() - 1))
	assert_eq(Array(linhas[0]), ["id", "pt_BR", "en", "es"], "cabecalho do CSV")


func test_nenhuma_chave_esta_duplicada_ou_vazia() -> void:
	var linhas := _linhas_do_csv()
	var vistas := {}
	for i in range(1, linhas.size()):
		var chave: String = linhas[i][0]
		assert_ne(chave.strip_edges(), "", "chave vazia na linha %d" % i)
		assert_false(vistas.has(chave), "chave %s duplicada" % chave)
		vistas[chave] = true


func test_todos_os_idiomas_estao_preenchidos() -> void:
	var linhas := _linhas_do_csv()
	for i in range(1, linhas.size()):
		var linha: PackedStringArray = linhas[i]
		assert_eq(linha.size(), 4, "linha %s tem as 4 colunas" % linha[0])
		for col in range(1, 4):
			assert_ne(linha[col].strip_edges(), "",
				"traducao %s faltando para %s" % [IDIOMAS[col - 1], linha[0]])


func test_chaves_essenciais_existem() -> void:
	var linhas := _linhas_do_csv()
	var chaves := {}
	for i in range(1, linhas.size()):
		chaves[linhas[i][0]] = true
	for essencial in ["APP_NAME", "APP_TITLE", "APP_SUBTITLE", "MENU_BOARD_GAMES",
			"MENU_CARD_GAMES", "BTN_BACK", "BTN_LANGUAGE"]:
		assert_true(chaves.has(essencial), "chave %s presente" % essencial)


func test_os_tres_catalogos_compilados_estao_registrados() -> void:
	var registrados: PackedStringArray = ProjectSettings.get_setting(
		"internationalization/locale/translations", PackedStringArray())
	assert_eq(registrados.size(), 3, "tres catalogos no project.godot")
	for caminho in registrados:
		assert_true(ResourceLoader.exists(caminho), "catalogo %s carrega" % caminho)


func test_traducao_muda_com_o_idioma() -> void:
	LocaleManager.set_locale("pt_BR")
	var em_portugues := tr("MENU_BOARD_GAMES")
	LocaleManager.set_locale("en")
	var em_ingles := tr("MENU_BOARD_GAMES")
	assert_ne(em_portugues, "MENU_BOARD_GAMES", "a chave foi traduzida em pt_BR")
	assert_ne(em_ingles, "MENU_BOARD_GAMES", "a chave foi traduzida em en")
	assert_ne(em_portugues, em_ingles, "os dois idiomas dao textos diferentes")


# --------------------------------------------------------------- LocaleManager

func test_deteccao_do_idioma_do_sistema() -> void:
	assert_eq(LocaleManager._match_supported("pt_BR"), "pt_BR", "portugues")
	assert_eq(LocaleManager._match_supported("pt_PT"), "pt_BR", "portugues de Portugal cai no pt_BR")
	assert_eq(LocaleManager._match_supported("en_US"), "en", "ingles")
	assert_eq(LocaleManager._match_supported("es_AR"), "es", "espanhol")
	assert_eq(LocaleManager._match_supported("ja_JP"), "pt_BR", "idioma sem suporte cai no pt_BR")
	assert_eq(LocaleManager._match_supported("EN_GB"), "en", "comparacao sem diferenciar maiusculas")


func test_idiomas_suportados() -> void:
	assert_eq(LocaleManager.SUPPORTED_LOCALES.size(), 3, "tres idiomas")
	for loc in LocaleManager.SUPPORTED_LOCALES:
		assert_true(LocaleManager._is_supported(loc["code"]), "%s suportado" % loc["code"])
	assert_false(LocaleManager._is_supported("ja"), "japones nao suportado")
	assert_false(LocaleManager._is_supported(""), "codigo vazio nao suportado")


func test_troca_de_idioma_avisa_o_translation_server() -> void:
	LocaleManager.set_locale("es")
	assert_eq(LocaleManager.get_current_locale(), "es", "idioma corrente")
	assert_eq(TranslationServer.get_locale(), "es", "TranslationServer acompanhou")
	assert_eq(LocaleManager.get_current_locale_name(), "Español", "nome de exibicao")


func test_troca_de_idioma_emite_o_sinal() -> void:
	watch_signals(LocaleManager)
	LocaleManager.set_locale("en")
	assert_signal_emitted_with_parameters(LocaleManager, "locale_changed", ["en"])


func test_ciclo_percorre_os_tres_idiomas_e_volta() -> void:
	LocaleManager.set_locale("pt_BR")
	assert_eq(LocaleManager.cycle_locale(), "en", "pt_BR -> en")
	assert_eq(LocaleManager.cycle_locale(), "es", "en -> es")
	assert_eq(LocaleManager.cycle_locale(), "pt_BR", "es -> pt_BR")


func test_idioma_escolhido_e_persistido() -> void:
	LocaleManager.set_locale("es")
	assert_eq(SaveManager.get_setting("locale"), "es", "gravado no SaveManager")
	SaveManager.settings = {}
	SaveManager.load_data()
	assert_eq(SaveManager.get_setting("locale"), "es", "sobrevive a releitura do disco")
