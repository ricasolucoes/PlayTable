@tool
extends Control

enum ThemeType { MAHOGANY_WOOD, CASINO_FELT, DARK_SLATE }

@export var theme_type: ThemeType = ThemeType.MAHOGANY_WOOD:
	set(value):
		theme_type = value
		queue_redraw()

func _ready():
	queue_redraw()

func _draw():
	var rect = get_rect()
	var w = rect.size.x
	var h = rect.size.y
	var center = Vector2(w * 0.5, h * 0.45)
	var max_radius = sqrt(w * w + h * h) * 0.65
	
	var base_center_color: Color
	var base_edge_color: Color
	var rim_color: Color
	var grain_color: Color
	
	match theme_type:
		ThemeType.MAHOGANY_WOOD:
			base_center_color = Color(0.24, 0.12, 0.07, 1.0) # Warm polished mahogany
			base_edge_color = Color(0.06, 0.03, 0.02, 1.0)   # Deep edge shadow
			rim_color = Color(0.65, 0.48, 0.22, 0.4)         # Warm brass trim
			grain_color = Color(0.32, 0.16, 0.09, 0.12)      # Wood grain
		ThemeType.CASINO_FELT:
			base_center_color = Color(0.08, 0.26, 0.15, 1.0) # Emerald casino felt
			base_edge_color = Color(0.02, 0.07, 0.04, 1.0)   # Deep night felt
			rim_color = Color(0.85, 0.72, 0.35, 0.5)         # Gold pinstripe
			grain_color = Color(0.12, 0.35, 0.20, 0.08)      # Felt texture
		ThemeType.DARK_SLATE:
			base_center_color = Color(0.16, 0.18, 0.22, 1.0)
			base_edge_color = Color(0.05, 0.06, 0.08, 1.0)
			rim_color = Color(0.45, 0.55, 0.70, 0.4)
			grain_color = Color(0.22, 0.25, 0.30, 0.1)

	# 1. Fill base dark
	draw_rect(Rect2(Vector2.ZERO, rect.size), base_edge_color)
	
	# 2. Radial warm spotlight vignette layers
	var rings = 12
	for i in range(rings, 0, -1):
		var t = float(i) / float(rings)
		var r = max_radius * t
		var c = base_edge_color.lerp(base_center_color, pow(1.0 - t, 1.4))
		draw_circle(center, r, c)
	
	# 3. Procedural wood grain / felt texture bands
	if theme_type == ThemeType.MAHOGANY_WOOD:
		for y in range(0, int(h), 8):
			var alpha_mod = sin(float(y) * 0.05) * 0.5 + 0.5
			var c = grain_color
			c.a *= (0.4 + 0.6 * alpha_mod)
			draw_line(Vector2(0, y), Vector2(w, y), c, 3.0)
			# Subtle fine grain
			if y % 24 == 0:
				var dark_grain = Color(0.0, 0.0, 0.0, 0.06)
				draw_line(Vector2(0, y + 2), Vector2(w, y + 2), dark_grain, 1.0)
	elif theme_type == ThemeType.CASINO_FELT:
		# Subtle cross-hatch felt texture
		for step in range(0, int(max(w, h)), 16):
			var c = grain_color
			draw_line(Vector2(step, 0), Vector2(step - 200, h), c, 1.0)
			draw_line(Vector2(0, step), Vector2(w, step + 200), c, 1.0)
			
	# 4. Outer vignette corner shadows
	var shadow_rect = Rect2(Vector2.ZERO, rect.size)
	# Draw luxury double border trim
	var inset1 = 12.0
	var inset2 = 18.0
	draw_rect(Rect2(inset1, inset1, w - inset1 * 2, h - inset1 * 2), rim_color, false, 2.0)
	var thin_rim = rim_color
	thin_rim.a *= 0.5
	draw_rect(Rect2(inset2, inset2, w - inset2 * 2, h - inset2 * 2), thin_rim, false, 1.0)
	
	# Corner corner accents (embossed gold brackets)
	var corner_len = 24.0
	var corners = [
		Vector2(inset1, inset1),
		Vector2(w - inset1, inset1),
		Vector2(w - inset1, h - inset1),
		Vector2(inset1, h - inset1)
	]
	for p in corners:
		draw_circle(p, 3.0, rim_color)
