class_name JogosIdentityPort
extends RefCounted

## Porta de identidade da loja (Play Games, Game Center, stub). O jogo só
## fala com esta interface; o provedor real é escolhido por plataforma.
##
## Fonte: Woof Honey/docs/STACK.md (desenho do IdentityPort) e
## PlayTable/core/services/PlayGamesManager.gd (o espírito: silent sign-in,
## `is_available()` diz a verdade, sem plugin o jogo é 100% local). Métodos
## devolvem `true` quando o pedido foi entregue ao provedor; `false` manda o
## chamador enfileirar. Nunca lança, nunca abre tela de login sozinho.

signal signed_in_changed(signed_in: bool, player_name: String)


func provider_name() -> String:
	return "none"


## Verdadeiro só quando o SDK existe de fato neste build.
func is_available() -> bool:
	return false


func is_signed_in() -> bool:
	return false


func sign_in_silent() -> void:
	pass


func sign_in() -> void:
	pass


func sign_out() -> void:
	pass


func player_id() -> String:
	return ""


func player_name() -> String:
	return ""


func unlock_achievement(_achievement_id: String) -> bool:
	return false


func increment_achievement(_achievement_id: String, _steps: int) -> bool:
	return false


func submit_score(_board_id: String, _value: int) -> bool:
	return false


func submit_event(_event_id: String, _amount: int) -> bool:
	return false


func show_leaderboard(_board_id: String) -> bool:
	return false


func show_achievements() -> bool:
	return false
