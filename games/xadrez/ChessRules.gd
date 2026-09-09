class_name ChessRules
extends RefCounted

## Regras do xadrez sobre um estado plano, sem no e sem tr().
##
## O estado e um Dictionary:
##   b       PackedInt32Array de 64 casas, indice = linha * 8 + coluna. A linha 0
##           e a oitava fileira (pretas, longe de quem joga) e a linha 7 e a
##           primeira (brancas, embaixo). Brancas positivas, pretas negativas,
##           codigos PAWN..KING.
##   turn    WHITE (1) ou BLACK (-1).
##   castle  mascara de direitos de roque (CASTLE_*).
##   ep      casa onde um peao pode pousar de passagem neste lance, ou -1.
##   half    lances sem captura nem peao (regra dos 50).
##   full    numero do lance.
##   hist    chaves das posicoes desde o ultimo lance irreversivel (repeticao).
##
## O lance anda como um int (`encode`/`decode`): a busca da IA gera milhares
## deles por segundo numa thread, e um Dictionary por lance e o que a deixaria
## lenta. A cena recebe o mesmo lance ja aberto num Dictionary por `decode`.
##
## A legalidade nao copia o tabuleiro para cada lance pseudo-legal: so o rei,
## as pecas cravadas, os lances em xeque e a captura de passagem precisam da
## prova completa. E o que deixa a geracao barata o bastante para 4 plies em
## GDScript.

const EMPTY := 0
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6

const WHITE := 1
const BLACK := -1

const CASTLE_WK := 1
const CASTLE_WQ := 2
const CASTLE_BK := 4
const CASTLE_BQ := 8

enum Result { PLAYING, CHECKMATE, STALEMATE, DRAW_MATERIAL, DRAW_50, DRAW_REPETITION }

## Codificacao do lance: origem nos bits 0-5, destino 6-11, promocao 12-14,
## bandeiras a partir do 15. Os bits acima de M_MASK sao da ordenacao da IA.
const M_FROM := 0x3F
const M_TO_SHIFT := 6
const M_PROMO_SHIFT := 12
const M_CASTLE := 1 << 15
const M_EP := 1 << 16
const M_DOUBLE := 1 << 17
const M_MASK := 0xFFFFF
const M_SCORE_SHIFT := 20

const KNIGHT_DR := PackedInt32Array([-2, -2, -1, -1, 1, 1, 2, 2])
const KNIGHT_DC := PackedInt32Array([-1, 1, -2, 2, -2, 2, -1, 1])
const KING_DR := PackedInt32Array([-1, -1, -1, 0, 0, 1, 1, 1])
const KING_DC := PackedInt32Array([-1, 0, 1, -1, 1, -1, 0, 1])
## As oito direcoes de deslize: quatro ortogonais e depois quatro diagonais.
const RAY_DR := PackedInt32Array([-1, 1, 0, 0, -1, -1, 1, 1])
const RAY_DC := PackedInt32Array([0, 0, -1, 1, -1, 1, -1, 1])
const PROMOS := PackedInt32Array([QUEEN, ROOK, BISHOP, KNIGHT])

## Valor em peoes, para o placar de material da barra.
const VALOR := PackedInt32Array([0, 1, 3, 3, 5, 9, 0])
## Material de um lado inteiro sem o rei: 8 peoes + 2 cavalos + 2 bispos + 2 torres + dama.
const MATERIAL_INICIAL := 39


# --------------------------------------------------------------- estado

static func new_game() -> Dictionary:
	var b := PackedInt32Array()
	b.resize(64)
	var fundo := PackedInt32Array([ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK])
	for c in 8:
		b[c] = -fundo[c]
		b[8 + c] = -PAWN
		b[48 + c] = PAWN
		b[56 + c] = fundo[c]
	var estado := {"b": b, "turn": WHITE, "castle": 15, "ep": -1, "half": 0, "full": 1, "hist": []}
	estado["hist"] = [position_key(estado)]
	return estado


