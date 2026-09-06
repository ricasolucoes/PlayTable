extends GutTest

const CENA := preload("res://games/sudoku/SudokuGame.tscn")

func test_celula_fixa_volta_a_ser_editavel_na_proxima_partida() -> void:
	var jogo: SudokuGame = add_child_autofree(CENA.instantiate())
	var cell: SudokuCell = jogo.cells_2d[0][0]
	cell.set_fixed_value(5)
	assert_true(cell.disabled)
	cell.is_fixed = false
	cell.set_user_value(0)
	assert_false(cell.disabled)
	cell.pressed.emit()
	assert_same(jogo.selected_cell, cell)
	jogo._on_numpad_pressed(4)
	assert_eq(cell.value, 4)

func test_reiniciar_reabilita_todas_as_casas_vazias() -> void:
	var jogo: SudokuGame = add_child_autofree(CENA.instantiate())
	for row in jogo.cells_2d:
		for cell in row:
			cell.set_fixed_value(1)
	jogo.restart_game()
	var vazias := 0
	for row in jogo.cells_2d:
		for cell in row:
			if not cell.is_fixed:
				vazias += 1
				assert_false(cell.disabled)
	assert_gt(vazias, 0)

func test_anotacoes_ficam_abaixo_da_barra_e_acima_do_tabuleiro() -> void:
	var jogo: SudokuGame = add_child_autofree(CENA.instantiate())
	await wait_process_frames(3)
	assert_false(jogo.btn_notes.get_global_rect().intersects(jogo.top_bar.get_global_rect()))
	assert_false(jogo.btn_notes.get_global_rect().intersects(jogo.main_grid.get_global_rect()))
	jogo.btn_notes.button_pressed = true
	assert_true(jogo.notes_mode)
