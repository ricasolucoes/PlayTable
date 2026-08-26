extends Node

## Sistema de Maestria Individual por Jogo
##
## Cada um dos 16 jogos de mesa possui sua própria trilha de proficiência (Mastery).
## Jogadores sobem de nível em um jogo específico ao ganhar partidas,
## liberando conquistas de maestria e badges no Perfil do Jogador.

var _mastery_data: Dictionary = {}

func _ready() -> void:
	if GameEventBus:
		GameEventBus.match_completed.connect(_on_match_completed)
	
	_load_mastery()

func _load_mastery() -> void:
	_mastery_data = PlayerProfile.get_stat("game_mastery", {})

func _save_mastery() -> void:
	PlayerProfile.stats["game_mastery"] = _mastery_data
	PlayerProfile.save_profile()

func get_mastery_level(game_id: String) -> int:
	if _mastery_data.has(game_id):
		return _mastery_data[game_id].get("level", 1)
	return 1

func get_mastery_xp(game_id: String) -> int:
	if _mastery_data.has(game_id):
		return _mastery_data[game_id].get("xp", 0)
	return 0

func _on_match_completed(game_id: String, result: Dictionary) -> void:
	if not _mastery_data.has(game_id):
		_mastery_data[game_id] = {"level": 1, "xp": 0}
	
	var xp_reward = 10
	if result.has("win") and result["win"] == true:
		xp_reward = 50
		
	# Bônus de combo ou performance (ex: 3 vitórias seguidas no mesmo jogo)
	if result.has("perfect") and result["perfect"] == true:
		xp_reward += 100
		
	_mastery_data[game_id]["xp"] += xp_reward
	_check_mastery_level_up(game_id)
	_save_mastery()

func _check_mastery_level_up(game_id: String) -> void:
	var current_level = _mastery_data[game_id]["level"]
	var current_xp = _mastery_data[game_id]["xp"]
	
	var xp_needed = current_level * 500
	
	if current_xp >= xp_needed:
		_mastery_data[game_id]["level"] += 1
		_mastery_data[game_id]["xp"] -= xp_needed
		
		# Dispara sinal de Maestria Global (Pode ativar novas Quests ou Conquistas)
		if GameEventBus:
			GameEventBus.xp_gained.emit(200, "mastery_level_up")
			# Check recursivo
			_check_mastery_level_up(game_id)
