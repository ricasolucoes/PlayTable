extends Node

## Autoload `SaveManager` (CONTRACTS.md §4.3): API do PlayTable sobre o motor
## `JogosSaveService`.
##
## API extraída de PlayTable `core/save/SaveManager.gd` (`get_setting/
## set_setting/has_section/flush/snapshot/restore`, flush diferido ao marcar
## sujo e no fechar/pausar). Motor extraído do VOLTA (JSON atômico com
## recuperação e migrações). Tirado do PlayTable: os dois caminhos legados
## (`config.save`, `player_profile.cfg`) — no lugar, `import_config_file()`
## traz qualquer ConfigFile antigo uma única vez.
##
## Caminho: ProjectSettings `jogos/save/path` (padrão `user://save_data.json`).

signal saved

const SETTING_PATH: String = "jogos/save/path"
const SETTING_SCHEMA: String = "jogos/save/schema_version"
const DEFAULT_PATH: String = "user://save_data.json"
const DEFAULT_SECTION: String = "Settings"

var save_path: String = ""
var _service: JogosSaveService = null
var _dirty: bool = false
var _flush_queued: bool = false
var _pending_migrations: Array[JogosSaveMigration] = []


func _ready() -> void:
	_ensure_service()


func _ensure_service() -> void:
	if _service == null:
		var path: String = save_path
		if path.is_empty():
			path = str(ProjectSettings.get_setting(SETTING_PATH, DEFAULT_PATH))
		var schema: int = int(ProjectSettings.get_setting(SETTING_SCHEMA, 1))
		setup(path, schema)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush()


## Cria (ou recria) o motor no caminho dado e carrega. Testes chamam antes de
## `_ready` com um caminho em `user://test_save/`.
func setup(path: String, schema_version: int = 1) -> int:
	save_path = path
	_service = JogosSaveService.new(path, schema_version)
	for m: JogosSaveMigration in _pending_migrations:
		_service.register_migration(m)
	_dirty = false
	_flush_queued = false
	var result: int = _service.load()
	JogosLocator.log("info", "save", "save_loaded", {"path": path, "result": result})
	return result


func service() -> JogosSaveService:
	_ensure_service()
	return _service


func load_data() -> void:
	_ensure_service()
	if _service != null:
		_service.load()


func last_result() -> int:
	_ensure_service()
	return _service.last_result if _service != null else JogosSaveService.Result.RECREATED


## Registra migração `from_version` → `from_version + 1`. Precisa acontecer
## antes do `_ready` (ou seguido de `setup()`), senão o arquivo já foi lido.
func register_migration(from_version: int, fn: Callable) -> void:
	var m: JogosSaveMigration = JogosSaveMigration.create(from_version, from_version + 1, fn)
	_pending_migrations.append(m)
	if _service != null:
		_service.register_migration(m)


func get_setting(key: String, default_value: Variant = null, section: String = DEFAULT_SECTION) -> Variant:
	_ensure_service()
	if _service == null:
		return default_value
	return _service.get_value(section, key, default_value)


func set_setting(key: String, value: Variant, section: String = DEFAULT_SECTION) -> void:
	_ensure_service()
	if _service == null:
		return
	_service.set_value(section, key, value)
	_mark_dirty()


func has_setting(key: String, section: String = DEFAULT_SECTION) -> bool:
	return _service != null and _service.has_key(section, key)


func erase_setting(key: String, section: String = DEFAULT_SECTION) -> void:
	if _service == null:
		return
	_service.erase_key(section, key)
	_mark_dirty()


func has_section(section: String) -> bool:
	return _service != null and _service.has_section(section)


func save_data() -> void:
	_dirty = false
	_flush_queued = false
	if _service == null:
		return
	_service.save()
	saved.emit()


func flush() -> void:
	_flush_queued = false
	if _dirty:
		save_data()


func is_dirty() -> bool:
	return _dirty


func snapshot() -> Dictionary:
	return _service.snapshot() if _service != null else {}


func restore(copy: Dictionary) -> void:
	if _service == null:
		return
	_service.restore(copy)
	_dirty = false
	_flush_queued = false
	saved.emit()


## Importa um `ConfigFile` antigo (ex.: `user://save_data.cfg` do PlayTable)
## seção a seção. Com `only_if_empty`, não faz nada se este save já tem dados
## — a migração legada é coisa de uma vez só.
func import_config_file(path: String, only_if_empty: bool = true) -> bool:
	if _service == null or not FileAccess.file_exists(path):
		return false
	if only_if_empty and not _service.sections().is_empty():
		return false
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		JogosLocator.log("warn", "save", "import_config_failed", {"path": path})
		return false
	for section: String in config.get_sections():
		for key: String in config.get_section_keys(section):
			_service.set_value(section, key, config.get_value(section, key))
	save_data()
	JogosLocator.log("info", "save", "import_config_done", {"path": path})
	return true


func _mark_dirty() -> void:
	_dirty = true
	if _flush_queued:
		return
	_flush_queued = true
	flush.call_deferred()
