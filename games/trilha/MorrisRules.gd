class_name MorrisRules
extends RefCounted

## As regras da Trilha (Nine Men's Morris / Moinho), puras: sem no, sem tr().
##
## O tabuleiro sao 24 pontos em tres quadrados concentricos, ligados pelos
## meios dos lados. O estado da partida e um Dictionary plano -- 24 bytes de
## tabuleiro, pecas na mao de cada lado, de quem e a vez e se ha captura
## pendente -- para poder ser clonado barato e viajar para a thread da IA.
##
## Uma vez tem ate duas metades: colocar ou mover a peca e, quando isso fecha
## uma trilha (tres em linha), capturar uma peca do adversario. A cena e a
## rede trabalham com as metades (`colocar`, `mover`, `remover`); a busca da
## IA trabalha com o lance completo (`lances`, `aplicar_lance`).
##
## Numeracao dos pontos:
##
##   0-----------1-----------2
##   |   3-------4-------5   |
##   |   |   6---7---8   |   |
##   9---10--11      12--13--14
##   |   |   15--16--17  |   |
##   |   18------19------20  |
##   21----------22----------23

const PONTOS := 24
const PECAS := 9
const VAZIO := 0
const BRANCO := 1
const PRETO := 2

enum Fase { COLOCACAO, MOVIMENTO, VOO }

## Meias-jogadas sem captura, na fase de movimento, ate o empate. Sem isto duas
## pessoas que nao se atacam jogam para sempre.
const LIMITE_SEM_CAPTURA := 50

## Quantas vezes a mesma posicao (com a mesma vez) pode voltar antes do empate.
const REPETICOES_PARA_EMPATE := 3

## Vizinhos de cada ponto ao longo das linhas desenhadas.
const ADJ := [
	[1, 9], [0, 2, 4], [1, 14],
	[4, 10], [1, 3, 5, 7], [4, 13],
	[7, 11], [4, 6, 8], [7, 12],
	[0, 10, 21], [3, 9, 11, 18], [6, 10, 15],
	[8, 13, 17], [5, 12, 14, 20], [2, 13, 23],
	[11, 16], [15, 17, 19], [12, 16],
	[10, 19], [16, 18, 20, 22], [13, 19],
	[9, 22], [19, 21, 23], [14, 22],
]

## As 16 trilhas possiveis: os lados dos tres quadrados e as quatro ligacoes.
const MOINHOS := [
	[0, 1, 2], [3, 4, 5], [6, 7, 8], [9, 10, 11],
	[12, 13, 14], [15, 16, 17], [18, 19, 20], [21, 22, 23],
	[0, 9, 21], [3, 10, 18], [6, 11, 15], [1, 4, 7],
	[16, 19, 22], [8, 12, 17], [5, 13, 20], [2, 14, 23],
]

## Coordenada de grade de cada ponto, de -3 a 3: quadrado externo em 3, medio
## em 2, interno em 1. A cena multiplica pelo passo do tabuleiro.
const COORDS := [
	Vector2i(-3, -3), Vector2i(0, -3), Vector2i(3, -3),
	Vector2i(-2, -2), Vector2i(0, -2), Vector2i(2, -2),
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-3, 0), Vector2i(-2, 0), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(-2, 2), Vector2i(0, 2), Vector2i(2, 2),
	Vector2i(-3, 3), Vector2i(0, 3), Vector2i(3, 3),
]

## Indices em MOINHOS das duas trilhas que passam por cada ponto. Montado uma
## vez no carregamento da classe, antes de qualquer thread existir.
static var _moinhos_do_ponto: Array = []


static func _static_init() -> void:
	_moinhos_do_ponto.clear()
	for p in PONTOS:
		_moinhos_do_ponto.append([])
	for m in MOINHOS.size():
		for p in MOINHOS[m]:
			(_moinhos_do_ponto[p] as Array).append(m)


# ================================================================ estado

static func novo_estado() -> Dictionary:
	var cells := PackedByteArray()
	cells.resize(PONTOS)
	return {
		"cells": cells,
		"mao": PackedInt32Array([0, PECAS, PECAS]),
		"vez": BRANCO,
		"remover": false,
		"sem_captura": 0,
		"lances": 0,
		"posicoes": {},
		"repeticoes": 0,
	}


