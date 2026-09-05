class_name DragPicker3D
extends Control

## Arrastar e tocar peças 3D, sem grade 2D ancorada na tela.
##
## Extraído do Resta Um, que era o único jogo do repositório com arrasto. O
## padrão é uma camada de tela cheia que recebe `gui_input` e projeta cada alvo
## do mundo com `unproject_position()` -- por isso esta classe É a camada, e não
## um ajudante que a cena teria de montar e alimentar.
##
## Duas coisas que a regra da casa exige e que estão aqui, não em cada jogo:
##
##   - o toque vai para o alvo MAIS PRÓXIMO dentro de um raio, e não para o que
##     estiver exatamente sob o dedo;
##   - o raio sai da menor distância real entre alvos projetados, então três
##     pinos de Hanói ganham raio generoso e vinte e seis pontas de gamão ganham
##     raio apertado, sem ninguém escrever número nenhum.
##
## O esquema de dois toques continua valendo: `target_tapped` é emitido quando o
## dedo sobe sem ter arrastado. Esta classe acrescenta o arrasto, não o substitui.
##
## O nó se chama "TouchPicker" -- começa com "Touch", que é como
## `BaseGame.measure_hud_bands()` já sabe ignorar camadas de toque ao medir a HUD.

## Tocou e soltou sem arrastar.
signal target_tapped(id: Variant)

## O dedo saiu do lugar com um alvo sob ele. Quem escuta levanta a peça.
signal drag_started(id: Variant)

## O dedo andou. `over` é o alvo mais próximo agora (`null` fora de tudo) e
## `world` é o ponto do plano de jogo sob o dedo, para a peça acompanhar.
signal drag_moved(from_id: Variant, over: Variant, world: Vector3)

## Soltou. `to` é o alvo mais próximo, ou `null` -- e aí quem escuta devolve a
## peça de onde ela veio.
signal drag_ended(from_id: Variant, to: Variant)

## Piso do raio de captura, em pixels de viewport.
const RAIO_MINIMO := 26.0

## Teto, para alvo isolado não capturar meia tela.
const RAIO_MAXIMO := 120.0

## Fração da menor distância entre alvos que vira raio. Acima de 0,5 dois alvos
## vizinhos disputariam o mesmo toque.
const RAIO_FRACAO := 0.46

## Quanto o dedo anda até o toque virar arrasto. Abaixo disso é tremor de mão.
const LIMIAR_ARRASTO := 12.0

var enabled: bool = true

var _env: TabletopEnvironment3D = null
var _plane_y: float = 0.0
var _targets: Dictionary = {}          # id -> Vector3 (mundo)
var _screen: Dictionary = {}           # id -> Vector2 (tela)
var _raio: float = RAIO_MINIMO

var _press_id: Variant = null
var _press_pos: Vector2 = Vector2.ZERO
var _arrastando: bool = false
var _ultimo_over: Variant = null


