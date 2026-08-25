extends Node

## Avalia regras de conquista baseadas em estatísticas e eventos locais.
## Quando os critérios são atingidos, dispara para o GameEventBus.

var _achievement_defs = {}

func _ready() -> void:
	_load_achievement_definitions()
	if GameEventBus:
		GameEventBus.match_completed.connect(_on_match_completed)
		GameEventBus.item_collected.connect(_on_item_collected)
		GameEventBus.player_leveled_up.connect(_on_player_leveled_up)

func _load_achievement_definitions() -> void:
	# Esta configuração mapeia o ID interno do jogo aos requisitos lógicos
	_achievement_defs = {
		"ACH_FIRST_BLOOD": {"type": "stat", "stat": "total_wins", "threshold": 1},
		"ACH_VETERAN": {"type": "stat", "stat": "total_matches", "threshold": 10},
		"ACH_MASTER": {"type": "stat", "stat": "total_wins", "threshold": 50},
		"ACH_LEVEL_10": {"type": "level", "threshold": 10},
		"ACH_ITEM_COLLECTOR": {"type": "stat", "stat": "total_items_collected", "threshold": 100},
		# Expansão para os +40 definidos na matriz será alimentada via JSON/Dicionário.
	}

func _on_match_completed(_game_id: String, _result: Dictionary) -> void:
	_evaluate_stat_achievements()

func _on_item_collected(_item_id: String, _amount: int) -> void:
	_evaluate_stat_achievements()

func _on_player_leveled_up(new_level: int) -> void:
	for ach_id in _achievement_defs.keys():
		if PlayerProfile.unlocked_achievements.has(ach_id):
			continue
			
		var def = _achievement_defs[ach_id]
		if def.type == "level" and new_level >= def.threshold:
			_unlock(ach_id)

func _evaluate_stat_achievements() -> void:
	for ach_id in _achievement_defs.keys():
		if PlayerProfile.unlocked_achievements.has(ach_id):
			continue
			
		var def = _achievement_defs[ach_id]
		if def.type == "stat":
			var current_val = PlayerProfile.get_stat(def.stat)
			if current_val >= def.threshold:
				_unlock(ach_id)

func _unlock(ach_id: String) -> void:
	if GameEventBus:
		GameEventBus.achievement_unlocked.emit(ach_id)
