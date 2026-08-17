extends Node

const SAVE_PATH = "user://config.save"

var settings = {
	"master_volume": 1.0,
	"theme_dark": true
}

func _ready():
	load_data()

func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()

func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var json = JSON.new()
			var err = json.parse(content)
			if err == OK:
				settings = json.data
			file.close()

func set_setting(key: String, value: Variant):
	settings[key] = value
	save_data()

func get_setting(key: String, default_val: Variant = null) -> Variant:
	if settings.has(key):
		return settings[key]
	return default_val
