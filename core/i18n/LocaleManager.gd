extends Node

## Manages application locale with auto-detection and persistence.

signal locale_changed(new_locale: String)

const SUPPORTED_LOCALES: Array[Dictionary] = [
	{"code": "pt_BR", "name": "Português (BR)"},
	{"code": "en", "name": "English"},
	{"code": "es", "name": "Español"}
]

var current_locale: String = "pt_BR"

func _ready() -> void:
	var saved_locale: String = SaveManager.get_setting("locale", "") as String
	if saved_locale != "" and _is_supported(saved_locale):
		set_locale(saved_locale)
	else:
		var sys_locale: String = OS.get_locale()
		var matched: String = _match_supported(sys_locale)
		set_locale(matched)

func _is_supported(code: String) -> bool:
	for loc in SUPPORTED_LOCALES:
		if loc["code"] == code:
			return true
	return false

func _match_supported(sys_locale: String) -> String:
	var lower: String = sys_locale.to_lower()
	if lower.begins_with("pt"):
		return "pt_BR"
	elif lower.begins_with("es"):
		return "es"
	elif lower.begins_with("en"):
		return "en"
	return "pt_BR"

func set_locale(code: String) -> void:
	current_locale = code
	TranslationServer.set_locale(code)
	SaveManager.set_setting("locale", code)
	locale_changed.emit(code)

func get_current_locale() -> String:
	return current_locale

func get_current_locale_name() -> String:
	for loc in SUPPORTED_LOCALES:
		if loc["code"] == current_locale:
			return loc["name"]
	return current_locale

func cycle_locale() -> String:
	var next_idx: int = 0
	for i in range(SUPPORTED_LOCALES.size()):
		if SUPPORTED_LOCALES[i]["code"] == current_locale:
			next_idx = (i + 1) % SUPPORTED_LOCALES.size()
			break
	var next_code: String = SUPPORTED_LOCALES[next_idx]["code"]
	set_locale(next_code)
	return next_code
