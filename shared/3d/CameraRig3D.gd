class_name CameraRig3D
extends Camera3D

## CameraRig3D: Camera que enquadra o conteudo do jogo em vez de ficar parada.
##
## O problema que ela resolve: `fov` no Godot e o angulo VERTICAL. Em retrato
## (720x1280) o angulo horizontal correspondente e quase metade, entao uma
## camera com distancia fixa corta as laterais do tabuleiro. Aqui a distancia
## sai do tamanho real do conteudo e da proporcao da janela, e nao de um numero
## escrito a mao.
##
## Tambem respeita a area util: a HUD ocupa o topo e o rodape, e o tabuleiro
## precisa ficar centrado na faixa que sobra, nao no centro geometrico da tela.

## Regiao do mundo que precisa caber na tela (em unidades, no plano XZ).
@export var content_size: Vector2 = Vector2(6.0, 6.0):
	set(value):
		content_size = value
		_dirty = true

## Inclinacao preferida em graus acima do plano da mesa. 90 = totalmente de cima.
## E um piso, nao um valor fixo: quando a tela e estreita a plataforma pode
## inclinar mais para aproveitar a altura que sobraria vazia.
@export_range(20.0, 90.0, 0.5) var tilt_degrees: float = Tokens3D.CAM_TILT_BOARD:
	set(value):
		tilt_degrees = value
		_dirty = true

## Limite de quanto o enquadramento automatico pode subir a camera.
@export_range(20.0, 89.0, 0.5) var max_auto_tilt: float = 70.0:
	set(value):
		max_auto_tilt = value
		_dirty = true

## Ponto do mundo que o enquadramento deve conter (centro do tabuleiro).
@export var focus_point: Vector3 = Vector3.ZERO:
	set(value):
		focus_point = value
		_dirty = true

## Faixa da tela ocupada pela HUD, em pixels do viewport logico (720x1280).
@export var safe_top_px: float = 190.0:
	set(value):
		safe_top_px = value
		_dirty = true

@export var safe_bottom_px: float = 120.0:
	set(value):
		safe_bottom_px = value
		_dirty = true

## Folga extra ao redor do conteudo.
@export var margin: float = Tokens3D.CAM_MARGIN:
	set(value):
		margin = value
		_dirty = true

var _dirty: bool = true
var _base_position: Vector3
var _base_target: Vector3
var _offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	fov = Tokens3D.CAM_FOV
	keep_aspect = Camera3D.KEEP_HEIGHT
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_on_viewport_resized)
	_apply_framing()

func _on_viewport_resized() -> void:
	_dirty = true
	_apply_framing()

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_dirty = true

## Reenquadra para um conteudo de `size_xz` unidades centrado em `center`.
func frame_content(size_xz: Vector2, center: Vector3 = Vector3.ZERO, tilt: float = -1.0) -> void:
	content_size = size_xz
	focus_point = center
	if tilt > 0.0:
		tilt_degrees = tilt
	_apply_framing()

## Define a area util a partir da HUD real do jogo.
func set_safe_area(top_px: float, bottom_px: float) -> void:
	safe_top_px = top_px
	safe_bottom_px = bottom_px
	_apply_framing()

