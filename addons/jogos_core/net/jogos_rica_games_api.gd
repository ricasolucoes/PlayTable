class_name JogosRicaGamesApi
extends RefCounted

## Fachada de alto nível para os endpoints da API do RicaGames (/api/v1).
## Consome JogosApiClient diretamente.

var _client: JogosApiClient


func _init(client: JogosApiClient = null) -> void:
	if client != null:
		_client = client
	else:
		var node: Node = JogosLocator.autoload(&"ApiClient")
		if node is JogosApiClient:
			_client = node as JogosApiClient
		elif node != null and node.has_method("get_json"):
			_client = node as JogosApiClient


func is_available() -> bool:
	return _client != null


func get_games() -> Dictionary:
	if not is_available():
		return {"ok": false, "error": "api_client_unavailable"}
	return await _client.get_json("/games")


func get_leaderboards(game_slug: String = "") -> Dictionary:
	if not is_available():
		return {"ok": false, "error": "api_client_unavailable"}
	var path: String = "/gamification/leaderboards"
	var query: Dictionary = {}
	if not game_slug.is_empty():
		query["slug"] = game_slug
	return await _client.get_json(path, query)


func submit_score(leaderboard_id: String, score: float, meta: Dictionary = {}) -> Dictionary:
	if not is_available():
		return {"ok": false, "error": "api_client_unavailable"}
	var payload: Dictionary = {
		"leaderboard_id": leaderboard_id,
		"score": score,
		"meta": meta
	}
	return await _client.post_json("/gamification/sync-score", payload)


func create_room(game_id: String, opts: Dictionary = {}) -> Dictionary:
	if not is_available():
		return {"ok": false, "error": "api_client_unavailable"}
	var payload: Dictionary = {
		"game_id": game_id,
		"options": opts
	}
	return await _client.post_json("/rooms", payload)


func join_room(code: String) -> Dictionary:
	if not is_available():
		return {"ok": false, "error": "api_client_unavailable"}
	return await _client.post_json("/rooms/%s/join" % code.to_upper(), {})
