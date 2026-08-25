extends Node

## Gerencia e aplica recompensas tangíveis (XP extra, desbloqueios cosméticos, moedas)
## mantendo idempotência para não haver abuse de claims de rewards.

var claimed_rewards = []

func _ready() -> void:
	_load_claimed_rewards()

func _load_claimed_rewards() -> void:
	claimed_rewards = PlayerProfile.get_claimed_rewards()

func grant_xp(amount: int, source: String) -> void:
	# Wrapper para garantir que grandes injeções de XP passem por uma verificação de anti-cheat futuro
	if GameEventBus:
		GameEventBus.emit_xp_gained(amount, source)

func claim_unique_reward(reward_id: String) -> bool:
	if claimed_rewards.has(reward_id):
		return false # Já resgatou, não conceder novamente
		
	claimed_rewards.append(reward_id)
	PlayerProfile.save_claimed_rewards(claimed_rewards)
	
	# TODO: Aplicar lógica cosmética (ex: liberar skin do tabuleiro)
	return true
