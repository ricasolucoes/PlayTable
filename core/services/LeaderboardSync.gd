extends Node

## Centralizador de Ranking e Leaderboards
## 
## Captura métricas competitivas do GameEventBus (como best time, combos)
## e avalia se merecem ir para os placares globais e sociais dos amigos via PGS.

func _ready() -> void:
	if GameEventBus:
		GameEventBus.score_updated.connect(_on_score_updated)
		GameEventBus.match_completed.connect(_on_match_completed)

func _on_score_updated(game_id: String, new_score: int) -> void:
	# Submete ao PGS Leaderboards se aplicável
	if PlayGamesManager and PlayGamesManager.is_available():
		PlayGamesManager.submit_score(game_id, new_score)
		
	# Avalia se a pontuação bateu o recorde local
	_evaluate_local_highscore(game_id, new_score)

func _on_match_completed(game_id: String, result: Dictionary) -> void:
	# Algumas tabelas são baseadas em tempo de vitória, não em "pontos" puros.
	if result.has("win") and result["win"] == true and result.has("time_taken"):
		# No Play Games, tempo muitas vezes é enviado em milissegundos
		var time_ms = result["time_taken"] * 1000
		
		# game_id_BEST_TIME deve estar mapeado no PlayGamesManager.LEADERBOARDS
		var leaderboard_key = game_id + "_BEST_TIME"
		if PlayGamesManager and PlayGamesManager.LEADERBOARDS.has(leaderboard_key):
			PlayGamesManager.submit_score(leaderboard_key, time_ms)

func _evaluate_local_highscore(game_id: String, score: int) -> void:
	var stat_key = "best_score_" + game_id
	var current_best = PlayerProfile.get_stat(stat_key, 0)
	
	if score > current_best:
		# Atualiza o melhor placar localmente (idempotência local)
		PlayerProfile.increment_stat(stat_key, score - current_best)
