class_name JogosTouchStick
extends Control

## Analogico de toque que alimenta as acoes `p{n}_up/down/left/right` com
## intensidade, em vez de mover o jogador por conta propria. O jogo le
## `InputRouter.get_vector(n)` e nao sabe se veio do dedo ou do gamepad.
##
## Novo (padrao SuperTuxParty). O stick nasce onde o dedo toca dentro deste
## Control (como o `JogosJoystickDriver` do VOLTA). O nome do no comeca com
## "Touch" de proposito: `JogosScreenFit` ignora camadas de toque ao medir a
## HUD.

signal changed(vector: Vector2)

@export_range(1, 4) var player: int = 1
@export var radius: float = 100.0
@export var deadzone: float = 12.0

var value: Vector2 = Vector2.ZERO
var _finger: int = -1
var _center: Vector2 = Vector2.ZERO


func _init() -> void:
	if name.is_empty() or not name.begins_with("Touch"):
		name = "TouchStick"
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)


## Conta pura: vetor -1..1 a partir do centro, com zona morta e raio.
static func vector_from(center: Vector2, pos: Vector2, stick_radius: float, dead: float) -> Vector2:
	var diff: Vector2 = pos - center
	var len: float = diff.length()
	if len <= dead:
		return Vector2.ZERO
	var r: float = maxf(stick_radius, dead + 0.001)
	var mag: float = clampf((len - dead) / (r - dead), 0.0, 1.0)
	return diff.normalized() * mag


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed and _finger == -1:
			_begin(st.index, st.position)
			accept_event()
		elif not st.pressed and st.index == _finger:
			_end()
			accept_event()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if sd.index == _finger:
			_move(sd.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed and _finger == -1:
			_begin(JogosSwipeDriver.MOUSE_INDEX, mb.position)
			accept_event()
		elif not mb.pressed and _finger == JogosSwipeDriver.MOUSE_INDEX:
			_end()
			accept_event()
	elif event is InputEventMouseMotion and _finger == JogosSwipeDriver.MOUSE_INDEX:
		_move((event as InputEventMouseMotion).position)
		accept_event()


func _begin(index: int, pos: Vector2) -> void:
	_finger = index
	_center = pos
	_set_value(Vector2.ZERO)


func _move(pos: Vector2) -> void:
	_set_value(vector_from(_center, pos, radius, deadzone))


func _end() -> void:
	_finger = -1
	_set_value(Vector2.ZERO)


func _set_value(v: Vector2) -> void:
	value = v
	_inject("left", maxf(-v.x, 0.0))
	_inject("right", maxf(v.x, 0.0))
	_inject("up", maxf(-v.y, 0.0))
	_inject("down", maxf(v.y, 0.0))
	changed.emit(v)


func _inject(action: String, strength: float) -> void:
	var name: StringName = JogosPlayerActions.action_name(player, action)
	if not InputMap.has_action(name):
		return
	var ev: InputEventAction = InputEventAction.new()
	ev.action = name
	ev.pressed = strength > 0.0
	ev.strength = strength
	Input.parse_input_event(ev)
