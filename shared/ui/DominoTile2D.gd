class_name DominoTile2D
extends Control

## DominoTile2D: a pedra de domino da mao do jogador, desenhada.
##
## A mao era um Button com o texto "6\n---\n4". Num telefone isso e tres
## caracteres pequenos dentro de um botao cinza: nao le como pedra de domino, e
## foi por isso que a mao pareceu vazia. Aqui a pedra e desenhada -- marfim,
## vinco central, pontos na disposicao de sempre -- e o proprio Control responde
## ao toque, sem botao por baixo.

signal pressed()

## Arranjo dos pontos em cada metade, em coordenadas -1..1.
const LAYOUT := {
	0: [],
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0),
		Vector2(-1, 1), Vector2(1, 1)],
}

const IVORY := Color(0.96, 0.94, 0.88)
const IVORY_SHADE := Color(0.87, 0.84, 0.76)
const PIP := Color(0.16, 0.14, 0.13)
const EDGE := Color(0.55, 0.50, 0.44)

@export var value_a: int = 0:
	set(v):
		value_a = clampi(v, 0, 6)
		queue_redraw()

@export var value_b: int = 0:
	set(v):
		value_b = clampi(v, 0, 6)
		queue_redraw()

## Pedra escolhida: sobe e ganha friso dourado.
@export var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()

## Pedra que encaixa em alguma das pontas agora.
@export var playable: bool = true:
	set(v):
		playable = v
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(64, 118)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(a: int, b: int) -> void:
	value_a = clampi(a, 0, 6)
	value_b = clampi(b, 0, 6)


func _gui_input(event: InputEvent) -> void:
	var hit := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		hit = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		hit = (event as InputEventScreenTouch).pressed
	if hit:
		accept_event()
		pressed.emit()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# A pedra levanta quando escolhida; o buraco que ela deixa e o que mostra
	# que ela saiu da fileira.
	var top := -6.0 if selected else 0.0
	var body := Rect2(0.0, top, w, h - 6.0)
	var radius := w * 0.14

	# Sombra de contato sob a pedra.
	draw_rect(Rect2(2.0, top + 5.0, w, h - 6.0), Color(0, 0, 0, 0.30), true)

	# A pedra que nao encaixa continua legivel: escurecer o marfim a ponto de
	# apagar os pontos foi o que fez a mao parecer vazia. O que muda e a moldura.
	var face := IVORY if playable or selected else IVORY.darkened(0.06)
	_rounded_rect(body, radius, face)

	# Bisel: uma faixa mais escura embaixo da o volume da resina.
	_rounded_rect(Rect2(body.position.x, body.position.y + body.size.y * 0.72,
		body.size.x, body.size.y * 0.28), radius * 0.6, Color(IVORY_SHADE, 0.55))
	var rim := EDGE
	var rim_w := 2.0
	if selected:
		rim = Color(0.98, 0.80, 0.26)
		rim_w = 3.5
	elif playable:
		rim = Color(0.36, 0.86, 0.48)
		rim_w = 3.0
	_rounded_rect_outline(body, radius, rim, rim_w)

	# Vinco central.
	var mid_y := body.position.y + body.size.y * 0.5
	var inset := w * 0.12
	draw_line(Vector2(inset, mid_y), Vector2(w - inset, mid_y), Color(0.62, 0.57, 0.50), 2.0)

	# Metade de cima = value_a, metade de baixo = value_b.
	var half := Rect2(body.position.x, body.position.y, body.size.x, body.size.y * 0.5)
	_draw_half(half, value_a)
	half.position.y = mid_y
	_draw_half(half, value_b)



func _draw_half(area: Rect2, value: int) -> void:
	if not LAYOUT.has(value):
		return
	var center := area.get_center()
	var pip_r: float = minf(area.size.x, area.size.y) * 0.115
	var spread := Vector2(area.size.x * 0.26, area.size.y * 0.28)
	for slot in LAYOUT[value]:
		var p := center + Vector2(slot.x * spread.x, slot.y * spread.y)
		# Sombra do ponto escavado, depois o ponto.
		draw_circle(p + Vector2(0.6, 0.8), pip_r, Color(0.70, 0.66, 0.58))
		draw_circle(p, pip_r, PIP)


func _rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(rect.size.x - r * 2.0, rect.size.y)), color, true)
	draw_rect(Rect2(rect.position + Vector2(0, r), Vector2(rect.size.x, rect.size.y - r * 2.0)), color, true)
	for corner in _corners(rect, r):
		draw_circle(corner, r, color)


func _rounded_rect_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var centers := _corners(rect, r)
	# Ordem: superior-esquerdo, superior-direito, inferior-direito, inferior-esquerdo.
	var starts := [PI, PI * 1.5, 0.0, PI * 0.5]
	for i in 4:
		var c: Vector2 = centers[i]
		var a0: float = starts[i]
		for s in 5:
			var ang: float = a0 + (PI * 0.5) * (float(s) / 4.0)
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	pts.append(pts[0])
	draw_polyline(pts, color, width)


## Centros dos quatro cantos arredondados, em ordem horaria a partir do topo-esq.
func _corners(rect: Rect2, r: float) -> Array[Vector2]:
	return [
		rect.position + Vector2(r, r),
		rect.position + Vector2(rect.size.x - r, r),
		rect.position + Vector2(rect.size.x - r, rect.size.y - r),
		rect.position + Vector2(r, rect.size.y - r),
	]
