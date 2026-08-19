class_name TurnManager
extends RefCounted

const PlayerScript = preload("res://shared/core_engine/players/Player.gd")
const GameActionScript = preload("res://shared/core_engine/network/GameAction.gd")

signal turn_started(player: Player)
signal turn_ended(player: Player, action: GameAction)
signal game_ended(winner: Player, reason: String)

var players: Array[Player] = []
var current_player_idx: int = 0
var turn_count: int = 0
var is_active: bool = false

func _init(initial_players: Array[Player] = []):
	players = initial_players.duplicate()

func add_player(p: Player) -> void:
	if p != null:
		players.append(p)

func start_game(starting_player_idx: int = 0) -> void:
	if players.is_empty(): return
	is_active = true
	turn_count = 1
	current_player_idx = starting_player_idx % players.size()
	turn_started.emit(get_current_player())

func next_turn(action: GameAction = null) -> Player:
	if not is_active or players.is_empty(): return null
	
	var prev_player = get_current_player()
	turn_ended.emit(prev_player, action)
	
	turn_count += 1
	current_player_idx = (current_player_idx + 1) % players.size()
	var current_player = get_current_player()
	turn_started.emit(current_player)
	return current_player

func get_current_player() -> Player:
	if players.is_empty(): return null
	return players[current_player_idx]

func get_player_by_id(id: int) -> Player:
	for p in players:
		if p.id == id:
			return p
	return null

func end_game(winner: Player, reason: String = "normal") -> void:
	is_active = false
	game_ended.emit(winner, reason)
