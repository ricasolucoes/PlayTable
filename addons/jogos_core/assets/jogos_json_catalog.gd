class_name JogosJsonCatalog
extends RefCounted

## Catálogo de dados agnóstico de schema: varre um diretório por `*.json`,
## indexa cada arquivo por `<categoria>/<id>` (categoria = primeira pasta,
## id = campo `id` ou nome do arquivo) e calcula uma versão por hash de
## conteúdo. Um segundo diretório (padrão `user://game-data`) sobrescreve
## entradas — é como um patch de balanceamento chega sem release.
##
## Fonte: the-war-for-survival/client/autoload/game_data.gd. Tirado: os
## caminhos fixos do TWFS (`res://../shared/game-data`) e a emissão em
## `Events` — aqui há o sinal `reloaded` próprio.

signal reloaded

var _entries: Dictionary = {}
var _version: String = ""


func scan(root_dir: String, override_dir: String = "user://game-data") -> int:
	_entries.clear()
	var hash_parts: PackedStringArray = PackedStringArray()
	var count: int = _scan_into(root_dir, hash_parts)
	if not override_dir.is_empty() and DirAccess.dir_exists_absolute(override_dir):
		count += _scan_into(override_dir, hash_parts)
	_version = "|".join(hash_parts).sha256_text() if not hash_parts.is_empty() else ""
	reloaded.emit()
	return count


func get_version() -> String:
	return _version


func get_entry(category: String, id: String) -> Dictionary:
	return _entries.get("%s/%s" % [category, id], {}) as Dictionary


func has(category: String, id: String) -> bool:
	return _entries.has("%s/%s" % [category, id])


## Ids em ordem alfabética: listas da interface não dançam entre aberturas.
func list_ids(category: String) -> PackedStringArray:
	var prefix: String = "%s/" % category
	var ids: PackedStringArray = PackedStringArray()
	for key: Variant in _entries.keys():
		var full_key: String = String(key)
		if full_key.begins_with(prefix):
			ids.append(full_key.substr(prefix.length()))
	ids.sort()
	return ids


func list_categories() -> PackedStringArray:
	var seen: Dictionary = {}
	for key: Variant in _entries.keys():
		var full_key: String = String(key)
		var slash: int = full_key.find("/")
		if slash > 0:
			seen[full_key.substr(0, slash)] = true
	var out: PackedStringArray = PackedStringArray(seen.keys())
	out.sort()
	return out


func size() -> int:
	return _entries.size()


func _scan_into(root_dir: String, hash_parts: PackedStringArray) -> int:
	if not DirAccess.dir_exists_absolute(root_dir):
		return 0
	var files: PackedStringArray = _scan_json_files(root_dir)
	files.sort()
	var count: int = 0
	for file_path: String in files:
		var content: String = FileAccess.get_file_as_string(file_path)
		if content.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(content)
		if typeof(parsed) != TYPE_DICTIONARY:
			JogosLocator.log("warn", "assets", "catalog_invalid_json", {"path": file_path})
			continue
		var entry: Dictionary = parsed as Dictionary
		var category: String = _category_for(root_dir, file_path)
		var id: String = String(entry.get("id", file_path.get_file().get_basename()))
		_entries["%s/%s" % [category, id]] = entry
		hash_parts.append("%s:%s" % [file_path.trim_prefix(root_dir + "/"), content.sha256_text()])
		count += 1
	return count


func _category_for(root_dir: String, file_path: String) -> String:
	var relative: String = file_path.trim_prefix(root_dir.trim_suffix("/") + "/")
	var slash: int = relative.find("/")
	if slash == -1:
		return ""
	return relative.substr(0, slash)


func _scan_json_files(root_dir: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var pending: Array[String] = [root_dir.trim_suffix("/")]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		var dir: DirAccess = DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name: String = dir.get_next()
		while name != "":
			if name != "." and name != "..":
				var full: String = "%s/%s" % [current, name]
				if dir.current_is_dir():
					pending.append(full)
				elif name.ends_with(".json"):
					result.append(full)
			name = dir.get_next()
	return result
