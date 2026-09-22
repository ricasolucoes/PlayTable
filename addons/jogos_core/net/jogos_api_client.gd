class_name JogosApiClient
extends Node

## Cliente HTTP robusto: retry com backoff exponencial + jitter, timeout
## configurável, header Idempotency-Key automático em mutações, resolução de
## base_url (ProjectSettings → ENV → user:// override → default).
##
## Nunca lança exceção: sempre devolve um Dictionary tipado
## {"ok": bool, "status": int, "data": Variant, "error": String, "meta": Dictionary}.
## status == 0 indica erro local/rede antes do servidor responder.

signal online
signal offline

const DEFAULT_TIMEOUT: float = 8.0
const MAX_ATTEMPTS: int = 3
const BASE_BACKOFF: float = 0.5
const PRODUCTION_BASE_URL: String = "https://games.ricasolucoes.com.br/api/v1"
const DESKTOP_DEV_BASE_URL: String = "http://localhost:8080/api/v1"
const ANDROID_EMU_BASE_URL: String = "http://10.0.2.2:8080/api/v1"

var base_url: String = ""
var auth_token: String = ""
var game_slug: String = ""
var timeout_seconds: float = DEFAULT_TIMEOUT
var is_online: bool = true


func _ready() -> void:
	if base_url.is_empty():
		base_url = resolve_base_url()


static func resolve_base_url() -> String:
	# 1. ProjectSettings
	var from_ps: Variant = ProjectSettings.get_setting("jogos/api/base_url", "")
	if from_ps != null and not str(from_ps).strip_edges().is_empty():
		return str(from_ps).strip_edges()

	# 2. Environment variable
	var env_url: String = OS.get_environment("JOGOS_API_BASE_URL")
	if not env_url.is_empty():
		return env_url

	# 3. Local user override file
	var override_file: String = "user://api_base_url.txt"
	if FileAccess.file_exists(override_file):
		var f: FileAccess = FileAccess.open(override_file, FileAccess.READ)
		if f != null:
			var txt: String = f.get_as_text().strip_edges()
			if not txt.is_empty():
				return txt

	# 4. Defaults by platform and build type
	var is_debug: bool = OS.is_debug_build()
	if OS.get_name() == "Android":
		return ANDROID_EMU_BASE_URL if is_debug else PRODUCTION_BASE_URL
	if is_debug:
		return DESKTOP_DEV_BASE_URL
	return PRODUCTION_BASE_URL


func get_json(path: String, query: Dictionary = {}) -> Dictionary:
	var full_path: String = path
	if not query.is_empty():
		var params: PackedStringArray = []
		for k: Variant in query.keys():
			params.append("%s=%s" % [str(k).uri_encode(), str(query[k]).uri_encode()])
		full_path = "%s?%s" % [path, "&".join(params)]
	return await _request_with_retry(HTTPClient.METHOD_GET, full_path, "")


func post_json(path: String, body: Variant, opts: Dictionary = {}) -> Dictionary:
	var payload: String = JSON.stringify(body) if typeof(body) != TYPE_STRING else str(body)
	return await _request_with_retry(HTTPClient.METHOD_POST, path, payload, opts)


func put_json(path: String, body: Variant, opts: Dictionary = {}) -> Dictionary:
	var payload: String = JSON.stringify(body) if typeof(body) != TYPE_STRING else str(body)
	return await _request_with_retry(HTTPClient.METHOD_PUT, path, payload, opts)


func delete_json(path: String, opts: Dictionary = {}) -> Dictionary:
	return await _request_with_retry(HTTPClient.METHOD_DELETE, path, "", opts)


func health() -> bool:
	var res: Dictionary = await get_json("/health")
	return bool(res.get("ok", false))


func _request_with_retry(
	method: HTTPClient.Method,
	path: String,
	body: String,
	opts: Dictionary = {}
) -> Dictionary:
	var url: String = _build_url(path)
	var is_mutation: bool = method != HTTPClient.METHOD_GET and method != HTTPClient.METHOD_HEAD
	var idempotency_key: String = str(opts.get("idempotency_key", ""))
	if is_mutation and idempotency_key.is_empty():
		idempotency_key = _generate_uuid()

	var attempts: int = 0
	var last_result: Dictionary = _error_dict(0, "not_attempted")

	while attempts < MAX_ATTEMPTS:
		attempts += 1
		var res: Dictionary = await _single_request(method, url, body, idempotency_key)
		last_result = res
		var status: int = int(res.get("status", 0))

		if bool(res.get("ok", false)):
			_set_online(true)
			return res

		# Erro de cliente (4xx exceto 429) não deve ter retry
		if status >= 400 and status < 500 and status != 429:
			return res

		# Se for a última tentativa, não espera
		if attempts < MAX_ATTEMPTS:
			var jitter: float = randf_range(0.8, 1.2)
			var delay: float = BASE_BACKOFF * pow(2.0, attempts - 1) * jitter
			await get_tree().create_timer(delay).timeout

	_set_online(false)
	return last_result


func _single_request(
	method: HTTPClient.Method,
	url: String,
	body: String,
	idempotency_key: String
) -> Dictionary:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = timeout_seconds
	add_child(http)

	var headers: PackedStringArray = [
		"Accept: application/json",
		"Content-Type: application/json",
	]
	if not auth_token.is_empty():
		headers.append("Authorization: Bearer %s" % auth_token)
	if not game_slug.is_empty():
		headers.append("X-Game-Slug: %s" % game_slug)
	if not idempotency_key.is_empty():
		headers.append("Idempotency-Key: %s" % idempotency_key)

	var err: Error = http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return _error_dict(0, "http_request_start_failed: %d" % err)

	var response: Array = await http.request_completed
	http.queue_free()

	if response.is_empty() or response.size() < 4:
		return _error_dict(0, "empty_response")

	var result_code: int = int(response[0])
	var status_code: int = int(response[1])
	var body_bytes: PackedByteArray = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return _error_dict(0, "transport_error: %d" % result_code)

	var body_text: String = body_bytes.get_string_from_utf8()
	var json_data: Variant = null
	if not body_text.is_empty():
		var json: JSON = JSON.new()
		if json.parse(body_text) == OK:
			json_data = json.data
		else:
			json_data = body_text

	var ok: bool = status_code >= 200 and status_code < 300
	return {
		"ok": ok,
		"status": status_code,
		"data": json_data,
		"error": "" if ok else str(json_data),
		"meta": {"url": url, "method": method}
	}


func _build_url(path: String) -> String:
	var base: String = base_url.trim_suffix("/")
	var p: String = path if path.begins_with("/") else ("/" + path)
	return base + p


func _set_online(online_state: bool) -> void:
	if is_online != online_state:
		is_online = online_state
		if is_online:
			online.emit()
			var bus: Node = JogosLocator.autoload(&"GameEventBus")
			if bus != null and bus.has_signal("net_online"):
				bus.emit_signal("net_online")
		else:
			offline.emit()
			var bus: Node = JogosLocator.autoload(&"GameEventBus")
			if bus != null and bus.has_signal("net_offline"):
				bus.emit_signal("net_offline")


static func _error_dict(status: int, error_msg: String) -> Dictionary:
	return {
		"ok": false,
		"status": status,
		"data": null,
		"error": error_msg,
		"meta": {}
	}


static func _generate_uuid() -> String:
	var b: PackedByteArray = []
	for i: int in range(16):
		b.append(randi() % 256)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
		b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
	]
