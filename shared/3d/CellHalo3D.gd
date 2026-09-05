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
}

## Altura do anel sobre o ponto do alvo. Baixo o bastante para pousar na
## superfície, alto o bastante para não brigar em z com ela.
const ALTURA := 0.02

## Espessura do anel como fração do raio.
const ESPESSURA := 0.22

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
	stop_pulse()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _build_mesh(radius, shape)
	mm.instance_count = maxi(count, 0)
	mm.visible_instance_count = 0
	multimesh = mm

	_positions.clear()
	_colors.clear()
	for i in count:
		_positions.append(Vector3.ZERO)
		_colors.append(Color.TRANSPARENT)


func _build_mesh(radius: float, shape: int) -> Mesh:
	if shape == Shape.DISC:
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.012
		disc.radial_segments = Quality3D.radial_segments(28)
		disc.rings = 1
		return disc

	var ring := TorusMesh.new()
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
