class_name CellHalo3D
extends MultiMeshInstance3D

## Anel de estado para quem não tem `Board3D`.
##
## Mancala, Ludo, Gamão, Hanói, Nim e Resta Um desenham os próprios tabuleiros e
## por isso não herdavam nada do marcador em grade -- cada um montava os anéis à
## mão (o Hanói três toros, o Nim um por pilha, o Resta Um recolorindo as 33
## cavidades) e o Mancala não tinha afordância nenhuma: não havia como saber
## quais covas dava para tocar.
##
## Aqui o anel é o MESMO do `Board3D`: mesma forma, mesmas cores de `Tokens3D` e
## o mesmo `StateShader3D`. Quem joga vê um sinal só no aplicativo inteiro, e
## quando ele precisar mudar, muda num lugar.
##
## É um `MultiMeshInstance3D` porque o alvo aceso e o apagado são a mesma malha
## com outra cor: N alvos custam uma chamada de desenho, e acender ou apagar não
## cria material nenhum. `MaterialFactory3D.get_state_overlay()` cacheia POR COR,
## então um halo que pulsa criava um material por quadro.
##
## Uso:
##
##     var halos := CellHalo3D.new()
##     add_child(halos)
##     halos.setup(6, 0.42)
##     halos.set_targets(posicoes_das_covas)
##     halos.light_only([0, 2, 5])          # as covas que dão para semear

enum Shape {
	RING,  ## Anel vazado: marca a casa sem cobrir o que está nela.
	DISC,  ## Disco cheio: para alvo pequeno, onde o anel fecharia num ponto.
	FRAME, ## Moldura retangular vazada: o anel de quem tem alvo comprido (a canaleta do Nim).
}

## Altura do anel sobre o ponto do alvo. Baixo o bastante para pousar na
## superfície, alto o bastante para não brigar em z com ela.
const ALTURA := 0.02

## Espessura do anel como fração do raio.
const ESPESSURA := 0.16

var _positions: Array[Vector3] = []
var _colors: Array[Color] = []
var _pulse: Tween = null
var _pulse_index: int = -1


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = StateShader3D.marker()


## Prepara `count` alvos apagados.
##
## Refaz o MultiMesh inteiro: chame quando o NÚMERO de alvos muda (o Nim troca
## de preset, o Ludo troca de jogador), não a cada jogada.
func setup(count: int, radius: float = 0.34, shape: int = Shape.RING) -> void:
	_setup_with_mesh(count, _build_mesh(radius, shape))


## Prepara `count` alvos retangulares de `size` (largura em X, comprimento em
## Z). E o anel de quem marca uma faixa inteira, e nao uma casa: a canaleta do
## Nim tem sete pecas de comprimento, e um anel redondo ou cobriria uma peca ou
## sairia da mesa.
func setup_frames(count: int, size: Vector2) -> void:
	_setup_with_mesh(count, _build_frame(size))


func _setup_with_mesh(count: int, mesh: Mesh) -> void:
	stop_pulse()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = maxi(count, 0)
	mm.visible_instance_count = 0
	multimesh = mm

	_positions.clear()
	_colors.clear()
	for i in count:
		_positions.append(Vector3.ZERO)
		_colors.append(Color.TRANSPARENT)


## Moldura vazada no plano XZ, virada para cima. A borda tem a mesma fracao do
## anel (`ESPESSURA` do menor lado), para as duas formas lerem como o mesmo sinal.
func _build_frame(size: Vector2) -> Mesh:
	var meia: Vector2 = size * 0.5
	var borda: float = minf(size.x, size.y) * 0.5 * ESPESSURA
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Quatro faixas: as duas ao longo de Z ocupam a altura inteira, as duas ao
	# longo de X preenchem o que sobra entre elas.
	var faixas: Array[Rect2] = [
		Rect2(-meia.x, -meia.y, borda, size.y),
		Rect2(meia.x - borda, -meia.y, borda, size.y),
		Rect2(-meia.x + borda, -meia.y, size.x - 2.0 * borda, borda),
		Rect2(-meia.x + borda, meia.y - borda, size.x - 2.0 * borda, borda),
	]
	for f in faixas:
		var a := Vector3(f.position.x, 0.0, f.position.y)
		var b := Vector3(f.end.x, 0.0, f.position.y)
		var c := Vector3(f.end.x, 0.0, f.end.y)
		var d := Vector3(f.position.x, 0.0, f.end.y)
		# Sentido horario visto de cima: e a face da frente para o `cull_back`
		# do StateShader3D, a mesma ordem que o conves do `ship_hull()` usa.
		for v in [a, b, c, a, c, d]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


