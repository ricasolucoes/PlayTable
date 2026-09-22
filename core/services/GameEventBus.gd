extends "res://addons/jogos_core/events/game_event_bus_autoload.gd"

## Barramento de eventos de gameplay e gamificacao do PlayTable.
## Herda os sinais de partida, sistema e limitador de anti-spam do jogos_core.

# ==============================================================================
# SESSAO E JOGADOR ESPECIFICOS DO PLAYTABLE
# ==============================================================================
signal game_started(game_id: String)
signal game_completed(game_id: String, result: Dictionary)
signal tutorial_completed(game_id: String)
signal player_leveled_up(new_level: int)

# ==============================================================================
# PARTIDA GRANULAR
# ==============================================================================
signal turn_completed(game_id: String, current_turn: int)
signal enemy_defeated(enemy_type: String)
signal perfect_run_completed(game_id: String)
signal combo_achieved(game_id: String, combo_count: int)

# ==============================================================================
# GAMIFICACAO EXTENDIDA
# ==============================================================================
signal achievement_progressed(achievement_id: String, current: int, target: int)
signal quest_completed(quest_id: String)
signal quest_progressed(quest_id: String, current: int, target: int)
signal quests_rolled(scope: String)
signal daily_streak_updated(current_streak: int)
signal streak_freeze_used(current_streak: int)
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
