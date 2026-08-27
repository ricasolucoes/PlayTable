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

func _on_match_completed(_game_id: String, result: Dictionary) -> void:
	var won: bool = bool(result.get("win", false))

	# O jogo pode trazer o proprio XP no resultado: o Gamao paga a mais por
	# gamao e backgammon, a Torre de Hanoi por numero de discos e por partida
	# perfeita. Sem isso vale a tabela padrao. Antes cada um desses jogos
	# emitia `xp_gained` por conta propria ALEM de publicar a partida aqui, e o
	# jogador recebia XP em dobro.
	var xp_reward: int = int(result.get("xp", 50 if won else 10))

	if LiveOpsManager:
		xp_reward = int(xp_reward * LiveOpsManager.get_xp_multiplier())
	if SecurityManager and not SecurityManager.validate_xp_gain(xp_reward):
		xp_reward = 0
	if xp_reward > 0 and GameEventBus:
		GameEventBus.emit_xp_gained(xp_reward, "match_win" if won else "match_loss")

	PlayerProfile.increment_stat("total_matches")
	if won:
		PlayerProfile.increment_stat("total_wins")
	PlayerProfile.update_daily_streak()


func _on_item_collected(_item_id: String, amount: int) -> void:
	PlayerProfile.increment_stat("total_items_collected", amount)
