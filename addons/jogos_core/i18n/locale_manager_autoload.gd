extends Node

## Autoload `LocaleManager` (CONTRACTS.md §4.9): casca sobre
## `JogosLocaleService` que persiste o locale em `AppSettings.locale` e
## republica `locale_changed` no `GameEventBus`.
##
## Extraído de PlayTable `core/i18n/LocaleManager.gd` e TWFS
## `client/autoload/loc.gd`. Configuração por ProjectSettings:
## `jogos/i18n/supported_locales` (PackedStringArray, padrão `["en"]`),
## `jogos/i18n/fallback_locale` (padrão `en`), `jogos/i18n/json_dir`
## (padrão `res://i18n`), `jogos/i18n/locale_names` (Dictionary código → nome).

signal locale_changed(locale: String)

const SETTING_SUPPORTED: String = "jogos/i18n/supported_locales"
const SETTING_FALLBACK: String = "jogos/i18n/fallback_locale"
const SETTING_JSON_DIR: String = "jogos/i18n/json_dir"
const SETTING_NAMES: String = "jogos/i18n/locale_names"

var locale_names: Dictionary = {}
var _service: JogosLocaleService = null


func _ready() -> void:
	if _service == null:
		var supported: PackedStringArray = PackedStringArray(ProjectSettings.get_setting(SETTING_SUPPORTED, PackedStringArray(["en"])))
		var fallback: String = str(ProjectSettings.get_setting(SETTING_FALLBACK, "en"))
		var dir: String = str(ProjectSettings.get_setting(SETTING_JSON_DIR, "res://i18n"))
		var names: Variant = ProjectSettings.get_setting(SETTING_NAMES, {})
		setup(supported, fallback, dir, names if typeof(names) == TYPE_DICTIONARY else {})
	_apply_initial_locale()


## Configura o serviço; testes chamam antes de `_ready`.
func setup(supported: PackedStringArray, fallback: String = "en", json_dir: String = "res://i18n", names: Dictionary = {}) -> void:
	_service = JogosLocaleService.new(supported, fallback, json_dir)
	_service.locale_changed.connect(_on_service_locale_changed)
	locale_names = names


func service() -> JogosLocaleService:
	return _service


func _apply_initial_locale() -> void:
	var saved: String = ""
	var settings: Node = JogosLocator.autoload(&"AppSettings")
	if settings != null and settings.has_method("locale"):
		saved = str(settings.call("locale"))
	if not saved.is_empty() and _service.is_supported(saved):
		_service.set_locale(saved)
	else:
		_service.set_locale(_service.detect_from_os())


func set_locale(code: String) -> bool:
	return _service.set_locale(code)


func cycle_locale() -> String:
	return _service.cycle_locale()


func get_current_locale() -> String:
	return _service.current_locale


var current_locale: String:
	get:
		return _service.current_locale if _service != null else ""


func get_current_locale_name() -> String:
	return str(locale_names.get(current_locale, current_locale))


func supported_locales() -> PackedStringArray:
	return _service.supported_locales


func t(key: String, args: Dictionary = {}) -> String:
	return _service.t(key, args)


func tid(prefix: String, id: String, suffix: String = "") -> String:
	return _service.tid(prefix, id, suffix)


func n(key: String, count: int, args: Dictionary = {}) -> String:
	return _service.n(key, count, args)


func has(key: String) -> bool:
	return _service.has(key)


func reload_strings() -> void:
	_service.reload_strings()


func _on_service_locale_changed(code: String) -> void:
	var settings: Node = JogosLocator.autoload(&"AppSettings")
	if settings != null and settings.has_method("set_value"):
		settings.call("set_value", "locale", code)
	locale_changed.emit(code)
	var bus: Node = JogosLocator.autoload(&"GameEventBus")
	if bus != null and bus.has_method("emit_locale_changed"):
		bus.call("emit_locale_changed", code)
