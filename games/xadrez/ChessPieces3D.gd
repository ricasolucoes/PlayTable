class_name ChessPieces3D
extends RefCounted

## As seis silhuetas do xadrez sobre o Token3D.
##
## A meio metro do rosto, num telefone, a peca tem uns 60 px de altura: o que
## separa uma da outra e a FORMA GRANDE, nao o detalhe. Cada tipo ganha um
## perfil torneado proprio (`MeshBuilder3D.revolve`) e, quando a silhueta
## sozinha nao chega, um enfeite: coroa e bola na dama, cruz no rei, cabeca
## inclinada no cavalo. O peao e o proprio "pawn" do Token3D.
##
## O Token3D continua dono do movimento, da elevacao, da sombra de contato e
## do material: aqui so se troca a malha depois de o token entrar na arvore.

const TOKEN_SCENE := preload("res://shared/3d/Token3D.tscn")

## Raio da base e altura do corpo torneado, por tipo (indice = codigo da peca).
const RAIO := PackedFloat32Array([0.0, 0.17, 0.19, 0.19, 0.21, 0.22, 0.22])
const ALTURA := PackedFloat32Array([0.0, 0.44, 0.60, 0.72, 0.56, 0.82, 0.92])

static var _malhas: Dictionary = {}


## O token da peca, ainda fora da arvore. Quem chama posiciona e pendura.
static func criar(tipo: int, side: int) -> Token3D:
	var tok: Token3D = TOKEN_SCENE.instantiate()
	tok.token_type = "pawn" if tipo == ChessRules.PAWN else "cylinder"
	tok.token_radius = RAIO[tipo]
	tok.material_name = "ivory" if side > 0 else "obsidian"
	# O cavalo olha para o adversario: a peca preta nasce virada.
	if side < 0:
		tok.rotation.y = PI
	return tok


## Troca o disco do Token3D pela silhueta do tipo. So depois de `add_child`:
## e o `_ready` do token que cria o MeshInstance3D e aplica o material.
static func vestir(tok: Token3D, tipo: int) -> void:
	if tipo == ChessRules.PAWN or tok.mesh_instance == null:
		return
	var mi := tok.mesh_instance
	mi.mesh = malha(tipo)
	for enfeite in _enfeites(tipo):
		enfeite.material_override = mi.material_override
		mi.add_child(enfeite)


static func malha(tipo: int) -> ArrayMesh:
	var chave := tipo * 10 + Quality3D.tier()
	if _malhas.has(chave):
		return _malhas[chave]
	var r: float = RAIO[tipo]
	var h: float = ALTURA[tipo]
	var perfil: PackedVector2Array
	match tipo:
		ChessRules.ROOK:
			perfil = _perfil_torre(r, h)
		ChessRules.KNIGHT:
			perfil = _perfil_cavalo(r, h)
		ChessRules.BISHOP:
			perfil = _perfil_bispo(r, h)
		ChessRules.QUEEN:
			perfil = _perfil_dama(r, h)
		_:
			perfil = _perfil_rei(r, h)
	var mesh := MeshBuilder3D.revolve(perfil, Quality3D.radial_segments(28))
	_malhas[chave] = mesh
	return mesh


## Pe comum a todas: um disco largo com chanfro, para a peca nao parecer
## fincada na casa.
static func _pe(r: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r * 0.92, 0.0),
		Vector2(r, h * 0.04),
		Vector2(r, h * 0.12),
	])


## Torre: corpo largo e reto, topo chato com o rebaixo de uma ameia.
static func _perfil_torre(r: float, h: float) -> PackedVector2Array:
	var p := _pe(r, h)
	p.append_array(PackedVector2Array([
		Vector2(r * 0.78, h * 0.20),
		Vector2(r * 0.66, h * 0.28),
		Vector2(r * 0.66, h * 0.70),
		Vector2(r * 0.84, h * 0.78),
		Vector2(r * 0.92, h * 0.84),
		Vector2(r * 0.92, h),
		Vector2(r * 0.62, h),
		Vector2(r * 0.62, h * 0.90),
	]))
	return p


## Cavalo: so o pescoco torneado; a cabeca e um bloco inclinado a parte.
static func _perfil_cavalo(r: float, h: float) -> PackedVector2Array:
	var p := _pe(r, h)
	p.append_array(PackedVector2Array([
		Vector2(r * 0.74, h * 0.20),
		Vector2(r * 0.48, h * 0.30),
		Vector2(r * 0.40, h * 0.42),
		Vector2(r * 0.44, h * 0.52),
		Vector2(r * 0.52, h * 0.58),
	]))
	return p


