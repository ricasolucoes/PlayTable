extends Node

## Autoload `AppSettings` (CONTRACTS.md §4.4): preferências do jogador com
## chaves canônicas, validadas, persistidas na seção `Settings` do
## `SaveManager` e anunciadas por `changed`.
##
## Extraído de TWFS `client/autoload/settings.gd` (acessibilidade, haptics,
## volumes por bus, `device_id`) e das chaves soltas do PlayTable
## (`locale`, `sound_enabled`, `music_enabled`, `gfx_quality_tier`,
## `gfx_reduced_motion`). Tirado: o `preload` das métricas de UI do TWFS
## (teto de `font_scale` virou constante) e a lista de presets `ultra`.
## Sem `SaveManager` (injeção, teste) fica tudo em memória.

signal changed(key: String, value: Variant)

const SECTION: String = "Settings"
const MAX_FONT_SCALE: float = 1.6

const DEFAULTS: Dictionary = {
	"locale": "",
	"sound_enabled": true,
	"music_enabled": true,
	"volume_master": 1.0,
	"volume_music": 1.0,
	"volume_sfx": 1.0,
	"volume_voice": 1.0,
	"volume_notification": 1.0,
	"reduced_motion": false,
	"font_scale": 1.0,
	"high_contrast": false,
	"colorblind": "none",
	"haptics": "full",
	"quality_tier": "auto",
}

var _memory: Dictionary = {}
var _device_id: String = ""


func _ready() -> void:
	reload()


## Relê tudo do SaveManager (chamado no `_ready` e após `restore()` de save).
func reload() -> void:
	_memory.clear()
	for key: String in DEFAULTS.keys():
		var raw: Variant = _read(key)
		_memory[key] = _sanitize(key, raw) if raw != null else DEFAULTS[key]


func keys() -> PackedStringArray:
	var out: PackedStringArray = []
	for key: String in DEFAULTS.keys():
		out.append(key)
	return out


func get_value(key: String) -> Variant:
	if not DEFAULTS.has(key):
		push_error("AppSettings: chave desconhecida '%s'" % key)
		return null
	return _memory.get(key, DEFAULTS[key])


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_error("AppSettings: chave desconhecida '%s'" % key)
		return
	var clean: Variant = _sanitize(key, value)
	if _memory.has(key) and _memory[key] == clean:
		return
	_memory[key] = clean
	_write(key, clean)
	changed.emit(key, clean)
	var bus: Node = JogosLocator.autoload(&"GameEventBus")
	if bus != null and bus.has_signal("settings_changed"):
		bus.emit_signal("settings_changed", key, clean)


func reset_to_defaults() -> void:
	for key: String in DEFAULTS.keys():
		set_value(key, DEFAULTS[key])


func locale() -> String:
	return str(get_value("locale"))


func sound_enabled() -> bool:
	return bool(get_value("sound_enabled"))


func music_enabled() -> bool:
	return bool(get_value("music_enabled"))


## `bus`: `master`, `music`, `sfx`, `voice` ou `notification`. Desconhecido devolve 1.0.
func volume(bus: String) -> float:
	var key: String = "volume_" + bus.to_lower()
	if not DEFAULTS.has(key):
		return 1.0
	return float(get_value(key))


func set_volume(bus: String, linear: float) -> void:
	set_value("volume_" + bus.to_lower(), linear)


func reduced_motion() -> bool:
	return bool(get_value("reduced_motion"))


func font_scale() -> float:
	return float(get_value("font_scale"))


func high_contrast() -> bool:
	return bool(get_value("high_contrast"))


func colorblind() -> String:
	return str(get_value("colorblind"))


func haptics() -> String:
	return str(get_value("haptics"))


func quality_tier() -> String:
	return str(get_value("quality_tier"))


## Id estável do aparelho para telemetria e fila offline; criado uma vez e
## guardado na seção `Device` do save (não é segredo, não é conta).
func device_id() -> String:
	if not _device_id.is_empty():
		return _device_id
	var save: Node = JogosLocator.autoload(&"SaveManager")
	if save != null and save.has_method("get_setting"):
		_device_id = str(save.call("get_setting", "device_id", "", "Device"))
	if _device_id.is_empty():
		_device_id = uuid_v4()
		if save != null and save.has_method("set_setting"):
			save.call("set_setting", "device_id", _device_id, "Device")
	return _device_id


static func uuid_v4() -> String:
	var bytes: PackedByteArray = PackedByteArray()
	for _i: int in range(16):
		bytes.append(randi() % 256)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)
	]


func _sanitize(key: String, value: Variant) -> Variant:
	var default_value: Variant = DEFAULTS[key]
	match key:
		"volume_master", "volume_music", "volume_sfx", "volume_voice", "volume_notification":
			return clampf(float(value), 0.0, 1.0)
		"font_scale":
			return clampf(float(value), 1.0, MAX_FONT_SCALE)
		"haptics":
			var mode: String = str(value)
			return mode if JogosHaptics.MODES.has(mode) else default_value
		"quality_tier":
			var tier: String = str(value)
			return tier if JogosQuality.is_valid(tier) else default_value
		"sound_enabled", "music_enabled", "reduced_motion", "high_contrast":
			return bool(value)
		_:
			return str(value)


func _read(key: String) -> Variant:
	var save: Node = JogosLocator.autoload(&"SaveManager")
	if save != null and save.has_method("get_setting"):
		return save.call("get_setting", key, null, SECTION)
	return null


func _write(key: String, value: Variant) -> void:
	var save: Node = JogosLocator.autoload(&"SaveManager")
	if save != null and save.has_method("set_setting"):
		save.call("set_setting", key, value, SECTION)
