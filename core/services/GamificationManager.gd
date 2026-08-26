extends Node

## GamificationManager atua como o cérebro das regras de engajamento.
## 
## Ele escuta o GameEventBus e traduz eventos puros de gameplay
## em recompensas de XP, chamadas de desbloqueio de conquistas
## e acompanhamento de Quests.

func _ready() -> void:
	if GameEventBus:
		GameEventBus.match_completed.connect(_on_match_completed)
		GameEventBus.item_collected.connect(_on_item_collected)

func _on_match_completed(game_id: String, result: Dictionary) -> void:
	# Exemplo: Recompensar XP baseado no resultado da partida
	var xp_reward = 0
	
	if result.has("win") and result["win"] == true:
		xp_reward = 50
		if LiveOpsManager:
			xp_reward *= LiveOpsManager.get_xp_multiplier()
			
		if SecurityManager and not SecurityManager.validate_xp_gain(xp_reward):
			xp_reward = 0
			
		if xp_reward > 0 and GameEventBus:
			GameEventBus.emit_xp_gained(xp_reward, "match_win")
		PlayerProfile.increment_stat("total_wins")
	else:
		xp_reward = 10
		if LiveOpsManager:
			xp_reward *= LiveOpsManager.get_xp_multiplier()
			
		if SecurityManager and not SecurityManager.validate_xp_gain(xp_reward):
			xp_reward = 0
			
		if xp_reward > 0 and GameEventBus:
			GameEventBus.emit_xp_gained(xp_reward, "match_loss")
	
	PlayerProfile.increment_stat("total_matches")
	PlayerProfile.update_daily_streak()

func _on_item_collected(_item_id: String, amount: int) -> void:
	PlayerProfile.increment_stat("total_items_collected", amount)
