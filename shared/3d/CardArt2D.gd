class_name CardArt2D
extends RefCounted

## CardArt2D: Desenho vetorial de uma face de carta.
##
## Fica separado de quem usa: o atlas 3D chama estas funcoes dentro de um
## SubViewport, e qualquer HUD 2D pode chamar as mesmas para desenhar a mesma
## carta. Uma unica definicao do que e um "3 de copas" no aplicativo inteiro.
##
## Os naipes sao poligonos, nao glifos de fonte: assim a carta fica identica em
## qualquer sistema e nao depende de uma fonte ter o caractere.

const SUIT_SPADE := "S"
const SUIT_HEART := "H"
const SUIT_DIAMOND := "D"
const SUIT_CLUB := "C"

const RANKS: PackedStringArray = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUITS: PackedStringArray = [SUIT_SPADE, SUIT_HEART, SUIT_DIAMOND, SUIT_CLUB]

const INK_BLACK := Color(0.11, 0.12, 0.16)
const INK_RED := Color(0.74, 0.12, 0.15)
const FACE_BG := Color(0.975, 0.968, 0.945)
const FACE_EDGE := Color(0.80, 0.78, 0.73)

## Posicoes dos naipes no miolo, em coordenadas normalizadas (0..1).
## `y` negativo na tabela indica naipe invertido, como em um baralho de verdade.
const PIP_LAYOUT := {
	"A": [Vector2(0.5, 0.5)],
	"2": [Vector2(0.5, 0.20), Vector2(0.5, -0.80)],
	"3": [Vector2(0.5, 0.20), Vector2(0.5, 0.50), Vector2(0.5, -0.80)],
	"4": [Vector2(0.30, 0.20), Vector2(0.70, 0.20), Vector2(0.30, -0.80), Vector2(0.70, -0.80)],
	"5": [Vector2(0.30, 0.20), Vector2(0.70, 0.20), Vector2(0.5, 0.50),
		Vector2(0.30, -0.80), Vector2(0.70, -0.80)],
	"6": [Vector2(0.30, 0.20), Vector2(0.70, 0.20), Vector2(0.30, 0.50), Vector2(0.70, 0.50),
		Vector2(0.30, -0.80), Vector2(0.70, -0.80)],
	"7": [Vector2(0.30, 0.20), Vector2(0.70, 0.20), Vector2(0.5, 0.35), Vector2(0.30, 0.50),
		Vector2(0.70, 0.50), Vector2(0.30, -0.80), Vector2(0.70, -0.80)],
	"8": [Vector2(0.30, 0.20), Vector2(0.70, 0.20), Vector2(0.5, 0.35), Vector2(0.30, 0.50),
		Vector2(0.70, 0.50), Vector2(0.5, -0.65), Vector2(0.30, -0.80), Vector2(0.70, -0.80)],
	"9": [Vector2(0.30, 0.18), Vector2(0.70, 0.18), Vector2(0.30, 0.39), Vector2(0.70, 0.39),
		Vector2(0.5, 0.50), Vector2(0.30, -0.61), Vector2(0.70, -0.61),
		Vector2(0.30, -0.82), Vector2(0.70, -0.82)],
	"10": [Vector2(0.30, 0.18), Vector2(0.70, 0.18), Vector2(0.5, 0.285), Vector2(0.30, 0.39),
		Vector2(0.70, 0.39), Vector2(0.30, -0.61), Vector2(0.70, -0.61),
		Vector2(0.5, -0.715), Vector2(0.30, -0.82), Vector2(0.70, -0.82)],
}

static func is_red(suit: String) -> bool:
	return suit == SUIT_HEART or suit == SUIT_DIAMOND

static func ink_for(suit: String) -> Color:
	return INK_RED if is_red(suit) else INK_BLACK

## Simbolo unicode do naipe, para HUD em texto.
static func suit_symbol(suit: String) -> String:
	match suit:
		SUIT_HEART: return "♥"
		SUIT_DIAMOND: return "♦"
		SUIT_CLUB: return "♣"
		_: return "♠"

# ---------------------------------------------------------------------------
# Face
# ---------------------------------------------------------------------------

