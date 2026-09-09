class_name ChessAI
extends RefCounted

## A cabeca da IA do xadrez: negamax com poda alfa-beta, capturas primeiro,
## nota de material mais tabelas de posicao. Roda numa thread sobre o estado
## plano de `ChessRules`, nunca sobre a cena.
##
## O degrau (1..10) do DifficultyManager vira profundidade, chance de erro e
## ruido na nota:
##   1-2  -> 1 ply, com erro frequente
##   3-4  -> 2 plies
##   5-7  -> 3 plies, com busca de capturas na folha
##   8-10 -> 4 plies, com corte de tempo
##
## A busca aprofunda iterativamente. Quando o tempo acaba, vale a ultima
## profundidade COMPLETA: uma busca cortada pela metade viu metade dos lances
## e nao serve para escolher nada.
##
## O erro do degrau baixo troca a escolha por um lance qualquer, mas nunca o
## mate que a busca ja enxergou: uma IA que ve o mate e nao da parece quebrada,
## nao fraca.

const VALOR := PackedInt32Array([0, 100, 320, 330, 500, 900, 0])
const MATE := 100000
const INFINITO := 1000000

const M_MASK := ChessRules.M_MASK
const M_FROM := ChessRules.M_FROM
const M_TO_SHIFT := ChessRules.M_TO_SHIFT
const M_PROMO_SHIFT := ChessRules.M_PROMO_SHIFT
const M_EP := ChessRules.M_EP
const M_SCORE_SHIFT := ChessRules.M_SCORE_SHIFT

## Abaixo deste material pesado (sem peoes) o rei sai do canto e vai para o
## centro: a tabela de final entra no lugar da de meio-jogo.
const LIMIAR_FINAL := 1300

## Tabelas de posicao (Michniewski), vistas pelas brancas: a primeira linha e
## a oitava fileira, que e a linha 0 do tabuleiro. As pretas leem a tabela
## espelhada (indice ^ 56).
const PST_PAWN := PackedInt32Array([
	0, 0, 0, 0, 0, 0, 0, 0,
	50, 50, 50, 50, 50, 50, 50, 50,
	10, 10, 20, 30, 30, 20, 10, 10,
	5, 5, 10, 25, 25, 10, 5, 5,
	0, 0, 0, 20, 20, 0, 0, 0,
	5, -5, -10, 0, 0, -10, -5, 5,
	5, 10, 10, -20, -20, 10, 10, 5,
	0, 0, 0, 0, 0, 0, 0, 0,
])
const PST_KNIGHT := PackedInt32Array([
	-50, -40, -30, -30, -30, -30, -40, -50,
	-40, -20, 0, 0, 0, 0, -20, -40,
	-30, 0, 10, 15, 15, 10, 0, -30,
	-30, 5, 15, 20, 20, 15, 5, -30,
	-30, 0, 15, 20, 20, 15, 0, -30,
	-30, 5, 10, 15, 15, 10, 5, -30,
	-40, -20, 0, 5, 5, 0, -20, -40,
	-50, -40, -30, -30, -30, -30, -40, -50,
])
const PST_BISHOP := PackedInt32Array([
	-20, -10, -10, -10, -10, -10, -10, -20,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-10, 0, 5, 10, 10, 5, 0, -10,
	-10, 5, 5, 10, 10, 5, 5, -10,
	-10, 0, 10, 10, 10, 10, 0, -10,
	-10, 10, 10, 10, 10, 10, 10, -10,
	-10, 5, 0, 0, 0, 0, 5, -10,
	-20, -10, -10, -10, -10, -10, -10, -20,
])
const PST_ROOK := PackedInt32Array([
	0, 0, 0, 0, 0, 0, 0, 0,
	5, 10, 10, 10, 10, 10, 10, 5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	0, 0, 0, 5, 5, 0, 0, 0,
])
const PST_QUEEN := PackedInt32Array([
	-20, -10, -10, -5, -5, -10, -10, -20,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-10, 0, 5, 5, 5, 5, 0, -10,
	-5, 0, 5, 5, 5, 5, 0, -5,
	0, 0, 5, 5, 5, 5, 0, -5,
	-10, 5, 5, 5, 5, 5, 0, -10,
	-10, 0, 5, 0, 0, 0, 0, -10,
	-20, -10, -10, -5, -5, -10, -10, -20,
])
const PST_KING_MID := PackedInt32Array([
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-20, -30, -30, -40, -40, -30, -30, -20,
	-10, -20, -20, -20, -20, -20, -20, -10,
	20, 20, 0, 0, 0, 0, 20, 20,
	20, 30, 10, 0, 0, 10, 30, 20,
])
const PST_KING_END := PackedInt32Array([
	-50, -40, -30, -20, -20, -30, -40, -50,
	-30, -20, -10, 0, 0, -10, -20, -30,
	-30, -10, 20, 30, 30, 20, -10, -30,
	-30, -10, 30, 40, 40, 30, -10, -30,
	-30, -10, 30, 40, 40, 30, -10, -30,
	-30, -10, 20, 30, 30, 20, -10, -30,
	-30, -30, 0, 0, 0, 0, -30, -30,
	-50, -30, -30, -30, -30, -30, -30, -50,
])
const PST := [PST_PAWN, PST_PAWN, PST_KNIGHT, PST_BISHOP, PST_ROOK, PST_QUEEN, PST_KING_MID]


