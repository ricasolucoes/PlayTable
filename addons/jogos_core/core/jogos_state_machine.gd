class_name JogosStateMachine
extends RefCounted

## Máquina de estados com tabela de transições validada.
##
## Fonte: VOLTA `src/core/fsm/state_machine.gd`. Generalizado: `request()`
## devolve se a transição aconteceu, há `can_transition()` para a HUD
## perguntar antes de habilitar um botão, e a transição inválida é
## `push_error` em build de debug (alto, contado pela suite) e `push_warning`
## em release — nunca `assert`, porque com o depurador ligado o assert pausa
## o jogo inteiro por causa de um botão apertado duas vezes.

signal state_changed(from_state: int, to_state: int)

var _states: Dictionary = {}
var _transitions: Dictionary = {}
var _current_id: int = -1
var _current: JogosState = null


func add_state(id: int, state: JogosState) -> void:
	_states[id] = state


func add_transition(from_id: int, to_id: int) -> void:
	if not _transitions.has(from_id):
		_transitions[from_id] = PackedInt32Array()
	var targets: PackedInt32Array = _transitions[from_id]
	if not targets.has(to_id):
		targets.append(to_id)
	_transitions[from_id] = targets


func add_transitions(from_id: int, to_ids: PackedInt32Array) -> void:
	for to_id: int in to_ids:
		add_transition(from_id, to_id)


func can_transition(to_id: int) -> bool:
	if not _states.has(to_id):
		return false
	if _current_id == -1:
		return true
	if not _transitions.has(_current_id):
		return false
	var targets: PackedInt32Array = _transitions[_current_id]
	return targets.has(to_id)


## Pede a transição. Devolve `false` (e reclama) quando ela não está na
## tabela; o estado não muda. A primeira chamada sempre entra.
func request(to_id: int) -> bool:
	if not _states.has(to_id):
		_complain("estado desconhecido: %d" % to_id)
		return false
	if _current_id != -1 and not can_transition(to_id):
		_complain("transição inválida: %d -> %d" % [_current_id, to_id])
		return false
	_transition_to(to_id)
	return true


func tick(delta: float) -> void:
	if _current != null:
		_current.update(delta)


func get_current_state() -> int:
	return _current_id


func current_state_object() -> JogosState:
	return _current


func is_in(id: int) -> bool:
	return _current_id == id


func _transition_to(to_id: int) -> void:
	var from_id: int = _current_id
	if _current != null:
		_current.exit()
	_current_id = to_id
	_current = _states[to_id] as JogosState
	_current.enter()
	state_changed.emit(from_id, to_id)


func _complain(msg: String) -> void:
	if OS.is_debug_build():
		push_error("JogosStateMachine: " + msg)
	else:
		push_warning("JogosStateMachine: " + msg)
