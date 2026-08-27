class_name PipFactory3D
extends RefCounted

## PipFactory3D: os pontos gravados no dado e na pedra de domino.
##
## Ate aqui o dado do Gamao era um cubo de marfim liso e a pedra de domino um
## retangulo liso: sem os pontos nao da para ler o valor, e o jogador fica sem
## saber o que rolou nem que pedra tem na mao.
##
## Cada conjunto de pontos e UM MultiMeshInstance3D, nao um no por ponto: um
## dado tem 21 pontos e uma pedra ate 12; com 30 pecas em mesa isso seria
## centenas de nos. Um MultiMesh e uma chamada de desenho por peca.
##
## O ponto e uma calota rebaixada (esfera achatada afundada na face), nao um
## disco colado: peca de resina de verdade tem o ponto escavado e pintado, e a
## sombra dentro da cavidade e o que faz ele existir sob qualquer luz.

## Distancia do centro do ponto ate a borda da face, em fracao da face.
const PIP_INSET := 0.26

## Raio do ponto em fracao do lado menor da face.
const PIP_RADIUS := 0.125

## Quanto o ponto afunda na face, em fracao do proprio raio.
const PIP_SINK := 0.30

## Arranjo dos pontos de cada valor, em coordenadas de face -1..1.
const FACE_LAYOUT := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0),
		Vector2(-1, 1), Vector2(1, 1)],
}

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}

## Valor impresso em cada face, pelo eixo da normal.
##
## Nao e arbitrario: e o inverso exato de Dice3D.FACE_ROTATIONS, que gira o dado
## para deixar um valor para cima. Girar 90 graus em +Z traz a face +X para
## cima, e FACE_ROTATIONS diz que esse giro mostra o 2 -- logo o 2 mora em +X.
## Mudar um dos dois sem o outro faz o dado parar mostrando a face errada.
## Faces opostas somam sete, como em dado de verdade.
const DICE_FACES := {
	Vector3.UP: 1,       # rotacao (0, 0, 0)
	Vector3.DOWN: 6,     # rotacao (PI, 0, 0)
	Vector3.RIGHT: 2,    # rotacao (0, 0, PI/2)
	Vector3.LEFT: 5,     # rotacao (0, 0, -PI/2)
	Vector3.BACK: 3,     # rotacao (-PI/2, 0, 0)
	Vector3.FORWARD: 4,  # rotacao (PI/2, 0, 0)
}


## Pontos das seis faces de um dado de lado `size`.
static func dice_pips(size: float, color: Color = Color(0.09, 0.09, 0.11)) -> MultiMeshInstance3D:
	return _build(dice_pip_transforms(size), color)


## Onde fica cada ponto do dado, antes de virar no.
##
## Separado do `_build` de proposito: a partir do momento que os pontos entram
## num MultiMesh eles moram no servidor de renderizacao, e ler de volta com
## `get_instance_transform` no mesmo quadro devolve identidade. Quem confere o
## arranjo -- os testes -- confere aqui.
static func dice_pip_transforms(size: float) -> Array[Transform3D]:
	var half := size * 0.5
	var radius: float = size * PIP_RADIUS
	var spread: float = half * (1.0 - PIP_INSET * 2.0)
	var faces := DICE_FACES

	var transforms: Array[Transform3D] = []
	for normal in faces:
		var value: int = faces[normal]
		var basis := _face_basis(normal)
		var center: Vector3 = normal * (half - radius * PIP_SINK)
		for slot in FACE_LAYOUT[value]:
			var offset: Vector3 = basis.x * (slot.x * spread) + basis.z * (slot.y * spread)
			transforms.append(Transform3D(basis.scaled(Vector3(radius, radius, radius)),
				center + offset))

	return transforms


## Pontos da face de cima de uma pedra de domino deitada no plano XZ.
##
## A pedra e mais comprida em Z (o eixo que MeshBuilder3D.domino_tile usa como
## comprimento): a metade `value_a` fica em -Z e a `value_b` em +Z.
static func domino_pips(value_a: int, value_b: int, length: float, width: float,
		thickness: float, color: Color = Color(0.12, 0.10, 0.10)) -> MultiMeshInstance3D:
	return _build(domino_pip_transforms(value_a, value_b, length, width, thickness), color)


## Onde fica cada ponto da pedra. Ver a nota em `dice_pip_transforms`.
static func domino_pip_transforms(value_a: int, value_b: int, length: float,
		width: float, thickness: float) -> Array[Transform3D]:
	var radius: float = width * PIP_RADIUS * 1.5
	var half_len := length * 0.25       # centro de cada metade
	var spread_x: float = width * 0.5 * (1.0 - PIP_INSET * 2.0)
	var spread_z: float = half_len * (1.0 - PIP_INSET * 2.0)
	var y: float = thickness * 0.5 - radius * PIP_SINK

	var transforms: Array[Transform3D] = []
	for par in [[value_a, -half_len], [value_b, half_len]]:
		var value: int = clampi(par[0], 0, 6)
		if value == 0:
			continue
		var center_z: float = par[1]
		for slot in FACE_LAYOUT[value]:
			var pos := Vector3(slot.x * spread_x, y, center_z + slot.y * spread_z)
			transforms.append(Transform3D(Basis().scaled(Vector3(radius, radius, radius)), pos))

	return transforms


## Vinco central da pedra: a linha gravada que separa as duas metades.
static func domino_divider(length: float, width: float, thickness: float) -> MeshInstance3D:
	var groove := BoxMesh.new()
	groove.size = Vector3(width * 0.86, thickness * 0.06, length * 0.035)
	var inst := MeshInstance3D.new()
	inst.name = "Divider"
	inst.mesh = groove
	inst.position = Vector3(0.0, thickness * 0.5 - thickness * 0.02, 0.0)
	inst.material_override = MaterialFactory3D.get_bronze()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


# ---------------------------------------------------------------------------
# Interno
# ---------------------------------------------------------------------------

## Base ortonormal cujo Y aponta para fora da face: X e Z varrem a face.
##
## O Z tem de ser X cross Y, nao Y cross X. Com a ordem invertida a base sai com
## determinante -1 -- espelhada -- e a malha do ponto renderiza com a face
## virada para dentro: o backface culling comia os 21 pontos e o dado
## continuava um cubo branco liso, com o MultiMesh no lugar certo e tudo.
static func _face_basis(normal: Vector3) -> Basis:
	var up := normal
	var reference := Vector3.BACK if absf(up.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
	var right := reference.cross(up).normalized()
	var forward := right.cross(up).normalized()
	return Basis(right, up, forward)


static func _build(transforms: Array[Transform3D], color: Color) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Pips"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _pip_mesh()
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	mmi.multimesh = mm
	mmi.material_override = _pip_material(color)
	# O ponto e pequeno demais para a sombra dele ler; desligada, some uma
	# passada de sombra por peca em mesas com 30 pecas.
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## Calota de raio 1, achatada: o ponto e mais largo que fundo.
static func _pip_mesh() -> Mesh:
	var key := "pip_%d" % Quality3D.tier()
	if _mesh_cache.has(key):
		return _mesh_cache[key] as Mesh
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.1
	sphere.radial_segments = 6 if Quality3D.tier() == Quality3D.Tier.LOW else 10
	sphere.rings = 3 if Quality3D.tier() == Quality3D.Tier.LOW else 5
	_mesh_cache[key] = sphere
	return sphere


static func _pip_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.34
	mat.metallic = 0.0
	mat.metallic_specular = 0.4
	_material_cache[key] = mat
	return mat


static func clear_cache() -> void:
	_mesh_cache.clear()
	_material_cache.clear()