func _apply_framing() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size := vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	var aspect := vp_size.x / vp_size.y

	# Fracao da altura da tela que sobra entre a HUD de cima e a de baixo.
	var safe_h := maxf(vp_size.y - safe_top_px - safe_bottom_px, vp_size.y * 0.35)
	var safe_fraction := safe_h / vp_size.y

	var half_v := tan(deg_to_rad(fov) * 0.5)
	var half_h := half_v * aspect

	var base_tilt := clampf(tilt_degrees, 20.0, 89.0)
	var need_w := content_size.x * 0.5 * margin
	var depth_half := content_size.y * 0.5 * margin

	# A borda de perto do tabuleiro nao esta na distancia do foco: esta
	# `depth_half * cos(tilt)` mais perto da camera, e por isso projeta MAIS
	# larga e MAIS alta que o centro. Dimensionar pelo plano do foco fazia o
	# tabuleiro vazar pela borda de baixo da tela; a folga de 12% em volta do
	# conteudo existia so para esconder isso, e comia tela nos jogos em que a
	# mesa era rasa. Agora a conta e feita na borda que realmente encosta.
	var dist_w := func(tilt: float) -> float:
		return need_w / maxf(half_h, 0.0001) + depth_half * cos(deg_to_rad(tilt))

	var dist_for_width: float = dist_w.call(base_tilt)

	# Em retrato a largura quase sempre manda. Se ela manda, sobra altura de
	# tela sem uso -- entao inclina mais a camera ate a profundidade projetada
	# encostar na faixa util. O tabuleiro cresce sem sair do enquadramento.
	if depth_half > 0.0001:
		# `sin_needed >= 1` significa que nem deitando a camera de todo a
		# profundidade encosta na faixa util -- e o caso do tabuleiro quadrado
		# em tela de retrato. Antes isso fazia o enquadramento DESISTIR de
		# inclinar e o tabuleiro ficava com 45% da altura util em branco.
		# Inclinar mais sempre ajuda: aumenta a profundidade projetada e ainda
		# aproxima a camera. Entao o caso sem solucao vai ate o limite.
		var sin_needed := (dist_for_width * half_v * safe_fraction) / depth_half
		var balanced := rad_to_deg(asin(clampf(sin_needed, 0.0, 1.0)))
		base_tilt = clampf(maxf(base_tilt, balanced), base_tilt, max_auto_tilt)
		dist_for_width = dist_w.call(base_tilt)

	var tilt_rad := deg_to_rad(base_tilt)
	var dist_for_depth := depth_half * sin(tilt_rad) / maxf(half_v * safe_fraction, 0.0001) \
		+ depth_half * cos(tilt_rad)
	var dist := maxf(dist_for_width, dist_for_depth)
	dist = maxf(dist, 1.0)

	_base_target = focus_point
	_base_position = focus_point + Vector3(
		0.0,
		dist * sin(tilt_rad),
		dist * cos(tilt_rad)
	)

	# Recentra o conteudo na faixa util: mover a camera para cima empurra a
	# imagem para baixo, que e o lado onde sobra espaco quando a HUD e alta.
	var world_h := 2.0 * dist * half_v
	var shift_px := (safe_top_px - safe_bottom_px) * 0.5
	var shift_world := (shift_px / vp_size.y) * world_h

	var forward := (_base_target - _base_position).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()

	_base_position += up * shift_world
	_base_target += up * shift_world

	_dirty = false
	_commit()

func _commit() -> void:
	position = _base_position + _offset
	var target := _base_target + _offset
	if position.distance_squared_to(target) > 0.0001:
		look_at(target, Vector3.UP)

## Deslocamento cinematografico curto, para chamar atencao a uma jogada.
## Deliberadamente pequeno: a partida nao vira um plano de acao.
func nudge_toward(world_point: Vector3, strength: float = 0.16) -> void:
	if Quality3D.reduced_motion():
		return
	var dir := (world_point - _base_target)
	dir.y = 0.0
	var target_offset := dir.limit_length(1.0) * strength
	var tw := create_tween()
	Tokens3D.ease_travel(tw)
	tw.tween_method(_set_offset, _offset, target_offset, Tokens3D.DUR_SLOW)
	tw.tween_interval(0.35)
	tw.tween_method(_set_offset, target_offset, Vector3.ZERO, Tokens3D.DUR_SLOW * 1.4)

func _set_offset(value: Vector3) -> void:
	_offset = value
	_commit()

## Devolve a camera ao repouso imediatamente.
func reset_offset() -> void:
	_offset = Vector3.ZERO
	_commit()
