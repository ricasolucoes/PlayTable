class_name JogosSwipeDetector
extends Node

## Gestos discretos de um dedo: toque, toque duplo, swipe (com direcao) e
## arrasto. Um dedo, uma maquina de estados, sem depender de camera.
##
## Novo, com os limiares da casa: 12 px ate o toque virar arrasto
## (PlayTable `DragPicker3D.LIMIAR_ARRASTO`), toque duplo em ate 300 ms e
## 24 px. Pendura-se no `gui_input` do Control pai (`attach`) ou recebe
## eventos por `feed()`. Relogio injetavel (`now_provider`) para a suite.

signal tapped(position: Vector2)
signal double_tapped(position: Vector2)
signal swiped(direction: Vector2, distance: float)
signal drag_started(position: Vector2)
signal drag_moved(position: Vector2, delta: Vector2)
signal drag_ended(position: Vector2)

const DRAG_THRESHOLD: float = 12.0
const DOUBLE_TAP_MS: int = 300
const DOUBLE_TAP_DISTANCE: float = 24.0
## Arrasto curto e rapido e swipe: distancia minima e duracao maxima.
const SWIPE_MIN_DISTANCE: float = 40.0
const SWIPE_MAX_MS: int = 400

## Devolve o instante em ms. Trocavel nos testes.
var now_provider: Callable = Callable(Time, &"get_ticks_msec")

var _finger: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _press_ms: int = 0
var _last_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _last_tap_pos: Vector2 = Vector2.INF
var _last_tap_ms: int = -100000


static func attach(control: Control) -> JogosSwipeDetector:
	if control == null:
		return null
	var existing: Node = control.get_node_or_null("SwipeDetector")
	if existing is JogosSwipeDetector:
		return existing as JogosSwipeDetector
	var d: JogosSwipeDetector = JogosSwipeDetector.new()
	d.name = "SwipeDetector"
	control.add_child(d)
	control.gui_input.connect(d.feed)
	return d


func is_dragging() -> bool:
	return _dragging


func feed(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			if _finger == -1:
				_begin(st.index, st.position)
		elif st.index == _finger:
			_end(st.position)
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if sd.index == _finger:
			_move(sd.position)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _finger == -1:
				_begin(JogosSwipeDriver.MOUSE_INDEX, mb.position)
		elif _finger == JogosSwipeDriver.MOUSE_INDEX:
			_end(mb.position)
	elif event is InputEventMouseMotion and _finger == JogosSwipeDriver.MOUSE_INDEX:
		_move((event as InputEventMouseMotion).position)


func cancel() -> void:
	_finger = -1
	_dragging = false


func _now() -> int:
	return int(now_provider.call())


func _begin(index: int, pos: Vector2) -> void:
	_finger = index
	_press_pos = pos
	_last_pos = pos
	_press_ms = _now()
	_dragging = false


func _move(pos: Vector2) -> void:
	if not _dragging:
		if pos.distance_to(_press_pos) < DRAG_THRESHOLD:
			return
		_dragging = true
		drag_started.emit(_press_pos)
	drag_moved.emit(pos, pos - _last_pos)
	_last_pos = pos


func _end(pos: Vector2) -> void:
	var now: int = _now()
	var was_dragging: bool = _dragging
	_finger = -1
	_dragging = false
	if was_dragging:
		var delta: Vector2 = pos - _press_pos
		var elapsed: int = now - _press_ms
		if delta.length() >= SWIPE_MIN_DISTANCE and elapsed <= SWIPE_MAX_MS:
			swiped.emit(cardinal(delta), delta.length())
		drag_ended.emit(pos)
		return
	if now - _last_tap_ms <= DOUBLE_TAP_MS and pos.distance_to(_last_tap_pos) <= DOUBLE_TAP_DISTANCE:
		_last_tap_ms = -100000
		_last_tap_pos = Vector2.INF
		double_tapped.emit(pos)
		return
	_last_tap_ms = now
	_last_tap_pos = pos
	tapped.emit(pos)


## Reduz um vetor a UP/DOWN/LEFT/RIGHT pelo eixo dominante.
static func cardinal(v: Vector2) -> Vector2:
	if absf(v.x) >= absf(v.y):
		return Vector2.RIGHT if v.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y >= 0.0 else Vector2.UP
