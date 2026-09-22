class_name JogosFileLogSink
extends JogosLogSink

## Sink de log em arquivo com rotação por tamanho.
##
## Extraído de VOLTA `src/core/log/file_log_sink.gd`. Generalização: `base_name`
## e `log_dir` viraram parâmetros do construtor (eram constantes "volta" e
## `user://logs/`). Mantém no máximo `max_files` arquivos de até `max_bytes`;
## a cada rotação os índices deslocam e o mais antigo é descartado — o
## telefone não pode encher de log.

var max_bytes: int = 2 * 1024 * 1024
var max_files: int = 5
var log_dir: String = "user://logs/"
var base_name: String = "jogos"

var _current: FileAccess = null
var _current_size: int = 0


func _init(name: String = "jogos", dir: String = "user://logs/") -> void:
	base_name = name
	log_dir = dir if dir.ends_with("/") else dir + "/"


func write(level: int, category: String, key: String, data: Dictionary) -> void:
	_ensure_open()
	if _current == null:
		return
	var line: String = "%s [%s:%s] %s %s\n" % [
		Time.get_datetime_string_from_system(true),
		category,
		JogosLog.level_name(level),
		key,
		JSON.stringify(data),
	]
	var bytes: PackedByteArray = line.to_utf8_buffer()
	if _current_size + bytes.size() > max_bytes:
		_rotate()
	_current.store_buffer(bytes)
	_current.flush()
	_current_size += bytes.size()


func current_path() -> String:
	return _path_for(0)


func close() -> void:
	if _current != null:
		_current.close()
		_current = null
	_current_size = 0


func _path_for(index: int) -> String:
	return "%s%s_%d.log" % [log_dir, base_name, index]


func _ensure_open() -> void:
	if _current != null:
		return
	DirAccess.make_dir_recursive_absolute(log_dir)
	var path: String = _path_for(0)
	if FileAccess.file_exists(path):
		_current = FileAccess.open(path, FileAccess.READ_WRITE)
	if _current == null:
		_current = FileAccess.open(path, FileAccess.WRITE)
	if _current == null:
		return
	_current.seek_end()
	_current_size = _current.get_length()


func _rotate() -> void:
	_current.close()
	var dir: DirAccess = DirAccess.open(log_dir)
	if dir == null:
		_current = FileAccess.open(_path_for(0), FileAccess.WRITE)
		_current_size = 0
		return
	var oldest: String = _path_for(max_files - 1)
	if FileAccess.file_exists(oldest):
		dir.remove(oldest)
	for i: int in range(max_files - 2, -1, -1):
		var src: String = _path_for(i)
		if FileAccess.file_exists(src):
			dir.rename(src, _path_for(i + 1))
	_current = FileAccess.open(_path_for(0), FileAccess.WRITE)
	_current_size = 0
