class_name RulesCatalog
extends RefCounted

## As regras de cada jogo, lidas de `core/configs/rules.json`.
##
## A divisão é deliberada: a ESTRUTURA (quantas seções, em que ordem, quais
## itens) mora no JSON; o TEXTO mora em `core/i18n/translations.csv`, porque é o
## CSV que `LocaleManager` traduz e que `test_i18n.gd` guarda contra chave sem
## tradução nos três idiomas. Codificar a estrutura no nome da chave -- varrer
## `RULES_X_S1_1`, `_S1_2`, até falhar -- faria o painel mudar de forma quando
## alguém renomeasse uma chave, sem erro nenhum.
##
## Jogo que não tem entrada aqui não ganha o botão de ajuda. É assim que se opta
## por não ter regras, e não com uma lista de exceções em outro lugar.

const CATALOG_PATH := "res://core/configs/rules.json"

static var _games: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_games = {}
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("RulesCatalog: %s não existe" % CATALOG_PATH)
		return
	var bruto := FileAccess.get_file_as_string(CATALOG_PATH)
	var json := JSON.new()
	if json.parse(bruto) != OK:
		push_error("RulesCatalog: %s inválido na linha %d" % [CATALOG_PATH, json.get_error_line()])
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		return
	var games: Variant = (json.data as Dictionary).get("games", {})
	if typeof(games) == TYPE_DICTIONARY:
		_games = games


## Este jogo tem regras escritas?
static func has(game_id: String) -> bool:
	_ensure_loaded()
	return _games.has(game_id)


## Chave i18n do objetivo, ou "" se o jogo não tem regras.
static func goal_of(game_id: String) -> String:
	_ensure_loaded()
	if not _games.has(game_id):
		return ""
	return str((_games[game_id] as Dictionary).get("goal", ""))


## Seções, cada uma `{"title": String, "items": Array[String]}` de chaves i18n.
static func sections_of(game_id: String) -> Array:
	_ensure_loaded()
	if not _games.has(game_id):
		return []
	var cru: Variant = (_games[game_id] as Dictionary).get("sections", [])
	if typeof(cru) != TYPE_ARRAY:
		return []
	var saida: Array = []
	for s in cru:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var itens: Array = []
		var brutos: Variant = (s as Dictionary).get("items", [])
		if typeof(brutos) == TYPE_ARRAY:
			for i in brutos:
				itens.append(str(i))
		saida.append({"title": str((s as Dictionary).get("title", "")), "items": itens})
	return saida


## Chave i18n da dica de estratégia, ou "".
static func tip_of(game_id: String) -> String:
	_ensure_loaded()
	if not _games.has(game_id):
		return ""
	return str((_games[game_id] as Dictionary).get("tip", ""))


## Todos os jogos com regras. A suíte usa para cruzar com o catálogo e com o CSV.
static func all_ids() -> Array:
	_ensure_loaded()
	return _games.keys()


## Descarta o que está em memória. Só a suíte precisa.
static func clear_cache() -> void:
	_loaded = false
	_games = {}
