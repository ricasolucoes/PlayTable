class_name JogosLocator
extends RefCounted

## Localiza autoloads sem referenciá-los por identificador.
##
## Dentro da lib, `SaveManager.get_setting()` escrito literalmente quebra o
## parse em qualquer jogo que não tenha habilitado esse autoload — e cada jogo
## habilita só o que usa. Aqui a busca é por nome, em runtime, e devolve
## `null` quando o singleton não existe; quem chama degrada sem erro.
## `override()` existe para os testes injetarem dublês e para quem prefere
## injeção de dependência (VOLTA) em vez de autoload.

static var _overrides: Dictionary = {}


static func autoload(name: StringName) -> Node:
	if _overrides.has(name):
		return _overrides[name] as Node
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	var root: Window = (loop as SceneTree).root
	if root == null:
		return null
	return root.get_node_or_null(NodePath(name))


static func override(name: StringName, node: Node) -> void:
	_overrides[name] = node


static func clear_overrides() -> void:
	_overrides.clear()


## Log sem depender do autoload `Log`: warning/error sempre chegam ao
## console do Godot; info/debug só se houver `Log`.
static func log(level: String, category: String, key: String, data: Dictionary = {}) -> void:
	var logger: Node = autoload(&"Log")
	if logger != null and logger.has_method(level):
		logger.call(level, category, key, data)
		return
	match level:
		"error":
			push_error("[%s] %s %s" % [category, key, JSON.stringify(data)])
		"warn":
			push_warning("[%s] %s %s" % [category, key, JSON.stringify(data)])
		_:
			pass
