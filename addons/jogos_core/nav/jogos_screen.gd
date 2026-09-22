class_name JogosScreen
extends Control

## Base de toda tela empilhável (`JogosScreenStack`).
##
## Fonte: VOLTA `src/ui/navigation/screen.gd`. Tirado: `ThemeService` /
## paleta (o tema em Godot vem pelo `Theme` do projeto). Acrescentado:
## `play_area_rect()`, o contrato que o enquadramento usa para saber qual
## retângulo da tela sobra para o jogo depois da HUD.

signal back_requested
signal exit_requested


func on_pushed(_args: Dictionary = {}) -> void:
	pass


func on_popped() -> void:
	pass


func on_focus_gained() -> void:
	pass


func on_focus_lost() -> void:
	pass


## `true` quando a tela tratou o Voltar (fechou um painel, por exemplo).
func handle_back_button() -> bool:
	return false


## Retângulo, em coordenadas do viewport, que sobra para o conteúdo do jogo
## depois da HUD desta tela. Padrão: a tela inteira.
func play_area_rect() -> Rect2:
	return get_global_rect()
