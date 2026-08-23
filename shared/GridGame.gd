class_name GridGame
extends BaseGame

## Jogos cujo tabuleiro é uma grade de células tocáveis sobre a cena 3D.
##
## Reversi, Damas, Batalha Naval, Campo Minado, Resta Um e Senet repetiam o
## mesmo laço para montar a grade invisível de botões que recebe o toque,
## trocando só o tamanho da célula e o alcance do laço.
##
## O corte não é "tabuleiro × cartas": Mancala, Ludo e Dominó são de tabuleiro e
## não têm grade, então herdam direto de `BaseGame`.


## Monta a grade de botões transparentes que capta o toque sobre o tabuleiro 3D.
##
## `on_cell` recebe `(linha, coluna)`. `is_cell_enabled` também recebe
## `(linha, coluna)` e, quando informado, desliga as casas que não existem no
## tabuleiro — o Resta Um deixa de fora 16 dos 49 quadrados.
func build_touch_grid(container: Node, rows: int, cols: int, cell_size: Vector2,
		on_cell: Callable, is_cell_enabled: Callable = Callable()) -> void:
	for child in container.get_children():
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
