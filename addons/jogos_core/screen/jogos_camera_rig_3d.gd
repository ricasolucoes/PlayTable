class_name JogosCameraRig3D
extends Camera3D

## Camera que enquadra o conteudo em vez de ficar parada.
##
## Fonte: PlayTable `shared/3d/CameraRig3D.gd`. Tirado: as constantes de
## `Tokens3D` (viraram `@export`), `Quality3D.reduced_motion()` (agora le
## `AppSettings` via JogosLocator, se existir). A conta mora em
## `JogosScreenFit.fit_3d`; aqui so estado e aplicacao.
##
## `fov` no Godot e o angulo VERTICAL: em retrato o horizontal e quase metade
## e uma camera de distancia fixa corta as laterais. A distancia sai do tamanho
## real do conteudo e da proporcao da janela. A HUD ocupa topo e rodape, e o
## conteudo fica centrado na faixa que sobra, nao no centro da tela.

## Regiao do mundo que precisa caber (unidades, plano XZ).
@export var content_size: Vector2 = Vector2(6.0, 6.0):
	set(value):
		content_size = value
		_apply_framing()

## Inclinacao preferida em graus acima do plano. E piso: tela estreita inclina
## mais para aproveitar a altura. 52 = tabuleiro, 44 = cartas, 58 = trilha.
@export_range(20.0, 89.0, 0.5) var tilt_degrees: float = 52.0:
	set(value):
		tilt_degrees = value
		_apply_framing()

## Teto do enquadramento automatico. Tabuleiro aceita quase de cima; mesa de
## carteado nao, senao a face da carta achata.
@export_range(20.0, 89.0, 0.5) var max_auto_tilt: float = 70.0:
	set(value):
		max_auto_tilt = value
		_apply_framing()

@export var focus_point: Vector3 = Vector3.ZERO:
	set(value):
		focus_point = value
		_apply_framing()

## Folga ao redor do conteudo (1,04 = 4%).
@export_range(1.0, 1.5, 0.01) var margin: float = 1.0 + JogosScreenFit.DEFAULT_SLACK:
	set(value):
		margin = value
		_apply_framing()

@export_range(20.0, 90.0, 0.5) var fov_degrees: float = 42.0

## Duracao do "nudge", em segundos.
@export var nudge_duration: float = 0.55

var _usable: Rect2 = Rect2()
var _has_usable: bool = false
var _base_position: Vector3 = Vector3.ZERO
var _base_target: Vector3 = Vector3.ZERO
var _offset: Vector3 = Vector3.ZERO
var _last_fit: Dictionary = {}


func _ready() -> void:
	fov = fov_degrees
	keep_aspect = Camera3D.KEEP_HEIGHT
	JogosScreenFit.watch_resize(self, _apply_framing)
	_apply_framing()


## Reenquadra para `size_xz` unidades centradas em `center`.
func frame_content(size_xz: Vector2, center: Vector3 = Vector3.ZERO, tilt: float = -1.0) -> void:
	content_size = size_xz
	focus_point = center
	if tilt > 0.0:
		tilt_degrees = tilt
	_apply_framing()


## Area util em pixels do viewport, como `JogosScreenFit.usable_rect` mede.
func set_usable_rect(usable: Rect2) -> void:
	_usable = usable
	_has_usable = usable.size.x > 0.0 and usable.size.y > 0.0
	_apply_framing()


## Compatibilidade com o PlayTable: faixas de HUD em pixels (topo, rodape).
func set_safe_area(top_px: float, bottom_px: float) -> void:
	var vp: Vector2 = _viewport_size()
	set_usable_rect(JogosScreenFit.shrink_by_bands(Rect2(Vector2.ZERO, vp), top_px, bottom_px))


func last_fit() -> Dictionary:
	return _last_fit


func _viewport_size() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	var vp: Viewport = get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2.ZERO


func _apply_framing() -> void:
	if not is_inside_tree():
		return
	var vp_size: Vector2 = _viewport_size()
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var usable: Rect2 = _usable if _has_usable else Rect2(Vector2.ZERO, vp_size)
	_last_fit = JogosScreenFit.fit_3d(content_size, usable, vp_size, fov, tilt_degrees, max_auto_tilt, margin)
	var pose: Dictionary = JogosScreenFit.camera_pose(focus_point, _last_fit)
	_base_position = pose["position"]
	_base_target = pose["target"]
	_commit()


func _commit() -> void:
	position = _base_position + _offset
	var target: Vector3 = _base_target + _offset
	if position.distance_squared_to(target) > 0.0001:
		look_at(target, Vector3.UP)


## Deslocamento cinematografico curto para chamar atencao a uma jogada.
## Pequeno de proposito: a partida nao vira plano de acao.
func nudge_toward(world_point: Vector3, strength: float = 0.16) -> void:
	if _reduced_motion():
		return
	var dir: Vector3 = world_point - _base_target
	dir.y = 0.0
	var target_offset: Vector3 = dir.limit_length(1.0) * strength
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_offset, _offset, target_offset, nudge_duration)
	tw.tween_interval(0.35)
	tw.tween_method(_set_offset, target_offset, Vector3.ZERO, nudge_duration * 1.4)


func _set_offset(value: Vector3) -> void:
	_offset = value
	_commit()


func reset_offset() -> void:
	_offset = Vector3.ZERO
	_commit()


func _reduced_motion() -> bool:
	var settings: Node = JogosLocator.autoload(&"AppSettings")
	if settings != null and settings.has_method("get_value"):
		return bool(settings.call("get_value", "reduced_motion"))
	return false
