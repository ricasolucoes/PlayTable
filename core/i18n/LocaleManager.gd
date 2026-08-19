extends Node

signal locale_changed(new_locale: String)

const SUPPORTED_LOCALES = [
	{"code": "pt_BR", "name": "Português (BR)"},
	{"code": "en", "name": "English"},
	{"code": "es", "name": "Español"}
]

var current_locale: String = "pt_BR"

func _ready():
	var saved_locale = SaveManager.get_setting("locale", "")
	if saved_locale != "" and _is_supported(saved_locale):
		set_locale(saved_locale)
	else:
		var sys_locale = OS.get_locale()
		var matched = _match_supported(sys_locale)
		set_locale(matched)

func _is_supported(code: String) -> bool:
	for loc in SUPPORTED_LOCALES:
		if loc["code"] == code:
			return true
	return false

func _match_supported(sys_locale: String) -> String:
	var lower = sys_locale.to_lower()
	if lower.begins_with("pt"):
		return "pt_BR"
	elif lower.begins_with("es"):
		return "es"
	elif lower.begins_with("en"):
		return "en"
	return "pt_BR"

func set_locale(code: String):
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
	var next_idx = 0
	for i in range(SUPPORTED_LOCALES.size()):
		if SUPPORTED_LOCALES[i]["code"] == current_locale:
			next_idx = (i + 1) % SUPPORTED_LOCALES.size()
			break
	var next_code = SUPPORTED_LOCALES[next_idx]["code"]
	set_locale(next_code)
	return next_code