func _build_mesh(radius: float, shape: int) -> Mesh:
	if shape == Shape.DISC:

		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.012
		disc.radial_segments = Quality3D.radial_segments(28)
		disc.rings = 1
		return disc

	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = radius * (1.0 - ESPESSURA)
	ring.outer_radius = radius
	# `rings` são as fatias em volta do anel e `ring_segments` as arestas da
	# seção do tubo -- nessa ordem. Trocados, o anel sai como um losango, que foi
	# o que aconteceu no `Board3D` e o que o jogador via como "losango branco".
	ring.rings = Quality3D.radial_segments(28)
	ring.ring_segments = 6
	return ring


## Onde cada alvo fica, em coordenadas locais ao pai deste nó.
func set_targets(positions: Array) -> void:
	if positions.size() != _positions.size():
		setup(positions.size())
	for i in positions.size():
		_positions[i] = positions[i]
	_refresh()


## Move um alvo só, sem mexer nos outros. O topo da pilha do Hanói sobe a cada
## disco, e refazer os três a cada movimento seria desperdício.
func move_target(index: int, position_3d: Vector3) -> void:
	if index < 0 or index >= _positions.size():
		return
	_positions[index] = position_3d
	_refresh()


## Acende um alvo. `Color.TRANSPARENT` apaga.
func light(index: int, color: Color = Tokens3D.COLOR_VALID) -> void:
	if index < 0 or index >= _colors.size():
		return
	_colors[index] = color
	_refresh()


## Acende estes e apaga o resto -- o caso comum de "estes são os destinos
## legais desta jogada".
func light_only(indices: Array, color: Color = Tokens3D.COLOR_VALID) -> void:
	stop_pulse()
	for i in _colors.size():
		_colors[i] = color if i in indices else Color.TRANSPARENT
	_refresh()


func clear() -> void:
	stop_pulse()
	for i in _colors.size():
		_colors[i] = Color.TRANSPARENT
	_refresh()


## A cor pedida para um alvo (`Color.TRANSPARENT` apagado). E o registro deste
## no, nao o do RenderingServer: em modo headless o MultiMesh nao devolve o que
## recebeu, e e por aqui que a suite confere o estado.
func color_of(index: int) -> Color:
	if index < 0 or index >= _colors.size():
		return Color.TRANSPARENT
	return _colors[index]


func position_of(index: int) -> Vector3:
	if index < 0 or index >= _positions.size():
		return Vector3.INF
	return _positions[index]


func target_count() -> int:
	return _positions.size()


## Pulso de atenção, para a dica: um alvo pisca até alguém tocá-lo. Só um por
## vez -- dois pulsando ao mesmo tempo deixam de apontar para alguma coisa.
func pulse(index: int, color: Color = Tokens3D.COLOR_HINT) -> void:
	stop_pulse()
	if index < 0 or index >= _colors.size():
		return
	_pulse_index = index
	_colors[index] = color
	_refresh()
	if Quality3D.reduced_motion():
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_method(_set_pulse_alpha, 1.0, 0.25, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_method(_set_pulse_alpha, 0.25, 1.0, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func stop_pulse() -> void:
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	_pulse_index = -1


func _set_pulse_alpha(a: float) -> void:
	if _pulse_index < 0 or _pulse_index >= _colors.size():
		return
	var c: Color = _colors[_pulse_index]
	c.a = a
	_colors[_pulse_index] = c
	_refresh()


func _refresh() -> void:
	if multimesh == null:
		return
	var n := 0
	for i in _positions.size():
		var cor: Color = _colors[i]
		if cor.a <= 0.0:
			continue
		multimesh.set_instance_transform(n,
			Transform3D(Basis.IDENTITY, _positions[i] + Vector3(0.0, ALTURA, 0.0)))
		multimesh.set_instance_color(n, cor)
		n += 1
	multimesh.visible_instance_count = n