## Copia independente: os arrays empacotados andam por referencia e uma copia
## rasa do Dictionary compartilharia o tabuleiro.
static func clonar(s: Dictionary) -> Dictionary:
	var c := s.duplicate()
	c["cells"] = (s["cells"] as PackedByteArray).duplicate()
	c["mao"] = (s["mao"] as PackedInt32Array).duplicate()
	c["posicoes"] = (s["posicoes"] as Dictionary).duplicate()
	return c


static func adversario(lado: int) -> int:
	return 3 - lado


static func contar(cells: PackedByteArray, lado: int) -> int:
	var n := 0
	for p in PONTOS:
		if cells[p] == lado:
			n += 1
	return n


## Pecas do lado ainda em jogo: no tabuleiro mais na mao.
static func total(s: Dictionary, lado: int) -> int:
	return contar(s["cells"], lado) + int((s["mao"] as PackedInt32Array)[lado])


## Em que fase o lado esta: colocando enquanto tem peca na mao, voando com
## exatamente tres no tabuleiro, movendo no resto.
static func fase(cells: PackedByteArray, mao: PackedInt32Array, lado: int) -> int:
	if mao[lado] > 0:
		return Fase.COLOCACAO
	if contar(cells, lado) == 3:
		return Fase.VOO
	return Fase.MOVIMENTO


static func fase_de(s: Dictionary, lado: int) -> int:
	return fase(s["cells"], s["mao"], lado)


static func moinhos_do_ponto(p: int) -> Array:
	return _moinhos_do_ponto[p]


## Quantas trilhas de `lado` passam completas por `p` (0, 1 ou 2). Supoe que
## `cells[p]` ja e de `lado`.
static func moinhos_fechados(cells: PackedByteArray, p: int, lado: int) -> int:
	var n := 0
	for m in _moinhos_do_ponto[p]:
		var tri: Array = MOINHOS[m]
		if cells[tri[0]] == lado and cells[tri[1]] == lado and cells[tri[2]] == lado:
			n += 1
	return n


static func em_moinho(cells: PackedByteArray, p: int) -> bool:
	var lado := int(cells[p])
	return lado != VAZIO and moinhos_fechados(cells, p, lado) > 0


static func contar_moinhos(cells: PackedByteArray, lado: int) -> int:
	var n := 0
	for tri in MOINHOS:
		if cells[tri[0]] == lado and cells[tri[1]] == lado and cells[tri[2]] == lado:
			n += 1
	return n


## As pecas de `alvo` que podem ser capturadas: as fora de trilha; se todas
## estao em trilha, qualquer uma.
static func removiveis(cells: PackedByteArray, alvo: int) -> PackedInt32Array:
	var fora := PackedInt32Array()
	var todas := PackedInt32Array()
	for p in PONTOS:
		if cells[p] != alvo:
			continue
		todas.append(p)
		if not em_moinho(cells, p):
			fora.append(p)
	return todas if fora.is_empty() else fora


static func vazios(cells: PackedByteArray) -> PackedInt32Array:
	var saida := PackedInt32Array()
	for p in PONTOS:
		if cells[p] == VAZIO:
			saida.append(p)
	return saida


## Para onde a peca em `p` pode ir: os vizinhos vazios, ou qualquer vazio
## quando o lado voa. Vazio na fase de colocacao -- ali ninguem move.
static func destinos(cells: PackedByteArray, mao: PackedInt32Array, p: int) -> PackedInt32Array:
	var lado := int(cells[p])
	if lado == VAZIO or mao[lado] > 0:
		return PackedInt32Array()
	if contar(cells, lado) == 3:
		return vazios(cells)
	var saida := PackedInt32Array()
	for q in ADJ[p]:
		if cells[q] == VAZIO:
			saida.append(q)
	return saida


static func pecas_moveis(cells: PackedByteArray, mao: PackedInt32Array, lado: int) -> PackedInt32Array:
	var saida := PackedInt32Array()
	if mao[lado] > 0:
		return saida
	for p in PONTOS:
		if cells[p] == lado and not destinos(cells, mao, p).is_empty():
			saida.append(p)
	return saida


## Na colocacao sempre ha ponto vazio (18 pecas em 24 pontos); no resto, ha
## lance se alguma peca tem destino.
static func tem_lance(cells: PackedByteArray, mao: PackedInt32Array, lado: int) -> bool:
	if mao[lado] > 0:
		return true
	for p in PONTOS:
		if cells[p] == lado and not destinos(cells, mao, p).is_empty():
			return true
	return false


