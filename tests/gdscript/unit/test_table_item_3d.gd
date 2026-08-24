extends GutTest

## Base compartilhada da mesa — exercita shared/3d/TableItem3D.gd.
##
## Card3D e Token3D convergiram sozinhos: _kill, hover e select eram identicos,
## reject e vanish diferiam so em amplitude, e a sombra de contato era o mesmo
## bloco com outro tamanho de quad. Estes testes batem na base direto e
## conferem que os dois herdeiros continuam respondendo pelo contrato.

const CARD_3D := preload("res://shared/3d/Card3D.tscn")
const TOKEN_3D := preload("res://shared/3d/Token3D.tscn")


## Dublê mínimo: registra o que set_lift recebeu, sem animar nada.
class ElevacaoAnotada extends TableItem3D:
	var pedidos: Array[float] = []

	func set_lift(amount: float, _duration: float = Tokens3D.DUR_FAST) -> void:
		pedidos.append(amount)


func test_hover_e_select_pedem_alturas_diferentes() -> void:
	var item := ElevacaoAnotada.new()
	add_child_autofree(item)
	item.hover(true)
	item.select(true)
	item.hover(false)
	assert_eq(item.pedidos, [Tokens3D.LIFT_HOVER, Tokens3D.LIFT_SELECTED, 0.0] as Array[float],
		"hover e select passam pela mesma set_lift, com alturas proprias")


func test_set_lift_da_base_nao_faz_nada_sem_sobrescrita() -> void:
	var item := TableItem3D.new()
	add_child_autofree(item)
	item.hover(true)
	assert_eq(item.position, Vector3.ZERO, "a base nao decide como cada item sobe")


func test_carta_e_peca_herdam_a_base() -> void:
	var carta: Card3D = add_child_autofree(CARD_3D.instantiate())
	var peca: Token3D = add_child_autofree(TOKEN_3D.instantiate())
	assert_true(carta is TableItem3D, "Card3D herda TableItem3D")
	assert_true(peca is TableItem3D, "Token3D herda TableItem3D")


func test_a_peca_treme_menos_que_a_carta() -> void:
	# Era a unica diferenca entre os dois reject(), e estava escrita duas vezes.
	var carta: Card3D = add_child_autofree(CARD_3D.instantiate())
	var peca: Token3D = add_child_autofree(TOKEN_3D.instantiate())
	assert_gt(carta.reject_shake, peca.reject_shake, "a carta e maior e treme mais")
	assert_gt(carta.reject_settle, peca.reject_settle, "o mesmo vale para o assentamento")


func test_reject_devolve_a_peca_ao_lugar() -> void:
	var peca: Token3D = add_child_autofree(TOKEN_3D.instantiate())
	peca.position = Vector3(1.0, 0.0, 2.0)
	peca.reject()
	await wait_seconds(Tokens3D.DUR_FAST + 0.1)
	assert_almost_eq(peca.position.x, 1.0, 0.001, "o tremor termina onde comecou")


func test_vanish_libera_o_no_ao_fim_da_animacao() -> void:
	var peca: Node = TOKEN_3D.instantiate()
	add_child(peca)
	peca.vanish(true)
	await wait_seconds(Tokens3D.DUR_FAST + 0.2)
	assert_true(!is_instance_valid(peca) or peca.is_queued_for_deletion(),
		"o vanish termina liberando o no")


func test_finish_vanish_esconde_quando_nao_e_para_liberar() -> void:
	# Caminho de duracao zero: Quality3D.duration devolve 0.0 para animacao nao
	# essencial com movimento reduzido, e o vanish tem de resolver na hora.
	var peca: Token3D = add_child_autofree(TOKEN_3D.instantiate())
	peca._finish_vanish(false)
	assert_false(peca.visible, "sem liberar, o objeto so some da tela")
