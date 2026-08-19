class_name AIPlayerController
extends IPlayerController

var ai_strategy: Callable # Assinatura: func(game_state: Dictionary, player_id: int) -> Dictionary
var difficulty: String = "medium"

func _init(p_player: Player = null, p_strategy: Callable = Callable(), p_difficulty: String = "medium").(p_player):
	ai_strategy = p_strategy
	difficulty = p_difficulty

func request_move(game_state: Dictionary) -> void:
	var player_id = player.id if player != null else 2
	var action_dict: Dictionary = {}
	
	if ai_strategy.is_valid():
		action_dict = ai_strategy.call(game_state, player_id)
	else:
		action_dict = {"action_type": "pass", "payload": {}}
		
	var action = GameAction.new(
		player_id,
		str(action_dict.get("action_type", "move")),
		action_dict.get("payload", {})
	)
	
	move_decided.emit(action)