## Perde quem fica com menos de tres pecas ou, sem peca na mao, sem lance.
static func perdeu(cells: PackedByteArray, mao: PackedInt32Array, lado: int) -> bool:
	if contar(cells, lado) + mao[lado] < 3:
		return true
	return not tem_lance(cells, mao, lado)


# ============================================================ validacao

static func pode_colocar(s: Dictionary, p: int) -> bool:
	if bool(s["remover"]) or p < 0 or p >= PONTOS:
		return false
	var cells: PackedByteArray = s["cells"]
	var mao: PackedInt32Array = s["mao"]
	var vez: int = s["vez"]
	return mao[vez] > 0 and cells[p] == VAZIO


static func pode_mover(s: Dictionary, de: int, para: int) -> bool:
	if bool(s["remover"]) or de < 0 or de >= PONTOS or para < 0 or para >= PONTOS:
		return false
	var cells: PackedByteArray = s["cells"]
	var mao: PackedInt32Array = s["mao"]
	var vez: int = s["vez"]
	if cells[de] != vez or mao[vez] > 0:
		return false
	return destinos(cells, mao, de).has(para)


static func pode_remover(s: Dictionary, p: int) -> bool:
	if not bool(s["remover"]) or p < 0 or p >= PONTOS:
		return false
	var cells: PackedByteArray = s["cells"]
	return removiveis(cells, adversario(int(s["vez"]))).has(p)


## A acao no formato que a rede usa: {"t":"place","p":i}, {"t":"move",
## "from":i,"to":j} ou {"t":"remove","p":i}. Os numeros passam por `int()`
## porque pela rede podem chegar como float.
static func valida(s: Dictionary, acao: Dictionary) -> bool:
	match str(acao.get("t", "")):
		"place":
			return pode_colocar(s, int(acao.get("p", -1)))
		"move":
			return pode_mover(s, int(acao.get("from", -1)), int(acao.get("to", -1)))
		"remove":
			return pode_remover(s, int(acao.get("p", -1)))
	return false


# ============================================================= aplicacao

## Coloca uma peca da mao de quem tem a vez em `p`. Devolve quantas trilhas
## fechou (0 a 2). Nao valida: chame `pode_colocar` antes.
static func colocar(s: Dictionary, p: int) -> int:
	var cells: PackedByteArray = s["cells"]
	var mao: PackedInt32Array = s["mao"]
	var vez: int = s["vez"]
	cells[p] = vez
	mao[vez] -= 1
	return _depois_do_lance(s, p)


static func mover(s: Dictionary, de: int, para: int) -> int:
	var cells: PackedByteArray = s["cells"]
	var vez: int = s["vez"]
	cells[de] = VAZIO
	cells[para] = vez
	return _depois_do_lance(s, para)


## Captura a peca em `p` e passa a vez. Nao valida: chame `pode_remover` antes.
static func remover(s: Dictionary, p: int) -> void:
	var cells: PackedByteArray = s["cells"]
	cells[p] = VAZIO
	s["remover"] = false
	s["sem_captura"] = 0
	# Depois de uma captura a posicao nunca mais se repete: o historico recomeca.
	(s["posicoes"] as Dictionary).clear()
	s["repeticoes"] = 0
	_passar(s)


## Aplica a acao da rede/da cena. Devolve as trilhas fechadas, ou -1 se a
## acao e ilegal (e entao nada muda).
static func aplicar(s: Dictionary, acao: Dictionary) -> int:
	if not valida(s, acao):
		return -1
	match str(acao.get("t", "")):
		"place":
			return colocar(s, int(acao["p"]))
		"move":
			return mover(s, int(acao["from"]), int(acao["to"]))
		"remove":
			remover(s, int(acao["p"]))
			return 0
	return -1


static func _depois_do_lance(s: Dictionary, p: int) -> int:
	var cells: PackedByteArray = s["cells"]
	var vez: int = s["vez"]
	var fechados := moinhos_fechados(cells, p, vez)
	s["lances"] = int(s["lances"]) + 1
	if _em_movimento(s):
		s["sem_captura"] = int(s["sem_captura"]) + 1
	# Trilha fechada com o adversario sem peca no tabuleiro nao captura nada:
	# a vez passa direto em vez de travar esperando um toque impossivel.
	if fechados > 0 and not removiveis(cells, adversario(vez)).is_empty():
		s["remover"] = true
	else:
		_passar(s)
	return fechados


