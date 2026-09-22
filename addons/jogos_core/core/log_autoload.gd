extends Node

## Autoload `Log` (CONTRACTS.md §4.2): casca sobre `JogosLog` com um sink de
## arquivo em `user://logs/<nome_do_app>_N.log`.
##
## Extraído de VOLTA `src/core/log/log.gd`. Sem `class_name`: o Godot 4.7
## rejeita class_name igual ao nome do singleton. Quem usa injeção instancia
## `JogosLog` direto; quem usa autoload chama `Log.info("save", "loaded", {...})`.
## `JogosLocator.log()` encontra este nó por nome e delega para `debug/info/
## warn/error` — por isso os nomes dos métodos são o contrato.

enum Level { DEBUG, INFO, WARN, ERROR }

## Desligar em testes ou em jogo que não quer arquivo de log no aparelho.
var file_logging: bool = true

var _impl: JogosLog = JogosLog.new()
var _file_sink: JogosFileLogSink = null


func _ready() -> void:
	if file_logging and not Engine.is_editor_hint():
		_file_sink = JogosFileLogSink.new(base_name())
		_impl.add_sink(_file_sink)


func _exit_tree() -> void:
	if _file_sink != null:
		_file_sink.close()


## Nome base dos arquivos: o nome do projeto em minúsculas sem espaços, para
## dois jogos na mesma máquina de desenvolvimento não escreverem no mesmo log.
func base_name() -> String:
	var name: String = str(ProjectSettings.get_setting("application/config/name", "")).strip_edges()
	if name.is_empty():
		return "jogos"
	var slug: String = name.to_lower()
	var out: String = ""
	for i: int in slug.length():
		var ch: String = slug[i]
		if ch.is_valid_identifier() or ch.is_valid_int():
			out += ch
		elif ch == " " or ch == "-":
			out += "_"
	return out if not out.is_empty() else "jogos"


func impl() -> JogosLog:
	return _impl


func debug(category: String, key: String, data: Dictionary = {}) -> void:
	_impl.debug(category, key, data)


func info(category: String, key: String, data: Dictionary = {}) -> void:
	_impl.info(category, key, data)


func warn(category: String, key: String, data: Dictionary = {}) -> void:
	_impl.warn(category, key, data)


func error(category: String, key: String, data: Dictionary = {}) -> void:
	_impl.error(category, key, data)


func set_min_level(category: String, level: int) -> void:
	_impl.set_min_level(category, level)


func enabled(category: String, level: int) -> bool:
	return _impl.enabled(category, level)


func add_sink(sink: JogosLogSink) -> void:
	_impl.add_sink(sink)


func remove_sink(sink: JogosLogSink) -> void:
	_impl.remove_sink(sink)


## Só testes: troca todos os sinks por dublês sem tocar disco.
func set_sinks_for_test(sinks: Array[JogosLogSink]) -> void:
	_impl.set_sinks(sinks)
