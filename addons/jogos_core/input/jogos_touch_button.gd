class_name JogosTouchButton
extends Control

## Botao de toque que dispara uma acao de jogador (`p1_confirm`, `p2_action1`).
## O jogo le `InputRouter.is_pressed()` e nao sabe se veio do dedo, do
## teclado ou do gamepad. Sem desenho: cada jogo pendura a arte por cima
## (TextureRect filho) ou herda e sobrescreve `_draw`.
##
## Novo (padrao SuperTuxParty). Nome comeca com "Touch" para a medida de HUD
## ignorar a camada de toque.

signal pressed
signal released

@export_range(1, 4) var player: int = 1
@export var action: String = "confirm"

var is_down: bool = false
var _finger: int = -1


func _init() -> void:
	if name.is_empty() or not name.begins_with("Touch"):
		name = "TouchButton"
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)


func _notification(what: int) -> void:
	# Perdeu o foco ou saiu da arvore com o dedo em cima: solta, senao a acao
	# fica presa.
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_down:
			_release()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed and _finger == -1:
			_finger = st.index
			_press()
			accept_event()
		elif not st.pressed and st.index == _finger:
			_release()
			accept_event()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed and _finger == -1:
			_finger = JogosSwipeDriver.MOUSE_INDEX
			_press()
			accept_event()
		elif not mb.pressed and _finger == JogosSwipeDriver.MOUSE_INDEX:
			_release()
			accept_event()


func _press() -> void:
	is_down = true
	_inject(true)
	pressed.emit()


func _release() -> void:
	is_down = false
	_finger = -1
	_inject(false)
	released.emit()


func _inject(down: bool) -> void:
	var name: StringName = JogosPlayerActions.action_name(player, action)
	if not InputMap.has_action(name):
		return
	var ev: InputEventAction = InputEventAction.new()
	ev.action = name
	ev.pressed = down
	ev.strength = 1.0 if down else 0.0
	Input.parse_input_event(ev)
