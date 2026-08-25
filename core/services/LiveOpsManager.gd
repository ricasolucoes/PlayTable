extends Node

## Gerenciador de LiveOps e Feature Flags.
##
## Em um ambiente real, este arquivo faria fetch de um JSON num servidor remoto
## para ativar ou desativar campanhas, missões e recursos do Sidekick sem precisar 
## enviar uma atualização para a Play Store.

const CONFIG_PATH = "res://core/configs/liveops_config.json"
var _config_data: Dictionary = {}

func _ready() -> void:
	_load_local_fallback()
	# Aqui no futuro poderia haver HTTPRequest para um remote config
	
func _load_local_fallback() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			_config_data = json.data

func is_feature_enabled(feature_name: String, default_value: bool = false) -> bool:
	if _config_data.has("features") and _config_data["features"].has(feature_name):
		return _config_data["features"][feature_name]
	return default_value

func get_active_season() -> String:
	if _config_data.has("liveops"):
		return _config_data["liveops"].get("current_season", "default_season")
	return "default_season"

func get_xp_multiplier() -> float:
	if _config_data.has("liveops"):
		return _config_data["liveops"].get("xp_multiplier", 1.0)
	return 1.0
