class_name DragScroll
extends Node

## Rolagem por arrasto do dedo dentro de um ScrollContainer.
##
## O ScrollContainer do Godot rola na roda do mouse e na barra lateral. O
## arrasto de toque, que e o unico gesto que existe num telefone, nao acontece:
## medido no 4.7.2 com evento sintetico fiel (`InputEventScreenTouch` seguido de
## `InputEventScreenDrag` com `relative` e `screen_relative` preenchidos, no
## SubViewport e na janela raiz, com e sem `--headless`, com
## `DisplayServer.is_touchscreen_available()` verdadeiro), `scroll_vertical`
## termina em zero e `scroll_started` nunca e emitido. Por isso a rolagem mora
## aqui, e nao numa configuracao da engine.
##
## Uso:
##
##     DragScroll.attach(minha_rolagem)
##
## O no se pendura no proprio ScrollContainer e escuta o sinal `gui_input`
## dele. O sinal e o PRIMEIRO passo de `Control._call_gui_input`: quem aceita o
## evento ali desliga o `_gui_input` do script e o `gui_input` de C++ que vem
## depois. Entao nao ha rolagem em dobro -- esta classe substitui a da engine
## em vez de somar com ela.
##
## O que ela respeita:
##
##   - so rola no eixo que o proprio ScrollContainer permite e que tem conteudo
##     sobrando; arrasto no eixo travado nao engole o gesto;
##   - a roda do mouse continua com a engine, intocada;
##   - passada a zona morta, avisa a arvore com `NOTIFICATION_SCROLL_BEGIN`,
##     que e como o `BaseButton` desarma o toque pendente -- sem isso, arrastar
##     a lista comecando em cima de um botao abriria o jogo ao soltar o dedo;
##   - solta com inercia, que e o que faz uma lista de 55 conquistas ser
##     percorrivel sem doze arrastos.

## Quanto o dedo anda ate o toque virar rolagem. Abaixo disso e tremor de mao,
## e o toque continua sendo do botao embaixo dele.
const ZONA_MORTA := 10.0

## Atrito da inercia, por segundo. 0,12 para em cerca de meio segundo.
const ATRITO := 0.12

## Velocidade abaixo da qual a inercia para de valer a pena, em px/s.
const VELOCIDADE_MINIMA := 24.0

## Teto da velocidade de lancamento, para um estalo do dedo nao atravessar a
## lista inteira.
const VELOCIDADE_MAXIMA := 4200.0

var _sc: ScrollContainer = null

## Toque em curso: indice do dedo, ou -1 fora do gesto.
var _dedo: int = -1

## Verdadeiro depois do primeiro `InputEventScreenTouch`. Dali em diante os
## eventos de mouse sao ignorados: no Android o `emulate_mouse_from_touch` faz
## o mesmo dedo chegar duas vezes, e sem esta trava a lista rolaria em dobro.
var _tem_toque: bool = false

var _mouse_pressionado: bool = false
var _origem: Vector2 = Vector2.ZERO
var _rolagem_inicial: Vector2 = Vector2.ZERO
var _acumulado: Vector2 = Vector2.ZERO
var _arrastando: bool = false
var _velocidade: Vector2 = Vector2.ZERO
var _ultimo_delta: Vector2 = Vector2.ZERO


## Pendura a rolagem por arrasto num ScrollContainer. Devolve o no criado, ou o
## que ja estava la -- chamar duas vezes no mesmo container nao duplica nada.
static func attach(sc: ScrollContainer) -> DragScroll:
	if sc == null:
		return null
	var existente := sc.get_node_or_null("DragScroll")
	if existente is DragScroll:
		return existente
	var d := DragScroll.new()
	d.name = "DragScroll"
	sc.add_child(d)
	return d


## Pendura em todos os ScrollContainer de uma subarvore. E o atalho para quem
## carrega uma cena pronta e nao quer procurar um por um.
static func attach_all(raiz: Node) -> int:
	if raiz == null:
		return 0
	var n := 0
	if raiz is ScrollContainer:
		attach(raiz as ScrollContainer)
		n += 1
	for filho in raiz.get_children():
		n += attach_all(filho)
	return n


