class_name JogosLocaleService
extends RefCounted

## Locale atual, detecção do sistema e tradução por chave com fallback.
##
## Extraído de PlayTable `core/i18n/LocaleManager.gd` (locales suportados,
## detecção do SO por prefixo, `cycle_locale`, `TranslationServer`) e TWFS
## `client/autoload/loc.gd` (dicionários JSON `<dir>/<locale>/*.json`,
## `t(key, args)` com `{nome}`, `tid`, `has`, chave ausente devolve a própria
## chave com um aviso — nunca crash). Generalização: a lista de locales e o
## diretório JSON são parâmetros; `n()` ganhou plural real por sufixo
## (`.zero`/`.one`/`.other`); o aviso de chave ausente sai uma vez por chave.
##
## Ordem de resolução em `t()`: `TranslationServer` (arquivos `.translation`
## do projeto) → JSON do locale atual → JSON do fallback → a própria chave.

signal locale_changed(locale: String)

var supported_locales: PackedStringArray = ["en"]
var fallback_locale: String = "en"
var json_dir: String = "res://i18n"
var current_locale: String = ""

var _strings: Dictionary = {}
var _fallback_strings: Dictionary = {}
var _warned: Dictionary = {}


func _init(locales: PackedStringArray = ["en"], fallback: String = "en", dir: String = "res://i18n") -> void:
	supported_locales = locales
	fallback_locale = fallback
	json_dir = dir


func is_supported(code: String) -> bool:
	return supported_locales.has(code) or supported_locales.has(normalize(code))


## `pt_BR` e `pt-BR` são o mesmo locale para quem configura; o Godot usa `_`.
static func normalize(code: String) -> String:
	return code.replace("-", "_")


## Casa o locale do sistema com um suportado por prefixo de língua
## (`pt_PT` → `pt_BR` se só `pt_BR` existir). Sem casamento, o fallback.
func match_supported(system_locale: String) -> String:
	var wanted: String = normalize(system_locale)
	for code: String in supported_locales:
		if normalize(code) == wanted:
			return code
	var lang: String = wanted.split("_")[0].to_lower()
	for code: String in supported_locales:
		if normalize(code).split("_")[0].to_lower() == lang:
			return code
	return fallback_locale


func detect_from_os() -> String:
	return match_supported(OS.get_locale())


func set_locale(code: String) -> bool:
	if not is_supported(code):
		JogosLocator.log("warn", "i18n", "locale_unsupported", {"locale": code})
		return false
	current_locale = code
	TranslationServer.set_locale(normalize(code))
	reload_strings()
	locale_changed.emit(code)
	return true


func cycle_locale() -> String:
	if supported_locales.is_empty():
		return current_locale
	var idx: int = 0
	for i: int in supported_locales.size():
		if supported_locales[i] == current_locale:
			idx = (i + 1) % supported_locales.size()
			break
	set_locale(supported_locales[idx])
	return current_locale


func reload_strings() -> void:
	_strings = _load_locale(current_locale)
	_fallback_strings = {} if normalize(current_locale) == normalize(fallback_locale) else _load_locale(fallback_locale)


func t(key: String, args: Dictionary = {}) -> String:
	var raw: Variant = _lookup(key)
	if raw == null:
		if not _warned.has(key):
			_warned[key] = true
			JogosLocator.log("warn", "i18n", "i18n_key_missing", {"key": key, "locale": current_locale})
		return _interpolate(key, args)
	return _interpolate(str(raw), args)


## `tid("resource", "wood", "name")` → `t("resource.wood.name")`.
func tid(prefix: String, id: String, suffix: String = "") -> String:
	var composed: String = "%s.%s" % [prefix, id]
	if not suffix.is_empty():
		composed = "%s.%s" % [composed, suffix]
	return t(composed)


## Plural por sufixo: `key.zero` (0), `key.one` (1), `key.other`; sem os
## sufixos cai em `key`. `{count}` entra nos args automaticamente.
func n(key: String, count: int, args: Dictionary = {}) -> String:
	var merged: Dictionary = args.duplicate()
	merged["count"] = count
	var candidates: PackedStringArray = []
	if count == 0:
		candidates.append(key + ".zero")
	if count == 1:
		candidates.append(key + ".one")
	candidates.append(key + ".other")
	for candidate: String in candidates:
		if _strings.has(candidate) or (TranslationServer.translate(candidate) != candidate):
			return t(candidate, merged)
	for candidate: String in candidates:
		if has(candidate):
			return t(candidate, merged)
	return t(key, merged)


func has(key: String) -> bool:
	return _lookup(key) != null


func _lookup(key: String) -> Variant:
	var translated: String = str(TranslationServer.translate(key))
	if translated != key:
		return translated
	var raw: Variant = _strings.get(key)
	if raw == null:
		raw = _fallback_strings.get(key)
	return raw


func _interpolate(text: String, args: Dictionary) -> String:
	var result: String = text
	for arg_key: Variant in args.keys():
		result = result.replace("{%s}" % str(arg_key), str(args[arg_key]))
	return result


## Junta todos os `*.json` do diretório do locale; tenta o código como veio
## e com `-`/`_` trocados, porque os jogos nomeiam as pastas dos dois jeitos.
func _load_locale(code: String) -> Dictionary:
	if code.is_empty() or json_dir.is_empty():
		return {}
	for candidate: String in [code, normalize(code), code.replace("_", "-")]:
		var dir_path: String = json_dir.path_join(candidate)
		if DirAccess.dir_exists_absolute(dir_path):
			return _load_dir(dir_path)
	return {}


func _load_dir(dir_path: String) -> Dictionary:
	var merged: Dictionary = {}
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return merged
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			var text: String = FileAccess.get_file_as_string(dir_path.path_join(name))
			var json: JSON = JSON.new()
			if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
				merged.merge(json.data, true)
			else:
				JogosLocator.log("warn", "i18n", "i18n_json_invalid", {"path": dir_path.path_join(name)})
		name = dir.get_next()
	dir.list_dir_end()
	return merged
