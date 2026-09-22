class_name JogosSwipeDriver
extends JogosInputDriver

## Direcao pelo arraste do dedo, com zona morta fisica (~3 mm) convertida
## para pixels pelo DPI real. Um segundo dedo nao cancela nem redireciona o
## gesto ativo.
##
## Fonte: VOLTA `src/input/drivers/swipe_driver.gd`. Tirado: nada.

var is_touching: bool = false
var active_touch_index: int = -1
var start_pos: Vector2 = Vector2.ZERO
var current_pos: Vector2 = Vector2.ZERO
var current_dir: Vector2 = Vector2.UP

var deadzone_mm: float = 3.0
var deadzone_px: float = 20.0

const MOUSE_INDEX: int = 99


func _init() -> void:
	var dpi: int = DisplayServer.screen_get_dpi()
	if dpi > 0:
		deadzone_px = mm_to_px(deadzone_mm, float(dpi))


static func mm_to_px(mm: float, dpi: float) -> float:
	return (mm / 25.4) * dpi


func process_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			if active_touch_index != -1:
				return
			active_touch_index = st.index
			is_touching = true
			start_pos = st.position
			current_pos = st.position
		elif st.index == active_touch_index:
			is_touching = false
			active_touch_index = -1
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if is_touching and sd.index == active_touch_index:
			current_pos = sd.position
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if active_touch_index != -1:
				return
			active_touch_index = MOUSE_INDEX
			is_touching = true
			start_pos = mb.position
			current_pos = mb.position
		elif active_touch_index == MOUSE_INDEX:
			is_touching = false
			active_touch_index = -1
	elif event is InputEventMouseMotion:
		if is_touching and active_touch_index == MOUSE_INDEX:
			current_pos = (event as InputEventMouseMotion).position


func poll(_delta: float) -> Vector2:
	if is_touching:
		var diff: Vector2 = current_pos - start_pos
		if diff.length() > deadzone_px:
			current_dir = diff.normalized()
			# Reancora logo atras do dedo: o proximo arraste muda de rumo sem
			# ter de desfazer todo o caminho ja andado.
			start_pos = current_pos - (current_dir * deadzone_px)
	return current_dir
