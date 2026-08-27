extends Node

## Barramento de eventos de gameplay e gamificacao.
##
## Os 19 jogos publicam fatos ("a partida acabou e o jogador venceu"); as
## engines de gamificacao reagem. Nenhum jogo conhece XP, conquista, missao ou
## Play Games -- e nenhuma engine conhece as regras de nenhum jogo.
##
## Quem publica: `BaseGame.report_match_result()` cobre o fim de partida dos 19
## jogos. Os sinais granulares abaixo sao publicados pelo jogo que tem aquele
## conceito (so o poker tem royal flush).

# ==============================================================================
# SESSAO E JOGADOR
# ==============================================================================
signal game_started(game_id: String)
signal game_completed(game_id: String, result: Dictionary)
signal tutorial_completed(game_id: String)
signal player_leveled_up(new_level: int)

# ==============================================================================
# PARTIDA E PROGRESSAO
# ==============================================================================
signal match_started(game_id: String, mode: String)
signal match_completed(game_id: String, result: Dictionary)
signal turn_completed(game_id: String, current_turn: int)
signal score_updated(game_id: String, new_score: int)

# ==============================================================================
# ACOES ESPECIFICAS (GRANULARES)
# ==============================================================================
signal enemy_defeated(enemy_type: String)
signal item_collected(item_id: String, amount: int)
signal perfect_run_completed(game_id: String)
signal combo_achieved(game_id: String, combo_count: int)

# ==============================================================================
# GAMIFICACAO (FEEDBACK)
# ==============================================================================
signal achievement_unlocked(achievement_id: String)
signal achievement_progressed(achievement_id: String, current: int, target: int)
signal quest_completed(quest_id: String)
signal quest_progressed(quest_id: String, current: int, target: int)
signal quests_rolled(scope: String)
signal daily_streak_updated(current_streak: int)
signal streak_freeze_used(current_streak: int)
signal xp_gained(amount: int, source: String)
signal reward_granted(reward_id: String, kind: String)
signal mastery_leveled(game_id: String, new_level: int)
signal league_changed(league_id: String, promoted: bool)

# ==============================================================================
# PLAY GAMES
# ==============================================================================
signal pgs_sign_in_changed(logged_in: bool, player_name: String)
signal pgs_sync_finished(success: bool, detail: String)


func emit_game_started(game_id: String) -> void:
	game_started.emit(game_id)


func emit_match_started(game_id: String, mode: String = "solo") -> void:
	match_started.emit(game_id, mode)


func emit_match_completed(game_id: String, result: Dictionary) -> void:
	match_completed.emit(game_id, result)


func emit_xp_gained(amount: int, source: String) -> void:
	xp_gained.emit(amount, source)


func emit_score(game_id: String, score: int) -> void:
	score_updated.emit(game_id, score)


func emit_item_collected(item_id: String, amount: int = 1) -> void:
	item_collected.emit(item_id, amount)