## Desenha a face completa de uma carta dentro de `rect`.
static func draw_face(ci: CanvasItem, rect: Rect2, rank: String, suit: String) -> void:
	var ink := ink_for(suit)
	_draw_card_base(ci, rect)

	var pad: float = rect.size.x * 0.085
	var corner_h: float = rect.size.y * 0.115

	# Indice nos dois cantos opostos, como em um baralho real: a carta continua
	# legivel em leque, segura de qualquer lado.
	_draw_index(ci, Rect2(rect.position + Vector2(pad, pad),
		Vector2(rect.size.x * 0.20, corner_h)), rank, suit, ink, false)
	_draw_index(ci, Rect2(rect.position + rect.size - Vector2(pad + rect.size.x * 0.20, pad + corner_h),
		Vector2(rect.size.x * 0.20, corner_h)), rank, suit, ink, true)

	var inner := Rect2(
		rect.position + Vector2(rect.size.x * 0.20, rect.size.y * 0.11),
		Vector2(rect.size.x * 0.60, rect.size.y * 0.78))

	if PIP_LAYOUT.has(rank):
		_draw_pips(ci, inner, rank, suit, ink)
	else:
		_draw_court(ci, inner, rank, suit, ink)

static func _draw_card_base(ci: CanvasItem, rect: Rect2) -> void:
	var radius: float = rect.size.x * 0.075
	ci.draw_rect(rect, FACE_BG, true)
	# Moldura interna fina: e o que faz a carta parecer impressa e nao um
	# retangulo branco.
	var inset: float = rect.size.x * 0.045
	ci.draw_rect(Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2(inset, inset) * 2.0),
		FACE_EDGE, false, maxf(1.0, rect.size.x * 0.008))
	# Cantos arredondados desenhados como recortes do fundo.
	_round_corners(ci, rect, radius)

static func _round_corners(ci: CanvasItem, rect: Rect2, radius: float) -> void:
	var bg := Color(0, 0, 0, 0)
	var steps := 8
	for corner in 4:
		var cx: float = rect.position.x + (radius if corner % 2 == 0 else rect.size.x - radius)
		var cy: float = rect.position.y + (radius if corner < 2 else rect.size.y - radius)
		var centre := Vector2(cx, cy)
		var pts := PackedVector2Array()
		var ox: float = rect.position.x if corner % 2 == 0 else rect.position.x + rect.size.x
		var oy: float = rect.position.y if corner < 2 else rect.position.y + rect.size.y
		pts.append(Vector2(ox, oy))
		for i in range(steps + 1):
			var ang: float = PI * 0.5 * float(i) / float(steps)
			var dx: float = -cos(ang) if corner % 2 == 0 else cos(ang)
			var dy: float = -sin(ang) if corner < 2 else sin(ang)
			pts.append(centre + Vector2(dx, dy) * radius)
		ci.draw_colored_polygon(pts, bg)

## Indice de canto: valor por extenso e o naipe pequeno logo abaixo.
static func _draw_index(ci: CanvasItem, rect: Rect2, rank: String, suit: String,
		ink: Color, upside_down: bool) -> void:
	var font := ThemeDB.fallback_font
	var font_size: int = int(rect.size.y * 0.52)
	var label := rank
	var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	if upside_down:
		# Gira o proprio canvas para o indice de baixo, em vez de manter um
		# segundo conjunto de desenhos espelhados.
		var centre := rect.position + rect.size * 0.5
		ci.draw_set_transform(centre, PI, Vector2.ONE)
		var local := Rect2(-rect.size * 0.5, rect.size)
		ci.draw_string(font, local.position + Vector2((rect.size.x - text_w) * 0.5, font_size),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		draw_suit(ci, Rect2(local.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.60),
			Vector2(rect.size.x * 0.64, rect.size.y * 0.36)), suit, ink)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_string(font, rect.position + Vector2((rect.size.x - text_w) * 0.5, font_size),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		draw_suit(ci, Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.60),
			Vector2(rect.size.x * 0.64, rect.size.y * 0.36)), suit, ink)