func _init() -> void:
	name = "TouchPicker"
	# Sem isto o `measure_hud_bands()` do BaseGame leria uma camada de tela cheia
	# como faixa de HUD e o tabuleiro encolheria para caber "abaixo" dela.
	set_meta("alvo_projetado", true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	var vp: Viewport = get_viewport()
	if vp:
		vp.size_changed.connect(refresh_projection)


## Liga o picker à mesa. `play_plane_y` é a altura do plano onde a peça desliza
## enquanto arrastada -- normalmente o tampo do tabuleiro.
func attach(environment: TabletopEnvironment3D, play_plane_y: float = 0.0) -> void:
	_env = environment
	_plane_y = play_plane_y
	if _env and not _env.framing_changed.is_connected(_on_framing_changed):
		_env.framing_changed.connect(_on_framing_changed)
	refresh_projection.call_deferred()


func _on_framing_changed(_size: Vector2) -> void:
	refresh_projection()


## Declara os alvos: `{id: Vector3}` em coordenadas de MUNDO.
##
## `id` é `Variant` de propósito: `Vector2i` numa grade, `int` nos três pinos do
## Hanói, `int` nas vinte e seis pontas do gamão. Quem consome devolve o mesmo
## valor nos sinais, e não um índice que a cena teria de traduzir.
func set_targets(targets: Dictionary) -> void:
	_targets = targets.duplicate()
	refresh_projection()


## Move um alvo só. O topo da pilha do Hanói sobe a cada disco, e refazer os três
## a cada movimento seria desperdício.
func move_target(id: Variant, world_pos: Vector3) -> void:
	if not _targets.has(id):
		return
	_targets[id] = world_pos
	refresh_projection()


func clear_targets() -> void:
	_targets.clear()
	_screen.clear()


## Reprojeta tudo. Público para quem mexe na câmera à mão.
func refresh_projection() -> void:
	_screen.clear()
	var cam: Camera3D = _camera()
	if cam == null:
		return
	for id in _targets:
		var mundo: Vector3 = _targets[id]
		if cam.is_position_behind(mundo):
			continue
		_screen[id] = cam.unproject_position(mundo)
	_recalcular_raio()


## O raio de captura sai da menor distância entre dois alvos na tela.
##
## Escrever um número fixo obriga cada jogo a reencontrá-lo, e o número certo
## muda com o tamanho da tela e com o enquadramento -- que muda quando a HUD do
## próprio jogo muda de altura.
func _recalcular_raio() -> void:
	var menor: float = INF
	var ids: Array = _screen.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var d: float = (_screen[ids[i]] as Vector2).distance_to(_screen[ids[j]])
			if d > 0.0:
				menor = minf(menor, d)
	if menor == INF:
		_raio = RAIO_MAXIMO
		return
	_raio = clampf(menor * RAIO_FRACAO, RAIO_MINIMO, RAIO_MAXIMO)


## O alvo mais próximo do ponto, ou `null` se nenhum está dentro do raio.
func target_at(screen_point: Vector2) -> Variant:
	var melhor: Variant = null
	var menor: float = _raio
	for id in _screen:
		var d: float = (_screen[id] as Vector2).distance_to(screen_point)
		if d < menor:
			menor = d
			melhor = id
	return melhor


## Onde um alvo caiu na tela. `Vector2.INF` se ele não está projetado.
func screen_of(id: Variant) -> Vector2:
	return _screen.get(id, Vector2.INF)


## O ponto do plano de jogo sob um ponto da tela. `Vector3.INF` atrás da câmera.
func world_at(screen_point: Vector2) -> Vector3:
	var cam: Camera3D = _camera()
	if cam == null:
		return Vector3.INF
	var origem: Vector3 = cam.project_ray_origin(screen_point)
	var dir: Vector3 = cam.project_ray_normal(screen_point)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t: float = (_plane_y - origem.y) / dir.y
	if t < 0.0:
		return Vector3.INF
	return origem + dir * t


## Interrompe o arrasto sem emitir `drag_ended` -- fim de partida no meio do gesto.
func cancel_drag() -> void:
	_press_id = null
	_arrastando = false
	_ultimo_over = null


func is_dragging() -> bool:
	return _arrastando


func _camera() -> Camera3D:
	if _env and is_instance_valid(_env):
		var c: Node = _env.get_node_or_null("CameraRig3D")
		if c is Camera3D:
			return c
	var vp: Viewport = get_viewport()
	return vp.get_camera_3d() if vp else null


func _on_gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if mb.pressed:
			_begin(mb.position)
		else:
			_end(mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		accept_event()
		if st.pressed:
			_begin(st.position)
		else:
			_end(st.position)
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if _press_id == null:
			return
		accept_event()
		_move(event.position)


func _begin(ponto: Vector2) -> void:
	_press_id = target_at(ponto)
	_press_pos = ponto
	_arrastando = false
	_ultimo_over = null


func _move(ponto: Vector2) -> void:
	if not _arrastando:
		if ponto.distance_to(_press_pos) < LIMIAR_ARRASTO:
			return
		_arrastando = true
		drag_started.emit(_press_id)
	var over: Variant = target_at(ponto)
	_ultimo_over = over
	drag_moved.emit(_press_id, over, world_at(ponto))


func _end(ponto: Vector2) -> void:
	var origem: Variant = _press_id
	var arrastou: bool = _arrastando
	_press_id = null
	_arrastando = false
	_ultimo_over = null
	if origem == null:
		return
	if arrastou:
		drag_ended.emit(origem, target_at(ponto))
	else:
		target_tapped.emit(origem)
