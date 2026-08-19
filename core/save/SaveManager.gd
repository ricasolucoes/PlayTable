class_name SaveManager
extends Node

## Manages persistent user settings via JSON file.

const SAVE_PATH = "user://config.save"

var settings: Dictionary = {
	"master_volume": 1.0,
	"theme_dark": true
}

func _ready() -> void:
	load_data()

func save_data() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()

func load_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var json = JSON.new()
			var err = json.parse(content)
			if err == OK:
				if typeof(json.data) == TYPE_DICTIONARY:
					settings = json.data
			file.close()

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_data()

func get_setting(key: String, default_val: Variant = null) -> Variant:
	if settings.has(key):
		return settings[key]
	return default_val