static func _draw_pips(ci: CanvasItem, inner: Rect2, rank: String, suit: String, ink: Color) -> void:
	var layout: Array = PIP_LAYOUT[rank]
	var pip_size := Vector2(inner.size.x * 0.30, inner.size.y * 0.17)
	if rank == "A":
		pip_size = Vector2(inner.size.x * 0.62, inner.size.y * 0.34)

	for entry in layout:
		var p: Vector2 = entry
		var flipped: bool = p.y < 0.0
		var ny: float = absf(p.y)
		var centre := inner.position + Vector2(inner.size.x * p.x, inner.size.y * ny)
		var r := Rect2(centre - pip_size * 0.5, pip_size)
		if flipped:
			ci.draw_set_transform(centre, PI, Vector2.ONE)
			draw_suit(ci, Rect2(-pip_size * 0.5, pip_size), suit, ink)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_suit(ci, r, suit, ink)

## Figuras (J, Q, K): um brasao com a inicial, em vez de uma ilustracao
## detalhada que ficaria ilegivel no tamanho em que a carta aparece.
static func _draw_court(ci: CanvasItem, inner: Rect2, rank: String, suit: String, ink: Color) -> void:
	var centre := inner.position + inner.size * 0.5
	var w: float = inner.size.x
	var h: float = inner.size.y
	var gold := Color(0.78, 0.62, 0.26)

	var shield := PackedVector2Array([
		centre + Vector2(-w * 0.34, -h * 0.30),
		centre + Vector2(w * 0.34, -h * 0.30),
		centre + Vector2(w * 0.34, h * 0.10),
		centre + Vector2(0.0, h * 0.36),
		centre + Vector2(-w * 0.34, h * 0.10),
	])
	ci.draw_colored_polygon(shield, Color(0.955, 0.94, 0.90))
	ci.draw_polyline(shield + PackedVector2Array([shield[0]]), gold, maxf(1.0, w * 0.014), true)

	match rank:
		"K":
			_draw_crown(ci, centre + Vector2(0.0, -h * 0.34), w * 0.30, gold)
		"Q":
			_draw_crown(ci, centre + Vector2(0.0, -h * 0.34), w * 0.24, gold)
		_:
			ci.draw_circle(centre + Vector2(0.0, -h * 0.34), w * 0.07, gold)

	var font := ThemeDB.fallback_font
	var fs: int = int(h * 0.30)
	var tw := font.get_string_size(rank, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, centre + Vector2(-tw * 0.5, -h * 0.02), rank,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	draw_suit(ci, Rect2(centre + Vector2(-w * 0.13, h * 0.06), Vector2(w * 0.26, h * 0.22)), suit, ink)

static func _draw_crown(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-r, r * 0.55),
		c + Vector2(-r, -r * 0.35),
		c + Vector2(-r * 0.5, r * 0.05),
		c + Vector2(0.0, -r * 0.60),
		c + Vector2(r * 0.5, r * 0.05),
		c + Vector2(r, -r * 0.35),
		c + Vector2(r, r * 0.55),
	])
	ci.draw_colored_polygon(pts, col)

# ---------------------------------------------------------------------------
# Naipes
# ---------------------------------------------------------------------------

## Desenha um naipe preenchendo `rect`.
static func draw_suit(ci: CanvasItem, rect: Rect2, suit: String, col: Color) -> void:
	match suit:
		SUIT_HEART:
			_draw_heart(ci, rect, col)
		SUIT_DIAMOND:
			_draw_diamond(ci, rect, col)
		SUIT_CLUB:
			_draw_club(ci, rect, col)
		_:
			_draw_spade(ci, rect, col)

static func _draw_heart(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	var c := rect.position + rect.size * 0.5
	var w: float = rect.size.x * 0.5
	var h: float = rect.size.y * 0.5
	var pts := PackedVector2Array()
	var steps := 28
	for i in range(steps + 1):
		var t: float = TAU * float(i) / float(steps)
		# Curva de coracao classica, normalizada para o retangulo.
		var x: float = pow(sin(t), 3.0)
		var y: float = -(0.8125 * cos(t) - 0.3125 * cos(2.0 * t) - 0.125 * cos(3.0 * t) - 0.0625 * cos(4.0 * t))
		pts.append(c + Vector2(x * w, y * h))
	ci.draw_colored_polygon(pts, col)

static func _draw_diamond(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	var c := rect.position + rect.size * 0.5
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.0, -rect.size.y * 0.5),
		c + Vector2(rect.size.x * 0.42, 0.0),
		c + Vector2(0.0, rect.size.y * 0.5),
		c + Vector2(-rect.size.x * 0.42, 0.0),
	]), col)

