extends Node

## Gerenciador do Perfil Local do Jogador.
## 
## Responsável por manter o estado da experiência (XP), Nível, 
## dias de streak e estatísticas gerais agregadas localmente,
## para rápida leitura na UI antes mesmo da sincronização com o Cloud Save.

const SAVE_PATH := "user://player_profile.cfg"

var level: int = 1
var total_xp: int = 0
var current_streak: int = 0
var last_played_date: String = ""
var stats: Dictionary = {}
var unlocked_achievements: Array = []
var active_quests: Dictionary = {}
var claimed_rewards: Array = []

func _ready() -> void:
	load_profile()
	if GameEventBus:
		GameEventBus.xp_gained.connect(_on_xp_gained)
		GameEventBus.achievement_unlocked.connect(_on_achievement_unlocked)

func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		level = config.get_value("Progression", "level", 1)
		total_xp = config.get_value("Progression", "total_xp", 0)
		current_streak = config.get_value("Engagement", "current_streak", 0)
		last_played_date = config.get_value("Engagement", "last_played_date", "")
		stats = config.get_value("Stats", "metrics", {})
		unlocked_achievements = config.get_value("Achievements", "unlocked", [])
		active_quests = config.get_value("Quests", "active", {})
		claimed_rewards = config.get_value("Rewards", "claimed", [])
	else:
		_initialize_new_profile()

func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("Progression", "level", level)
	config.set_value("Progression", "total_xp", total_xp)
	config.set_value("Engagement", "current_streak", current_streak)
	config.set_value("Engagement", "last_played_date", last_played_date)
	config.set_value("Stats", "metrics", stats)
	config.set_value("Achievements", "unlocked", unlocked_achievements)
	config.set_value("Quests", "active", active_quests)
	config.set_value("Rewards", "claimed", claimed_rewards)
	config.save(SAVE_PATH)

func _initialize_new_profile() -> void:
	level = 1
	total_xp = 0
	current_streak = 1
	last_played_date = Time.get_date_string_from_system()
	active_quests = {}
	claimed_rewards = []
	save_profile()

func update_daily_streak() -> void:
	var today = Time.get_date_string_from_system()
	if last_played_date == "":
		current_streak = 1
	elif last_played_date != today:
		# Lógica ultra simplificada de streak (pode ser expandida no GamificationManager)
		current_streak += 1
	
	last_played_date = today
	save_profile()

func add_xp(amount: int) -> void:
	total_xp += amount
	_check_level_up()
	save_profile()

func _check_level_up() -> void:
	# Curva de XP super simples: nivel * 1000
	var xp_needed = level * 1000
	if total_xp >= xp_needed:
		level += 1
		total_xp -= xp_needed
		if GameEventBus:
			GameEventBus.player_leveled_up.emit(level)
		_check_level_up() # Verifica níveis múltiplos

func _on_xp_gained(amount: int, _source: String) -> void:
	add_xp(amount)

func _on_achievement_unlocked(id: String) -> void:
	if not unlocked_achievements.has(id):
		unlocked_achievements.append(id)
		save_profile()

func get_stat(key: String, default_value: int = 0) -> int:
	return stats.get(key, default_value)

func increment_stat(key: String, amount: int = 1) -> void:
	stats[key] = get_stat(key) + amount
	save_profile()

func get_active_quests() -> Dictionary:
	return active_quests

func save_active_quests(quests: Dictionary) -> void:
	active_quests = quests
	save_profile()

func get_claimed_rewards() -> Array:
	return claimed_rewards

func save_claimed_rewards(rewards: Array) -> void:
	claimed_rewards = rewards
	save_profile()
