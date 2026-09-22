class_name JogosGameCatalog
extends RefCounted

## Registro dos jogos disponíveis: descoberta por pasta, filtros e sorteio
## sem repetição.
##
## Fonte: PlayTable `core/configs/GameCatalog.gd` (`id_from_scene_path`,
## filtros por modo). Tirado: a lista fixa de 22 jogos — aqui a lista vem
## de `scan()`: cada `res://games/<id>/game.json` (padrão do SuperTuxParty)
## ou `<id>/*.tres` com `JogosGameDefinition` vira uma entrada, sem
## recompilar nada. `random()` usa um saco por modo: esgota todos antes de
## repetir (a fila de minigames do SuperTuxParty).

signal changed

var _defs: Array[JogosGameDefinition] = []
var _by_id: Dictionary = {}
var _bags: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func register(def: JogosGameDefinition) -> void:
	if def == null or def.id == "":
		JogosLocator.log("warn", "catalog", "definition_without_id", {"scene": def.scene_path if def != null else ""})
		return
	if _by_id.has(def.id):
		_defs.erase(_by_id[def.id])
	_by_id[def.id] = def
	_defs.append(def)
	_bags.clear()
	changed.emit()


func unregister(id: String) -> void:
	if not _by_id.has(id):
		return
	_defs.erase(_by_id[id])
	_by_id.erase(id)
	_bags.clear()
	changed.emit()


func clear() -> void:
	_defs.clear()
	_by_id.clear()
	_bags.clear()
	changed.emit()


## Varre `dir/*/` e registra o que encontrar. Devolve quantos entraram.
func scan(dir: String = "res://games") -> int:
	var found: int = 0
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return 0
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		if da.current_is_dir() and not name.begins_with("."):
			found += _scan_game_dir(dir.path_join(name))
		name = da.get_next()
	da.list_dir_end()
	return found


func _scan_game_dir(game_dir: String) -> int:
	var json_path: String = game_dir.path_join("game.json")
	if FileAccess.file_exists(json_path):
		var def: JogosGameDefinition = _load_json(json_path, game_dir)
		if def != null:
			register(def)
			return 1
		return 0
	var da: DirAccess = DirAccess.open(game_dir)
	if da == null:
		return 0
	var count: int = 0
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		if not da.current_is_dir() and (name.ends_with(".tres") or name.ends_with(".res")):
			var res: Resource = ResourceLoader.load(game_dir.path_join(name))
			if res is JogosGameDefinition:
				register(res as JogosGameDefinition)
				count += 1
		name = da.get_next()
	da.list_dir_end()
	return count


func _load_json(path: String, base_dir: String) -> JogosGameDefinition:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		JogosLocator.log("warn", "catalog", "game_json_invalid", {"path": path})
		return null
	return JogosGameDefinition.from_dict(parsed as Dictionary, base_dir)


func all() -> Array[JogosGameDefinition]:
	return _defs.duplicate()


func ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for def: JogosGameDefinition in _defs:
		out.append(def.id)
	return out


func size() -> int:
	return _defs.size()


func has(id: String) -> bool:
	return _by_id.has(id)


func get_definition(id: String) -> JogosGameDefinition:
	return _by_id.get(id, null) as JogosGameDefinition


func by_tag(tag: String) -> Array[JogosGameDefinition]:
	return _defs.filter(func(d: JogosGameDefinition) -> bool: return d.has_tag(tag))


func by_mode(mode: String) -> Array[JogosGameDefinition]:
	return _defs.filter(func(d: JogosGameDefinition) -> bool: return d.has_mode(mode))


func by_category(category: StringName) -> Array[JogosGameDefinition]:
	return _defs.filter(func(d: JogosGameDefinition) -> bool: return d.category == category)


func for_players(count: int) -> Array[JogosGameDefinition]:
	return _defs.filter(func(d: JogosGameDefinition) -> bool: return d.supports_players(count))


func seed_random(seed_value: int) -> void:
	_rng.seed = seed_value
	_bags.clear()


## Sorteia um jogo do modo (vazio = qualquer) sem repetir até esgotar o
## saco. `exclude` tira ids desta rodada sem tirá-los do saco.
func random(mode: String = "", exclude: PackedStringArray = []) -> JogosGameDefinition:
	var pool: Array[JogosGameDefinition] = by_mode(mode) if mode != "" else _defs
	if pool.is_empty():
		return null
	var key: String = mode
	var bag: Array = _bags.get(key, [])
	var attempts: int = 0
	while attempts < 2:
		if bag.is_empty():
			bag = ids_of(pool)
			_shuffle(bag)
			attempts += 1
		while not bag.is_empty():
			var id: String = str(bag.pop_back())
			_bags[key] = bag
			if not exclude.has(id) and _by_id.has(id):
				return _by_id[id] as JogosGameDefinition
	_bags[key] = bag
	return null


func ids_of(defs: Array[JogosGameDefinition]) -> Array:
	var out: Array = []
	for def: JogosGameDefinition in defs:
		out.append(def.id)
	return out


func _shuffle(arr: Array) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## `res://games/gamao/BackgammonGame.tscn` -> `gamao`. Fora de `res://games/`
## vale o nome do arquivo em snake_case — o mesmo cálculo de
## `JogosBaseGame.derive_game_id`, para os dois lados falarem o mesmo id.
static func id_from_scene_path(scene_path: String) -> String:
	return JogosBaseGame.derive_game_id(scene_path)


## Abre a cena do jogo pelo SceneManager. `false` sem id ou sem navegação.
func launch(id: String, opts: Dictionary = {}) -> bool:
	var def: JogosGameDefinition = get_definition(id)
	if def == null or def.scene_path == "":
		return false
	var nav: Node = JogosLocator.autoload(&"SceneManager")
	if nav == null or not nav.has_method("goto_scene"):
		return false
	nav.call("goto_scene", def.scene_path, opts)
	return true
