extends Node

## Gerenciador de sincronização em nuvem via Saved Games (PGS)
## 
## O `CloudSaveSync` atua como ponte entre o `SaveManager` local
## e a nuvem do Google Play Games Services, lidando com resolução
## de conflitos (snapshots baseados em timestamp/nível).

signal cloud_save_loaded(success: bool)
signal cloud_save_saved(success: bool)
signal sync_conflict_detected()

const SNAPSHOT_NAME = "PlayTable_Progress"
const SAVE_DESCRIPTION = "Progresso do Jogador"

var _pgs_plugin: Object = null

func _ready() -> void:
	if Engine.has_singleton("GodotPlayGamesServices"):
		_pgs_plugin = Engine.get_singleton("GodotPlayGamesServices")
	elif Engine.has_singleton("PlayGamesServices"):
		_pgs_plugin = Engine.get_singleton("PlayGamesServices")
		
	if _pgs_plugin:
		_connect_signals()

func _connect_signals() -> void:
	if _pgs_plugin.has_signal("saved_game_loaded"):
		_pgs_plugin.connect("saved_game_loaded", Callable(self, "_on_saved_game_loaded"))
	if _pgs_plugin.has_signal("saved_game_saved"):
		_pgs_plugin.connect("saved_game_saved", Callable(self, "_on_saved_game_saved"))
	if _pgs_plugin.has_signal("saved_game_conflict"):
		_pgs_plugin.connect("saved_game_conflict", Callable(self, "_on_saved_game_conflict"))

func save_to_cloud(data_bytes: PackedByteArray) -> void:
	if not _pgs_plugin:
		return
	if _pgs_plugin.has_method("saveSnapshot"):
		_pgs_plugin.saveSnapshot(SNAPSHOT_NAME, SAVE_DESCRIPTION, data_bytes)
	elif _pgs_plugin.has_method("save_snapshot"):
		_pgs_plugin.save_snapshot(SNAPSHOT_NAME, SAVE_DESCRIPTION, data_bytes)

func load_from_cloud() -> void:
	if not _pgs_plugin:
		return
	if _pgs_plugin.has_method("loadSnapshot"):
		_pgs_plugin.loadSnapshot(SNAPSHOT_NAME)
	elif _pgs_plugin.has_method("load_snapshot"):
		_pgs_plugin.load_snapshot(SNAPSHOT_NAME)

func _on_saved_game_loaded(data: PackedByteArray) -> void:
	# Lógica para parsear e fazer merge com os dados locais
	if data.size() > 0:
		cloud_save_loaded.emit(true)
	else:
		cloud_save_loaded.emit(false)

func _on_saved_game_saved() -> void:
	cloud_save_saved.emit(true)

func _on_saved_game_conflict(conflict_id: String, local_data: PackedByteArray, server_data: PackedByteArray) -> void:
	sync_conflict_detected.emit()
	# TODO: Lógica de resolução (escolher a versão com Level/XP mais alto ou Timestamp mais recente)
	# Por padrão, um bom fallback é aceitar a versão do servidor se não houver um parse local robusto
	if _pgs_plugin.has_method("resolveSnapshotConflict"):
		_pgs_plugin.resolveSnapshotConflict(conflict_id, server_data)
