extends Node

## Autoload `FeatureFlags` (CONTRACTS.md §4.10): flags de recurso, números de
## LiveOps e fatos da build num lugar só.
##
## Extraído de PlayTable `core/services/LiveOpsManager.gd` (JSON local com
## `features` e `liveops.xp_multiplier`) + VOLTA `src/core/build.gd`
## (`is_debug/version/env`, aqui delegados a `JogosBuild`). Generalização: o
## caminho do JSON vem da ProjectSettings `jogos/flags/path` (padrão
## `res://flags.json`) e existe `apply_remote()` para um remote config
## sobrescrever sem mandar atualização para a loja — o que o PlayTable
## descrevia como futuro.
##
## Formato do JSON:
##   {"features": {"nome": true}, "numbers": {"nome": 1.5},
##    "liveops": {"xp_multiplier": 1.0, "current_season": "s1"}}

signal flags_changed

const SETTING_PATH: String = "jogos/flags/path"
const DEFAULT_PATH: String = "res://flags.json"

var flags_path: String = ""
var _data: Dictionary = {}


func _ready() -> void:
	if flags_path.is_empty():
		flags_path = str(ProjectSettings.get_setting(SETTING_PATH, DEFAULT_PATH))
	load_from_path(flags_path)


func load_from_path(path: String) -> bool:
	flags_path = path
	_data = {}
	if not FileAccess.file_exists(path):
		return false
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		JogosLocator.log("warn", "flags", "flags_json_invalid", {"path": path})
		return false
	_data = json.data
	flags_changed.emit()
	return true


## Sobrescreve com o que veio do servidor; chaves ausentes no remoto ficam
## como estavam. Nunca substitui o JSON inteiro: uma resposta parcial não pode
## apagar flags locais.
func apply_remote(remote: Dictionary) -> void:
	for section: String in ["features", "numbers", "liveops"]:
		if not remote.has(section) or typeof(remote[section]) != TYPE_DICTIONARY:
			continue
		var target: Dictionary = _section(section)
		var incoming: Dictionary = remote[section]
		for key: Variant in incoming.keys():
			target[key] = incoming[key]
		_data[section] = target
	flags_changed.emit()


func reset() -> void:
	_data = {}
	flags_changed.emit()


func is_enabled(flag: String, default_value: bool = false) -> bool:
	var features: Dictionary = _section("features")
	if features.has(flag):
		return bool(features[flag])
	return default_value


func get_number(flag: String, default_value: float = 0.0) -> float:
	var numbers: Dictionary = _section("numbers")
	if numbers.has(flag):
		var raw: Variant = numbers[flag]
		if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
			return float(raw)
	return default_value


func get_string(flag: String, default_value: String = "") -> String:
	var section: Dictionary = _section("liveops")
	if section.has(flag):
		return str(section[flag])
	return default_value


func get_xp_multiplier() -> float:
	var liveops: Dictionary = _section("liveops")
	var raw: Variant = liveops.get("xp_multiplier", 1.0)
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		return float(raw)
	return 1.0


func get_active_season() -> String:
	return get_string("current_season", "default_season")


func is_debug() -> bool:
	return JogosBuild.is_debug()


func version() -> String:
	return JogosBuild.version()


func env() -> String:
	return JogosBuild.env()


func _section(name: String) -> Dictionary:
	var raw: Variant = _data.get(name, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw
