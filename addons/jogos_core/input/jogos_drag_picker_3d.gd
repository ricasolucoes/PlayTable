class_name JogosDragPicker3D
extends Control

## Tocar e arrastar alvos 3D, sem grade 2D ancorada na tela.
##
## Fonte: PlayTable `shared/3d/DragPicker3D.gd`. Tirado: o tipo
## `TabletopEnvironment3D` (agora `attach` aceita qualquer Node3D que tenha um
## `Camera3D` filho, ou `set_camera`); a projecao ficou injetavel
## (`projector`/`unprojector`) para a suite provar a escolha do alvo sem
## camera.
##
## O que a regra da casa exige e que esta aqui, nao em cada jogo:
## - o toque vai para o alvo MAIS PROXIMO dentro de um raio, nao para o que
##   esta exatamente sob o dedo;
## - o raio sai da menor distancia real entre alvos projetados: tres pinos de
##   Hanoi ganham raio generoso, vinte e seis pontas de gamao raio apertado,
##   sem ninguem escrever numero nenhum.
## Dois toques continuam valendo (`target_tapped` quando o dedo sobe sem
## arrastar); o arrasto e acrescimo, nao substituto.
## O no chama-se "TouchPicker": comeca com "Touch", que e como a medida de HUD
## sabe ignorar camadas de toque.

signal target_tapped(id: Variant)
signal drag_started(id: Variant)
signal drag_moved(from_id: Variant, over: Variant, world: Vector3)
signal drag_ended(from_id: Variant, to: Variant)

const RADIUS_MIN: float = 26.0
const RADIUS_MAX: float = 120.0
## Fracao da menor distancia entre alvos que vira raio. Acima de 0,5 dois
## vizinhos disputariam o mesmo toque.
const RADIUS_FRACTION: float = 0.46
const DRAG_THRESHOLD: float = 12.0

var enabled: bool = true

## Vector3 (mundo) -> Vector2 (tela), ou Vector2.INF se atras da camera.
var projector: Callable = Callable()
## Vector2 (tela) -> Vector3 no plano de jogo, ou Vector3.INF.
var unprojector: Callable = Callable()

var _env: Node3D = null
var _camera: Camera3D = null
var _plane_y: float = 0.0
var _targets: Dictionary = {}
var _screen: Dictionary = {}
var _radius: float = RADIUS_MIN

var _press_id: Variant = null
var _press_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false


