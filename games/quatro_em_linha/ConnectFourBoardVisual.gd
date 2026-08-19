@tool
extends Control

## Helper class for Quatro Em Linha.

@export var cols: int = 7
@export var rows: int = 6
@export var cell_size: float = 80.0
@export var hole_radius: float = 32.0

func _draw() -> void:
	var total_w = cols * cell_size
	var total_h = rows * cell_size
	var frame_margin = 16.0
	var board_rect = Rect2(-frame_margin, -frame_margin, total_w + frame_margin * 2, total_h + frame_margin * 2)
	
	# 1. Soft Board Drop Shadow
	draw_rect(Rect2(board_rect.position + Vector2(0, 10), board_rect.size), Color(0, 0, 0, 0.45), true, -1, false)
	
	# 2. Main Blue Beveled Body
	var body_color = Color(0.10, 0.36, 0.76)
	var body_dark = Color(0.06, 0.22, 0.50)
	var body_light = Color(0.24, 0.52, 0.95)
	
	# Outer casing with rounded corners (using stylebox or drawn primitives)
	draw_rect(board_rect, body_dark, true)
	draw_rect(Rect2(board_rect.position + Vector2(3, 3), board_rect.size - Vector2(6, 6)), body_color, true)
	
	# 3. Top and Side Bevel Highlight
	draw_line(board_rect.position + Vector2(4, 3), board_rect.position + Vector2(board_rect.size.x - 4, 3), body_light, 3.0)
	draw_line(board_rect.position + Vector2(3, 4), board_rect.position + Vector2(3, board_rect.size.y - 4), body_light, 3.0)
	
	# 4. Corner Fastener Screws (Metallic rivets)
	var screw_positions = [
		board_rect.position + Vector2(10, 10),
		board_rect.position + Vector2(board_rect.size.x - 10, 10),
		board_rect.position + Vector2(board_rect.size.x - 10, board_rect.size.y - 10),
		board_rect.position + Vector2(10, board_rect.size.y - 10)
	]
	for p in screw_positions:
		draw_circle(p, 5.0, Color(0.7, 0.75, 0.82))
		draw_circle(p, 4.0, Color(0.85, 0.88, 0.92))
		draw_line(p - Vector2(2, 0), p + Vector2(2, 0), Color(0.4, 0.45, 0.5), 1.2)
	
	# 5. Column Slot Cutouts (Realistic recessed holes)
	for c in range(cols):
		for r in range(rows):
			var center = Vector2(c * cell_size + cell_size * 0.5, r * cell_size + cell_size * 0.5)
			
			# Outer hole shadow (cylinder depth)
			draw_circle(center + Vector2(0, -1), hole_radius + 2.0, Color(0.04, 0.14, 0.32, 0.9))
			
			# Cutout hole opening (transparent black depth)
			draw_circle(center, hole_radius, Color(0.03, 0.08, 0.16, 0.95))
			
			# Bottom lip highlight (reflection of table light on lower curve of hole)
			draw_arc(center, hole_radius + 0.5, 0.1 * PI, 0.9 * PI, 24, Color(0.35, 0.65, 1.0, 0.45), 2.0, true)
			
			# Top inner rim shadow
			draw_arc(center, hole_radius - 1.0, 1.1 * PI, 1.9 * PI, 24, Color(0.0, 0.0, 0.0, 0.6), 2.5, true)