## Tabuleiro vazio, sem direito de roque: base das posicoes de teste.
static func empty_state(turn: int = WHITE) -> Dictionary:
	var b := PackedInt32Array()
	b.resize(64)
	return {"b": b, "turn": turn, "castle": 0, "ep": -1, "half": 0, "full": 1, "hist": []}


## "e4" -> indice. Coluna a..h, fileira 1..8 (a fileira 1 e a linha 7).
static func sq(nome_casa: String) -> int:
	var c := nome_casa.unicode_at(0) - "a".unicode_at(0)
	var fileira := int(nome_casa.substr(1, 1))
	return (8 - fileira) * 8 + c


static func nome(idx: int) -> String:
	return "%s%d" % [char("a".unicode_at(0) + (idx & 7)), 8 - (idx >> 3)]


static func side_of(peca: int) -> int:
	return signi(peca)


static func king_square(b: PackedInt32Array, side: int) -> int:
	var rei := KING * side
	for i in 64:
		if b[i] == rei:
			return i
	return -1


static func position_key(estado: Dictionary) -> String:
	var b: PackedInt32Array = estado["b"]
	return "%s|%d|%d|%d" % [b.to_byte_array().hex_encode(), int(estado["turn"]), int(estado["castle"]), int(estado["ep"])]


# --------------------------------------------------------------- lances

static func encode(from: int, to: int, promo: int = 0, flags: int = 0) -> int:
	return from | (to << M_TO_SHIFT) | (promo << M_PROMO_SHIFT) | flags


static func move_from(m: int) -> int:
	return m & M_FROM


static func move_to(m: int) -> int:
	return (m >> M_TO_SHIFT) & 0x3F


static func move_promo(m: int) -> int:
	return (m >> M_PROMO_SHIFT) & 7


## Abre o lance num Dictionary para a cena: origem, destino, promocao e o que
## ele faz de especial. `capture` e o codigo (positivo) da peca comida, ou 0.
static func decode(m: int, b: PackedInt32Array) -> Dictionary:
	var from := m & M_FROM
	var to := (m >> M_TO_SHIFT) & 0x3F
	var ep := (m & M_EP) != 0
	var captura := PAWN if ep else absi(b[to])
	return {
		"from": from,
		"to": to,
		"promo": (m >> M_PROMO_SHIFT) & 7,
		"castle": (m & M_CASTLE) != 0,
		"ep": ep,
		"double": (m & M_DOUBLE) != 0,
		"piece": b[from],
		"capture": captura,
		"code": m & M_MASK,
	}


static func promo_letter(code: int) -> String:
	match code:
		QUEEN: return "q"
		ROOK: return "r"
		BISHOP: return "b"
		KNIGHT: return "n"
		_: return ""


static func promo_code(letra: String) -> int:
	match letra:
		"q": return QUEEN
		"r": return ROOK
		"b": return BISHOP
		"n": return KNIGHT
		_: return 0


# --------------------------------------------------------------- ataque

