extends GutTest

## Regras dos jogos — guarda o painel de "como se joga".
##
## O par `rules.json` + CSV pode se desencontrar sem erro nenhum aparecer: `tr()`
## de chave desconhecida devolve a própria chave, então uma regra sem tradução
## sai na tela como "RULES_LUDO_S2_1" e ninguém nota até um jogador ver.

const CATALOGO := "res://core/configs/rules.json"
const CSV := "res://core/i18n/translations.csv"

## Os jogos que o usuário apontou como "não sei como se joga". Ficam listados
## aqui para que apagar uma entrada do JSON reprove, e não passe calado.
const EXIGEM_REGRAS := [
	"reversi", "mancala", "ludo", "gamao", "damas", "campo_minado",
	"batalha_naval", "hanoi", "nim", "solitario", "unolike",
]


func _chaves_do_csv() -> Dictionary:
	var f := FileAccess.open(CSV, FileAccess.READ)
	assert_not_null(f, "CSV de traduções existe")
	var chaves := {}
	f.get_csv_line()  # cabeçalho
	while not f.eof_reached():
		var linha := f.get_csv_line()
		if linha.size() < 4 or linha[0].strip_edges() == "":
			continue
		chaves[linha[0].strip_edges()] = [linha[1], linha[2], linha[3]]
	f.close()
	return chaves


func test_o_catalogo_de_regras_carrega() -> void:
	RulesCatalog.clear_cache()
	assert_gt(RulesCatalog.all_ids().size(), 0, "rules.json tem jogos")


func test_os_onze_jogos_apontados_tem_regras() -> void:
	for gid in EXIGEM_REGRAS:
		assert_true(RulesCatalog.has(gid), "%s tem regras escritas" % gid)
		assert_ne(RulesCatalog.goal_of(gid), "", "%s declara o objetivo" % gid)
		assert_gt(RulesCatalog.sections_of(gid).size(), 0, "%s tem ao menos uma seção" % gid)
		assert_ne(RulesCatalog.tip_of(gid), "", "%s tem dica de estratégia" % gid)


func test_todo_game_id_das_regras_existe_no_catalogo() -> void:
	var ids := {}
	for d in GameCatalog.get_board_games() + GameCatalog.get_card_games():
		ids[d.scene_path.get_base_dir().get_file()] = true
	for gid in RulesCatalog.all_ids():
		assert_true(ids.has(gid), "%s das regras é um jogo do catálogo" % gid)


func test_toda_chave_de_regra_tem_linha_no_csv_nos_tres_idiomas() -> void:
	var csv := _chaves_do_csv()
	var faltando: Array = []
	var vazias: Array = []
	for gid in RulesCatalog.all_ids():
		var chaves: Array = [RulesCatalog.goal_of(gid), RulesCatalog.tip_of(gid)]
		for secao in RulesCatalog.sections_of(gid):
			chaves.append(str(secao["title"]))
			for item in secao["items"]:
				chaves.append(str(item))
		for c in chaves:
			if c == "":
				continue
			if not csv.has(c):
				faltando.append(c)
				continue
			for idioma in csv[c]:
				if str(idioma).strip_edges() == "":
					vazias.append(c)
					break
	assert_eq(faltando, [], "toda chave citada em rules.json existe no CSV")
	assert_eq(vazias, [], "nenhuma tradução em branco")


func test_a_interface_do_painel_esta_traduzida() -> void:
	var csv := _chaves_do_csv()
	for c in ["RULES_TITLE", "RULES_GOAL", "RULES_TIP", "RULES_CLOSE", "BTN_RULES_ICON"]:
		assert_true(csv.has(c), "%s está no CSV" % c)


func test_o_painel_montado_respeita_o_piso_de_fonte_e_o_alvo_de_toque() -> void:
	var painel := RulesPanel.new()
	add_child_autofree(painel)
	painel.build("gamao", "Gamão")
	assert_true(painel.has_content(), "o gamão monta painel")
	await wait_frames(2)

	var pequenos: Array = []
	var apertados: Array = []
	for no in _descendentes(painel):
		if no is Button:
			var b := no as Button
			if b.custom_minimum_size.y > 0.0 and b.custom_minimum_size.y < UIKit.TOQUE_MIN:
				apertados.append(b.name)
		elif no is Label:
			var l := no as Label
			var tam: int = l.get_theme_font_size("font_size")
			if tam < UIKit.FONTE_MIUDA:
				pequenos.append("%s: %d px" % [l.name, tam])
	assert_eq(pequenos, [], "nenhum texto do painel abaixo de %d px" % UIKit.FONTE_MIUDA)
	assert_eq(apertados, [], "nenhum botão do painel abaixo de %d px" % UIKit.TOQUE_MIN)


func test_jogo_sem_regras_nao_monta_painel() -> void:
	var painel := RulesPanel.new()
	add_child_autofree(painel)
	painel.build("jogo_que_nao_existe", "Nada")
	assert_false(painel.has_content(), "sem entrada no JSON, sem painel")


func _descendentes(no: Node) -> Array:
	var saida: Array = []
	for f in no.get_children():
		saida.append(f)
		saida.append_array(_descendentes(f))
	return saida