# --------------------------------------------------------------- degrau

## O que cada degrau da escada compra: profundidade, chance de erro, ruido na
## nota (variedade nos degraus baixos), teto de tempo e busca de capturas.
static func profile_for(level: int) -> Dictionary:
	match clampi(level, 1, 10):
		1: return {"depth": 1, "error": 0.35, "noise": 60, "time_ms": 0, "quiesce": false}
		2: return {"depth": 1, "error": 0.20, "noise": 40, "time_ms": 0, "quiesce": false}
		3: return {"depth": 2, "error": 0.12, "noise": 30, "time_ms": 1500, "quiesce": false}
		4: return {"depth": 2, "error": 0.06, "noise": 15, "time_ms": 1500, "quiesce": false}
		5: return {"depth": 3, "error": 0.0, "noise": 8, "time_ms": 2000, "quiesce": true}
		6: return {"depth": 3, "error": 0.0, "noise": 0, "time_ms": 2500, "quiesce": true}
		7: return {"depth": 3, "error": 0.0, "noise": 0, "time_ms": 3000, "quiesce": true}
		8: return {"depth": 4, "error": 0.0, "noise": 0, "time_ms": 3500, "quiesce": true}
		9: return {"depth": 4, "error": 0.0, "noise": 0, "time_ms": 4500, "quiesce": true}
		_: return {"depth": 4, "error": 0.0, "noise": 0, "time_ms": 6000, "quiesce": true}


# --------------------------------------------------------------- entrada

## O lance escolhido para o estado, codificado (`ChessRules.decode` abre), ou
## -1 sem lance legal.
static func choose_move(estado: Dictionary, level: int) -> int:
	return choose_encoded(estado["b"], int(estado["turn"]), int(estado["castle"]), int(estado["ep"]), level)


## Ponte para o WorkerThreadPool: escreve o lance em `saida`. Recebe so
## valores planos, entao a cena pode ser fechada com a busca no ar.
static func pensar_em_tarefa(b: PackedInt32Array, side: int, castle: int, ep: int,
		level: int, saida: Array) -> void:
	saida.append(choose_encoded(b, side, castle, ep, level))


static func choose_encoded(b: PackedInt32Array, side: int, castle: int, ep: int, level: int) -> int:
	var lances := ChessRules.legal_moves_encoded(b, side, castle, ep)
	if lances.is_empty():
		return -1
	if lances.size() == 1:
		return lances[0] & M_MASK
	var perfil := profile_for(level)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var estado := {"nos": 0, "fim": 0, "estourou": false, "quiesce": bool(perfil["quiesce"])}
	var limite := int(perfil["time_ms"])
	var ruido := int(perfil["noise"])
	var melhor := lances[0] & M_MASK
	var melhor_nota := -INFINITO
	for d in range(1, int(perfil["depth"]) + 1):
		# A primeira profundidade sempre termina: sem ela nao ha lance nenhum.
		if d == 2 and limite > 0:
			estado["fim"] = Time.get_ticks_msec() + limite
		var res := _raiz(b, side, castle, ep, lances, d, estado, ruido, rng, melhor)
		if bool(estado["estourou"]):
			break
		melhor = int(res["move"])
		melhor_nota = int(res["score"])
		if melhor_nota >= MATE - 100:
			break
	if melhor_nota < MATE - 100 and rng.randf() < float(perfil["error"]):
		return lances[rng.randi() % lances.size()] & M_MASK
	return melhor


# --------------------------------------------------------------- busca