func _init() -> void:
	name = "TouchPicker"
	set_meta(JogosScreenFit.META_IGNORE_FIT, true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(refresh_projection):
		vp.size_changed.connect(refresh_projection)
	# Fica EMBAIXO da HUD: no indice 0 o picker so recebe o que nenhum botao
	# acima quis -- a mesa. Adiado porque quem chama `add_child` pode ainda
	# estar montando a cena.
	var parent: Node = get_parent()
	if parent != null:
		parent.move_child.call_deferred(self, 0)


## Liga o picker a mesa. `play_plane_y` e a altura do plano onde a peca
## desliza enquanto arrastada. Se `environment` emite `framing_changed`,
## reprojeta a cada enquadramento.
func attach(environment: Node3D, play_plane_y: float = 0.0) -> void:
	_env = environment
	_plane_y = play_plane_y
	if _env != null and _env.has_signal("framing_changed"):
		if not _env.is_connected("framing_changed", _on_framing_changed):
			_env.connect("framing_changed", _on_framing_changed)
	refresh_projection.call_deferred()


func set_camera(camera: Camera3D) -> void:
	_camera = camera
	refresh_projection()


func set_play_plane(y: float) -> void:
	_plane_y = y


func _on_framing_changed(_size: Variant = null) -> void:
	refresh_projection()


## `{id: Vector3}` em MUNDO, ou `{id: [Vector3, ...]}` para alvo comprido
## (a ponta do gamao tem cinco casas enfileiradas). `id` e Variant de
## proposito: Vector2i numa grade, int nos pinos; volta igual nos sinais.
func set_targets(targets: Dictionary) -> void:
	_targets.clear()
	for id: Variant in targets:
		_targets[id] = _samples(targets[id])
	refresh_projection()


static func _samples(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate()
	return [value]


func move_target(id: Variant, world_pos: Vector3) -> void:
	if not _targets.has(id):
		return
	_targets[id] = [world_pos]
	refresh_projection()


func clear_targets() -> void:
	_targets.clear()
	_screen.clear()


func radius() -> float:
	return _radius


## Reprojeta tudo. Publico para quem mexe na camera a mao.
func refresh_projection() -> void:
	_screen.clear()
	var proj: Callable = _projector()
	if not proj.is_valid():
		return
	for id: Variant in _targets:
		var points: Array = []
		for world: Variant in _targets[id]:
			var p: Vector2 = proj.call(world as Vector3)
			if p != Vector2.INF:
				points.append(p)
		if not points.is_empty():
			_screen[id] = points
	_recompute_radius()


func _recompute_radius() -> void:
	# A distancia que importa e entre amostras de alvos DIFERENTES.
	var smallest: float = INF
	var ids: Array = _screen.keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			for a: Variant in _screen[ids[i]]:
				for b: Variant in _screen[ids[j]]:
					var d: float = (a as Vector2).distance_to(b as Vector2)
					if d > 0.0:
						smallest = minf(smallest, d)
	if smallest == INF:
		_radius = RADIUS_MAX
		return
	_radius = clampf(smallest * RADIUS_FRACTION, RADIUS_MIN, RADIUS_MAX)


## O alvo mais proximo do ponto, ou `null` se nenhum esta dentro do raio.
func target_at(screen_point: Vector2) -> Variant:
	var best: Variant = null
	var best_d: float = _radius
	for id: Variant in _screen:
		for p: Variant in _screen[id]:
			var d: float = (p as Vector2).distance_to(screen_point)
			if d < best_d:
				best_d = d
				best = id
	return best


func screen_of(id: Variant) -> Vector2:
	if not _screen.has(id):
		return Vector2.INF
	return (_screen[id] as Array)[0]


## O ponto do plano de jogo sob um ponto da tela. `Vector3.INF` atras da camera.
func world_at(screen_point: Vector2) -> Vector3:
	if unprojector.is_valid():
		return unprojector.call(screen_point)
	var cam: Camera3D = _find_camera()
	if cam == null:
		return Vector3.INF
	var origin: Vector3 = cam.project_ray_origin(screen_point)
	var dir: Vector3 = cam.project_ray_normal(screen_point)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t: float = (_plane_y - origin.y) / dir.y
	if t < 0.0:
		return Vector3.INF
	return origin + dir * t


func cancel_drag() -> void:
	_press_id = null
	_dragging = false


func is_dragging() -> bool:
	return _dragging


func _projector() -> Callable:
	if projector.is_valid():
		return projector
	var cam: Camera3D = _find_camera()
	if cam == null:
		return Callable()
	return func(world: Vector3) -> Vector2:
		if cam.is_position_behind(world):
			return Vector2.INF
		return cam.unproject_position(world)


func _find_camera() -> Camera3D:
	if _camera != null and is_instance_valid(_camera):
		return _camera
	if _env != null and is_instance_valid(_env):
		for child: Node in _env.get_children():
			if child is Camera3D:
				return child as Camera3D
	if not is_inside_tree():
		return null
	var vp: Viewport = get_viewport()
	return vp.get_camera_3d() if vp != null else null


func _on_gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	feed(event)


## Publico para a suite e para quem coleta o evento em outro lugar.
func feed(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_accept()
		if mb.pressed:
			_begin(mb.position)
		else:
			_end(mb.position)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		_accept()
		if st.pressed:
			_begin(st.position)
		else:
			_end(st.position)
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if _press_id == null:
			return
		_accept()
		_move((event as InputEventFromWindow).get("position"))


func _accept() -> void:
	if is_inside_tree():
		accept_event()


func _begin(point: Vector2) -> void:
	_press_id = target_at(point)
	_press_pos = point
	_dragging = false


func _move(point: Vector2) -> void:
	if not _dragging:
		if point.distance_to(_press_pos) < DRAG_THRESHOLD:
			return
		_dragging = true
		drag_started.emit(_press_id)
	drag_moved.emit(_press_id, target_at(point), world_at(point))


func _end(point: Vector2) -> void:
	var origin: Variant = _press_id
	var dragged: bool = _dragging
	_press_id = null
	_dragging = false
	if origin == null:
		return
	if dragged:
		drag_ended.emit(origin, target_at(point))
	else:
		target_tapped.emit(origin)
