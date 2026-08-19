class_name IPlayerController
extends RefCounted

const PlayerScript = preload("res://shared/core_engine/players/Player.gd")
const GameActionScript = preload("res://shared/core_engine/network/GameAction.gd")

signal move_decided(action: GameAction)

var player: Player

func _init(p_player: Player = null):
	player = p_player

func request_move(game_state: Dictionary) -> void:
	# Subclasses devem implementar a lógica de obtenção ou cálculo da jogada
	# e emitir o sinal move_decided(action).
	pass

func cancel_request() -> void:
	pass
