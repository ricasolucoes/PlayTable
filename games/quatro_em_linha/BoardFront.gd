@tool
extends Control

## Desenho do tabuleiro do Quatro em Linha. As medidas vêm do ConnectFourLayout
## e as dimensões em casas do ConnectFourRules.

const COLS = ConnectFourRules.COLS
const ROWS = ConnectFourRules.ROWS
const CELL_SIZE = ConnectFourLayout.CELL_SIZE
const HOLE_RADIUS = ConnectFourLayout.HOLE_RADIUS

func _draw() -> void:
	var total_w = COLS * CELL_SIZE
	var total_h = ROWS * CELL_SIZE
	var margin = 14.0
	
	var frame_rect = Rect2(-margin, -margin, total_w + margin * 2, total_h + margin * 2)
	
	# 1. Outer Frame Drop Shadow
	draw_rect(Rect2(frame_rect.position + Vector2(0, 10), frame_rect.size), Color(0, 0, 0, 0.45), false, 4.0)
	
	# 2. Outer Border Bevels (Deep Blue Deluxe Molded Plastic)
	var blue_base = Color(0.10, 0.36, 0.78, 1.0)
	var blue_highlight = Color(0.28, 0.58, 0.98, 1.0)
	var blue_dark = Color(0.05, 0.18, 0.42, 1.0)
	
	# Outer border bands
	draw_rect(Rect2(-margin, -margin, total_w + margin * 2, margin), blue_base, true)
	draw_rect(Rect2(-margin, total_h, total_w + margin * 2, margin + 6.0), blue_base, true)
	draw_rect(Rect2(-margin, -margin, margin, total_h + margin * 2), blue_base, true)
	draw_rect(Rect2(total_w, -margin, margin, total_h + margin * 2), blue_base, true)
	
	# Frame bevel strokes
	draw_line(Vector2(-margin, -margin), Vector2(total_w + margin, -margin), blue_highlight, 3.0)
	draw_line(Vector2(-margin, -margin), Vector2(-margin, total_h + margin), blue_highlight, 3.0)
	draw_line(Vector2(total_w + margin, -margin), Vector2(total_w + margin, total_h + margin), blue_dark, 3.0)
	draw_line(Vector2(-margin, total_h + margin), Vector2(total_w + margin, total_h + margin), blue_dark, 4.0)
	
	# 3. Column & Row Grid Dividers
	for c in range(1, COLS):
		var x = c * CELL_SIZE
		draw_line(Vector2(x, 0), Vector2(x, total_h), blue_dark, 4.0)
		draw_line(Vector2(x - 1, 0), Vector2(x - 1, total_h), blue_highlight, 1.5)
		
	for r in range(1, ROWS):
		var y = r * CELL_SIZE
		draw_line(Vector2(0, y), Vector2(total_w, y), blue_dark, 3.0)
		draw_line(Vector2(0, y - 1), Vector2(total_w, y - 1), blue_highlight, 1.0)
		
	# 4. Socket Rim Rings (Frame rings around each cell)
	for c in range(COLS):
		for r in range(ROWS):
			var center = Vector2(c * CELL_SIZE + (CELL_SIZE * 0.5), r * CELL_SIZE + (CELL_SIZE * 0.5))
			# Bottom highlight lip
			draw_arc(center, HOLE_RADIUS + 1.0, 0.1 * PI, 0.9 * PI, 24, Color(0.4, 0.7, 1.0, 0.6), 2.5, true)
			# Top shadow lip
			draw_arc(center, HOLE_RADIUS + 0.5, 1.1 * PI, 1.9 * PI, 24, Color(0.02, 0.08, 0.2, 0.8), 2.5, true)

	# 5. Metallic Rivets on 4 corners & side supports
	var rivets = [
		Vector2(-margin * 0.5, -margin * 0.5),
		Vector2(total_w + margin * 0.5, -margin * 0.5),
		Vector2(total_w + margin * 0.5, total_h + margin * 0.5),
		Vector2(-margin * 0.5, total_h + margin * 0.5),
		Vector2(-margin * 0.5, total_h * 0.5),
		Vector2(total_w + margin * 0.5, total_h * 0.5)
	]
	for p in rivets:
		draw_circle(p, 5.0, Color(0.65, 0.72, 0.82))
		draw_circle(p + Vector2(-1, -1), 3.0, Color(0.85, 0.90, 0.96))
		draw_line(p - Vector2(2, 0), p + Vector2(2, 0), Color(0.35, 0.40, 0.48), 1.0)
