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


## Verdadeiro entre o toque e o soltar. So conta como jogada quem solta o dedo
## na propria carta sem ter arrastado no meio do caminho.
var _apertada: bool = false

## Com `emulate_mouse_from_touch` ligado -- o padrao, e o que vale no Android --
## um dedo chega duas vezes: como toque cru e como mouse emulado. Tratar as
## duas familias jogaria a carta duas vezes. O mesmo cuidado que `Board3D` toma.
var _toque_vira_mouse: bool = ProjectSettings.get_setting(
	"input_devices/pointing/emulate_mouse_from_touch", true)


func _ready() -> void:
	# `PASS` e nao `STOP`: com a mao cheia a fileira nao cabe na largura do
	# telefone e passa a rolar, e em `STOP` a carta engolia o arrasto -- o dedo
	# so conseguia mexer nas cartas que ja estavam a vista. Ver `UIKit.rolavel`.
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup(card: Card) -> void:
	kind = UnoCardArt2D.kind_key(card)
	color_key = UnoCardArt2D.color_key(card.color_type)


## O ScrollContainer avisa a arvore quando o arrasto vira rolagem. Aqui isso
## desarma a carta: sem o aviso, arrastar a mao para o lado comecando em cima
## de uma carta a jogava ao levantar o dedo.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN:
		_apertada = false


func _gui_input(event: InputEvent) -> void:
	if not playable:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_apertada = true
		elif _apertada:
			_apertada = false
			_disparar(mb.position)
	elif event is InputEventScreenTouch and not _toque_vira_mouse:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_apertada = true
		elif _apertada:
			_apertada = false
			_disparar(st.position)


## Solta a jogada, mas so se o dedo subiu DENTRO da carta -- deslizar para fora
## e desistir, como em qualquer botao.
func _disparar(ponto: Vector2) -> void:
	if not Rect2(Vector2.ZERO, size).has_point(ponto):
		return
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
