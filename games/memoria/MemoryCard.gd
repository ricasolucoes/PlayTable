@tool
extends Control

## Helper class for Memoria.

signal card_clicked(card)

enum CardSymbol {
	CROWN,
	RUBY,
	EMERALD,
	SHIELD,
	STAR,
	CHEST,
	CLOVER,
	KEY
}

@export var symbol_type: CardSymbol = CardSymbol.CROWN:
	set(value):
		symbol_type = value
		queue_redraw()

@export var is_face_up: bool = false:
	set(value):
		is_face_up = value
		queue_redraw()

@export var is_matched: bool = false:
	set(value):
		is_matched = value
		queue_redraw()

var is_animating: bool = false
var glow_pulse: float = 0.0

func _process(delta) -> void:
	if is_matched:
		glow_pulse += delta * 4.0
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(130, 175)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_animating and not is_face_up and not is_matched:
			card_clicked.emit(self)

func flip(face_up: bool, on_complete: Callable = Callable()):
	if is_face_up == face_up or is_animating:
		if on_complete.is_valid(): on_complete.call()
		return
		
	is_animating = true
	var pivot_x = size.x * 0.5
	pivot_offset = Vector2(pivot_x, size.y * 0.5)
	
	var tw = get_tree().create_tween()
	tw.tween_property(self, "scale:x", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		is_face_up = face_up
		if AudioManager: AudioManager.play_card_flip()
	)
	tw.tween_property(self, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		is_animating = false
		if on_complete.is_valid(): on_complete.call()
	)

func play_match_animation() -> void:
	is_matched = true
	set_process(true)
	var tw = get_tree().create_tween()
	tw.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func play_mismatch_shake() -> void:
	var orig_x = position.x
	var tw = get_tree().create_tween()
	tw.tween_property(self, "position:x", orig_x - 8.0, 0.05)
	tw.tween_property(self, "position:x", orig_x + 8.0, 0.05)
	tw.tween_property(self, "position:x", orig_x - 6.0, 0.05)
	tw.tween_property(self, "position:x", orig_x, 0.05)

func _draw() -> void:
	var w = size.x
	var h = size.y
	var card_rect = Rect2(Vector2.ZERO, size)
	
	# 1. Soft Drop Shadow
	draw_rect(Rect2(Vector2(0, 6), size), Color(0, 0, 0, 0.4), true)
	
	# 2. Matched Golden Aura
	if is_matched:
		var p = 0.5 + 0.5 * sin(glow_pulse)
		var aura_c = Color(1.0, 0.85, 0.25, 0.6 * p)
		draw_rect(Rect2(-6, -6, w + 12, h + 12), aura_c, false, 4.0)
	
	if not is_face_up:
		_draw_card_back(w, h)
	else:
		_draw_card_front(w, h)

func _draw_card_back(w: float, h: float) -> void:
	# Ivory border
	draw_rect(Rect2(0, 0, w, h), Color(0.96, 0.94, 0.90), true)
	
	# Deep Royal Blue velvet inner rect
	var inset = 8.0
	var inner_rect = Rect2(inset, inset, w - inset * 2, h - inset * 2)
	draw_rect(inner_rect, Color(0.08, 0.16, 0.38), true)
	
	# Gold filigree border
	var gold = Color(0.88, 0.72, 0.32, 0.85)
	draw_rect(Rect2(inset + 3, inset + 3, w - (inset + 3) * 2, h - (inset + 3) * 2), gold, false, 1.5)
	
	# Victorian diamond lattice pattern
	var center = Vector2(w * 0.5, h * 0.5)
	var dia_size = 28.0
	var dia_pts = [
		center + Vector2(0, -dia_size),
		center + Vector2(dia_size * 0.7, 0),
		center + Vector2(0, dia_size),
		center + Vector2(-dia_size * 0.7, 0)
	]
	draw_colored_polygon(dia_pts, gold)
	
	# Center starlet
	draw_circle(center, 6.0, Color(0.98, 0.90, 0.60))
	draw_circle(center, 3.0, Color(0.08, 0.16, 0.38))
	
	# Corner gold ornaments
	var c_offsets = [
		Vector2(inset + 8, inset + 8),
		Vector2(w - inset - 8, inset + 8),
		Vector2(w - inset - 8, h - inset - 8),
		Vector2(inset + 8, h - inset - 8)
	]
	for cp in c_offsets:
		draw_circle(cp, 3.0, gold)

func _draw_card_front(w: float, h: float) -> void:
	# Ivory / Pearl Card Face
	draw_rect(Rect2(0, 0, w, h), Color(0.98, 0.97, 0.94), true)
	
	# Elegant Inset Frame
	var inset = 6.0
	var gold_trim = Color(0.78, 0.64, 0.32, 0.6)
	draw_rect(Rect2(inset, inset, w - inset * 2, h - inset * 2), gold_trim, false, 1.5)
	
	# Center Icon Background Medallion
	var center = Vector2(w * 0.5, h * 0.5)
	draw_circle(center + Vector2(0, 2), 44.0, Color(0.0, 0.0, 0.0, 0.06))
	draw_circle(center, 42.0, Color(0.92, 0.90, 0.85))
	draw_circle(center, 40.0, Color(0.96, 0.95, 0.92))
	draw_arc(center, 40.0, 0, TAU, 32, gold_trim, 1.2, true)
	
	# Draw specific symbol
	match symbol_type:
		CardSymbol.CROWN:
			_draw_crown(center)
		CardSymbol.RUBY:
			_draw_ruby(center)
		CardSymbol.EMERALD:
			_draw_emerald(center)
		CardSymbol.SHIELD:
			_draw_shield(center)
		CardSymbol.STAR:
			_draw_star(center)
		CardSymbol.CHEST:
			_draw_chest(center)
		CardSymbol.CLOVER:
			_draw_clover(center)
		CardSymbol.KEY:
			_draw_key(center)

