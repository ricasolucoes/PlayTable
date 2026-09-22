class_name JogosState
extends RefCounted

## Estado de uma `JogosStateMachine`. Fonte: VOLTA `src/core/fsm/state.gd`.
## Sobrescreva os três ganchos; nenhum é obrigatório.


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass
