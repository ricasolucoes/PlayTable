class_name UnoCardArt2D
extends RefCounted

## UnoCardArt2D: desenho vetorial de uma carta do baralho colorido.
##
## O baralho do Cartas Coloridas sempre foi um baralho de UNO de verdade -- quatro
## cores, bloquear, inverter, +2, curinga e curinga +4. Quem estava errado era o
## desenho: as cartas eram pedidas ao CardAtlas3D, que so conhece baralho frances,
## e uma carta "7 vermelho" saia como um 7 de espadas. A mesa dizia "Cor Ativa:
## Amarelo" com uma carta de espadas em cima.
##
## Como no CardArt2D, o simbolo e poligono e nao glifo de fonte: a carta fica
## identica em qualquer aparelho e nao depende de a fonte ter o caractere. So os
## algarismos usam fonte, porque digito toda fonte tem.

const RED := "red"
const YELLOW := "yellow"
const GREEN := "green"
const BLUE := "blue"
const WILD := "wild"

## Cores na ordem em que ocupam as linhas do atlas.
const COLOR_KEYS: PackedStringArray = [RED, YELLOW, GREEN, BLUE]

## Tipos de carta na ordem em que ocupam as colunas do atlas.
const KINDS: PackedStringArray = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
	"skip", "reverse", "draw2"]

const INK := {
	RED: Color(0.84, 0.16, 0.16),
	YELLOW: Color(0.97, 0.75, 0.06),
	GREEN: Color(0.16, 0.66, 0.29),
	BLUE: Color(0.13, 0.42, 0.82),
	WILD: Color(0.13, 0.13, 0.16),
}

const PAPER := Color(0.985, 0.982, 0.975)
const SHADOW := Color(0.0, 0.0, 0.0, 0.22)


static func color_of(key: String) -> Color:
	return INK.get(key, INK[WILD])


## Chave de cor a partir do enum do baralho.
static func color_key(color_type: int) -> String:
	match color_type:
		Card.ColorType.RED: return RED
		Card.ColorType.YELLOW: return YELLOW
		Card.ColorType.GREEN: return GREEN
		Card.ColorType.BLUE: return BLUE
		_: return WILD


## Chave de tipo a partir da carta: "0".."9", "skip", "reverse", "draw2",
## "wild", "wild4".
static func kind_key(card: Card) -> String:
	match card.card_type:
		"skip": return "skip"
		"reverse": return "reverse"
		"draw2": return "draw2"
		"wild": return "wild"
		"wild4": return "wild4"
		_: return str(clampi(card.value, 0, 9))


## Rotulo curto do canto, para HUD em texto.
static func label_for(kind: String) -> String:
	match kind:
		"skip": return "⊘"
		"reverse": return "⇄"
		"draw2": return "+2"
		"wild": return "★"
		"wild4": return "+4"
		_: return kind


# ---------------------------------------------------------------------------
# Face
# ---------------------------------------------------------------------------

## Desenha a face completa dentro de `rect`.
##
## Carta de UNO e o oposto da carta francesa: o fundo e a cor e o miolo e um
## oval branco inclinado. E o oval que faz a carta ser reconhecida de longe, e
## por isso ele nasce antes do simbolo.
static func draw_face(ci: CanvasItem, rect: Rect2, kind: String, color: String) -> void:
	var base := color_of(color)
	_base(ci, rect, base)

	# Oval branco inclinado no miolo.
	var centre := rect.position + rect.size * 0.5
	var oval := Vector2(rect.size.x * 0.42, rect.size.y * 0.40)
	_ellipse(ci, centre, oval, -0.42, PAPER)

	if kind == "wild" or kind == "wild4":
		_wild_quadrants(ci, centre, oval * 0.88, -0.42)
		if kind == "wild4":
			# Sem o "+4" no miolo, curinga e curinga +4 sao a mesma carta de
			# longe -- e a diferenca entre elas custa quatro cartas.
			_outlined(ci, Rect2(centre - oval * 0.60, oval * 1.20), "+4")
	else:
		_symbol(ci, Rect2(centre - oval * 0.72, oval * 1.44), kind, base, true)

	# Indices nos dois cantos opostos: a carta continua legivel em leque.
	var pad := rect.size * Vector2(0.085, 0.075)
	var idx := Vector2(rect.size.x * 0.26, rect.size.y * 0.17)
	_corner(ci, Rect2(rect.position + pad, idx), kind, false)
	_corner(ci, Rect2(rect.position + rect.size - pad - idx, idx), kind, true)