## A casa esta atacada por alguma peca do lado `by`?
static func is_attacked(b: PackedInt32Array, casa: int, by: int) -> bool:
	var r := casa >> 3
	var c := casa & 7
	# O peao branco ataca de baixo para cima: para atingir `casa` ele esta na
	# linha seguinte (r + 1). O preto, na anterior.
	var pr := r + by
	if pr >= 0 and pr < 8:
		var peao := PAWN * by
		if c > 0 and b[pr * 8 + c - 1] == peao:
			return true
		if c < 7 and b[pr * 8 + c + 1] == peao:
			return true
	var cavalo := KNIGHT * by
	for i in 8:
		var nr := r + KNIGHT_DR[i]
		var nc := c + KNIGHT_DC[i]
		if nr >= 0 and nr < 8 and nc >= 0 and nc < 8 and b[nr * 8 + nc] == cavalo:
			return true
	var rei := KING * by
	for i in 8:
		var nr := r + KING_DR[i]
		var nc := c + KING_DC[i]
		if nr >= 0 and nr < 8 and nc >= 0 and nc < 8 and b[nr * 8 + nc] == rei:
			return true
	var dama := QUEEN * by
	var torre := ROOK * by
	var bispo := BISHOP * by
	for i in 8:
		var dr := RAY_DR[i]
		var dc := RAY_DC[i]
		var deslizante := torre if i < 4 else bispo
		var nr := r + dr
		var nc := c + dc
		while nr >= 0 and nr < 8 and nc >= 0 and nc < 8:
			var q := b[nr * 8 + nc]
			if q != 0:
				if q == dama or q == deslizante:
					return true
				break
			nr += dr
			nc += dc
	return false


static func is_in_check(estado: Dictionary, side: int = 0) -> bool:
	var lado := side if side != 0 else int(estado["turn"])
	var b: PackedInt32Array = estado["b"]
	var k := king_square(b, lado)
	return k >= 0 and is_attacked(b, k, -lado)


# --------------------------------------------------------------- geracao

