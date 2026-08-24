@tool
extends Node2D

## Ficha 2D desenhada por código, com aparência de volume e brilho de vitória.
##
## Chamava-se shared/pecas/Piece.gd, o único diretório em português dentro de
## shared/ e um nome que colidia com o class_name Piece de
## shared/core_engine/board/Piece.gd, que é outra coisa: dado de tabuleiro, sem
## desenho nenhum.

const SHADOW_OFFSET := Vector2(0, 4)
const SHADOW_EXTRA_RADIUS := 2.0
const GLOW_BASE_SIZE := 6.0
const GLOW_PULSE_SIZE := 6.0
const RIDGE_OUTER_RATIO := 0.68
const RIDGE_INNER_RATIO := 0.38
const SPECULAR_OFFSET_RATIO := Vector2(-0.25, -0.28)

@export var is_red: bool = true:
	set(value):
		is_red = value
		queue_redraw()

@export var radius: float = 28.0:
	set(value):
		radius = value
		queue_redraw()

var is_winning: bool = false
var win_glow_t: float = 0.0

func _process(delta: float) -> void:
	if is_winning:
		win_glow_t += delta * 4.0
		queue_redraw()

func set_winning(win: bool) -> void:
	is_winning = win
	set_process(win)
	queue_redraw()

func _draw() -> void:
	var r = radius
	var base_c = Color(0.88, 0.15, 0.15) if is_red else Color(0.96, 0.75, 0.12)
	var dark_c = Color(0.50, 0.06, 0.06) if is_red else Color(0.62, 0.42, 0.04)
	var light_c = Color(1.0, 0.45, 0.45) if is_red else Color(1.0, 0.92, 0.50)
	var rim_top = Color(1.0, 0.6, 0.6) if is_red else Color(1.0, 0.98, 0.75)
	var rim_bottom = dark_c
	
	# 1. Soft Drop Shadow below piece
	draw_circle(SHADOW_OFFSET, r + SHADOW_EXTRA_RADIUS, Color(0.0, 0.0, 0.0, 0.35))
	
	# 2. Winning Glow Aura
	if is_winning:
		var glow_pulse = 0.5 + 0.5 * sin(win_glow_t)
		var glow_r = r + GLOW_BASE_SIZE + (glow_pulse * GLOW_PULSE_SIZE)
		var glow_color = Color(1.0, 0.9, 0.2, 0.6 * glow_pulse)
		draw_circle(Vector2.ZERO, glow_r, glow_color)
	
	# 3. Outer Disc Bevel & Rim
	draw_circle(Vector2.ZERO, r, dark_c)
	draw_circle(Vector2(0, -1), r - 1.5, base_c)
	
	# 4. 3D Spherical Volume Gradient (multi-layer concentric)
	var steps = 6
	for i in range(steps):
		var t = float(i) / float(steps)
		var step_r = r * (1.0 - t * 0.4)
		var offset_y = -t * 2.0
		var c = base_c.lerp(light_c, t * 0.45)
		draw_circle(Vector2(0, offset_y), step_r, c)
	
	# 5. Concentric Tactile Ridge Rings
	draw_arc(Vector2(0, -0.5), r * RIDGE_OUTER_RATIO, 0, TAU, 32, dark_c, 2.0, true)
	draw_arc(Vector2(0, -1.5), r * RIDGE_OUTER_RATIO, PI * 0.8, PI * 1.8, 20, rim_top, 1.5, true)
	
	draw_arc(Vector2(0, -0.5), r * RIDGE_INNER_RATIO, 0, TAU, 24, dark_c, 1.8, true)
	draw_arc(Vector2(0, -1.5), r * RIDGE_INNER_RATIO, PI * 0.8, PI * 1.8, 16, rim_top, 1.2, true)
	
	# 6. Central Glossy Specular Highlight Dome
	var spec_pos = Vector2(r * SPECULAR_OFFSET_RATIO.x, r * SPECULAR_OFFSET_RATIO.y)
	draw_circle(spec_pos, r * 0.25, Color(1.0, 1.0, 1.0, 0.45))
	draw_circle(spec_pos + Vector2(-1, -1), r * 0.12, Color(1.0, 1.0, 1.0, 0.75))

func drop_to(target_y: float, on_finished: Callable = Callable()) -> void:
	var start_y = position.y
	var dist = abs(target_y - start_y)
	var duration = clampf(sqrt(dist / 900.0) * 0.45, 0.25, 0.55)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", target_y, duration)
	
	tween.tween_callback(func():
		if AudioManager:
			AudioManager.play_chip_drop()
		# Slight bounce
		var bounce_tween = create_tween()
		bounce_tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		bounce_tween.tween_property(self, "position:y", target_y - 12.0, 0.08)
		bounce_tween.tween_property(self, "position:y", target_y, 0.12)
		if on_finished.is_valid():
			bounce_tween.tween_callback(on_finished)
	)
