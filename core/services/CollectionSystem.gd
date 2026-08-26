extends Node

## Sistema de Coleções (Collections System)
##
## Gerencia itens desbloqueáveis como fundos de mesa, versos de cartas,
## avatares, e medalhas conquistadas. (Preparação Play Games Rewards)

var unlocked_items: Array = []

func _ready() -> void:
	_load_collections()

func _load_collections() -> void:
	unlocked_items = PlayerProfile.get_stat("collections_unlocked", [])

func unlock_item(item_id: String) -> bool:
	if unlocked_items.has(item_id):
		return false
	
	unlocked_items.append(item_id)
	PlayerProfile.stats["collections_unlocked"] = unlocked_items
	PlayerProfile.save_profile()
	
	# Progresso de Game Stats para "Total de Itens Raros/Colecionáveis"
	if PlayGamesManager and PlayGamesManager.is_available():
		PlayGamesManager.submit_game_event("event_item_collected", 1)
		
	return true

func has_item(item_id: String) -> bool:
	return unlocked_items.has(item_id)

func get_completion_percentage() -> float:
	# Simula que existem 100 itens cosméticos no jogo no total
	var total_available = 100.0
	return (float(unlocked_items.size()) / total_available) * 100.0
