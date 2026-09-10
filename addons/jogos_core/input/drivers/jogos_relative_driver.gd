class_name JogosRelativeDriver
extends JogosInputDriver

## "Steering": arrastar para os lados gira o rumo atual.
##
## Fonte: VOLTA `src/input/drivers/relative_driver.gd`. Tirado: nada.

var is_touching: bool = false
var active_touch_index: int = -1
var last_pos: Vector2 = Vector2.ZERO
var current_angle: float = -PI / 2.0
var sensitivity: float = 0.01


func process_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			if active_touch_index != -1:
				return
			active_touch_index = st.index
			is_touching = true
			last_pos = st.position
		elif st.index == active_touch_index:
			is_touching = false
			active_touch_index = -1
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if is_touching and sd.index == active_touch_index:
			current_angle += (sd.position.x - last_pos.x) * sensitivity
			last_pos = sd.position


func poll(_delta: float) -> Vector2:
	return Vector2.RIGHT.rotated(current_angle)
