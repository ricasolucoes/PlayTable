@tool
extends Node2D

enum PieceType { EMPTY, X_PIECE, O_PIECE }

@export var piece_type: PieceType = PieceType.EMPTY:
	set(value):
		piece_type = value
		queue_redraw()

@export var size: float = 130.0:
	set(value):
		size = value
		queue_redraw()

var is_winning: bool = false
var glow_t: float = 0.0

func _process(delta):
	if is_winning:
		glow_t += delta * 5.0
		queue_redraw()

func set_winning(win: bool):
	is_winning = win
	set_process(win)
	queue_redraw()

func _draw():
	if piece_type == PieceType.EMPTY:
		return
		
	var hs = size * 0.5
	
	if piece_type == PieceType.X_PIECE:
		_draw_realistic_x(hs)
	elif piece_type == PieceType.O_PIECE:
		_draw_realistic_o(hs)

func _draw_realistic_x(hs: float):
	var arm_len = hs * 0.72
	var thickness = hs * 0.32
	
	var base_red = Color(0.88, 0.16, 0.18)
	var dark_red = Color(0.48, 0.06, 0.08)
	var light_red = Color(1.0, 0.45, 0.45)
	
	# Winning Glow
	if is_winning:
		var pulse = 0.5 + 0.5 * sin(glow_t)
		var glow_c = Color(1.0, 0.9, 0.2, 0.7 * pulse)
		draw_line(Vector2(-arm_len, -arm_len), Vector2(arm_len, arm_len), glow_c, thickness + 16.0)
		draw_line(Vector2(-arm_len, arm_len), Vector2(arm_len, -arm_len), glow_c, thickness + 16.0)

	# 1. Soft Drop Shadow
	var shadow_offset = Vector2(0, 6)
	draw_line(Vector2(-arm_len, -arm_len) + shadow_offset, Vector2(arm_len, arm_len) + shadow_offset, Color(0, 0, 0, 0.4), thickness + 4.0)
	draw_line(Vector2(-arm_len, arm_len) + shadow_offset, Vector2(arm_len, -arm_len) + shadow_offset, Color(0, 0, 0, 0.4), thickness + 4.0)
	
	# 2. Dark Bevel Base
	draw_line(Vector2(-arm_len, -arm_len), Vector2(arm_len, arm_len), dark_red, thickness + 2.0)
	draw_line(Vector2(-arm_len, arm_len), Vector2(arm_len, -arm_len), dark_red, thickness + 2.0)
	
	# 3. Main Carmine Cross Body
	draw_line(Vector2(-arm_len, -arm_len), Vector2(arm_len, arm_len), base_red, thickness)
	draw_line(Vector2(-arm_len, arm_len), Vector2(arm_len, -arm_len), base_red, thickness)
	
	# 4. Top Bevel Specular Highlights
	draw_line(Vector2(-arm_len, -arm_len) + Vector2(-1, -1), Vector2(arm_len, arm_len) + Vector2(-1, -1), light_red, thickness * 0.35)
	draw_line(Vector2(-arm_len, arm_len) + Vector2(-1, -1), Vector2(arm_len, -arm_len) + Vector2(-1, -1), light_red, thickness * 0.35)
	
	# 5. Core Central Shine
	draw_circle(Vector2(-4, -4), thickness * 0.45, Color(1.0, 0.8, 0.8, 0.6))
	draw_circle(Vector2(-4, -4), thickness * 0.22, Color(1.0, 1.0, 1.0, 0.8))

func _draw_realistic_o(hs: float):
	var outer_r = hs * 0.72
	var inner_r = hs * 0.38
	var thickness = outer_r - inner_r
	var mid_r = (outer_r + inner_r) * 0.5
	
	var gold_base = Color(0.96, 0.76, 0.16)
	var gold_dark = Color(0.55, 0.38, 0.05)
	var gold_light = Color(1.0, 0.95, 0.60)
	var gold_spec = Color(1.0, 1.0, 0.90)
	
	# Winning Glow
	if is_winning:
		var pulse = 0.5 + 0.5 * sin(glow_t)
		draw_circle(Vector2.ZERO, outer_r + 8.0 + pulse * 6.0, Color(1.0, 0.9, 0.2, 0.6 * pulse))
	
	# 1. Soft Drop Shadow
	draw_arc(Vector2(0, 6), mid_r, 0, TAU, 36, Color(0, 0, 0, 0.4), thickness + 4.0, true)
	
	# 2. Dark Ring Bevel Base
	draw_arc(Vector2.ZERO, mid_r, 0, TAU, 36, gold_dark, thickness + 2.0, true)
	
	# 3. Metallic Gold Torus Body
	draw_arc(Vector2.ZERO, mid_r, 0, TAU, 36, gold_base, thickness, true)
	
	# 4. Top-Left Arc Highlight
	draw_arc(Vector2(-1, -1), mid_r, PI * 0.75, PI * 1.75, 24, gold_light, thickness * 0.45, true)
	
	# 5. Glossy Specular Highlights (Torus reflections)
	draw_arc(Vector2(-1, -1), outer_r - 2.0, PI * 0.9, PI * 1.5, 16, gold_spec, 2.5, true)
	draw_arc(Vector2(1, 1), inner_r + 2.0, PI * 0.9, PI * 1.5, 16, gold_spec, 2.0, true)

func play_spawn_animation():
	scale = Vector2(1.45, 1.45)
	modulate.a = 0.0
	var tw = get_tree().create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.12)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
