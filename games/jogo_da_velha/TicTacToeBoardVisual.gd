@tool
extends Control

const BOARD_SIZE = 520.0
const CELL_SIZE = 160.0
const GAP = 12.0

func _draw():
	var total_w = 3 * CELL_SIZE + 2 * GAP
	var total_h = total_w
	var offset = Vector2(-total_w * 0.5, -total_h * 0.5)
	
	# 1. Deep Board Drop Shadow
	var shadow_rect = Rect2(offset + Vector2(0, 12), Vector2(total_w + 32, total_h + 32))
	draw_rect(shadow_rect, Color(0, 0, 0, 0.45), true)
	
	# 2. Carved Wood Slab Base
	var slab_margin = 16.0
	var slab_rect = Rect2(offset - Vector2(slab_margin, slab_margin), Vector2(total_w + slab_margin * 2, total_h + slab_margin * 2))
	var wood_base = Color(0.22, 0.12, 0.07, 1.0)
	var wood_light = Color(0.38, 0.22, 0.14, 1.0)
	var wood_dark = Color(0.12, 0.06, 0.03, 1.0)
	var gold_rim = Color(0.75, 0.58, 0.25, 0.7)
	
	draw_rect(slab_rect, wood_dark, true)
	draw_rect(Rect2(slab_rect.position + Vector2(3, 3), slab_rect.size - Vector2(6, 6)), wood_base, true)
	
	# Top and left highlight edges
	draw_line(slab_rect.position + Vector2(4, 3), slab_rect.position + Vector2(slab_rect.size.x - 4, 3), wood_light, 3.0)
	draw_line(slab_rect.position + Vector2(3, 4), slab_rect.position + Vector2(3, slab_rect.size.y - 4), wood_light, 3.0)
	# Gold border line
	draw_rect(Rect2(slab_rect.position + Vector2(6, 6), slab_rect.size - Vector2(12, 12)), gold_rim, false, 1.5)
	
	# 3. Recessed 3x3 Sockets
	for col in range(3):
		for row in range(3):
			var x = offset.x + col * (CELL_SIZE + GAP)
			var y = offset.y + row * (CELL_SIZE + GAP)
			var cell_rect = Rect2(x, y, CELL_SIZE, CELL_SIZE)
			
			# Recessed inner cell background
			draw_rect(cell_rect, Color(0.14, 0.08, 0.04, 0.95), true)
			
			# Cell top/left inner shadow
			draw_line(cell_rect.position, cell_rect.position + Vector2(CELL_SIZE, 0), Color(0.05, 0.02, 0.01, 0.8), 2.0)
			draw_line(cell_rect.position, cell_rect.position + Vector2(0, CELL_SIZE), Color(0.05, 0.02, 0.01, 0.8), 2.0)
			
			# Cell bottom/right inner highlight
			draw_line(cell_rect.position + Vector2(0, CELL_SIZE), cell_rect.position + Vector2(CELL_SIZE, CELL_SIZE), Color(0.40, 0.25, 0.15, 0.4), 1.5)
			draw_line(cell_rect.position + Vector2(CELL_SIZE, 0), cell_rect.position + Vector2(CELL_SIZE, CELL_SIZE), Color(0.40, 0.25, 0.15, 0.4), 1.5)
			
			# Inlaid gold corner pins
			draw_circle(cell_rect.position + Vector2(6, 6), 2.5, Color(0.85, 0.72, 0.35, 0.6))
			draw_circle(cell_rect.position + Vector2(CELL_SIZE - 6, 6), 2.5, Color(0.85, 0.72, 0.35, 0.6))
			draw_circle(cell_rect.position + Vector2(CELL_SIZE - 6, CELL_SIZE - 6), 2.5, Color(0.85, 0.72, 0.35, 0.6))
			draw_circle(cell_rect.position + Vector2(6, CELL_SIZE - 6), 2.5, Color(0.85, 0.72, 0.35, 0.6))
