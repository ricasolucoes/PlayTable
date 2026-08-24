extends GutTest

## Ciclo de vida compartilhado — exercita shared/BaseGame.gd e shared/GridGame.gd.
##
## As duas classes nasceram concentrando o que os 16 jogos repetiam: o botao
## voltar tinha 13 copias, o reiniciar 11, o fim de partida 8 e a grade de toque
## 6. Ate aqui elas so eram exercitadas de rabo de olho, pelos testes dos jogos
## que as herdam; estes testes batem nelas direto.


const ENV_3D := preload("res://shared/3d/TabletopEnvironment3D.tscn")


# -------------------------------------------------------------------- dubles

## Conta reinicios em vez de comecar uma partida de verdade.
class ContadorDeReinicio extends BaseGame:
	var reinicios: int = 0

	func _start_new_game() -> void:
		reinicios += 1


## Anota o pedido de voltar sem trocar de cena.
class VoltaAnotada extends BaseGame:
	var voltas: int = 0

	func go_back_to_menu() -> void:
		voltas += 1


## Grade de toque que anota a casa tocada.
class GradeAnotada extends GridGame:
	var toques: Array[Vector2i] = []
	var caixa: GridContainer

	func _init() -> void:
		caixa = GridContainer.new()
		add_child(caixa)

	func _on_cell(r: int, c: int) -> void:
		toques.append(Vector2i(r, c))


func _jogo_com_ui() -> BaseGame:
	var jogo := BaseGame.new()
	add_child_autofree(jogo)
	jogo.status_label = Label.new()
	jogo.add_child(jogo.status_label)
	jogo.btn_restart = Button.new()
	jogo.add_child(jogo.btn_restart)
	jogo.btn_restart.hide()
	return jogo


func _grade() -> GradeAnotada:
	var jogo := GradeAnotada.new()
	add_child_autofree(jogo)
	return jogo


# ---------------------------------------------------------- fim de partida

func test_finish_game_trava_anuncia_e_libera_o_reiniciar() -> void:
	var jogo := _jogo_com_ui()
	assert_false(jogo.game_over, "a partida comeca aberta")
	assert_false(jogo.btn_restart.visible, "o reiniciar comeca escondido")

	jogo.finish_game("Empate! (24 x 24)")

	assert_true(jogo.game_over, "a partida trava")
	assert_eq(jogo.status_label.text, "Empate! (24 x 24)", "o resultado vai para o rotulo")
	assert_true(jogo.btn_restart.visible, "o reiniciar aparece")


func test_finish_game_sem_rotulo_nem_botao_nao_quebra() -> void:
	var jogo := BaseGame.new()
	add_child_autofree(jogo)
	jogo.finish_game("fim", true)
	assert_true(jogo.game_over, "os tres nos sao opcionais: sem eles, sobra travar a partida")


func test_a_mesa_3d_comemora_so_quando_o_jogador_vence() -> void:
	var jogo := _jogo_com_ui()
	var mesa: TabletopEnvironment3D = ENV_3D.instantiate()
	jogo.add_child(mesa)
	jogo.env_3d = mesa

	jogo.finish_game("IA Venceu! (26 x 22)", false)
	assert_false(mesa.win_particles.emitting, "derrota nao solta confete")

	jogo.finish_game("🏆 Você Venceu! (26 x 22)", true)
	assert_true(mesa.win_particles.emitting, "vitoria solta confete")


# ------------------------------------------------------- botoes de comando

func test_os_dois_nomes_do_reiniciar_caem_em_start_new_game() -> void:
	var jogo := ContadorDeReinicio.new()
	add_child_autofree(jogo)

	jogo._on_btn_restart_pressed()
	assert_eq(jogo.reinicios, 1, "_on_btn_restart_pressed, ligado em 11 cenas")

	jogo._on_restart_pressed()
	assert_eq(jogo.reinicios, 2, "_on_restart_pressed, ligado em 3 cenas")


func test_os_dois_nomes_do_voltar_caem_em_go_back_to_menu() -> void:
	var jogo := VoltaAnotada.new()
	add_child_autofree(jogo)

	jogo._on_btn_back_pressed()
	jogo._on_back_pressed()

	assert_eq(jogo.voltas, 2, "as duas ligacoes de cena chegam no mesmo lugar")


func test_o_menu_padrao_e_o_de_tabuleiro() -> void:
	var jogo := BaseGame.new()
	add_child_autofree(jogo)
	assert_eq(jogo.menu_scene_path, BaseGame.MENU_TABULEIRO,
		"11 dos 16 jogos nao precisam declarar nada")


func test_set_status_ignora_texto_vazio() -> void:
	var jogo := _jogo_com_ui()
	jogo.status_label.text = "Vez da IA..."
	jogo.set_status("")
	assert_eq(jogo.status_label.text, "Vez da IA...", "texto vazio nao apaga o rotulo")


func test_set_status_sem_rotulo_nao_quebra() -> void:
	var jogo := BaseGame.new()
	add_child_autofree(jogo)
	jogo.set_status("Sua vez!")
	pass_test("um jogo sem rotulo de status apenas ignora a mensagem")


# ----------------------------------------------------------- grade de toque

func test_a_grade_cria_uma_celula_por_casa() -> void:
	var jogo := _grade()
	jogo.build_touch_grid(jogo.caixa, 3, 10, Vector2(34, 38), jogo._on_cell)

	assert_eq(jogo.caixa.get_child_count(), 30, "o tabuleiro do Senet tem 3 x 10 casas")
	for celula in jogo.caixa.get_children():
		var botao := celula as Button
		assert_not_null(botao, "toda celula e um Button")
		assert_eq(botao.custom_minimum_size, Vector2(34, 38), "com o tamanho pedido")
		assert_true(botao.flat, "e transparente, para o tabuleiro 3D aparecer embaixo")


func test_o_toque_entrega_linha_e_coluna() -> void:
	var jogo := _grade()
	jogo.build_touch_grid(jogo.caixa, 8, 8, Vector2(40, 40), jogo._on_cell)

	(jogo.caixa.get_child(0) as Button).pressed.emit()
	(jogo.caixa.get_child(2 * 8 + 5) as Button).pressed.emit()

	assert_eq(jogo.toques, [Vector2i(0, 0), Vector2i(2, 5)] as Array[Vector2i],
		"o jogo recebe (linha, coluna), nao o indice do filho")


func test_as_casas_que_nao_existem_ficam_desligadas() -> void:
	var jogo := _grade()
	jogo.build_touch_grid(jogo.caixa, 7, 7, Vector2(44, 44), jogo._on_cell,
		PegSolitaireRules.is_valid_cell)

	var desligadas := 0
	for celula in jogo.caixa.get_children():
		if (celula as Button).disabled:
			desligadas += 1
	assert_eq(desligadas, 16, "os quatro cantos 2 x 2 fora da cruz do Resta Um")

	(jogo.caixa.get_child(0) as Button).pressed.emit()
	assert_eq(jogo.toques, [] as Array[Vector2i], "casa desligada nem chega a ser ligada ao jogo")


func test_remontar_a_grade_nao_empilha_botoes() -> void:
	var jogo := _grade()
	jogo.build_touch_grid(jogo.caixa, 3, 3, Vector2(10, 10), jogo._on_cell)
	jogo.build_touch_grid(jogo.caixa, 3, 3, Vector2(10, 10), jogo._on_cell)

	assert_eq(jogo.caixa.get_child_count(), 9, "a grade antiga sai da arvore na hora")

	# O queue_free so efetiva no fim do quadro; esperar por ele evita deixar as
	# 9 celulas antigas para tras como orfas.
	await get_tree().process_frame
