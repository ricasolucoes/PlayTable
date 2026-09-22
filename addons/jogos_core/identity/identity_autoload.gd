extends Node

## Autoload `Identity`: escolhe o provedor por plataforma, faz silent sign-in
## no boot, traduz chaves internas para ids da loja e enfileira offline o que
## não pôde ser entregue. Sem `class_name`.
##
## Três regras herdadas do PlayGamesManager do PlayTable:
## 1. Não inventar id: chave sem entrada em `id_map` não é enviada, e aparece
##    em `unmapped_keys()` para o diagnóstico.
## 2. Fila offline persistida: fechar o app não perde nada.
## 3. Degradar sem mentir: sem plugin, `is_available()` é falso e a UI esconde
##    o que não dá para mostrar. Nunca tela de login obrigatória.

signal signed_in_changed(signed_in: bool, player_name: String)
signal delivered(kind: String, id: String, value: int)

const KIND_UNLOCK: String = "unlock"
const KIND_INCREMENT: String = "increment"
const KIND_SCORE: String = "score"
const KIND_EVENT: String = "event"

## `{ "achievements": {chave: id}, "leaderboards": {...}, "events": {...} }`.
## Vazio = sem mapa: as chaves internas são usadas como estão.
var id_map: Dictionary = {}
var queue_path: String = JogosOfflineQueue.DEFAULT_PATH
var provider: JogosIdentityPort = null
var _queue: JogosOfflineQueue = null
var _unmapped: Dictionary = {}
var _auto_provider: bool = true


func _ready() -> void:
	_queue = JogosOfflineQueue.new(queue_path)
	if provider == null and _auto_provider:
		set_provider(_default_provider())
	if provider != null and provider.is_available():
		provider.sign_in_silent()


func set_provider(new_provider: JogosIdentityPort) -> void:
	_auto_provider = false
	if provider != null and provider.signed_in_changed.is_connected(_on_provider_signed_in):
		provider.signed_in_changed.disconnect(_on_provider_signed_in)
	provider = new_provider
	if provider != null:
		provider.signed_in_changed.connect(_on_provider_signed_in)
		if _queue == null:
			_queue = JogosOfflineQueue.new(queue_path)


func load_id_map(json_path: String) -> bool:
	if not FileAccess.file_exists(json_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (parsed is Dictionary):
		return false
	id_map = parsed as Dictionary
	return true


func is_available() -> bool:
	return provider != null and provider.is_available()


func is_signed_in() -> bool:
	return provider != null and provider.is_signed_in()


func player_id() -> String:
	return provider.player_id() if provider != null else ""


func player_name() -> String:
	return provider.player_name() if provider != null else ""


func sign_in() -> void:
	if provider != null and provider.is_available():
		provider.sign_in()


func sign_out() -> void:
	if provider != null:
		provider.sign_out()


func unlock_achievement(key: String) -> void:
	_send(KIND_UNLOCK, _map("achievements", key), 0)


func increment_achievement(key: String, steps: int = 1) -> void:
	_send(KIND_INCREMENT, _map("achievements", key), steps)


func submit_score(key: String, value: int) -> void:
	_send(KIND_SCORE, _map("leaderboards", key), value)


func submit_event(key: String, amount: int = 1) -> void:
	_send(KIND_EVENT, _map("events", key), amount)


func show_leaderboard(key: String) -> bool:
	var id: String = _map("leaderboards", key)
	return provider != null and not id.is_empty() and provider.show_leaderboard(id)


func show_achievements() -> bool:
	return provider != null and provider.show_achievements()


func pending_count() -> int:
	return _queue.size() if _queue != null else 0


func unmapped_keys() -> Array:
	return _unmapped.keys()


## Tenta esvaziar a fila agora (chame ao voltar do segundo plano).
func flush() -> int:
	if _queue == null or provider == null or not provider.is_signed_in():
		return 0
	return _queue.drain(_deliver)


func _send(kind: String, id: String, value: int) -> void:
	if id.is_empty():
		return
	if provider != null and provider.is_signed_in() and _queue.is_empty() and _deliver(kind, id, value):
		return
	_queue.push(kind, id, value)
	flush()


func _deliver(kind: String, id: String, value: int) -> bool:
	if provider == null:
		return false
	var ok: bool = false
	match kind:
		KIND_UNLOCK:
			ok = provider.unlock_achievement(id)
		KIND_INCREMENT:
			ok = provider.increment_achievement(id, value)
		KIND_SCORE:
			ok = provider.submit_score(id, value)
		KIND_EVENT:
			ok = provider.submit_event(id, value)
		_:
			ok = false
	if ok:
		delivered.emit(kind, id, value)
	return ok


## Chave interna → id da loja. Sem mapa, a chave é o id. Com mapa e sem
## entrada, vazio (e registrado): id vazio não se inventa.
func _map(kind: String, key: String) -> String:
	if id_map.is_empty():
		return key
	var table: Dictionary = id_map.get(kind, {}) as Dictionary
	var id: String = String(table.get(key, ""))
	if id.is_empty():
		_unmapped[kind + "/" + key] = true
	return id


func _on_provider_signed_in(signed_in: bool, name: String) -> void:
	signed_in_changed.emit(signed_in, name)
	var bus: Node = JogosLocator.autoload(&"GameEventBus")
	if bus != null and bus.has_signal("identity_changed"):
		bus.emit_signal("identity_changed", signed_in, name)
	if signed_in:
		flush()


func _default_provider() -> JogosIdentityPort:
	match OS.get_name():
		"Android":
			return JogosPlayGamesIdentity.new()
		"iOS":
			return JogosGameCenterIdentity.new()
		_:
			return JogosStubIdentity.new()
