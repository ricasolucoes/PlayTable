@tool
extends EditorPlugin

## Registra os autoloads da lib na ordem do CONTRACTS.md §3 ao habilitar o
## plugin no editor. Um jogo também pode declarar só alguns deles à mão no
## `project.godot`; a ordem importa porque AppSettings lê do SaveManager e
## quase todo o resto lê de AppSettings/GameEventBus.

const BASE := "res://addons/jogos_core/"
const AUTOLOADS: Array[Array] = [
	["Log", "core/log_autoload.gd"],
	["FeatureFlags", "core/feature_flags_autoload.gd"],
	["SaveManager", "save/save_manager_autoload.gd"],
	["AppSettings", "settings/app_settings_autoload.gd"],
	["GameEventBus", "events/game_event_bus_autoload.gd"],
	["LocaleManager", "i18n/locale_manager_autoload.gd"],
	["AudioManager", "audio/audio_manager_autoload.gd"],
	["AssetLoader", "assets/asset_loader_autoload.gd"],
	["InputRouter", "input/input_router_autoload.gd"],
	["GameCatalog", "catalog/game_catalog_autoload.gd"],
	["SceneManager", "nav/scene_manager_autoload.gd"],
	["ApiClient", "net/api_client_autoload.gd"],
	["Identity", "identity/identity_autoload.gd"],
	["Telemetry", "telemetry/telemetry_autoload.gd"],
]


func _enable_plugin() -> void:
	for entry: Array in AUTOLOADS:
		var name: String = entry[0]
		if not ProjectSettings.has_setting("autoload/" + name):
			add_autoload_singleton(name, BASE + String(entry[1]))


func _disable_plugin() -> void:
	for entry: Array in AUTOLOADS:
		var name: String = entry[0]
		var current: String = str(ProjectSettings.get_setting("autoload/" + name, ""))
		if current.begins_with("*" + BASE) or current.begins_with(BASE):
			remove_autoload_singleton(name)
