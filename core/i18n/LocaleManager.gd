extends "res://addons/jogos_core/i18n/locale_manager_autoload.gd"

## Manages application locale with auto-detection and persistence.
## Herda do LocaleManager canônico de jogos_core preservando as chaves locais do PlayTable.

const SUPPORTED_LOCALES: Array[Dictionary] = [
	{"code": "pt_BR", "name": "Português (BR)"},
	{"code": "en", "name": "English"},
	{"code": "es", "name": "Español"}
]


func _ready() -> void:
	FontFallbacks.aplicar()
	setup(PackedStringArray(["pt_BR", "en", "es"]), "pt_BR", "res://core/i18n", {
		"pt_BR": "Português (BR)",
		"en": "English",
		"es": "Español"
	})
	super._ready()


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