## Verso: mesmo corpo escuro para todo o baralho, com o oval e a marca.
static func draw_back(ci: CanvasItem, rect: Rect2) -> void:
	_base(ci, rect, INK[WILD])
	var centre := rect.position + rect.size * 0.5
	var oval := Vector2(rect.size.x * 0.44, rect.size.y * 0.42)
	_ellipse(ci, centre, oval, -0.42, PAPER)
	_wild_quadrants(ci, centre, oval * 0.86, -0.42)
	_ellipse(ci, centre, oval * 0.34, -0.42, INK[WILD])


# ---------------------------------------------------------------------------
# Partes
# ---------------------------------------------------------------------------

## Corpo da carta: borda branca grossa por fora, cor por dentro.
static func _base(ci: CanvasItem, rect: Rect2, base: Color) -> void:
	var radius: float = rect.size.x * 0.10
	_round_rect(ci, rect, radius, PAPER)
	var inset: float = rect.size.x * 0.070
	_round_rect(ci, Rect2(rect.position + Vector2(inset, inset),
		rect.size - Vector2(inset, inset) * 2.0), radius * 0.72, base)


static func _corner(ci: CanvasItem, rect: Rect2, kind: String, upside_down: bool) -> void:
	if upside_down:
		var centre := rect.position + rect.size * 0.5
		ci.draw_set_transform(centre, PI, Vector2.ONE)
		_symbol(ci, Rect2(-rect.size * 0.5, rect.size), kind, PAPER, false)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_symbol(ci, rect, kind, PAPER, false)


## O simbolo da carta. `big` liga o contorno escuro que o numero grande do meio
## tem numa carta de verdade -- no canto ele so polui.
static func _symbol(ci: CanvasItem, rect: Rect2, kind: String, col: Color, big: bool) -> void:
	match kind:
		"skip":
			_skip(ci, rect, col, big)
		"reverse":
			_reverse(ci, rect, col)
		"draw2":
			_digit(ci, rect, "+2", col, big)
		"wild":
			_digit(ci, rect, "★", col, big)
		"wild4":
			_digit(ci, rect, "+4", col, big)
		_:
			_digit(ci, rect, kind, col, big)


