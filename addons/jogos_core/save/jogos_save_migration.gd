class_name JogosSaveMigration
extends RefCounted

## Migração encadeada de save: de `from_version()` para `to_version()`.
##
## Extraída de VOLTA `src/core/save/save_migration.gd`. Generalização: além de
## subclasse, aceita um `Callable` (`JogosSaveMigration.create(1, 2, fn)`), que
## é o que `SaveManager.register_migration(from, fn)` usa. O serviço encadeia
## até não haver migração cujo `from_version()` bata com o `schema_version`
## carregado — nunca pula versão.

var _from: int = -1
var _to: int = -1
var _fn: Callable = Callable()


static func create(from: int, to: int, fn: Callable) -> JogosSaveMigration:
	var m: JogosSaveMigration = JogosSaveMigration.new()
	m._from = from
	m._to = to
	m._fn = fn
	return m


func from_version() -> int:
	if _from < 0:
		push_error("JogosSaveMigration.from_version() não implementado em %s" % [get_script()])
	return _from


func to_version() -> int:
	if _to < 0:
		push_error("JogosSaveMigration.to_version() não implementado em %s" % [get_script()])
	return _to


func migrate(data: Dictionary) -> Dictionary:
	if _fn.is_valid():
		var out: Variant = _fn.call(data)
		return out if typeof(out) == TYPE_DICTIONARY else data
	push_error("JogosSaveMigration.migrate() não implementado em %s" % [get_script()])
	return data
