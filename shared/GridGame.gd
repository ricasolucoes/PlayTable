class_name TouchGrid

## Static helper to build a grid of invisible touchable buttons over a 3D board.
##
## Reversi, Damas, Batalha Naval, Campo Minado, Resta Um e Senet used to repeat
## the same loop to build this invisible grid.

static func build_touch_grid(container: Node, rows: int, cols: int, cell_size: Vector2,
		on_cell: Callable, is_cell_enabled: Callable = Callable()) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

	for r in range(rows):
		for c in range(cols):
			var btn := Button.new()
			btn.custom_minimum_size = cell_size
			btn.flat = true
			if is_cell_enabled.is_valid() and not is_cell_enabled.call(r, c):
				btn.disabled = true
			else:
				btn.pressed.connect(on_cell.bind(r, c))
			container.add_child(btn)