## Algarismo. A sombra deslocada e o que da o relevo do numero impresso.
static func _digit(ci: CanvasItem, rect: Rect2, texto: String, col: Color, big: bool) -> void:
	var font := ThemeDB.fallback_font
	var size: int = int(rect.size.y * (0.96 if big else 1.05))
	var w := font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	# "+2" e "+4" sao quase o dobro da largura de um algarismo: sem encolher
	# para caber, o "2" saia do canto e ficava so o sinal de mais.
	if w > rect.size.x:
		size = int(float(size) * rect.size.x / w)
		w = font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := rect.position + Vector2((rect.size.x - w) * 0.5, rect.size.y * (0.86 if big else 0.90))
	if big:
		ci.draw_string(font, base + Vector2(rect.size.x * 0.045, rect.size.y * 0.035),
			texto, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SHADOW)
	ci.draw_string(font, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Bloquear: anel grosso cortado por uma barra, o sinal de proibido.
static func _skip(ci: CanvasItem, rect: Rect2, col: Color, big: bool) -> void:
	var c := rect.position + rect.size * 0.5
	var r: float = minf(rect.size.x, rect.size.y) * (0.40 if big else 0.44)
	var largura: float = r * 0.30
	if big:
		ci.draw_arc(c + Vector2(r * 0.10, r * 0.10), r, 0.0, TAU, 28, SHADOW, largura)
	ci.draw_arc(c, r, 0.0, TAU, 28, col, largura)
	var d := Vector2(cos(-PI * 0.25), sin(-PI * 0.25)) * r
	ci.draw_line(c - d, c + d, col, largura * 0.92)


## Inverter: duas setas lado a lado, uma para cima e outra para baixo.
static func _reverse(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	var meia := Vector2(rect.size.x * 0.44, rect.size.y * 0.86)
	var y := rect.position.y + (rect.size.y - meia.y) * 0.5
	_arrow(ci, Rect2(Vector2(rect.position.x + rect.size.x * 0.04, y), meia), true, col)
	_arrow(ci, Rect2(Vector2(rect.position.x + rect.size.x * 0.52, y), meia), false, col)


## Seta vertical cheia: haste retangular e ponta triangular.
static func _arrow(ci: CanvasItem, rect: Rect2, up: bool, col: Color) -> void:
	var meio: float = rect.position.x + rect.size.x * 0.5
	var topo: float = rect.position.y if up else rect.end.y
	var base: float = rect.end.y if up else rect.position.y
	var ponta: float = rect.size.y * (0.42 if up else -0.42)
	var haste: float = rect.size.x * 0.20
	var asa: float = rect.size.x * 0.48
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(meio, topo),
		Vector2(meio + asa, topo + ponta),
		Vector2(meio + haste, topo + ponta),
		Vector2(meio + haste, base),
		Vector2(meio - haste, base),
		Vector2(meio - haste, topo + ponta),
		Vector2(meio - asa, topo + ponta),
	]), col)


## O oval do curinga dividido nas quatro cores.
static func _wild_quadrants(ci: CanvasItem, centre: Vector2, radii: Vector2,
		tilt: float) -> void:
	var passos := 10
	for i in COLOR_KEYS.size():
		var a0: float = TAU * float(i) / 4.0 - PI * 0.5
		var a1: float = TAU * float(i + 1) / 4.0 - PI * 0.5
		var pts := PackedVector2Array([centre])
		for s in range(passos + 1):
			var a: float = lerpf(a0, a1, float(s) / float(passos))
			var p := Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(tilt)
			pts.append(centre + p)
		ci.draw_colored_polygon(pts, color_of(COLOR_KEYS[i]))


## Texto claro com contorno escuro, para ler por cima das quatro cores.
static func _outlined(ci: CanvasItem, rect: Rect2, texto: String) -> void:
	for d in [Vector2(-2.0, 0.0), Vector2(2.0, 0.0), Vector2(0.0, -2.0), Vector2(0.0, 2.0),
			Vector2(-1.5, -1.5), Vector2(1.5, 1.5), Vector2(-1.5, 1.5), Vector2(1.5, -1.5)]:
		var escala: float = maxf(rect.size.x / 60.0, 1.0)
		_digit(ci, Rect2(rect.position + d * escala, rect.size), texto, INK[WILD], false)
	_digit(ci, rect, texto, PAPER, false)


# ---------------------------------------------------------------------------
# Primitivas
# ---------------------------------------------------------------------------

static func _ellipse(ci: CanvasItem, centre: Vector2, radii: Vector2, tilt: float,
		col: Color) -> void:
	var passos := 40
	var pts := PackedVector2Array()
	for i in range(passos):
		var a: float = TAU * float(i) / float(passos)
		pts.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(tilt))
	ci.draw_colored_polygon(pts, col)


static func _round_rect(ci: CanvasItem, rect: Rect2, radius: float, col: Color) -> void:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var passos := 6
	var cantos := [
		[Vector2(rect.position.x + r, rect.position.y + r), PI, PI * 1.5],
		[Vector2(rect.end.x - r, rect.position.y + r), PI * 1.5, TAU],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0, PI * 0.5],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5, PI],
	]
	for canto in cantos:
		var c: Vector2 = canto[0]
		for s in range(passos + 1):
			var a: float = lerpf(canto[1], canto[2], float(s) / float(passos))
			pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, col)
