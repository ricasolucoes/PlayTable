extends Node

## Avaliador diário e semanal de missões (Quests) baseadas em GameEvents.

var current_daily_quests = {}

func _ready() -> void:
	if GameEventBus:
		GameEventBus.match_completed.connect(_on_match_completed)
		GameEventBus.item_collected.connect(_on_item_collected)
	
	_load_daily_quests()

func _load_daily_quests() -> void:
	# Lógica provisória: carregar missões do PlayerProfile ou sortear novas
	var saved_quests = PlayerProfile.get_active_quests()
	if saved_quests.is_empty():
		_roll_new_quests()
	else:
		current_daily_quests = saved_quests

func _roll_new_quests() -> void:
	# Sistema sorteia baseado na raridade ou progresso
	current_daily_quests = {
		"quest_play_3": {"type": "play", "target": 3, "progress": 0, "completed": false, "xp_reward": 300},
		"quest_win_1": {"type": "win", "target": 1, "progress": 0, "completed": false, "xp_reward": 500},
		"quest_collect_10": {"type": "collect", "target": 10, "progress": 0, "completed": false, "xp_reward": 200}
	}
	PlayerProfile.save_active_quests(current_daily_quests)

func _on_match_completed(_game_id: String, result: Dictionary) -> void:
	_progress_quest_type("play", 1)
	if result.has("win") and result["win"] == true:
		_progress_quest_type("win", 1)

func _on_item_collected(_item_id: String, amount: int) -> void:
	_progress_quest_type("collect", amount)

func _progress_quest_type(q_type: String, amount: int) -> void:
	var quests_updated = false
	for q_id in current_daily_quests.keys():
		var q = current_daily_quests[q_id]
		if not q.completed and q.type == q_type:
			q.progress += amount
			quests_updated = true
			if q.progress >= q.target:
				q.progress = q.target
				q.completed = true
				_complete_quest(q_id, q.xp_reward)
				
	if quests_updated:
		PlayerProfile.save_active_quests(current_daily_quests)

func _complete_quest(q_id: String, reward_xp: int) -> void:
	if GameEventBus:
		GameEventBus.quest_completed.emit(q_id)
	
	if RewardSystem:
		RewardSystem.grant_xp(reward_xp, "quest_completion")
