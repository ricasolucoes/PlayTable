@tool
extends Control

const COLS = 7
const ROWS = 6
const CELL_SIZE = 86.0
const HOLE_RADIUS = 34.0

func _draw():
	var total_w = COLS * CELL_SIZE
	var total_h = ROWS * CELL_SIZE
	var margin = 14.0
	
	# Background plate
	var plate_rect = Rect2(-margin, -margin, total_w + margin * 2, total_h + margin * 2)
	draw_rect(plate_rect, Color(0.04, 0.12, 0.24, 1.0), true)
	
	# Dark recessed socket slots
	for c in range(COLS):
		for r in range(ROWS):
			var center = Vector2(c * CELL_SIZE + (CELL_SIZE * 0.5), r * CELL_SIZE + (CELL_SIZE * 0.5))
			draw_circle(center, HOLE_RADIUS + 1.0, Color(0.02, 0.05, 0.10, 1.0))
			draw_circle(center + Vector2(0, 1), HOLE_RADIUS - 1.0, Color(0.01, 0.03, 0.06, 1.0))