func _draw_crown(c: Vector2) -> void:
	var pts = [
		c + Vector2(-24, 14),
		c + Vector2(-24, -8),
		c + Vector2(-12, 2),
		c + Vector2(0, -14),
		c + Vector2(12, 2),
		c + Vector2(24, -8),
		c + Vector2(24, 14)
	]
	draw_colored_polygon(pts, Color(0.96, 0.78, 0.15))
	# Bottom band
	draw_rect(Rect2(c.x - 24, c.y + 10, 48, 6), Color(0.80, 0.58, 0.08), true)
	# Ruby jewels on tips
	draw_circle(c + Vector2(-24, -8), 3.5, Color(0.9, 0.15, 0.15))
	draw_circle(c + Vector2(0, -14), 4.5, Color(0.9, 0.15, 0.15))
	draw_circle(c + Vector2(24, -8), 3.5, Color(0.9, 0.15, 0.15))

func _draw_ruby(c: Vector2) -> void:
	var top = [
		c + Vector2(-16, -14),
		c + Vector2(16, -14),
		c + Vector2(24, -2),
		c + Vector2(-24, -2)
	]
	var bot = [
		c + Vector2(-24, -2),
		c + Vector2(24, -2),
		c + Vector2(0, 22)
	]
	draw_colored_polygon(top, Color(1.0, 0.35, 0.35))
	draw_colored_polygon(bot, Color(0.85, 0.10, 0.15))
	draw_line(c + Vector2(-8, -14), c + Vector2(0, 22), Color(1.0, 0.6, 0.6, 0.8), 1.5)
	draw_line(c + Vector2(8, -14), c + Vector2(0, 22), Color(0.6, 0.05, 0.1, 0.8), 1.5)

func _draw_emerald(c: Vector2) -> void:
	var pts = [
		c + Vector2(-12, -20),
		c + Vector2(12, -20),
		c + Vector2(22, 0),
		c + Vector2(12, 20),
		c + Vector2(-12, 20),
		c + Vector2(-22, 0)
	]
	draw_colored_polygon(pts, Color(0.12, 0.82, 0.42))
	# Inner table facet
	var inner = [
		c + Vector2(-8, -12),
		c + Vector2(8, -12),
		c + Vector2(14, 0),
		c + Vector2(8, 12),
		c + Vector2(-8, 12),
		c + Vector2(-14, 0)
	]
	draw_colored_polygon(inner, Color(0.35, 0.95, 0.65))

func _draw_shield(c: Vector2) -> void:
	var pts = [
		c + Vector2(-20, -18),
		c + Vector2(20, -18),
		c + Vector2(20, 4),
		c + Vector2(0, 22),
		c + Vector2(-20, 4)
	]
	draw_colored_polygon(pts, Color(0.20, 0.45, 0.85))
	# Gold cross
	draw_rect(Rect2(c.x - 4, c.y - 18, 8, 38), Color(0.95, 0.80, 0.20), true)
	draw_rect(Rect2(c.x - 18, c.y - 6, 36, 8), Color(0.95, 0.80, 0.20), true)

func _draw_star(c: Vector2) -> void:
	var r_out = 22.0
	var r_in = 9.0
	var pts: PackedVector2Array = []
	for i in range(10):
		var angle = -PI * 0.5 + float(i) * PI / 5.0
		var r = r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(pts, Color(0.98, 0.82, 0.12))
	# Core highlight
	draw_circle(c, 5.0, Color(1.0, 1.0, 0.8))

func _draw_chest(c: Vector2) -> void:
	# Base chest
	draw_rect(Rect2(c.x - 22, c.y - 6, 44, 24), Color(0.52, 0.28, 0.12), true)
	# Dome lid
	draw_rect(Rect2(c.x - 22, c.y - 18, 44, 12), Color(0.65, 0.36, 0.16), true)
	# Gold bands
	draw_rect(Rect2(c.x - 14, c.y - 18, 6, 36), Color(0.95, 0.80, 0.20), true)
	draw_rect(Rect2(c.x + 8, c.y - 18, 6, 36), Color(0.95, 0.80, 0.20), true)
	# Keyhole
	draw_circle(c + Vector2(0, 2), 4.0, Color(0.2, 0.15, 0.05))

func _draw_clover(c: Vector2) -> void:
	var leaf_c = Color(0.18, 0.78, 0.28)
	var leaf_r = 10.0
	var offsets = [Vector2(0, -10), Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0)]
	for off in offsets:
		draw_circle(c + off, leaf_r, leaf_c)
	# Stem
	draw_line(c, c + Vector2(8, 20), Color(0.12, 0.55, 0.18), 3.0)

func _draw_key(c: Vector2) -> void:
	var key_c = Color(0.92, 0.74, 0.22)
	# Ring top
	draw_circle(c + Vector2(0, -12), 10.0, key_c)
	draw_circle(c + Vector2(0, -12), 5.0, Color(0.96, 0.95, 0.92))
	# Shaft
	draw_rect(Rect2(c.x - 2.5, c.y - 3, 5, 24), key_c, true)
	# Teeth
	draw_rect(Rect2(c.x + 2.5, c.y + 11, 8, 4), key_c, true)
	draw_rect(Rect2(c.x + 2.5, c.y + 17, 6, 4), key_c, true)
