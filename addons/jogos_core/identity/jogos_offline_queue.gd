class_name JogosOfflineQueue
extends RefCounted

## Fila persistida em `user://` para o que precisa chegar à loja/servidor
## quando a rede ou o SDK voltarem. Colapsa repetição: dez mortes offline não
## viram dez desbloqueios iguais.
##
## Regras de colapso por `kind` (mesmo kind+id):
##   unlock        → uma entrada só
##   increment     → soma os passos
##   event         → soma a quantidade
##   score         → guarda o maior
##   outros        → substitui o valor (último vence)
##
## Fonte: VOLTA/src/platform/api/offline_queue.gd (persistência) e
## PlayTable/core/services/PlayGamesManager.gd (fila do PGS com colapso e
## teto). Tirado: replay acoplado ao `Net` do VOLTA — aqui `drain()` recebe
## um Callable e para na primeira entrega recusada, preservando a ordem.

const DEFAULT_PATH: String = "user://identity_queue.json"
const DEFAULT_MAX: int = 256

var path: String = DEFAULT_PATH
var max_items: int = DEFAULT_MAX
var _items: Array[Dictionary] = []


func _init(queue_path: String = DEFAULT_PATH) -> void:
	path = queue_path
	load_from_disk()


func size() -> int:
	return _items.size()


func is_empty() -> bool:
	return _items.is_empty()


func items() -> Array[Dictionary]:
	return _items.duplicate()


func push(kind: String, id: String, value: int = 0) -> void:
	if id.is_empty():
		return
	for existing: Dictionary in _items:
		if String(existing["kind"]) != kind or String(existing["id"]) != id:
			continue
		match kind:
			"unlock":
				pass
			"increment", "event":
				existing["value"] = int(existing["value"]) + value
			"score":
				existing["value"] = maxi(int(existing["value"]), value)
			_:
				existing["value"] = value
		existing["ts"] = Time.get_unix_time_from_system()
		save_to_disk()
		return
	if _items.size() >= max_items:
		_items.pop_front()
	_items.append({"kind": kind, "id": id, "value": value, "ts": Time.get_unix_time_from_system()})
	save_to_disk()


## Entrega em ordem; `deliver(kind, id, value) -> bool`. Para na primeira
## recusa (o provedor caiu de novo) e devolve quantas entregou.
func drain(deliver: Callable) -> int:
	var delivered: int = 0
	while not _items.is_empty():
		var item: Dictionary = _items[0]
		var ok: bool = bool(deliver.call(String(item["kind"]), String(item["id"]), int(item["value"])))
		if not ok:
			break
		_items.pop_front()
		delivered += 1
	if delivered > 0:
		save_to_disk()
	return delivered


func clear() -> void:
	_items.clear()
	save_to_disk()


func load_from_disk() -> void:
	_items.clear()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Array):
		return
	for entry: Variant in (parsed as Array):
		if entry is Dictionary and (entry as Dictionary).has("kind") and (entry as Dictionary).has("id"):
			var d: Dictionary = entry as Dictionary
			_items.append({
				"kind": String(d["kind"]),
				"id": String(d["id"]),
				"value": int(d.get("value", 0)),
				"ts": float(d.get("ts", 0)),
			})


func save_to_disk() -> void:
	var dir: String = path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		JogosLocator.log("warn", "identity", "queue_write_failed", {"path": path})
		return
	f.store_string(JSON.stringify(_items))
	f.close()
	var abs_tmp: String = ProjectSettings.globalize_path(tmp)
	var abs_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.rename_absolute(abs_tmp, abs_path) != OK:
		DirAccess.remove_absolute(abs_tmp)
