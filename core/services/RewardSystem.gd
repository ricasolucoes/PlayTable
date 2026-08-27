extends Node

## Funil unico de recompensa.
##
## Todo XP do jogo passa por aqui: partida, missao, conquista, maestria,
## promocao de liga, bonus diario. Antes cada engine emitia `xp_gained` por
## conta propria e so o XP de partida passava pelo anti-cheat -- validar um
## caminho de seis nao valida nada. Agora `GameEventBus.xp_gained` tem um
## unico emissor, e o multiplicador de LiveOps tambem se aplica uma vez so.

var claimed_rewards: Array = []


func _ready() -> void:
	claimed_rewards = PlayerProfile.get_claimed_rewards()


## Concede XP. `source` entra no log e no toast ("+400 XP · conquista").
## Devolve o valor efetivamente concedido -- 0 quando o anti-cheat barrou.
func grant_xp(amount: int, source: String, aplicar_multiplicador: bool = true) -> int:
	if amount <= 0:
		return 0

	var valor := amount
	if aplicar_multiplicador and LiveOpsManager:
		valor = int(round(valor * LiveOpsManager.get_xp_multiplier()))

	if SecurityManager and not SecurityManager.validate_xp_gain(valor, source):
		return 0

	if GameEventBus:
		GameEventBus.emit_xp_gained(valor, source)
	return valor


## Recompensa de resgate unico (cosmetico, moeda, congelamento de streak).
## Idempotente: o segundo resgate do mesmo id devolve false sem conceder nada.
func claim_unique_reward(reward_id: String, kind: String = "generic") -> bool:
	if claimed_rewards.has(reward_id):
		return false

	claimed_rewards.append(reward_id)
	PlayerProfile.save_claimed_rewards(claimed_rewards)

	match kind:
		"streak_freeze":
			PlayerProfile.increment_stat("streak_freezes", 1)
		"cosmetic":
			if CollectionSystem:
				CollectionSystem.unlock_item(reward_id)
		_:
			pass

	if GameEventBus:
		GameEventBus.reward_granted.emit(reward_id, kind)
	return true


func has_claimed(reward_id: String) -> bool:
	return claimed_rewards.has(reward_id)
