extends Node

## Barramento de eventos globais de Gamificação e Domínio.
##
## Este serviço centraliza a comunicação entre as mecânicas dos jogos
## e as engines de gamificação, garantindo que conquistas, estatísticas e missões
## possam reagir passivamente sem acoplamento direto no código dos jogos.

# ==============================================================================
# EVENTOS DE SESSÃO & JOGADOR
# ==============================================================================
signal game_started(game_id: String)
signal game_completed(game_id: String, result: Dictionary)
signal tutorial_completed(game_id: String)
signal player_leveled_up(new_level: int)

# ==============================================================================
# EVENTOS DE PARTIDA & PROGRESSÃO
# ==============================================================================
signal match_started(game_id: String, mode: String)
signal match_completed(game_id: String, result: Dictionary)
signal turn_completed(game_id: String, current_turn: int)
signal score_updated(game_id: String, new_score: int)

# ==============================================================================
# EVENTOS DE AÇÃO ESPECÍFICA (GRANULARES)
# ==============================================================================
signal enemy_defeated(enemy_type: String)
signal item_collected(item_id: String, amount: int)
signal perfect_run_completed(game_id: String)
signal combo_achieved(game_id: String, combo_count: int)

# ==============================================================================
# EVENTOS DE GAMIFICAÇÃO (FEEDBACK)
# ==============================================================================
signal achievement_unlocked(achievement_id: String)
signal quest_completed(quest_id: String)
signal daily_streak_updated(current_streak: int)
signal xp_gained(amount: int, source: String)

func emit_game_started(game_id: String) -> void:
	game_started.emit(game_id)

func emit_match_completed(game_id: String, result: Dictionary) -> void:
	match_completed.emit(game_id, result)
	
func emit_xp_gained(amount: int, source: String) -> void:
	xp_gained.emit(amount, source)
