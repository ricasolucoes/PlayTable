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

	# Le com uma instancia limpa, como um boot novo faria: reler no proprio
	# autoload nao distingue o que esta no disco do que esta so na memoria.
	SaveManager.save_data()
	var novo: Node = load("res://core/save/SaveManager.gd").new()
	novo.load_data()
	assert_eq(novo.get_setting("locale"), "es", "sobrevive a releitura do disco")
	novo.free()


# ------------------------------------------------ o codigo e o CSV batem

## Pastas de producao varridas pelos tres testes abaixo.
const FONTES := ["res://core", "res://games", "res://shared"]


## Todo arquivo com uma das extensoes, recursivamente.
func _arquivos(extensoes: Array) -> Array:
	var achados: Array = []
	var pilha: Array = FONTES.duplicate()
	while not pilha.is_empty():
		var pasta: String = pilha.pop_back()
		var d := DirAccess.open(pasta)
		if d == null:
			continue
		d.list_dir_begin()
		var nome := d.get_next()
		while nome != "":
			if nome.begins_with("."):
				nome = d.get_next()
				continue
			var caminho := pasta.path_join(nome)
			if d.current_is_dir():
				pilha.append(caminho)
			elif nome.get_extension() in extensoes:
				achados.append(caminho)
			nome = d.get_next()
		d.list_dir_end()
	return achados


func _texto_de(caminho: String) -> String:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _chaves_do_csv() -> Dictionary:
	var chaves := {}
	var linhas := _linhas_do_csv()
	for i in range(1, linhas.size()):
		chaves[linhas[i][0]] = true
	return chaves


## Chave citada em `tr("X")` ou posta como `text = "X"` numa cena, mas sem linha
## no CSV, aparece na tela como o proprio nome da chave -- "MENU_TODAY_QUESTS"
## no lugar de "Desafios de hoje". Era o caso das dezenove `GAME_DESC_*`, que o
## catalogo citava e o CSV nao tinha.
func test_toda_chave_citada_no_codigo_tem_linha_no_csv() -> void:
	var chaves := _chaves_do_csv()
	var re_tr := RegEx.create_from_string('\\btr\\("([A-Z][A-Z0-9_]+)"\\)')
	var re_txt := RegEx.create_from_string('(?m)^text = "([A-Z][A-Z0-9_]+)"$')
	var orfas: Array[String] = []
	for caminho in _arquivos(["gd"]):
		for m in re_tr.search_all(_texto_de(caminho)):
			if not chaves.has(m.get_string(1)):
				orfas.append("%s: %s" % [caminho.get_file(), m.get_string(1)])
	for caminho in _arquivos(["tscn"]):
		for m in re_txt.search_all(_texto_de(caminho)):
			if not chaves.has(m.get_string(1)):
				orfas.append("%s: %s" % [caminho.get_file(), m.get_string(1)])
	assert_eq(orfas, [] as Array[String], "chave citada sem linha no CSV")


## Cena com a frase escrita dentro nunca muda de idioma: o `text` de um Control
## e traduzido pelo Godot quando o valor E uma chave, e ignorado quando e texto
## pronto. Numeros, simbolos e emoji (o "⭐⭐⭐" do modal, o "7" do contador)
## passam -- nao sao frase.
func test_nenhuma_cena_tem_frase_escrita_no_lugar_da_chave() -> void:
	var chaves := _chaves_do_csv()
	var re_txt := RegEx.create_from_string('(?m)^text = "((?:[^"\\\\]|\\\\.)*)"$')
	var re_letras := RegEx.create_from_string("[A-Za-zÀ-ÿ]")
	var fixos: Array[String] = []
	for caminho in _arquivos(["tscn"]):
		for m in re_txt.search_all(_texto_de(caminho)):
			var valor := m.get_string(1)
			if valor == "" or chaves.has(valor):
				continue
			if re_letras.search_all(valor).size() < 3:
				continue
			fixos.append("%s: %s" % [caminho.get_file(), valor])
	assert_eq(fixos, [] as Array[String], "cena com texto fixo em vez de chave")


