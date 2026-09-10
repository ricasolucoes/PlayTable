class_name JogosMatchFlow
extends RefCounted

## O ciclo de vida de qualquer partida, como máquina de estados.
##
## Fonte: VOLTA `src/gameplay/game_state.gd` (enum e tabela de transições).
## Tirado: `MatchDirector`, os `Log.info` por estado e o `SceneTree.paused`
## do PausedState — pausar a árvore é decisão do jogo (`JogosBaseGame` faz
## isso), não da máquina. Os estados são `JogosState` vazios por padrão;
## `set_state(id, state)` troca qualquer um por uma implementação própria.

enum Id { BOOT, MENU, LOADING, COUNTDOWN, PLAYING, PAUSED, RESULTS }

const TRANSITIONS: Dictionary = {
	Id.BOOT: [Id.MENU, Id.LOADING],
	Id.MENU: [Id.LOADING],
	Id.LOADING: [Id.COUNTDOWN, Id.PLAYING, Id.MENU],
	Id.COUNTDOWN: [Id.PLAYING, Id.MENU],
	Id.PLAYING: [Id.PAUSED, Id.RESULTS, Id.MENU],
	Id.PAUSED: [Id.PLAYING, Id.RESULTS, Id.MENU],
	Id.RESULTS: [Id.MENU, Id.LOADING],
}

signal state_changed(from_state: int, to_state: int)

var fsm: JogosStateMachine = JogosStateMachine.new()


func _init() -> void:
	for id: int in Id.values():
		fsm.add_state(id, JogosState.new())
	for from_id: int in TRANSITIONS:
		for to_id: int in TRANSITIONS[from_id]:
			fsm.add_transition(from_id, to_id)
	fsm.state_changed.connect(func(a: int, b: int) -> void: state_changed.emit(a, b))
	fsm.request(Id.BOOT)


func set_state(id: int, state: JogosState) -> void:
	fsm.add_state(id, state)


func request(to_id: int) -> bool:
	return fsm.request(to_id)


func can_transition(to_id: int) -> bool:
	return fsm.can_transition(to_id)


func current() -> int:
	return fsm.get_current_state()


func is_in(id: int) -> bool:
	return fsm.is_in(id)


func tick(delta: float) -> void:
	fsm.tick(delta)


static func state_name(id: int) -> String:
	return str(Id.keys()[id]) if id >= 0 and id < Id.size() else "NONE"
