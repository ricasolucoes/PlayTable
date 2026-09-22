extends Node

## Autoload sobre `JogosGameCatalog`. No `_ready` varre a pasta de
## `ProjectSettings "jogos/catalog/games_dir"` (padrão `res://games`) se ela
## existir; o jogo pode em vez disso registrar as entradas à mão.

const SETTING_DIR: String = "jogos/catalog/games_dir"
const DEFAULT_DIR: String = "res://games"

signal changed

var catalog: JogosGameCatalog = JogosGameCatalog.new()


func _ready() -> void:
	catalog.changed.connect(func() -> void: changed.emit())
	var dir: String = str(ProjectSettings.get_setting(SETTING_DIR, DEFAULT_DIR))
	if DirAccess.dir_exists_absolute(dir):
		catalog.scan(dir)


func scan(dir: String = DEFAULT_DIR) -> int:
	return catalog.scan(dir)


func register(def: JogosGameDefinition) -> void:
	catalog.register(def)


func all() -> Array[JogosGameDefinition]:
	return catalog.all()


func get_definition(id: String) -> JogosGameDefinition:
	return catalog.get_definition(id)


func has(id: String) -> bool:
	return catalog.has(id)


func by_tag(tag: String) -> Array[JogosGameDefinition]:
	return catalog.by_tag(tag)


func by_mode(mode: String) -> Array[JogosGameDefinition]:
	return catalog.by_mode(mode)


func by_category(category: StringName) -> Array[JogosGameDefinition]:
	return catalog.by_category(category)


func random(mode: String = "", exclude: PackedStringArray = []) -> JogosGameDefinition:
	return catalog.random(mode, exclude)


func id_from_scene_path(scene_path: String) -> String:
	return JogosGameCatalog.id_from_scene_path(scene_path)


func launch(id: String, opts: Dictionary = {}) -> bool:
	return catalog.launch(id, opts)