## `tr("X") % [a, b]` estoura em tempo de execucao quando a traducao daquele
## idioma tem menos marcadores que os argumentos passados -- e o jogo so quebra
## para quem esta naquele idioma, que e onde ninguem olha.
func test_os_marcadores_de_formato_batem_nos_tres_idiomas() -> void:
	var re_marc := RegEx.create_from_string("%[-0-9.]*[a-z]")
	var linhas := _linhas_do_csv()
	for i in range(1, linhas.size()):
		var linha: PackedStringArray = linhas[i]
		if linha.size() < 4:
			continue
		var referencia: Array[String] = []
		for m in re_marc.search_all(linha[1]):
			referencia.append(m.get_string())
		for col in range(2, 4):
			var achados: Array[String] = []
			for m in re_marc.search_all(linha[col]):
				achados.append(m.get_string())
			assert_eq(achados, referencia,
				"%s: marcadores de %s diferem do pt_BR" % [linha[0], IDIOMAS[col - 1]])


## O mesmo que o teste das cenas, do lado do codigo: literal que o script
## escreve direto num rotulo, num botao ou na barra de estado nunca muda de
## idioma. Foi assim que "%d Discos" sobreviveu no seletor da Torre de Hanoi
## depois de o resto da tela ja estar traduzido.
##
## Marcadores de formato e escapes saem antes da contagem: "+%d XP" e "%s\n%s"
## sao esqueleto, nao frase. Uma chave inteira ou um prefixo de chave
## ("LEAGUE_", que o codigo completa com o id da liga) tambem passam.
const ESCREVEM_NA_TELA := [
	".text =", ".game_title =", ".tooltip_text =", ".placeholder_text =",
	"set_status(", "finish_game(", "_end_game(", "UIKit.rotulo(", "UIKit.botao(",
]


func test_nenhum_script_escreve_frase_direto_na_tela() -> void:
	var chaves := _chaves_do_csv()
	var re_ruido := RegEx.create_from_string("%[-0-9.]*[a-z]")
	var re_letras := RegEx.create_from_string("[A-Za-zÀ-ÿ]")
	var fixos: Array[String] = []
	for caminho in _arquivos(["gd"]):
		var n := 0
		for linha in _texto_de(caminho).split("\n"):
			n += 1
			if linha.strip_edges().begins_with("#"):
				continue
			for valor in _literais_que_vao_para_a_tela(linha):
				if chaves.has(valor) or _e_prefixo_de_chave(valor, chaves):
					continue
				if valor.begins_with("res://") or valor.begins_with("uid://"):
					continue
				var nu := re_ruido.sub(valor, "", true).replace("\\n", "").replace("\\t", "")
				if re_letras.search_all(nu).size() < 3:
					continue
				fixos.append("%s:%d: %s" % [caminho.get_file(), n, valor])
	assert_eq(fixos, [] as Array[String], "script escrevendo frase em vez de chave")


## O literal que vem COLADO no marcador -- so espaco entre eles. `_icon.text =
## item["icon"]` nao entra: o "icon" ali e chave de dicionario, e a frase que
## aparece na tela veio de outro lugar. `set_status(tr("X"))` tambem nao: o que
## segue o parentese e o `tr`, nao a aspa.
func _literais_que_vao_para_a_tela(linha: String) -> Array[String]:
	var saida: Array[String] = []
	for marca in ESCREVEM_NA_TELA:
		var i := linha.find(marca)
		while i != -1:
			var j: int = i + marca.length()
			while j < linha.length() and linha[j] == " ":
				j += 1
			if j < linha.length() and linha[j] == '"':
				var fim := linha.find('"', j + 1)
				if fim != -1:
					saida.append(linha.substr(j + 1, fim - j - 1))
			i = linha.find(marca, i + 1)
	return saida


func _e_prefixo_de_chave(valor: String, chaves: Dictionary) -> bool:
	if valor == "" or not valor.ends_with("_"):
		return false
	for k in chaves:
		if str(k).begins_with(valor):
			return true
	return false
