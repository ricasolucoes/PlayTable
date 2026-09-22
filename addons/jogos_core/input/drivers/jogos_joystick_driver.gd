class_name JogosJoystickDriver
extends JogosInputDriver

## Joystick virtual que nasce onde o dedo toca.
##
## Fonte: VOLTA `src/input/drivers/joystick_driver.gd`. Tirado: nada.

var is_touching: bool = false
var active_touch_index: int = -1
var center_pos: Vector2 = Vector2.ZERO
var current_pos: Vector2 = Vector2.ZERO

var radius: float = 100.0
var deadzone: float = 20.0
var current_dir: Vector2 = Vector2.UP


func process_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			if active_touch_index != -1:
				return
			active_touch_index = st.index
			is_touching = true
			center_pos = st.position
			current_pos = st.position
		elif st.index == active_touch_index:
			is_touching = false
			active_touch_index = -1
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if is_touching and sd.index == active_touch_index:
			current_pos = sd.position
			var diff: Vector2 = current_pos - center_pos
			if diff.length() > radius:
				current_pos = center_pos + diff.normalized() * radius


## Intensidade 0..1 do desvio (para quem desenha o joystick).
func strength() -> float:
	if not is_touching:
		return 0.0
	return clampf((current_pos - center_pos).length() / maxf(radius, 0.0001), 0.0, 1.0)


func poll(_delta: float) -> Vector2:
	if is_touching:
		var diff: Vector2 = current_pos - center_pos
		if diff.length() > deadzone:
			current_dir = diff.normalized()
	return current_dir