## Lances pseudo-legais: tudo o que a peca alcanca, sem olhar se o proprio rei
## fica em xeque. O roque ja sai completo daqui, porque as casas atacadas no
## caminho sao parte da regra dele e nao da legalidade geral.
static func pseudo_moves(b: PackedInt32Array, side: int, castle: int, ep: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var branco := side > 0
	for from in 64:
		var p := b[from]
		if p == 0 or (p > 0) != branco:
			continue
		var t := absi(p)
		var r := from >> 3
		var c := from & 7
		match t:
			PAWN:
				var dir := -side
				var nr := r + dir
				if nr < 0 or nr > 7:
					continue
				var promove := nr == 0 or nr == 7
				var frente := nr * 8 + c
				if b[frente] == 0:
					_add_pawn(out, from, frente, promove)
					var linha_inicial := 6 if branco else 1
					if r == linha_inicial and b[frente + dir * 8] == 0:
						out.append(encode(from, frente + dir * 8, 0, M_DOUBLE))
				if c > 0:
					_pawn_capture(out, b, from, nr * 8 + c - 1, branco, promove, ep)
				if c < 7:
					_pawn_capture(out, b, from, nr * 8 + c + 1, branco, promove, ep)
			KNIGHT:
				for i in 8:
					var nr := r + KNIGHT_DR[i]
					var nc := c + KNIGHT_DC[i]
					if nr < 0 or nr > 7 or nc < 0 or nc > 7:
						continue
					var q := b[nr * 8 + nc]
					if q == 0 or (q > 0) != branco:
						out.append(encode(from, nr * 8 + nc))
			BISHOP:
				_slide(out, b, from, branco, 4, 8)
			ROOK:
				_slide(out, b, from, branco, 0, 4)
			QUEEN:
				_slide(out, b, from, branco, 0, 8)
			KING:
				for i in 8:
					var nr := r + KING_DR[i]
					var nc := c + KING_DC[i]
					if nr < 0 or nr > 7 or nc < 0 or nc > 7:
						continue
					var q := b[nr * 8 + nc]
					if q == 0 or (q > 0) != branco:
						out.append(encode(from, nr * 8 + nc))
				_castling(out, b, from, side, castle)
	return out


static func _add_pawn(out: PackedInt32Array, from: int, to: int, promove: bool) -> void:
	if promove:
		for promo in PROMOS:
			out.append(encode(from, to, promo))
	else:
		out.append(encode(from, to))


static func _pawn_capture(out: PackedInt32Array, b: PackedInt32Array, from: int, to: int,
		branco: bool, promove: bool, ep: int) -> void:
	var q := b[to]
	if q != 0 and (q > 0) != branco:
		_add_pawn(out, from, to, promove)
	elif q == 0 and to == ep:
		out.append(encode(from, to, 0, M_EP))


static func _slide(out: PackedInt32Array, b: PackedInt32Array, from: int, branco: bool,
		ray_ini: int, ray_fim: int) -> void:
	var r := from >> 3
	var c := from & 7
	for i in range(ray_ini, ray_fim):
		var dr := RAY_DR[i]
		var dc := RAY_DC[i]
		var nr := r + dr
		var nc := c + dc
		while nr >= 0 and nr < 8 and nc >= 0 and nc < 8:
			var to := nr * 8 + nc
			var q := b[to]
			if q == 0:
				out.append(encode(from, to))
			else:
				if (q > 0) != branco:
					out.append(encode(from, to))
				break
			nr += dr
			nc += dc


## Roque: rei e torre nunca movidos (a mascara), casas entre eles vazias, a
## torre ainda no canto, e o rei nem em xeque nem passando por casa atacada.
static func _castling(out: PackedInt32Array, b: PackedInt32Array, from: int, side: int, castle: int) -> void:
	if side > 0:
		if from != 60:
			return
		if castle & CASTLE_WK and b[61] == 0 and b[62] == 0 and b[63] == ROOK \
				and not is_attacked(b, 60, BLACK) and not is_attacked(b, 61, BLACK) and not is_attacked(b, 62, BLACK):
			out.append(encode(60, 62, 0, M_CASTLE))
		if castle & CASTLE_WQ and b[59] == 0 and b[58] == 0 and b[57] == 0 and b[56] == ROOK \
				and not is_attacked(b, 60, BLACK) and not is_attacked(b, 59, BLACK) and not is_attacked(b, 58, BLACK):
			out.append(encode(60, 58, 0, M_CASTLE))
	else:
		if from != 4:
			return
		if castle & CASTLE_BK and b[5] == 0 and b[6] == 0 and b[7] == -ROOK \
				and not is_attacked(b, 4, WHITE) and not is_attacked(b, 5, WHITE) and not is_attacked(b, 6, WHITE):
			out.append(encode(4, 6, 0, M_CASTLE))
		if castle & CASTLE_BQ and b[3] == 0 and b[2] == 0 and b[1] == 0 and b[0] == -ROOK \
				and not is_attacked(b, 4, WHITE) and not is_attacked(b, 3, WHITE) and not is_attacked(b, 2, WHITE):
			out.append(encode(4, 2, 0, M_CASTLE))


## Mascara das pecas proprias cravadas contra o rei: uma por raio, com um
## deslizante inimigo do tipo certo logo atras dela.
static func _pins(b: PackedInt32Array, ksq: int, side: int) -> int:
	var mask := 0
	var kr := ksq >> 3
	var kc := ksq & 7
	var branco := side > 0
	for i in 8:
		var dr := RAY_DR[i]
		var dc := RAY_DC[i]
		var r := kr + dr
		var c := kc + dc
		var candidata := -1
		while r >= 0 and r < 8 and c >= 0 and c < 8:
			var q := b[r * 8 + c]
			if q != 0:
				if (q > 0) == branco:
					if candidata >= 0:
						break
					candidata = r * 8 + c
				else:
					if candidata >= 0:
						var qt := absi(q)
						if qt == QUEEN or (i < 4 and qt == ROOK) or (i >= 4 and qt == BISHOP):
							mask |= 1 << candidata
					break
			r += dr
			c += dc
	return mask


## Lances legais codificados. E a funcao que a IA chama em cada no.
static func legal_moves_encoded(b: PackedInt32Array, side: int, castle: int, ep: int) -> PackedInt32Array:
	var pseudo := pseudo_moves(b, side, castle, ep)
	var ksq := king_square(b, side)
	if ksq < 0:
		return pseudo
	var em_xeque := is_attacked(b, ksq, -side)
	var cravadas := _pins(b, ksq, side)
	var out := PackedInt32Array()
	for m in pseudo:
		var from := m & M_FROM
		var precisa_prova := em_xeque or from == ksq or ((cravadas >> from) & 1) == 1 or (m & M_EP) != 0
		if precisa_prova:
			var nb := b.duplicate()
			apply_on_board(nb, m, side)
			var k := ((m >> M_TO_SHIFT) & 0x3F) if from == ksq else ksq
			if is_attacked(nb, k, -side):
				continue
		out.append(m)
	return out


static func all_legal_moves(estado: Dictionary) -> PackedInt32Array:
	return legal_moves_encoded(estado["b"], int(estado["turn"]), int(estado["castle"]), int(estado["ep"]))


## Lances legais da peca em `casa`, abertos para a cena.
static func legal_moves(estado: Dictionary, casa: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var b: PackedInt32Array = estado["b"]
	for m in all_legal_moves(estado):
		if (m & M_FROM) == casa:
			out.append(decode(m, b))
	return out


## O lance legal de `from` para `to`, ou -1. Uma promocao sem letra vira dama,
## para a jogada que chega pela rede sem o campo nao ser recusada por isso.
static func find_move(estado: Dictionary, from: int, to: int, promo: int = 0) -> int:
	var dama := -1
	for m in all_legal_moves(estado):
		if (m & M_FROM) != from or ((m >> M_TO_SHIFT) & 0x3F) != to:
			continue
		var mp := (m >> M_PROMO_SHIFT) & 7
		if mp == promo:
			return m
		if mp == QUEEN:
			dama = m
	if promo == 0:
		return dama
	return -1


# --------------------------------------------------------------- aplicar

## Executa o lance no tabuleiro (em lugar) e devolve o codigo da peca comida.
static func apply_on_board(b: PackedInt32Array, m: int, side: int) -> int:
	var from := m & M_FROM
	var to := (m >> M_TO_SHIFT) & 0x3F
	var promo := (m >> M_PROMO_SHIFT) & 7
	var p := b[from]
	var comida := absi(b[to])
	b[from] = 0
	if m & M_EP:
		# O peao comido de passagem esta na linha de partida do capturador.
		var cs := to + (8 if side > 0 else -8)
		comida = absi(b[cs])
		b[cs] = 0
	if promo != 0:
		p = promo * side
	b[to] = p
	if m & M_CASTLE:
		var linha := to & ~7
		if (to & 7) == 6:
			b[linha + 5] = b[linha + 7]
			b[linha + 7] = 0
		else:
			b[linha + 3] = b[linha]
			b[linha] = 0
	return comida


## Direitos de roque depois do lance: o rei que anda perde os dois, a torre
## que sai do canto (ou e comida nele) perde o seu.
static func castle_after(castle: int, m: int, b_antes: PackedInt32Array, side: int) -> int:
	var from := m & M_FROM
	var to := (m >> M_TO_SHIFT) & 0x3F
	if absi(b_antes[from]) == KING:
		castle &= ~(CASTLE_WK | CASTLE_WQ) if side > 0 else ~(CASTLE_BK | CASTLE_BQ)
	if from == 63 or to == 63:
		castle &= ~CASTLE_WK
	if from == 56 or to == 56:
		castle &= ~CASTLE_WQ
	if from == 7 or to == 7:
		castle &= ~CASTLE_BK
	if from == 0 or to == 0:
		castle &= ~CASTLE_BQ
	return castle


static func ep_after(m: int) -> int:
	if m & M_DOUBLE:
		return ((m & M_FROM) + ((m >> M_TO_SHIFT) & 0x3F)) / 2
	return -1


## Estado novo com o lance aplicado. Aceita o int codificado ou o Dictionary
## de `decode`. Nao valida: quem chama ja escolheu entre os legais.
static func apply_move(estado: Dictionary, lance: Variant) -> Dictionary:
	var m: int = int(lance["code"]) if lance is Dictionary else int(lance)
	var b: PackedInt32Array = (estado["b"] as PackedInt32Array).duplicate()
	var side := int(estado["turn"])
	var movida := absi(b[m & M_FROM])
	var comida := apply_on_board(b, m, side)
	var castle := castle_after(int(estado["castle"]), m, estado["b"], side)
	var novo := {
		"b": b,
		"turn": -side,
		"castle": castle,
		"ep": ep_after(m),
		"half": 0 if (movida == PAWN or comida != 0) else int(estado["half"]) + 1,
		"full": int(estado["full"]) + (1 if side < 0 else 0),
		"hist": [],
	}
	var irreversivel := movida == PAWN or comida != 0 or castle != int(estado["castle"])
	var hist: Array = [] if irreversivel else (estado["hist"] as Array).duplicate()
	hist.append(position_key(novo))
	novo["hist"] = hist
	return novo


# --------------------------------------------------------------- fim de partida

static func game_state(estado: Dictionary) -> int:
	if all_legal_moves(estado).is_empty():
		return Result.CHECKMATE if is_in_check(estado) else Result.STALEMATE
	if int(estado["half"]) >= 100:
		return Result.DRAW_50
	if insufficient_material(estado["b"]):
		return Result.DRAW_MATERIAL
	if repetitions(estado) >= 3:
		return Result.DRAW_REPETITION
	return Result.PLAYING


## Rei contra rei, rei e uma peca menor contra rei, ou so bispos todos na
## mesma cor de casa: ninguem consegue dar mate.
static func insufficient_material(b: PackedInt32Array) -> bool:
	var cavalos := 0
	var bispos_claros := 0
	var bispos_escuros := 0
	for i in 64:
		var t := absi(b[i])
		match t:
			PAWN, ROOK, QUEEN:
				return false
			KNIGHT:
				cavalos += 1
			BISHOP:
				if (((i >> 3) + (i & 7)) & 1) == 0:
					bispos_claros += 1
				else:
					bispos_escuros += 1
	var menores := cavalos + bispos_claros + bispos_escuros
	if menores <= 1:
		return true
	return cavalos == 0 and (bispos_claros == 0 or bispos_escuros == 0)


static func repetitions(estado: Dictionary) -> int:
	var chave := position_key(estado)
	var n := 0
	for k in estado["hist"]:
		if k == chave:
			n += 1
	return n


# --------------------------------------------------------------- material

static func material(b: PackedInt32Array, side: int) -> int:
	var total := 0
	for i in 64:
		var p := b[i]
		if p != 0 and (p > 0) == (side > 0):
			total += VALOR[absi(p)]
	return total


## Quanto `side` ja comeu, em peoes. Promocao inflaria o outro lado, por isso
## o piso em zero.
static func captured_value(b: PackedInt32Array, side: int) -> int:
	return maxi(0, MATERIAL_INICIAL - material(b, -side))


static func count_pieces(b: PackedInt32Array, side: int) -> int:
	var n := 0
	for i in 64:
		var p := b[i]
		if p != 0 and (p > 0) == (side > 0):
			n += 1
	return n


## `side` tem mate em um nesta posicao, se fosse a vez dele? Serve ao
## "por um triz" da gamificacao: o mate que veio com o proprio rei a um lance
## de cair.
static func has_mate_in_one(estado: Dictionary, side: int) -> bool:
	var b: PackedInt32Array = estado["b"]
	var castle := int(estado["castle"])
	for m in legal_moves_encoded(b, side, castle, -1):
		var nb := b.duplicate()
		apply_on_board(nb, m, side)
		var k := king_square(nb, -side)
		if k < 0 or not is_attacked(nb, k, side):
			continue
		if legal_moves_encoded(nb, -side, castle_after(castle, m, b, side), ep_after(m)).is_empty():
			return true
	return false
