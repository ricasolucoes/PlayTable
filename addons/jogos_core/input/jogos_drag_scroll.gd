class_name JogosDragScroll
extends Node

## Rolagem por arrasto do dedo dentro de um ScrollContainer.
##
## Fonte: PlayTable `shared/ui/DragScroll.gd`. Tirado: nada.
##
## O ScrollContainer do Godot rola na roda do mouse e na barra; o arrasto de
## toque -- o unico gesto que existe num telefone -- nao acontece (medido no
## 4.7.2 com evento sintetico fiel: `scroll_vertical` termina em zero). Por
## isso a rolagem mora aqui. O sinal `gui_input` e o PRIMEIRO passo de
## `_call_gui_input`: aceitar o evento ali desliga a rolagem da engine, entao
## nao ha rolagem em dobro.
##
## Respeita: so o eixo liberado E com conteudo sobrando; a roda continua com a
## engine; passada a zona morta avisa `NOTIFICATION_SCROLL_BEGIN` (e como o
## BaseButton desarma o toque pendente); solta com inercia.

const DEAD_ZONE: float = 10.0
## Atrito da inercia por segundo. 0,12 para em cerca de meio segundo.
const FRICTION: float = 0.12
const MIN_VELOCITY: float = 24.0
const MAX_VELOCITY: float = 4200.0

var _sc: ScrollContainer = null
var _finger: int = -1
## Depois do primeiro toque, mouse e ignorado: no Android
## `emulate_mouse_from_touch` faz o mesmo dedo chegar duas vezes.
var _has_touch: bool = false
var _mouse_down: bool = false
var _origin: Vector2 = Vector2.ZERO
var _initial_scroll: Vector2 = Vector2.ZERO
var _accumulated: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _last_delta: Vector2 = Vector2.ZERO


static func attach(sc: ScrollContainer) -> JogosDragScroll:
	if sc == null:
		return null
	var existing: Node = sc.get_node_or_null("DragScroll")
	if existing is JogosDragScroll:
		return existing as JogosDragScroll
	var d: JogosDragScroll = JogosDragScroll.new()
	d.name = "DragScroll"
	sc.add_child(d)
	return d


static func attach_all(root: Node) -> int:
	if root == null:
		return 0
	var n: int = 0
	if root is ScrollContainer:
		attach(root as ScrollContainer)
		n += 1
	for child: Node in root.get_children():
		n += attach_all(child)
	return n


func _ready() -> void:
	set_process(false)
	_sc = get_parent() as ScrollContainer
	if _sc == null:
		JogosLocator.log("warn", "input", "drag_scroll_parent", {"node": str(get_path())})
		return
	if not _sc.gui_input.is_connected(_on_gui_input):
		_sc.gui_input.connect(_on_gui_input)


func _scrolls_h() -> bool:
	if _sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	var b: HScrollBar = _sc.get_h_scroll_bar()
	return b != null and b.max_value - b.min_value > b.page


func _scrolls_v() -> bool:
	if _sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	var b: VScrollBar = _sc.get_v_scroll_bar()
	return b != null and b.max_value - b.min_value > b.page


func _any_axis() -> bool:
	return _scrolls_h() or _scrolls_v()


func _on_gui_input(event: InputEvent) -> void:
	if _sc == null or not _any_axis():
		return
	if event is InputEventScreenTouch:
		_has_touch = true
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			if _finger == -1:
				_finger = st.index
				_start(st.position)
		elif st.index == _finger:
			_finger = -1
			_release()
		return
	if event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if sd.index == _finger:
			_move(sd.position)
		return
	if _has_touch:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_mouse_down = true
			_start(mb.position)
		elif _mouse_down:
			_mouse_down = false
			_release()
		return
	if event is InputEventMouseMotion and _mouse_down:
		_move((event as InputEventMouseMotion).position)


func _start(point: Vector2) -> void:
	set_process(false)
	_velocity = Vector2.ZERO
	_last_delta = Vector2.ZERO
	_origin = point
	_accumulated = Vector2.ZERO
	_dragging = false
	_initial_scroll = Vector2(float(_sc.scroll_horizontal), float(_sc.scroll_vertical))


func _move(point: Vector2) -> void:
	var displacement: Vector2 = point - _origin
	if not _dragging:
		var moved: float = 0.0
		if _scrolls_h() and _scrolls_v():
			moved = displacement.length()
		elif _scrolls_h():
			moved = absf(displacement.x)
		else:
			moved = absf(displacement.y)
		if moved < DEAD_ZONE:
			return
		_dragging = true
		_sc.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	_last_delta = displacement - _accumulated
	_accumulated = displacement
	_apply(_initial_scroll - displacement)
	var dt: float = maxf(get_process_delta_time(), 0.0001)
	_velocity = (-_last_delta / dt).limit_length(MAX_VELOCITY)
	_sc.accept_event()


func _release() -> void:
	if not _dragging:
		return
	_dragging = false
	_sc.propagate_notification(Control.NOTIFICATION_SCROLL_END)
	_sc.accept_event()
	if _velocity.length() > MIN_VELOCITY:
		set_process(true)


func _apply(target: Vector2) -> void:
	if _scrolls_h():
		_sc.scroll_horizontal = int(round(target.x))
	if _scrolls_v():
		_sc.scroll_vertical = int(round(target.y))


func _process(delta: float) -> void:
	if _sc == null:
		set_process(false)
		return
	var current: Vector2 = Vector2(float(_sc.scroll_horizontal), float(_sc.scroll_vertical))
	_apply(current + _velocity * delta)
	_velocity *= pow(FRICTION, delta)
	if _velocity.length() < MIN_VELOCITY:
		_velocity = Vector2.ZERO
		set_process(false)
