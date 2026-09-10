class_name JogosInputDriver
extends RefCounted

## Traduz eventos brutos numa direcao continua (Vector2). Base dos drivers de
## toque: swipe, joystick virtual, relativo ("steering").
##
## Fonte: VOLTA `src/input/input_driver.gd`. Tirado: nada. `process_event`
## ganhou corpo vazio na base para o roteador nao precisar de `has_method`.


func process_event(_event: InputEvent) -> void:
	pass


func poll(_delta: float) -> Vector2:
	return Vector2.ZERO
