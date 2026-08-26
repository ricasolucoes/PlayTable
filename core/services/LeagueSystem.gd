extends Node

## Sistema de Ligas (Leagues) e Temporadas (Seasons)
##
## Mapeia o jogador para um Ranking Global competitivo com base em ELO/Pontuação.
## Bronze, Prata, Ouro, Platina, Diamante, Mestre, Lenda.

const LEAGUES = [
	{"id": "bronze", "min_elo": 0, "name": "Bronze"},
	{"id": "silver", "min_elo": 1000, "name": "Prata"},
	{"id": "gold", "min_elo": 2000, "name": "Ouro"},
	{"id": "platinum", "min_elo": 3500, "name": "Platina"},
	{"id": "diamond", "min_elo": 5000, "name": "Diamante"},
	{"id": "master", "min_elo": 7000, "name": "Mestre"},
	{"id": "legend", "min_elo": 10000, "name": "Lenda"}
]

var current_elo: int = 0

func _ready() -> void:
	current_elo = PlayerProfile.get_stat("competitive_elo", 0)
	if GameEventBus:
		GameEventBus.match_completed.connect(_on_match_completed)

func _on_match_completed(_game_id: String, result: Dictionary) -> void:
	# Ajuste de ELO básico
	var elo_change = 0
	if result.has("win") and result["win"] == true:
		elo_change = 25
	else:
		elo_change = -15
		
	# Previne cair abaixo de zero
	current_elo = max(0, current_elo + elo_change)
	PlayerProfile.stats["competitive_elo"] = current_elo
	PlayerProfile.save_profile()
	
	_evaluate_league_promotion()

func get_current_league() -> Dictionary:
	var active_league = LEAGUES[0]
	for league in LEAGUES:
		if current_elo >= league["min_elo"]:
			active_league = league
	return active_league

func _evaluate_league_promotion() -> void:
	var league = get_current_league()
	var last_league_id = PlayerProfile.get_stat("last_league_id", "bronze")
	
	if league["id"] != last_league_id:
		# Subiu (ou caiu) de liga
		PlayerProfile.stats["last_league_id"] = league["id"]
		PlayerProfile.save_profile()
		
		# Dispara evento que pode gerar recompensa (Play Games Reward)
		if GameEventBus:
			GameEventBus.xp_gained.emit(1000, "league_promotion")
