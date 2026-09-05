extends Node

## Manages persistent user settings and unified save pipeline.

const SAVE_PATH = "user://save_data.cfg"
const LEGACY_JSON_PATH = "user://config.save"
const LEGACY_PROFILE_PATH = "user://player_profile.cfg"

var _config := ConfigFile.new()
var _dirty := false
var _flush_queued := false

var _defaults := {
	"master_volume": 1.0,
	"theme_dark": true
}

func _ready() -> void:
	load_data()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush()

func load_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		_config.load(SAVE_PATH)
	else:
		# Migrate legacy JSON
		if FileAccess.file_exists(LEGACY_JSON_PATH):
			var file = FileAccess.open(LEGACY_JSON_PATH, FileAccess.READ)
			if file:
				var json = JSON.new()
				if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
					for k in json.data.keys():
						_config.set_value("Settings", k, json.data[k])
				file.close()
		
		# Migrate legacy Profile ConfigFile
		if FileAccess.file_exists(LEGACY_PROFILE_PATH):
			var legacy_prof := ConfigFile.new()
			if legacy_prof.load(LEGACY_PROFILE_PATH) == OK:
				for section in legacy_prof.get_sections():
					for key in legacy_prof.get_section_keys(section):
						_config.set_value(section, key, legacy_prof.get_value(section, key))
		
		# Apply defaults for any missing settings
		for k in _defaults.keys():
			if not _config.has_section_key("Settings", k):
				_config.set_value("Settings", k, _defaults[k])
				
		save_data()

func save_data() -> void:
	_dirty = false
	_flush_queued = false
	_config.save(SAVE_PATH)

func flush() -> void:
	_flush_queued = false
	if _dirty:
		save_data()

func _mark_dirty() -> void:
	_dirty = true
	if _flush_queued:
		return
	_flush_queued = true
	flush.call_deferred()

func set_setting(key: String, value: Variant, section: String = "Settings") -> void:
	_config.set_value(section, key, value)
	_mark_dirty()

func get_setting(key: String, default_val: Variant = null, section: String = "Settings") -> Variant:
	if _config.has_section_key(section, key):
		return _config.get_value(section, key)
	if section == "Settings" and _defaults.has(key) and default_val == null:
		return _defaults[key]
	return default_val

func has_section(section: String) -> bool:
	return _config.has_section(section)
