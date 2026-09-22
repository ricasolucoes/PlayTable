class_name JogosLog
extends RefCounted

## Log estruturado por categoria e nível: a mensagem é uma chave estável em
## snake_case e os dados vão num dicionário, para que arquivo, overlay e
## telemetria leiam a mesma coisa.
##
## Extraído de VOLTA `src/core/log/log.gd`. Generalização: categoria é
## `String`; o `print` em debug virou espelho opcional para o console do Godot
## (`mirror_to_console`) só em WARN/ERROR, porque é isso que o editor mostra
## em vermelho e amarelo. DEBUG só sai em build de debug. Nada é montado
## quando o nível está desabilitado — ver `enabled()`.

enum Level { DEBUG, INFO, WARN, ERROR }

var mirror_to_console: bool = true
var default_min_level: int = Level.INFO

var _min_level: Dictionary = {}
var _sinks: Array[JogosLogSink] = []


static func level_name(level: int) -> String:
	if level < 0 or level >= Level.size():
		return "?"
	return Level.keys()[level]


func add_sink(sink: JogosLogSink) -> void:
	_sinks.append(sink)


func remove_sink(sink: JogosLogSink) -> void:
	_sinks.erase(sink)


func set_sinks(sinks: Array[JogosLogSink]) -> void:
	_sinks = sinks


func sinks() -> Array[JogosLogSink]:
	return _sinks


func set_min_level(category: String, level: int) -> void:
	_min_level[category] = level


func enabled(category: String, level: int) -> bool:
	if level == Level.DEBUG and not JogosBuild.is_debug():
		return false
	return level >= int(_min_level.get(category, default_min_level))


func debug(category: String, key: String, data: Dictionary = {}) -> void:
	_log(category, Level.DEBUG, key, data)


func info(category: String, key: String, data: Dictionary = {}) -> void:
	_log(category, Level.INFO, key, data)


func warn(category: String, key: String, data: Dictionary = {}) -> void:
	_log(category, Level.WARN, key, data)


func error(category: String, key: String, data: Dictionary = {}) -> void:
	_log(category, Level.ERROR, key, data)


func _log(category: String, level: int, key: String, data: Dictionary) -> void:
	if not enabled(category, level):
		return
	if mirror_to_console:
		if level == Level.ERROR:
			push_error("[%s] %s %s" % [category, key, JSON.stringify(data)])
		elif level == Level.WARN:
			push_warning("[%s] %s %s" % [category, key, JSON.stringify(data)])
	for sink: JogosLogSink in _sinks:
		sink.write(level, category, key, data)