## Bispo: alto e fino, com um colar e a mitra em gota.
static func _perfil_bispo(r: float, h: float) -> PackedVector2Array:
	var p := _pe(r, h)
	p.append_array(PackedVector2Array([
		Vector2(r * 0.72, h * 0.20),
		Vector2(r * 0.44, h * 0.30),
		Vector2(r * 0.36, h * 0.44),
		Vector2(r * 0.40, h * 0.54),
		Vector2(r * 0.56, h * 0.58),
		Vector2(r * 0.56, h * 0.62),
		Vector2(r * 0.40, h * 0.65),
		Vector2(r * 0.58, h * 0.72),
		Vector2(r * 0.62, h * 0.80),
		Vector2(r * 0.52, h * 0.88),
		Vector2(r * 0.30, h * 0.94),
		Vector2(r * 0.18, h * 0.96),
	]))
	return p


## Dama: alta, cintura fina e a saia que se abre para a coroa.
static func _perfil_dama(r: float, h: float) -> PackedVector2Array:
	var p := _pe(r, h)
	p.append_array(PackedVector2Array([
		Vector2(r * 0.70, h * 0.20),
		Vector2(r * 0.42, h * 0.30),
		Vector2(r * 0.34, h * 0.45),
		Vector2(r * 0.40, h * 0.58),
		Vector2(r * 0.56, h * 0.70),
		Vector2(r * 0.64, h * 0.80),
		Vector2(r * 0.64, h * 0.86),
		Vector2(r * 0.50, h * 0.88),
	]))
	return p


## Rei: a mais alta, com um pescoco que sobe ate a base da cruz.
static func _perfil_rei(r: float, h: float) -> PackedVector2Array:
	var p := _pe(r, h)
	p.append_array(PackedVector2Array([
		Vector2(r * 0.70, h * 0.18),
		Vector2(r * 0.42, h * 0.28),
		Vector2(r * 0.34, h * 0.44),
		Vector2(r * 0.40, h * 0.58),
		Vector2(r * 0.56, h * 0.70),
		Vector2(r * 0.62, h * 0.82),
		Vector2(r * 0.62, h * 0.88),
		Vector2(r * 0.40, h * 0.90),
		Vector2(r * 0.40, h * 0.95),
		Vector2(r * 0.30, h),
	]))
	return p


## Os enfeites que a silhueta torneada nao da: filhos do MeshInstance3D, para
## subirem junto quando o token levanta.
static func _enfeites(tipo: int) -> Array[MeshInstance3D]:
	var r: float = RAIO[tipo]
	var h: float = ALTURA[tipo]
	var out: Array[MeshInstance3D] = []
	match tipo:
		ChessRules.QUEEN:
			out.append(_enfeite(MeshBuilder3D.crown(r * 0.62, 0.09), Vector3(0.0, h * 0.86, 0.0)))
			out.append(_enfeite(MeshBuilder3D.sphere_token(0.05), Vector3(0.0, h * 0.86 + 0.13, 0.0)))
		ChessRules.KING:
			out.append(_enfeite(MeshBuilder3D.rounded_box(Vector3(0.035, 0.17, 0.035), 0.01, 2), Vector3(0.0, h + 0.08, 0.0)))
			out.append(_enfeite(MeshBuilder3D.rounded_box(Vector3(0.12, 0.035, 0.035), 0.01, 2), Vector3(0.0, h + 0.10, 0.0)))
		ChessRules.KNIGHT:
			# Cabeca inclinada para a frente (-Z e o lado do adversario das
			# brancas), com focinho e duas orelhas: e o que le como cavalo.
			var inclinacao := deg_to_rad(-35.0)
			var cabeca := _enfeite(MeshBuilder3D.rounded_box(Vector3(0.20, 0.30, 0.20), 0.05, 3), Vector3(0.0, h * 0.58 + 0.12, -0.02))
			cabeca.rotation.x = inclinacao
			out.append(cabeca)
			var focinho := _enfeite(MeshBuilder3D.rounded_box(Vector3(0.13, 0.11, 0.15), 0.04, 3), Vector3(0.0, h * 0.58 + 0.24, -0.15))
			focinho.rotation.x = inclinacao
			out.append(focinho)
			for lado in [-1.0, 1.0]:
				var orelha := _enfeite(MeshBuilder3D.rounded_box(Vector3(0.045, 0.09, 0.045), 0.01, 2), Vector3(0.055 * lado, h * 0.58 + 0.31, 0.02))
				orelha.rotation.x = inclinacao
				out.append(orelha)
	return out


static func _enfeite(mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	return mi
