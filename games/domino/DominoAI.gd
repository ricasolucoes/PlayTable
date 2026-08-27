class_name DominoAI
extends RefCounted

## A cabeca da IA do Domino: escolha por avaliacao da ponta que a jogada deixa.
##
## O que havia antes era `playable[0]` -- a primeira pedra jogavel na ordem em
## que ela caiu na mao. E exatamente o `moves[0]` que o cabecalho da
## `CheckersAI` documenta ter substituido nas Damas, e no Domino ele custa a
## partida do mesmo jeito: a IA descartava as pedras leves primeiro e ficava
## com as caras na mao, nunca fechava o jogo de proposito e nunca aproveitava
## o que os passes do adversario denunciavam.
##
## O que esta IA olha, em cada jogada possivel:
##
##   1. **O que o adversario ja denunciou.** Toda vez que ele compra ou passa,
##      ele diz que nao tem as duas pontas da mesa. Deixar as duas pontas em
##      numeros que ele nao tem e travar o jogo com a mao mais leve -- a
##      vitoria por pontos que o jogo fechado paga;
##   2. **O peso da pedra.** Quem fica com a mao cara perde por pontos quando o
##      outro bate. Pedra cara sai primeiro;
##   3. **A flexibilidade que sobra.** Uma jogada que deixa as pontas em
##      numeros que a propria mao ainda cobre vale mais que uma que fecha a
##      mao em si mesma.
##
## O degrau (1 a 10) do DifficultyManager vira a chance de largar a avaliacao
## e sortear a pedra.

## Travar o jogo com as duas pontas em numeros que o adversario nao tem.
const PESO_TRAVA := 60

## Uma das pontas em numero que ele nao tem.
const PESO_MEIA_TRAVA := 18

## Cada ponto da pedra que sai da mao.
const PESO_PONTOS := 3

## Cada pedra da propria mao que ainda encaixa nas pontas resultantes.
const PESO_FLEXIBILIDADE := 5

## Bucha (pedra dupla) sai cedo: ela so encaixa num numero, e quanto mais o
## jogo anda, mais dificil e coloca-la.
const PESO_BUCHA := 7

## Perfil de cada degrau: chance de sortear entre as jogaveis em vez de seguir
## a avaliacao. Domino tem informacao escondida -- a mao do adversario nao esta
## na mesa -- entao nao ha busca a fazer, so leitura do que ele denunciou.
const PERFIS := [
	{"erro": 0.88},   # 1
	{"erro": 0.72},   # 2
	{"erro": 0.58},   # 3
	{"erro": 0.45},   # 4
	{"erro": 0.33},   # 5
	{"erro": 0.22},   # 6
	{"erro": 0.14},   # 7
	{"erro": 0.07},   # 8
	{"erro": 0.02},   # 9
	{"erro": 0.0},    # 10
]


## O que a IA sabe do adversario. `vazios` guarda os numeros que ele denunciou
## nao ter, um por vez em que comprou ou passou.
static func nova_memoria() -> Dictionary:
	return {"vazios": {}}


## O adversario comprou ou passou: ele nao tem nenhuma das duas pontas.
static func registrar_falta(memoria: Dictionary, left_end: int, right_end: int) -> void:
	if left_end >= 0:
		memoria["vazios"][left_end] = true
	if right_end >= 0:
		memoria["vazios"][right_end] = true


## A jogada da IA no degrau pedido: `{tile_index, side}`, ou `{}` sem jogada.
static func escolher(mao: Array, left_end: int, right_end: int, memoria: Dictionary,
		level: int) -> Dictionary:
	var opcoes := _opcoes(mao, left_end, right_end)
	if opcoes.is_empty():
		return {}
	if opcoes.size() == 1:
		return opcoes[0]

	var perfil: Dictionary = PERFIS[clampi(level, 1, PERFIS.size()) - 1]
	if randf() < float(perfil["erro"]):
		return opcoes[randi() % opcoes.size()]

	var vazios: Dictionary = memoria.get("vazios", {})
	var melhores: Array[Dictionary] = []
	var melhor_nota := -0x7FFFFFFF

	for op in opcoes:
		var nota := avaliar(mao, op, left_end, right_end, vazios)
		if nota > melhor_nota:
			melhor_nota = nota
			melhores = [op]
		elif nota == melhor_nota:
			melhores.append(op)

	return melhores[randi() % melhores.size()]


## Quanto vale a jogada. Maior e melhor.
static func avaliar(mao: Array, op: Dictionary, left_end: int, right_end: int,
		vazios: Dictionary) -> int:
	var idx: int = op["tile_index"]
	var pedra: Dictionary = mao[idx]
	var giro := DominoRules.orient_tile_for_side(pedra, op["side"], left_end, right_end)
	var nova_esq: int = giro["new_left_end"]
	var nova_dir: int = giro["new_right_end"]

	var nota := PESO_PONTOS * (int(pedra["a"]) + int(pedra["b"]))

	if int(pedra["a"]) == int(pedra["b"]):
		nota += PESO_BUCHA

	# O que os passes dele ja disseram.
	var trava_esq: bool = vazios.has(nova_esq)
	var trava_dir: bool = vazios.has(nova_dir)
	if trava_esq and trava_dir:
		nota += PESO_TRAVA
	elif trava_esq or trava_dir:
		nota += PESO_MEIA_TRAVA

	# Quantas pedras da mao ainda encaixam depois desta jogada.
	for i in range(mao.size()):
		if i == idx:
			continue
		if DominoRules.can_tile_fit(mao[i], nova_esq, nova_dir):
			nota += PESO_FLEXIBILIDADE

	return nota


## Toda pedra jogavel, em cada ponta em que ela cabe.
##
## A IA antiga so olhava uma ponta por pedra -- a esquerda quando a pedra
## batia com ela. Uma pedra que cabe nas duas e duas jogadas diferentes, e
## costumam valer notas bem diferentes.
static func _opcoes(mao: Array, left_end: int, right_end: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for i in range(mao.size()):
		var t: Dictionary = mao[i]
		var a: int = int(t["a"])
		var b: int = int(t["b"])
		if a == left_end or b == left_end:
			saida.append({"tile_index": i, "side": "left"})
		if a == right_end or b == right_end:
			saida.append({"tile_index": i, "side": "right"})
	return saida
