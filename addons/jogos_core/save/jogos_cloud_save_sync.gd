class_name JogosCloudSaveSync
extends Node

## Sincronização em nuvem e resolução de conflitos para Saved Games (Play Games / Game Center).
## Resolução por merge inteligente (maior valor para contadores, união para conquistas/flags).
## Generalizado de PlayTable/core/save/CloudSaveSync.gd.

signal cloud_save_loaded(success: bool)
signal cloud_save_saved(success: bool)
signal sync_conflict_resolved

@export var snapshot_name: String = "jogos_progress"
@export var save_description_key: String = "CLOUD_SAVE_DESCRIPTION"
@export var schema_version: int = 1

var _plugin: Object = null
var _sync_pending: bool = false


func _ready() -> void:
	if OS.get_name() == "Android" and Engine.has_singleton("PlayGames"):
		_plugin = Engine.get_singleton("PlayGames")
		if _plugin != null:
			if _plugin.has_signal("pgs_snapshot_loaded"):
				_plugin.connect("pgs_snapshot_loaded", _on_snapshot_loaded)
			if _plugin.has_signal("pgs_snapshot_saved"):
				_plugin.connect("pgs_snapshot_saved", _on_snapshot_saved)
			if _plugin.has_signal("pgs_snapshot_conflict"):
				_plugin.connect("pgs_snapshot_conflict", _on_snapshot_conflict)

	var bus: Node = JogosLocator.autoload(&"GameEventBus")
	if bus != null and bus.has_signal("match_completed"):
		bus.connect("match_completed", _on_match_completed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _sync_pending:
			save_to_cloud()


func _on_match_completed(_game_id: String, _result: Dictionary) -> void:
	_sync_pending = true


func is_available() -> bool:
	return _plugin != null


func save_to_cloud() -> void:
	if not is_available():
		return
	_sync_pending = false
	var save_mgr: Node = JogosLocator.autoload(&"SaveManager")
	if save_mgr == null or not save_mgr.has_method("snapshot"):
		return
	var data: Dictionary = save_mgr.call("snapshot")
	var bytes: PackedByteArray = JSON.stringify(data).to_utf8_buffer()
	if _plugin.has_method("saveSnapshot"):
		_plugin.call("saveSnapshot", snapshot_name, tr(save_description_key), Marshalls.raw_to_base64(bytes))


func load_from_cloud() -> void:
	if not is_available():
		return
	if _plugin.has_method("loadSnapshot"):
		_plugin.call("loadSnapshot", snapshot_name)


func apply_remote(remote_data: Dictionary) -> void:
	if remote_data.is_empty():
		return
	var save_mgr: Node = JogosLocator.autoload(&"SaveManager")
	if save_mgr == null:
		return

	var local_data: Dictionary = {}
	if save_mgr.has_method("snapshot"):
		local_data = save_mgr.call("snapshot")

	var merged: Dictionary = merge_save_dicts(local_data, remote_data)
	if save_mgr.has_method("restore"):
		save_mgr.call("restore", merged)


static func merge_save_dicts(local: Dictionary, remote: Dictionary) -> Dictionary:
	var result: Dictionary = local.duplicate(true)
	for sec_key: Variant in remote.keys():
		var section: String = str(sec_key)
		if not result.has(section):
			result[section] = remote[sec_key]
			continue

		if typeof(result[section]) == TYPE_DICTIONARY and typeof(remote[sec_key]) == TYPE_DICTIONARY:
			var sec_local: Dictionary = result[section]
			var sec_remote: Dictionary = remote[sec_key]
			for k: Variant in sec_remote.keys():
				var key: String = str(k)
				if not sec_local.has(key):
					sec_local[key] = sec_remote[k]
				else:
					var v_local: Variant = sec_local[key]
					var v_remote: Variant = sec_remote[k]
					if (v_local is int or v_local is float) and (v_remote is int or v_remote is float):
						sec_local[key] = max(v_local, v_remote)
					elif v_local is Array and v_remote is Array:
						for item: Variant in v_remote:
							if not (v_local as Array).has(item):
								(v_local as Array).append(item)
					else:
						# Mantém local para strings/estados correntes
						pass
	return result


func _decode(base64: String) -> Dictionary:
	if base64.is_empty():
		return {}
	var bytes: PackedByteArray = Marshalls.base64_to_raw(base64)
	if bytes.is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {}
	return json.data as Dictionary


func _on_snapshot_loaded(base64: String) -> void:
	var remote: Dictionary = _decode(base64)
	if remote.is_empty():
		cloud_save_loaded.emit(false)
		save_to_cloud()
		return
	apply_remote(remote)
	cloud_save_loaded.emit(true)


func _on_snapshot_saved(ok: bool, message: String) -> void:
	cloud_save_saved.emit(ok)
	if not ok:
		push_warning("JogosCloudSaveSync: falha ao gravar snapshot: %s" % message)


func _on_snapshot_conflict(conflict_id: String, base64_local: String, base64_server: String) -> void:
	var l: Dictionary = _decode(base64_local)
	var s: Dictionary = _decode(base64_server)
	var merged: Dictionary = merge_save_dicts(l, s)
	apply_remote(merged)
	var resolved_bytes: PackedByteArray = JSON.stringify(merged).to_utf8_buffer()
	if _plugin != null and _plugin.has_method("resolveSnapshotConflict"):
		_plugin.call("resolveSnapshotConflict", conflict_id, Marshalls.raw_to_base64(resolved_bytes))
	sync_conflict_resolved.emit()
