class_name GeneralAI
extends RefCounted

## A maquina do General: valor esperado simplificado, sem busca.
##
## Tres perguntas, todas estaticas e sem estado: o que segurar antes da
## proxima rolagem, se vale a pena parar de rolar, e onde gravar. O degrau
## (1..10) entra como chance de errar -- no baixo ela segura o dado errado ou
## grava numa categoria qualquer; no alto ela nunca deixa passar o que a folha
## rende mais.
##
## O que ela persegue, em ordem: cinco iguais (General), quatro (Quadra), a
## trinca que vira uma das duas, a sequencia aberta, o par. Com folha vazia e
## dados soltos, guarda os altos para os Seis e os Cincos.

## Chance de errar por degrau: 45% no primeiro, zero no decimo.
static func chance_de_erro(nivel: int) -> float:
	return clampf(0.5 - 0.05 * float(nivel), 0.0, 0.45)


static func _sorteio(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()


static func _erra(nivel: int, rng: RandomNumberGenerator) -> bool:
	return _sorteio(rng) < chance_de_erro(nivel)


## Quais dados segurar (um bool por dado) antes de rolar de novo.
static func choose_holds(dados: Array, folha: Dictionary, nivel: int,
		rng: RandomNumberGenerator = null) -> Array[bool]:
	var presos: Array[bool] = []
	presos.resize(GeneralRules.DADOS)
	presos.fill(false)
	if _erra(nivel, rng):
		# O iniciante que guarda o 2 e solta o par de 6.
		for i in GeneralRules.DADOS:
			presos[i] = _sorteio(rng) < 0.5
		return presos
	for i in alvos_de_guarda(dados, folha):
		presos[i] = true
	return presos


## Os indices que a jogada certa segura. Publico para a suite conferir a
## heuristica sem o ruido do degrau.
static func alvos_de_guarda(dados: Array, folha: Dictionary) -> Array[int]:
	var cont := GeneralRules.contagem(dados)
	var valor_top := 0
	var repeticao_top := 0
	# Do 6 para o 1: em empate de repeticao, o valor alto vale mais nos numeros.
	for v in range(6, 0, -1):
		if cont[v] > repeticao_top:
			repeticao_top = cont[v]
			valor_top = v

	if repeticao_top >= 5:
		return _indices_de(dados, [1, 2, 3, 4, 5, 6])

	# Sequencia aberta (quatro seguidos) com a Sequencia livre: vale mais que
	# um par, e so uma trinca a supera.
	if repeticao_top <= 2 and GeneralRules.esta_livre(folha, "sequencia"):
		var corrida := maior_corrida(dados)
		if corrida.size() >= 4:
			return _um_de_cada(dados, corrida)

	if repeticao_top >= 3:
		var alvo := _indices_de(dados, [valor_top])
		# Trinca + par com o Full livre: segura os cinco, esta feito.
		if repeticao_top == 3 and GeneralRules.esta_livre(folha, "full"):
			for v in range(1, 7):
				if v != valor_top and cont[v] == 2:
					alvo.append_array(_indices_de(dados, [v]))
		return alvo

	if repeticao_top == 2:
		var pares: Array[int] = []
		for v in range(6, 0, -1):
			if cont[v] == 2:
				pares.append(v)
		if pares.size() == 2 and GeneralRules.esta_livre(folha, "full"):
			return _indices_de(dados, pares)
		return _indices_de(dados, [valor_top])

	# Tudo solto: tres seguidos com a Sequencia livre, senao os altos cujos
	# numeros ainda estao livres.
	if GeneralRules.esta_livre(folha, "sequencia"):
		var corrida := maior_corrida(dados)
		if corrida.size() >= 3:
			return _um_de_cada(dados, corrida)
	var altos: Array[int] = []
	if GeneralRules.esta_livre(folha, "seis"):
		altos.append(6)
	if GeneralRules.esta_livre(folha, "cinco"):
		altos.append(5)
	return _indices_de(dados, altos)


## Vale parar de rolar e gravar agora? Com uma combinacao feita, sim: uma
## Quadra de mao vale 45, e rolar de novo atras do General (uma chance em
## seis) joga fora o bonus. Sem combinacao, continua ate a terceira.
static func should_stop(dados: Array, folha: Dictionary, rolagem: int, nivel: int,
		rng: RandomNumberGenerator = null) -> bool:
	if rolagem >= GeneralRules.MAX_ROLAGENS:
		return true
	var de_mao := rolagem == 1
	var melhor := GeneralRules.best_category(dados, folha, de_mao)
	if melhor in GeneralRules.COMBINACOES and GeneralRules.score_for(melhor, dados, de_mao) > 0:
		return true
	# O iniciante as vezes para cedo sem motivo.
	return _erra(nivel, rng) and _sorteio(rng) < 0.5


## Onde gravar. Cinco iguais viram General em qualquer degrau -- ninguem deixa
## isso passar. Fora disso, o degrau alto pega o que rende mais (e risca na
## ordem certa quando nada rende); o baixo as vezes grava numa livre qualquer.
static func choose_category(dados: Array, folha: Dictionary, de_mao: bool, nivel: int,
		rng: RandomNumberGenerator = null) -> String:
	if GeneralRules.esta_livre(folha, "general") and GeneralRules.e_general(dados):
		return "general"
	var melhor := GeneralRules.best_category(dados, folha, de_mao)
	if melhor == "" or not _erra(nivel, rng):
		return melhor
	var livres := GeneralRules.categorias_livres(folha)
	var rendem: Array[String] = []
	for cat in livres:
		if GeneralRules.score_for(cat, dados, de_mao) > 0:
			rendem.append(cat)
	var bolsa := rendem if not rendem.is_empty() else livres
	var i := (rng.randi() if rng != null else randi()) % bolsa.size()
	return bolsa[i]


## Os valores distintos da maior sequencia de consecutivos nos dados
## ([1,2,3,5,6] -> [1,2,3]).
static func maior_corrida(dados: Array) -> Array[int]:
	var cont := GeneralRules.contagem(dados)
	var melhor: Array[int] = []
	var atual: Array[int] = []
	for v in range(1, 7):
		if cont[v] > 0:
			atual.append(v)
			if atual.size() > melhor.size():
				melhor = atual.duplicate()
		else:
			atual.clear()
	return melhor


## Indices de todos os dados cujo valor esta em `valores`.
static func _indices_de(dados: Array, valores: Array) -> Array[int]:
	var saida: Array[int] = []
	for i in dados.size():
		if int(dados[i]) in valores:
			saida.append(i)
	return saida


## Um dado de cada valor de `valores` -- para a sequencia, o par repetido sobra.
static func _um_de_cada(dados: Array, valores: Array) -> Array[int]:
	var saida: Array[int] = []
	var vistos: Array[int] = []
	for i in dados.size():
		var v := int(dados[i])
		if v in valores and not (v in vistos):
			vistos.append(v)
			saida.append(i)
	return saida
