extends GutTest

## Os pontos do dado e da pedra de domino.
##
## Dois defeitos motivaram estes testes, e os dois passavam despercebidos porque
## o no estava montado e no lugar certo -- so nao aparecia nada na tela:
##
##  1. A base de cada face saia espelhada (determinante -1). A malha do ponto
##     renderizava com a face virada para dentro e o backface culling comia os
##     21 pontos: o dado do Gamao continuava um cubo branco liso.
##  2. O arranjo dos pontos e o inverso de Dice3D.FACE_ROTATIONS. Mexer num sem
##     mexer no outro faz o dado parar mostrando um valor e imprimir outro.

const EPS := 0.0001


func test_toda_base_de_face_e_destra() -> void:
	# Determinante negativo = malha espelhada = ponto invisivel.
	for normal in PipFactory3D.DICE_FACES:
		var base: Basis = PipFactory3D._face_basis(normal)
		assert_almost_eq(base.determinant(), 1.0, EPS,
			"a base da face %s tem de ser destra" % normal)
		assert_almost_eq(base.y.dot(normal), 1.0, EPS,
			"o Y da base aponta para fora da face %s" % normal)


func test_a_face_que_para_para_cima_e_a_que_mostra_o_valor() -> void:
	for valor in range(1, 7):
		var rot: Vector3 = Dice3D.FACE_ROTATIONS[valor]
		var base := Basis.from_euler(rot)
		var impresso := -1
		for normal in PipFactory3D.DICE_FACES:
			if (base * normal).dot(Vector3.UP) > 0.99:
				impresso = PipFactory3D.DICE_FACES[normal]
		assert_eq(impresso, valor,
			"rolar %d tem de deixar para cima a face com %d pontos" % [valor, valor])


func test_faces_opostas_somam_sete() -> void:
	for normal in PipFactory3D.DICE_FACES:
		var oposta: int = PipFactory3D.DICE_FACES[-normal]
		assert_eq(PipFactory3D.DICE_FACES[normal] + oposta, 7,
			"faces opostas de um dado somam sete")


func test_o_dado_tem_vinte_e_um_pontos() -> void:
	assert_eq(PipFactory3D.dice_pip_transforms(0.5).size(), 21, "1+2+3+4+5+6")
	var pips := PipFactory3D.dice_pips(0.5)
	assert_not_null(pips.material_override, "os pontos tem material proprio")
	pips.free()


func test_os_pontos_do_dado_sobram_da_face() -> void:
	# Afundados demais, a calota nao aparece e o dado volta a parecer liso.
	var lado := 0.5
	var maior := 0.0
	for t in PipFactory3D.dice_pip_transforms(lado):
		maior = maxf(maior, t.origin.length())
	assert_gt(maior, lado * 0.5 * 0.85, "o ponto fica encostado na face, nao no miolo")


func test_a_pedra_de_domino_tem_os_pontos_das_duas_metades() -> void:
	for par in [[0, 0, 0], [3, 4, 7], [6, 6, 12], [0, 5, 5]]:
		var t := PipFactory3D.domino_pip_transforms(par[0], par[1], 0.82, 0.41, 0.12)
		assert_eq(t.size(), par[2], "pedra [%d|%d] tem %d pontos" % par)


func test_as_metades_da_pedra_ficam_em_lados_opostos() -> void:
	# `a` na metade -Z e `b` na +Z: trocadas, a pedra mostra o valor invertido.
	var em_a := 0
	var em_b := 0
	for t in PipFactory3D.domino_pip_transforms(1, 6, 0.82, 0.41, 0.12):
		if t.origin.z < 0.0:
			em_a += 1
		else:
			em_b += 1
	assert_eq(em_a, 1, "a metade `a` tem 1 ponto")
	assert_eq(em_b, 6, "a metade `b` tem 6 pontos")