static func _passar(s: Dictionary) -> void:
	s["vez"] = adversario(int(s["vez"]))
	if _em_movimento(s):
		var chave := (s["cells"] as PackedByteArray).hex_encode() + str(s["vez"])
		var posicoes: Dictionary = s["posicoes"]
		var n := int(posicoes.get(chave, 0)) + 1
		posicoes[chave] = n
		s["repeticoes"] = maxi(int(s["repeticoes"]), n)


## Os dois lados ja colocaram tudo: e daqui em diante que se conta empate.
static func _em_movimento(s: Dictionary) -> bool:
	var mao: PackedInt32Array = s["mao"]
	return mao[BRANCO] == 0 and mao[PRETO] == 0


# ============================================================== resultado

## `{"over", "winner", "draw", "reason"}`, com `reason` em "pecas",
## "bloqueio", "lances" ou "repeticao". Conferido sobre quem TEM a vez: e quem
## nao consegue jogar que perde.
static func resultado(s: Dictionary) -> Dictionary:
	var aberto := {"over": false, "winner": VAZIO, "draw": false, "reason": ""}
	if bool(s["remover"]):
		return aberto
	var cells: PackedByteArray = s["cells"]
	var mao: PackedInt32Array = s["mao"]
	var vez: int = s["vez"]
	if contar(cells, vez) + mao[vez] < 3:
		return {"over": true, "winner": adversario(vez), "draw": false, "reason": "pecas"}
	if not tem_lance(cells, mao, vez):
		return {"over": true, "winner": adversario(vez), "draw": false, "reason": "bloqueio"}
	if int(s["sem_captura"]) >= LIMITE_SEM_CAPTURA:
		return {"over": true, "winner": VAZIO, "draw": true, "reason": "lances"}
	if int(s["repeticoes"]) >= REPETICOES_PARA_EMPATE:
		return {"over": true, "winner": VAZIO, "draw": true, "reason": "repeticao"}
	return aberto


# ======================================================= lances completos
#
# Para a busca: um lance e Vector3i(de, para, captura), com `de` = -1 na
# colocacao e `captura` = -1 quando nao fechou trilha. Aplicar e desfazer
# mexem no tabuleiro no lugar, sem alocar.

static func lances(cells: PackedByteArray, mao: PackedInt32Array, lado: int) -> Array[Vector3i]:
	var saida: Array[Vector3i] = []
	if mao[lado] > 0:
		for p in PONTOS:
			if cells[p] == VAZIO:
				_acrescentar_lances(cells, lado, -1, p, saida)
		return saida
	for p in PONTOS:
		if cells[p] != lado:
			continue
		for q in destinos(cells, mao, p):
			_acrescentar_lances(cells, lado, p, q, saida)
	return saida


static func _acrescentar_lances(cells: PackedByteArray, lado: int, de: int, para: int,
		saida: Array[Vector3i]) -> void:
	if de >= 0:
		cells[de] = VAZIO
	cells[para] = lado
	if moinhos_fechados(cells, para, lado) > 0:
		var alvos := removiveis(cells, adversario(lado))
		if alvos.is_empty():
			saida.append(Vector3i(de, para, -1))
		for r in alvos:
			saida.append(Vector3i(de, para, r))
	else:
		saida.append(Vector3i(de, para, -1))
	cells[para] = VAZIO
	if de >= 0:
		cells[de] = lado


static func aplicar_lance(cells: PackedByteArray, mao: PackedInt32Array, lado: int, l: Vector3i) -> void:
	if l.x >= 0:
		cells[l.x] = VAZIO
	else:
		mao[lado] -= 1
	cells[l.y] = lado
	if l.z >= 0:
		cells[l.z] = VAZIO


static func desfazer_lance(cells: PackedByteArray, mao: PackedInt32Array, lado: int, l: Vector3i) -> void:
	if l.z >= 0:
		cells[l.z] = adversario(lado)
	cells[l.y] = VAZIO
	if l.x >= 0:
		cells[l.x] = lado
	else:
		mao[lado] += 1


## O lance completo como a sequencia de acoes que a cena e a rede entendem.
static func lance_para_acoes(l: Vector3i) -> Array[Dictionary]:
	var acoes: Array[Dictionary] = []
	if l.x < 0:
		acoes.append({"t": "place", "p": l.y})
	else:
		acoes.append({"t": "move", "from": l.x, "to": l.y})
	if l.z >= 0:
		acoes.append({"t": "remove", "p": l.z})
	return acoes