func _ready() -> void:
	set_process(false)
	_sc = get_parent() as ScrollContainer
	if _sc == null:
		push_warning("DragScroll precisa ser filho de um ScrollContainer.")
		return
	if not _sc.gui_input.is_connected(_on_gui_input):
		_sc.gui_input.connect(_on_gui_input)


# ------------------------------------------------------------------ eixos

## Verdadeiro quando o eixo esta liberado E ha conteudo sobrando para rolar.
## Sem a segunda metade, a tira de abas do perfil -- que so rola na horizontal
## -- engoliria o arrasto vertical da lista que a cerca.
func _rola_h() -> bool:
	if _sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	var b := _sc.get_h_scroll_bar()
	return b != null and b.max_value - b.min_value > b.page


func _rola_v() -> bool:
	if _sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	var b := _sc.get_v_scroll_bar()
	return b != null and b.max_value - b.min_value > b.page


func _algum_eixo() -> bool:
	return _rola_h() or _rola_v()


# ------------------------------------------------------------------ entrada

func _on_gui_input(evento: InputEvent) -> void:
	if _sc == null or not _algum_eixo():
		return

	if evento is InputEventScreenTouch:
		_tem_toque = true
		var st := evento as InputEventScreenTouch
		if st.pressed:
			if _dedo == -1:
				_dedo = st.index
				_comecar(st.position)
		elif st.index == _dedo:
			_dedo = -1
			_soltar()
		return

	if evento is InputEventScreenDrag:
		var sd := evento as InputEventScreenDrag
		if sd.index == _dedo:
			_mover(sd.position)
		return

	# Daqui para baixo e mouse, e so vale enquanto nenhum dedo apareceu.
	if _tem_toque:
		return

	if evento is InputEventMouseButton:
		var mb := evento as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return                      # a roda continua sendo da engine
		if mb.pressed:
			_mouse_pressionado = true
			_comecar(mb.position)
		elif _mouse_pressionado:
			_mouse_pressionado = false
			_soltar()
		return

	if evento is InputEventMouseMotion and _mouse_pressionado:
		_mover((evento as InputEventMouseMotion).position)


func _comecar(ponto: Vector2) -> void:
	set_process(false)
	_velocidade = Vector2.ZERO
	_ultimo_delta = Vector2.ZERO
	_origem = ponto
	_acumulado = Vector2.ZERO
	_arrastando = false
	_rolagem_inicial = Vector2(float(_sc.scroll_horizontal), float(_sc.scroll_vertical))


func _mover(ponto: Vector2) -> void:
	var deslocamento := ponto - _origem
	if not _arrastando:
		var andou := 0.0
		if _rola_h() and _rola_v():
			andou = deslocamento.length()
		elif _rola_h():
			andou = absf(deslocamento.x)
		else:
			andou = absf(deslocamento.y)
		if andou < ZONA_MORTA:
			return
		_arrastando = true
		# O botao sob o dedo tem de saber que isto virou rolagem, senao ele
		# dispara `pressed` quando o dedo subir.
		_sc.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)

	_ultimo_delta = deslocamento - _acumulado
	_acumulado = deslocamento
	_aplicar(_rolagem_inicial - deslocamento)
	var dt := maxf(get_process_delta_time(), 0.0001)
	_velocidade = (-_ultimo_delta / dt).limit_length(VELOCIDADE_MAXIMA)
	_sc.accept_event()


func _soltar() -> void:
	if not _arrastando:
		return
	_arrastando = false
	_sc.propagate_notification(Control.NOTIFICATION_SCROLL_END)
	_sc.accept_event()
	if _velocidade.length() > VELOCIDADE_MINIMA:
		set_process(true)


func _aplicar(alvo: Vector2) -> void:
	if _rola_h():
		_sc.scroll_horizontal = int(round(alvo.x))
	if _rola_v():
		_sc.scroll_vertical = int(round(alvo.y))


# ------------------------------------------------------------------ inercia

func _process(delta: float) -> void:
	if _sc == null:
		set_process(false)
		return
	var atual := Vector2(float(_sc.scroll_horizontal), float(_sc.scroll_vertical))
	_aplicar(atual + _velocidade * delta)
	_velocidade *= pow(ATRITO, delta)
	if _velocidade.length() < VELOCIDADE_MINIMA:
		_velocidade = Vector2.ZERO
		set_process(false)
