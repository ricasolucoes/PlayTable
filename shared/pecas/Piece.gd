extends Node2D

@export var is_red: bool = true

func _draw():
	var color = Color(0.9, 0.1, 0.1) if is_red else Color(0.9, 0.8, 0.1)
	# Draw a circle with a border
	draw_circle(Vector2.ZERO, 30, color)
	draw_arc(Vector2.ZERO, 30, 0, TAU, 32, Color(0.1, 0.1, 0.1), 2.0, true)

func drop_to(target_y: float):
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position:y", target_y, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
