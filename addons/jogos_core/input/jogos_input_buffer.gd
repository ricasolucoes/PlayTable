class_name JogosInputBuffer
extends RefCounted

## Fila universal de comandos de entrada: suporta comandos contínuos de direção
## (Vector2) e comandos discretos de ação (String) com tempo de expiração
## (age-out) e descarte de redundâncias.
##
## Unifica VOLTA (direções) e CampanhaPrototype (ações).

class Command:
	var dir: Vector2
	var age: float

	func _init(d: Vector2) -> void:
		dir = d
		age = 0.0


class ActionCommand:
	var action: String
	var age: float

	func _init(act: String) -> void:
		action = act
		age = 0.0


var _queue: Array[Command] = []
var _action_queue: Array[ActionCommand] = []
var max_age: float = 0.5
var max_action_buffer_size: int = 5
## Produto escalar acima do qual dois comandos de direção são "o mesmo".
var similarity_threshold: float = 0.95


# ------------------------------------------------------------------ Direção (Vector2)

func push_command(dir: Vector2) -> void:
	if dir.length_squared() < 0.1:
		return
	dir = dir.normalized()
	if not _queue.is_empty():
		var last_cmd: Command = _queue[_queue.size() - 1]
		if last_cmd.dir.dot(dir) > similarity_threshold:
			return
	_queue.append(Command.new(dir))


func has_commands() -> bool:
	return not _queue.is_empty()


func pop_command() -> Vector2:
	if _queue.is_empty():
		return Vector2.ZERO
	var cmd: Command = _queue.pop_front()
	return cmd.dir


func peek_command() -> Vector2:
	if _queue.is_empty():
		return Vector2.ZERO
	return _queue[0].dir


# ------------------------------------------------------------------ Ações Nominais (String)

func push_action(action_name: String) -> void:
	if action_name.is_empty():
		return
	if _action_queue.size() >= max_action_buffer_size:
		_action_queue.pop_front()
	for cmd in _action_queue:
		if cmd.action == action_name and cmd.age < 0.08:
			return
	_action_queue.append(ActionCommand.new(action_name))


func has_action(action_name: String = "") -> bool:
	if action_name.is_empty():
		return not _action_queue.is_empty()
	for cmd in _action_queue:
		if cmd.action == action_name:
			return true
	return false


func consume_action(action_name: String = "") -> String:
	if _action_queue.is_empty():
		return ""
	if action_name.is_empty():
		var oldest: ActionCommand = _action_queue.pop_front()
		return oldest.action
	for i in range(_action_queue.size()):
		if _action_queue[i].action == action_name:
			var act: String = _action_queue[i].action
			_action_queue.remove_at(i)
			return act
	return ""


func clear_actions() -> void:
	_action_queue.clear()


# ------------------------------------------------------------------ Ciclo e Limpeza

func tick(delta: float) -> void:
	for i: int in range(_queue.size() - 1, -1, -1):
		_queue[i].age += delta
		if _queue[i].age > max_age:
			_queue.remove_at(i)

	for j: int in range(_action_queue.size() - 1, -1, -1):
		_action_queue[j].age += delta
		if _action_queue[j].age > max_age:
			_action_queue.remove_at(j)


func clear() -> void:
	_queue.clear()
	_action_queue.clear()
