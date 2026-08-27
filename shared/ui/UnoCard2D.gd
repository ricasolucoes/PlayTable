class_name UnoCard2D
extends Control

## UnoCard2D: a carta colorida na mao do jogador.
##
## Desenha pela mesma UnoCardArt2D que pinta o atlas 3D, entao a carta na mao e
## a carta na mesa sao a mesma carta -- antes a mao era um Button colorido com o
## valor em texto e a mesa era uma carta de espadas.

signal pressed()

@export var kind: String = "0":
	set(v):
		kind = v
		queue_redraw()

@export var color_key: String = UnoCardArt2D.RED:
	set(v):
		color_key = v
		queue_redraw()

## Carta que encaixa no descarte agora.
@export var playable: bool = true:
	set(v):
		playable = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(card: Card) -> void:
	kind = UnoCardArt2D.kind_key(card)
	color_key = UnoCardArt2D.color_key(card.color_type)


func _gui_input(event: InputEvent) -> void:
	if not playable:
		return
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
	# A carta que pode ser jogada sobe e ganha halo; a que nao pode fica no
	# lugar e escurece -- sem apagar o simbolo, que e o que se precisa ler para
	# saber por que ela nao serve.
	var lift := 8.0 if playable else 0.0
	var body := Rect2(Vector2(0.0, 8.0 - lift), size - Vector2(0.0, 8.0))

	draw_rect(Rect2(body.position + Vector2(2.0, 4.0), body.size), Color(0, 0, 0, 0.30), true)
	UnoCardArt2D.draw_face(self, body, kind, color_key)

	if playable:
		_halo(body)
	else:
		UnoCardArt2D._round_rect(self, body, body.size.x * 0.10, Color(0.05, 0.06, 0.10, 0.42))


func _halo(body: Rect2) -> void:
	var grow := body.grow(3.0)
	var pts := PackedVector2Array()
	var r: float = grow.size.x * 0.11
	var cantos := [
		[Vector2(grow.position.x + r, grow.position.y + r), PI, PI * 1.5],
		[Vector2(grow.end.x - r, grow.position.y + r), PI * 1.5, TAU],
		[Vector2(grow.end.x - r, grow.end.y - r), 0.0, PI * 0.5],
		[Vector2(grow.position.x + r, grow.end.y - r), PI * 0.5, PI],
	]
	for canto in cantos:
		var c: Vector2 = canto[0]
		for s in range(7):
			var a: float = lerpf(canto[1], canto[2], float(s) / 6.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(pts[0])
	draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.95), 3.0)