## Uma rodada da raiz. O melhor da rodada anterior vai primeiro: e o que faz
## a poda cortar cedo na profundidade seguinte.
##
## Com ruido (degraus baixos) a janela fica cheia em todo lance da raiz, para
## as notas serem comparaveis entre si e o empate sortear de verdade -- e o
## defeito que o Reversi documenta em `_raiz`. Sem ruido a janela estreita e
## vale o primeiro melhor, sem sorteio.
static func _raiz(b: PackedInt32Array, side: int, castle: int, ep: int, lances: PackedInt32Array,
		depth: int, estado: Dictionary, ruido: int, rng: RandomNumberGenerator, primeiro: int) -> Dictionary:
	var ordenados := _ordenar(b, lances)
	var lista := PackedInt32Array()
	if primeiro >= 0:
		lista.append(primeiro)
	for i in range(ordenados.size() - 1, -1, -1):
		var m := ordenados[i] & M_MASK
		if m != primeiro:
			lista.append(m)
	var melhores: Array[int] = []
	var melhor_nota := -INFINITO
	var alpha := -INFINITO
	for m in lista:
		var nb := b.duplicate()
		ChessRules.apply_on_board(nb, m, side)
		var beta_filho := INFINITO if ruido > 0 else -alpha
		var nota := -_buscar(nb, -side, ChessRules.castle_after(castle, m, b, side),
			ChessRules.ep_after(m), depth - 1, -INFINITO, beta_filho, 1, estado)
		if bool(estado["estourou"]):
			break
		if ruido > 0:
			nota += rng.randi_range(-ruido, ruido)
		if nota > melhor_nota:
			melhor_nota = nota
			melhores = [m]
		elif nota == melhor_nota and ruido > 0:
			melhores.append(m)
		if nota > alpha:
			alpha = nota
	if melhores.is_empty():
		return {"move": lista[0], "score": -INFINITO}
	return {"move": melhores[rng.randi() % melhores.size()], "score": melhor_nota}


static func _buscar(b: PackedInt32Array, side: int, castle: int, ep: int, depth: int,
		alpha: int, beta: int, ply: int, estado: Dictionary) -> int:
	if _estourou(estado):
		return 0
	var ksq := ChessRules.king_square(b, side)
	var em_xeque := ksq >= 0 and ChessRules.is_attacked(b, ksq, -side)
	if depth <= 0:
		if bool(estado["quiesce"]):
			return _quiesce(b, side, castle, ep, alpha, beta, ply, estado, 3)
		# Mate na folha: e o que faz a busca de 1 ply enxergar o mate em um.
		if em_xeque and ChessRules.legal_moves_encoded(b, side, castle, ep).is_empty():
			return -MATE + ply
		return evaluate(b, side)
	var lances := ChessRules.legal_moves_encoded(b, side, castle, ep)
	if lances.is_empty():
		return (-MATE + ply) if em_xeque else 0
	var ordenados := _ordenar(b, lances)
	var melhor := -INFINITO
	for i in range(ordenados.size() - 1, -1, -1):
		var m := ordenados[i] & M_MASK
		var nb := b.duplicate()
		ChessRules.apply_on_board(nb, m, side)
		var nota := -_buscar(nb, -side, ChessRules.castle_after(castle, m, b, side),
			ChessRules.ep_after(m), depth - 1, -beta, -alpha, ply + 1, estado)
		if bool(estado["estourou"]):
			return 0
		if nota > melhor:
			melhor = nota
		if nota > alpha:
			alpha = nota
		if alpha >= beta:
			break
	return melhor


