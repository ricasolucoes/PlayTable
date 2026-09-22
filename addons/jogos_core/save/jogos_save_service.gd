class_name JogosSaveService
extends RefCounted

## Um arquivo JSON em `user://` com escrita atômica, recuperação de corrupção
## em dois níveis e migrações encadeadas por `schema_version`.
##
## Extraído de VOLTA `src/core/save/file_save_service.gd` + `save_data.gd`.
## Generalização: os blocos fixos do VOLTA (player/progress/wallet...) viraram
## seções livres (`data[section][key]`), e profile/settings deixaram de ser
## dois arquivos amarrados — quem quer isolamento cria dois serviços com
## caminhos diferentes. Preservado do original:
## - escrita: `.tmp` → flush → copia o principal válido para `.bak` → rename;
## - leitura: principal inválido → `.bak`; os dois inválidos → renomeia para
##   `.corrupt-<timestamp>` (nunca apaga) e recria vazio;
## - chave desconhecida sobrevive ao ciclo load/save (é tudo Dictionary).

enum Result { OK, RESTORED_FROM_BACKUP, RECREATED }

const META: String = "meta"

var path: String = "user://save.json"
var schema_version: int = 1
var data: Dictionary = {}
var last_result: int = Result.RECREATED

var _migrations: Array[JogosSaveMigration] = []


func _init(file_path: String = "user://save.json", current_schema_version: int = 1) -> void:
	path = file_path
	schema_version = current_schema_version
	data = _empty_data()


func register_migration(migration: JogosSaveMigration) -> void:
	_migrations.append(migration)


func load() -> int:
	var loaded: Dictionary = _load_with_recovery()
	var result: int = loaded["result"]
	last_result = result
	if result == Result.RECREATED:
		data = _empty_data()
		save()
		return result
	data = _run_migrations(loaded["data"])
	if not data.has(META) or typeof(data[META]) != TYPE_DICTIONARY:
		data[META] = _empty_data()[META]
	return result


func save() -> void:
	var meta: Dictionary = data.get(META, {})
	meta["schema_version"] = int(meta.get("schema_version", schema_version))
	meta["app_version"] = JogosBuild.version()
	meta["updated_at"] = Time.get_datetime_string_from_system(true)
	data[META] = meta
	_write_atomic(data)


func get_value(section: String, key: String, default_value: Variant = null) -> Variant:
	var sec: Variant = data.get(section)
	if typeof(sec) != TYPE_DICTIONARY:
		return default_value
	return (sec as Dictionary).get(key, default_value)


func set_value(section: String, key: String, value: Variant) -> void:
	if section == META:
		push_error("JogosSaveService: a seção 'meta' é reservada")
		return
	var sec: Variant = data.get(section)
	if typeof(sec) != TYPE_DICTIONARY:
		sec = {}
		data[section] = sec
	(sec as Dictionary)[key] = value


func has_section(section: String) -> bool:
	if section == META:
		return false
	return data.has(section) and typeof(data[section]) == TYPE_DICTIONARY


func has_key(section: String, key: String) -> bool:
	return has_section(section) and (data[section] as Dictionary).has(key)


func erase_key(section: String, key: String) -> void:
	if has_section(section):
		(data[section] as Dictionary).erase(key)


func sections() -> PackedStringArray:
	var out: PackedStringArray = []
	for key: Variant in data.keys():
		if str(key) != META and typeof(data[key]) == TYPE_DICTIONARY:
			out.append(str(key))
	return out


func current_schema_version() -> int:
	var meta: Dictionary = data.get(META, {})
	return int(meta.get("schema_version", schema_version))


## Cópia profunda para a suite guardar e devolver: fim de partida grava, e
## sem isto os testes escreviam no progresso de quem joga nesta máquina.
func snapshot() -> Dictionary:
	return data.duplicate(true)


func restore(copy: Dictionary) -> void:
	data = copy.duplicate(true)
	if not data.has(META):
		data[META] = _empty_data()[META]
	save()


func _empty_data() -> Dictionary:
	return {
		META: {
			"schema_version": schema_version,
			"app_version": JogosBuild.version(),
			"created_at": Time.get_datetime_string_from_system(true),
			"updated_at": "",
		}
	}


func _run_migrations(raw: Dictionary) -> Dictionary:
	var current: Dictionary = raw
	var guard: int = 0
	while guard < 1000:
		guard += 1
		var meta: Dictionary = current.get(META, {})
		var version: int = int(meta.get("schema_version", schema_version))
		var next: JogosSaveMigration = null
		for m: JogosSaveMigration in _migrations:
			if m.from_version() == version:
				next = m
				break
		if next == null:
			break
		current = next.migrate(current)
		var after: Dictionary = current.get(META, {})
		if int(after.get("schema_version", version)) == version:
			after["schema_version"] = next.to_version()
			current[META] = after
	return current


func _base_dir() -> String:
	return path.get_base_dir()


func _write_atomic(payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_base_dir())
	var tmp_path: String = path + ".tmp"
	var bak_path: String = path + ".bak"

	var tmp_file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		push_error("JogosSaveService: falha ao abrir %s (erro %d)" % [tmp_path, FileAccess.get_open_error()])
		return
	tmp_file.store_string(JSON.stringify(payload, "  "))
	tmp_file.flush()
	tmp_file.close()

	if _try_parse(path)["valid"]:
		var current_text: String = FileAccess.get_file_as_string(path)
		var bak_file: FileAccess = FileAccess.open(bak_path, FileAccess.WRITE)
		if bak_file != null:
			bak_file.store_string(current_text)
			bak_file.flush()
			bak_file.close()

	var dir: DirAccess = DirAccess.open(_base_dir())
	if dir == null:
		push_error("JogosSaveService: não foi possível abrir %s para renomear %s" % [_base_dir(), tmp_path])
		return
	dir.rename(tmp_path, path)


func _load_with_recovery() -> Dictionary:
	var bak_path: String = path + ".bak"
	if not FileAccess.file_exists(path):
		return {"result": Result.RECREATED, "data": {}}

	var main: Dictionary = _try_parse(path)
	if main["valid"]:
		return {"result": Result.OK, "data": main["data"]}

	var bak: Dictionary = _try_parse(bak_path)
	if bak["valid"]:
		_write_atomic(bak["data"])
		return {"result": Result.RESTORED_FROM_BACKUP, "data": bak["data"]}

	var timestamp: int = int(Time.get_unix_time_from_system())
	_rename_to_corrupt(path, timestamp)
	if FileAccess.file_exists(bak_path):
		_rename_to_corrupt(bak_path, timestamp)
	return {"result": Result.RECREATED, "data": {}}


func _rename_to_corrupt(file_path: String, timestamp: int) -> void:
	var dir: DirAccess = DirAccess.open(_base_dir())
	if dir == null:
		push_error("JogosSaveService: não foi possível abrir %s para preservar %s" % [_base_dir(), file_path])
		return
	dir.rename(file_path, "%s.corrupt-%d" % [file_path, timestamp])
	JogosLocator.log("warn", "save", "save_file_corrupt_preserved", {"path": file_path})


## `JSON.new().parse()` em vez de `JSON.parse_string()`: o segundo imprime
## erro no console a cada arquivo inválido, e arquivo inválido aqui é cenário
## previsto, não bug.
func _try_parse(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"valid": false, "data": {}}
	var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return {"valid": false, "data": {}}
	var text: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {"valid": false, "data": {}}
	return {"valid": true, "data": json.data}