static func _draw_spade(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	var c := rect.position + rect.size * 0.5
	var w: float = rect.size.x * 0.5
	var h: float = rect.size.y * 0.5
	var pts := PackedVector2Array()
	var steps := 28
	for i in range(steps + 1):
		var t: float = TAU * float(i) / float(steps)
		var x: float = pow(sin(t), 3.0)
		var y: float = 0.8125 * cos(t) - 0.3125 * cos(2.0 * t) - 0.125 * cos(3.0 * t) - 0.0625 * cos(4.0 * t)
		pts.append(c + Vector2(x * w, y * h * 0.92 - h * 0.10))
	ci.draw_colored_polygon(pts, col)
	# Pe do espadilha.
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-w * 0.30, h * 0.98),
		c + Vector2(w * 0.30, h * 0.98),
		c + Vector2(w * 0.10, h * 0.42),
		c + Vector2(-w * 0.10, h * 0.42),
	]), col)

static func _draw_club(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	var c := rect.position + rect.size * 0.5
	var w: float = rect.size.x * 0.5
	var h: float = rect.size.y * 0.5
	var r: float = minf(w, h) * 0.46
	ci.draw_circle(c + Vector2(0.0, -h * 0.36), r, col)
	ci.draw_circle(c + Vector2(-w * 0.50, h * 0.10), r, col)
	ci.draw_circle(c + Vector2(w * 0.50, h * 0.10), r, col)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-w * 0.30, h * 0.98),
		c + Vector2(w * 0.30, h * 0.98),
		c + Vector2(w * 0.10, h * 0.30),
		c + Vector2(-w * 0.10, h * 0.30),
	]), col)

# ---------------------------------------------------------------------------
# Verso
# ---------------------------------------------------------------------------

## Verso do baralho da casa: azul-marinho com trama e filete dourado.
static func draw_back(ci: CanvasItem, rect: Rect2, tint: Color = Color(0.09, 0.16, 0.36)) -> void:
	var ivory := Color(0.955, 0.94, 0.90)
	var gold := Color(0.80, 0.66, 0.30)
	ci.draw_rect(rect, ivory, true)

	var inset: float = rect.size.x * 0.055
	var inner := Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2(inset, inset) * 2.0)
	ci.draw_rect(inner, tint, true)

	# Trama diagonal: duas familias de linhas cruzadas, recortadas pelo miolo.
	var step: float = rect.size.x * 0.11
	var light := tint.lightened(0.16)
	var total: float = inner.size.x + inner.size.y
	var n := int(total / step) + 2
	for i in range(n):
		var o: float = float(i) * step
		_clipped_line(ci, inner, inner.position + Vector2(o, 0.0),
			inner.position + Vector2(o - inner.size.y, inner.size.y), light, rect.size.x * 0.012)
		_clipped_line(ci, inner, inner.position + Vector2(o - inner.size.y, 0.0),
			inner.position + Vector2(o, inner.size.y), light, rect.size.x * 0.012)

	ci.draw_rect(Rect2(inner.position + Vector2(inset * 0.5, inset * 0.5),
		inner.size - Vector2(inset, inset)), gold, false, maxf(1.0, rect.size.x * 0.010))

	var c := rect.position + rect.size * 0.5
	var d: float = rect.size.x * 0.20
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.0, -d), c + Vector2(d * 0.66, 0.0),
		c + Vector2(0.0, d), c + Vector2(-d * 0.66, 0.0),
	]), gold)
	ci.draw_circle(c, rect.size.x * 0.055, tint)

	_round_corners(ci, rect, rect.size.x * 0.075)

static func _clipped_line(ci: CanvasItem, clip: Rect2, from: Vector2, to: Vector2,
		col: Color, width: float) -> void:
	# Recorte barato por amostragem: linhas da trama nao precisam de precisao
	# geometrica, so nao podem vazar para fora do miolo.
	var steps := 14
	var prev := Vector2.INF
	for i in range(steps + 1):
		var p := from.lerp(to, float(i) / float(steps))
		var inside := clip.has_point(p)
		if inside and prev != Vector2.INF:
			ci.draw_line(prev, p, col, width)
		prev = p if inside else Vector2.INF