## Busca de capturas na folha: so para de olhar quando a posicao esta quieta.
## Sem isto a busca de profundidade fixa troca a dama por um peao "protegido"
## que ela nao viu ser recapturado -- o efeito de horizonte.
##
## Fora de xeque gera so as capturas e promocoes pseudo-legais e prova cada
## uma; em xeque nao ha ficar parado, e entram todos os lances legais.
static func _quiesce(b: PackedInt32Array, side: int, castle: int, ep: int,
		alpha: int, beta: int, ply: int, estado: Dictionary, resto: int) -> int:
	if _estourou(estado):
		return 0
	var ksq := ChessRules.king_square(b, side)
	var em_xeque := ksq >= 0 and ChessRules.is_attacked(b, ksq, -side)
	if em_xeque:
		var saidas := ChessRules.legal_moves_encoded(b, side, castle, ep)
		if saidas.is_empty():
			return -MATE + ply
		if resto <= 0:
			return evaluate(b, side)
		var pior := -INFINITO
		var ordenadas := _ordenar(b, saidas)
		for i in range(ordenadas.size() - 1, -1, -1):
			var m := ordenadas[i] & M_MASK
			var nb := b.duplicate()
			ChessRules.apply_on_board(nb, m, side)
			var nota := -_quiesce(nb, -side, ChessRules.castle_after(castle, m, b, side),
				ChessRules.ep_after(m), -beta, -alpha, ply + 1, estado, resto - 1)
			if nota > pior:
				pior = nota
			if nota > alpha:
				alpha = nota
			if alpha >= beta:
				break
		return pior

	var parado := evaluate(b, side)
	if resto <= 0 or parado >= beta:
		return parado
	if parado > alpha:
		alpha = parado
	var capturas := PackedInt32Array()
	for m in ChessRules.pseudo_moves(b, side, castle, ep):
		var to := (m >> M_TO_SHIFT) & 0x3F
		if b[to] != 0 or (m & M_EP) != 0 or ((m >> M_PROMO_SHIFT) & 7) != 0:
			capturas.append(m)
	if capturas.is_empty():
		return parado
	var melhor := parado
	var ordenados := _ordenar(b, capturas)
	for i in range(ordenados.size() - 1, -1, -1):
		var m := ordenados[i] & M_MASK
		var nb := b.duplicate()
		ChessRules.apply_on_board(nb, m, side)
		var k := ((m >> M_TO_SHIFT) & 0x3F) if (m & M_FROM) == ksq else ksq
		if k >= 0 and ChessRules.is_attacked(nb, k, -side):
			continue
		var nota := -_quiesce(nb, -side, ChessRules.castle_after(castle, m, b, side),
			ChessRules.ep_after(m), -beta, -alpha, ply + 1, estado, resto - 1)
		if nota > melhor:
			melhor = nota
		if nota > alpha:
			alpha = nota
		if alpha >= beta:
			break
	return melhor


## Conta o no e confere o relogio a cada 256: `Time.get_ticks_msec()` por no
## custaria mais que a propria avaliacao.
static func _estourou(estado: Dictionary) -> bool:
	if bool(estado["estourou"]):
		return true
	var nos: int = int(estado["nos"]) + 1
	estado["nos"] = nos
	if (nos & 255) == 0:
		var fim := int(estado["fim"])
		if fim > 0 and Time.get_ticks_msec() > fim:
			estado["estourou"] = true
			return true
	return false


## Capturas primeiro, a vitima mais valiosa pelo atacante mais barato
## (MVV-LVA), promocoes acima de tudo. A nota sobe para os bits altos do
## proprio int e um `sort()` de PackedInt32Array resolve a ordem -- a lista
## sai crescente, quem consome anda de tras para a frente.
static func _ordenar(b: PackedInt32Array, lances: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(lances.size())
	for i in lances.size():
		var m := lances[i] & M_MASK
		var to := (m >> M_TO_SHIFT) & 0x3F
		var vitima := 1 if (m & M_EP) != 0 else absi(b[to])
		var score := 0
		if vitima != 0:
			score = 100 + vitima * 10 - absi(b[m & M_FROM])
		var promo := (m >> M_PROMO_SHIFT) & 7
		if promo != 0:
			score += 200 + promo * 10
		out[i] = (score << M_SCORE_SHIFT) | m
	out.sort()
	return out


# --------------------------------------------------------------- avaliacao

## Nota da posicao do ponto de vista de `side`, em centesimos de peao.
static func evaluate(b: PackedInt32Array, side: int) -> int:
	var score := 0
	var wk := -1
	var bk := -1
	var pesado := 0
	for i in 64:
		var p := b[i]
		if p == 0:
			continue
		if p > 0:
			if p == ChessRules.KING:
				wk = i
				continue
			var tab: PackedInt32Array = PST[p]
			score += VALOR[p] + tab[i]
			if p != ChessRules.PAWN:
				pesado += VALOR[p]
		else:
			var t := -p
			if t == ChessRules.KING:
				bk = i
				continue
			var tab: PackedInt32Array = PST[t]
			score -= VALOR[t] + tab[i ^ 56]
			if t != ChessRules.PAWN:
				pesado += VALOR[t]
	var rei: PackedInt32Array = PST_KING_END if pesado <= LIMIAR_FINAL else PST_KING_MID
	if wk >= 0:
		score += rei[wk]
	if bk >= 0:
		score -= rei[bk ^ 56]
	return score * side
