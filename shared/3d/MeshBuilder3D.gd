class_name MeshBuilder3D
extends RefCounted

## MeshBuilder3D: Geometria compartilhada das pecas de mesa.
##
## Duas tecnicas cobrem quase tudo:
##  - `revolve()` gira um perfil 2D em torno de Y. E assim que se faz uma peca
##    de damas com chanfro e friso, um peao ou um pino -- em vez de um cilindro
##    cru, que le como um disco de papelao.
##  - `rounded_box()` empurra os vertices de um cubo subdividido para um cubo
##    de cantos arredondados. Dados e pedras de domino precisam disso: aresta
##    viva nao existe em peca de resina de verdade e e o que mais denuncia
##    geometria de biblioteca.
##
## Toda malha fica em cache: dois tabuleiros de damas compartilham a mesma peca.

static var _cache: Dictionary = {}

# ---------------------------------------------------------------------------
# Nucleo
# ---------------------------------------------------------------------------

## Gira um perfil (x = raio, y = altura) em torno do eixo Y.
## O perfil vai da base ao topo e NAO precisa fechar nas pontas: as tampas sao
## geradas aqui. A ordem dos vertices e horaria vista de fora, que e a convencao
## que o Godot usa para face frontal -- inverter isso deixa a peca preta.
static func revolve(profile: PackedVector2Array, segments: int = 32) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var seg: int = maxi(segments, 6)
	var count := profile.size()

	for s in seg:
		var a0 := TAU * float(s) / float(seg)
		var a1 := TAU * float(s + 1) / float(seg)
		var c0 := Vector2(cos(a0), sin(a0))
		var c1 := Vector2(cos(a1), sin(a1))

		for i in range(count - 1):
			var p0 := profile[i]
			var p1 := profile[i + 1]
			if is_equal_approx(p0.x, 0.0) and is_equal_approx(p1.x, 0.0):
				continue

			var v00 := Vector3(p0.x * c0.x, p0.y, p0.x * c0.y)
			var v01 := Vector3(p0.x * c1.x, p0.y, p0.x * c1.y)
			var v10 := Vector3(p1.x * c0.x, p1.y, p1.x * c0.y)
			var v11 := Vector3(p1.x * c1.x, p1.y, p1.x * c1.y)

			# Normal do segmento do perfil, girada para o angulo atual.
			var d := (p1 - p0).normalized()
			var n2 := Vector2(d.y, -d.x)
			var n0 := Vector3(n2.x * c0.x, n2.y, n2.x * c0.y).normalized()
			var n1 := Vector3(n2.x * c1.x, n2.y, n2.x * c1.y).normalized()

			var u0 := float(s) / float(seg)
			var u1 := float(s + 1) / float(seg)
			var t0 := float(i) / float(count - 1)
			var t1 := float(i + 1) / float(count - 1)

			var deg0: bool = is_equal_approx(p1.x, 0.0)
			var deg1: bool = is_equal_approx(p0.x, 0.0)
			if not deg0:
				_tri(st, v00, n0, Vector2(u0, t0), v11, n1, Vector2(u1, t1), v10, n0, Vector2(u0, t1))
			if not deg1:
				_tri(st, v00, n0, Vector2(u0, t0), v01, n1, Vector2(u1, t0), v11, n1, Vector2(u1, t1))

	# Tampas
	_cap(st, profile[0], seg, Vector3.DOWN)
	_cap(st, profile[count - 1], seg, Vector3.UP)

	st.generate_tangents()
	return st.commit()

static func _tri(st: SurfaceTool,
		a: Vector3, na: Vector3, ua: Vector2,
		b: Vector3, nb: Vector3, ub: Vector2,
		c: Vector3, nc: Vector3, uc: Vector2) -> void:
	st.set_normal(na); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(nb); st.set_uv(ub); st.add_vertex(b)
	st.set_normal(nc); st.set_uv(uc); st.add_vertex(c)

static func _cap(st: SurfaceTool, edge: Vector2, seg: int, normal: Vector3) -> void:
	if edge.x <= 0.0001:
		return
	var centre := Vector3(0.0, edge.y, 0.0)
	for s in seg:
		var a0 := TAU * float(s) / float(seg)
		var a1 := TAU * float(s + 1) / float(seg)
		var v0 := Vector3(edge.x * cos(a0), edge.y, edge.x * sin(a0))
		var v1 := Vector3(edge.x * cos(a1), edge.y, edge.x * sin(a1))
		var uv_c := Vector2(0.5, 0.5)
		var uv0 := Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5)
		var uv1 := Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5)
		if normal.y > 0.0:
			_tri(st, centre, normal, uv_c, v0, normal, uv0, v1, normal, uv1)
		else:
			_tri(st, centre, normal, uv_c, v1, normal, uv1, v0, normal, uv0)

## Cubo de cantos arredondados. `subdiv` controla a suavidade do canto.
static func rounded_box(size: Vector3, radius: float, subdiv: int = 4) -> ArrayMesh:
	var half := size * 0.5
	var r: float = minf(radius, minf(half.x, minf(half.y, half.z)) * 0.98)
	var inner := half - Vector3(r, r, r)
	var n: int = maxi(subdiv, 2)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Seis faces de um cubo subdividido. Cada vertice e recuado ate o nucleo
	# interno e depois empurrado de volta por `r` na direcao do recuo: com uma
	# conta so, arestas e cantos ficam arredondados e as normais saem corretas.
	var faces: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3.RIGHT, Vector3.BACK, Vector3.UP]),
		PackedVector3Array([Vector3.LEFT, Vector3.FORWARD, Vector3.UP]),
		PackedVector3Array([Vector3.UP, Vector3.RIGHT, Vector3.BACK]),
		PackedVector3Array([Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD]),
		PackedVector3Array([Vector3.BACK, Vector3.LEFT, Vector3.UP]),
		PackedVector3Array([Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]),
	]
	var corners: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])

	for face in faces:
		var normal: Vector3 = face[0]
		var u_axis: Vector3 = face[1]
		var v_axis: Vector3 = face[2]
		var hn := _extent_along(half, normal)
		var hu := _extent_along(half, u_axis)
		var hv := _extent_along(half, v_axis)

		for iy in n:
			for ix in n:
				var pos: PackedVector3Array = PackedVector3Array()
				var nrm: PackedVector3Array = PackedVector3Array()
				var uvs: PackedVector2Array = PackedVector2Array()

				for k in 4:
					var corner: Vector2 = corners[k]
					var fx: float = (float(ix) + corner.x) / float(n) * 2.0 - 1.0
					var fy: float = (float(iy) + corner.y) / float(n) * 2.0 - 1.0
					var p: Vector3 = normal * hn + u_axis * (fx * hu) + v_axis * (fy * hv)
					var clamped := Vector3(
						clampf(p.x, -inner.x, inner.x),
						clampf(p.y, -inner.y, inner.y),
						clampf(p.z, -inner.z, inner.z))
					var offset: Vector3 = p - clamped
					var vn: Vector3 = offset.normalized() if offset.length() > 0.0001 else normal
					pos.append(clamped + vn * r)
					nrm.append(vn)
					uvs.append(Vector2(fx * 0.5 + 0.5, fy * 0.5 + 0.5))

				_tri(st, pos[0], nrm[0], uvs[0], pos[1], nrm[1], uvs[1], pos[2], nrm[2], uvs[2])
				_tri(st, pos[0], nrm[0], uvs[0], pos[2], nrm[2], uvs[2], pos[3], nrm[3], uvs[3])

	st.generate_tangents()
	return st.commit()

## Meia-extensao da caixa ao longo de um eixo unitario alinhado aos eixos.
static func _extent_along(half: Vector3, axis: Vector3) -> float:
	return absf(axis.x) * half.x + absf(axis.y) * half.y + absf(axis.z) * half.z

# ---------------------------------------------------------------------------
# Pecas prontas
# ---------------------------------------------------------------------------

## Peca de damas / reversi: chanfro em cima e embaixo e um friso na lateral.
static func disc_token(radius: float = 0.36, height: float = Tokens3D.TOKEN_HEIGHT) -> ArrayMesh:
	var key := "disc_%.3f_%.3f_%d" % [radius, height, Quality3D.tier()]
	if _cache.has(key):
		return _cache[key]

	var ch: float = height * 0.28
	var rim: float = radius * 0.90
	var h := height
	var profile := PackedVector2Array([
		Vector2(rim, 0.0),
		Vector2(radius, ch),
		Vector2(radius, h * 0.42),
		Vector2(radius * 0.965, h * 0.50),
		Vector2(radius, h * 0.58),
		Vector2(radius, h - ch),
		Vector2(rim, h),
	])
	var mesh := revolve(profile, Quality3D.radial_segments(40))
	_cache[key] = mesh
	return mesh

## Peao de trilha (Ludo, Senet): base larga, colo estreito, cabeca arredondada.
static func pawn(height: float = 0.62, base_radius: float = 0.22) -> ArrayMesh:
	var key := "pawn_%.3f_%.3f_%d" % [height, base_radius, Quality3D.tier()]
	if _cache.has(key):
		return _cache[key]

	var h := height
	var b := base_radius
	var profile := PackedVector2Array([
		Vector2(b * 0.92, 0.0),
		Vector2(b, h * 0.045),
		Vector2(b, h * 0.11),
		Vector2(b * 0.72, h * 0.20),
		Vector2(b * 0.42, h * 0.34),
		Vector2(b * 0.34, h * 0.50),
		Vector2(b * 0.40, h * 0.60),
		Vector2(b * 0.62, h * 0.70),
		Vector2(b * 0.70, h * 0.80),
		Vector2(b * 0.58, h * 0.90),
		Vector2(b * 0.30, h * 0.975),
	])
	var mesh := revolve(profile, Quality3D.radial_segments(28))
	_cache[key] = mesh
	return mesh

## Esfera de Resta Um / semente de Mancala.
static func sphere_token(radius: float = 0.30) -> SphereMesh:
	var key := "sphere_%.3f_%d" % [radius, Quality3D.tier()]
	if _cache.has(key):
		return _cache[key]
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.rings = maxi(6, Quality3D.radial_segments(14) / 2)
	mesh.radial_segments = Quality3D.radial_segments(24)
	_cache[key] = mesh
	return mesh

## Coroa de dama: um anel de pontas, nao um cilindro solto.
static func crown(radius: float = 0.20, height: float = 0.10) -> ArrayMesh:
	var key := "crown_%.3f_%.3f_%d" % [radius, height, Quality3D.tier()]
	if _cache.has(key):
		return _cache[key]
	var profile := PackedVector2Array([
		Vector2(radius * 0.55, 0.0),
		Vector2(radius, 0.0),
		Vector2(radius, height * 0.30),
		Vector2(radius * 0.86, height * 0.55),
		Vector2(radius * 0.96, height),
		Vector2(radius * 0.62, height),
		Vector2(radius * 0.52, height * 0.62),
		Vector2(radius * 0.55, height * 0.55),
	])
	var mesh := revolve(profile, Quality3D.radial_segments(18))
	_cache[key] = mesh
	return mesh

## Pedra de domino.
static func domino_tile(length: float = 0.94, width: float = 0.47, thickness: float = 0.14) -> ArrayMesh:
	var key := "domino_%.3f_%.3f_%.3f_%d" % [length, width, thickness, Quality3D.tier()]
	if _cache.has(key):
		return _cache[key]
	var mesh := rounded_box(Vector3(width, thickness, length), thickness * 0.34,
		3 if Quality3D.tier() == Quality3D.Tier.LOW else 5)
	_cache[key] = mesh
	return mesh

## Carta de baralho: prisma de retangulo arredondado, em DUAS superficies.
##
## Superficie 0 = so a face de cima, com UV 0..1. E ela que recebe o material
## por carta, apontando para a celula do atlas.
## Superficie 1 = verso + borda, com as UVs do atlas ja embutidas. Como o verso
## e igual em todas as cartas, a malha inteira e compartilhada: 52 cartas usam
## um unico ArrayMesh e duas chamadas de desenho cada.
static func card_mesh(width: float, length: float, thickness: float,
		back_uv: Rect2, rim_uv: Rect2, corner_segments: int = 4) -> ArrayMesh:
	var key := "cardmesh_%.3f_%.3f_%.4f_%s_%s" % [width, length, thickness, back_uv, rim_uv]
	if _cache.has(key):
		return _cache[key]

	var radius: float = minf(width, length) * 0.075
	var outline := _rounded_rect_outline(width, length, radius, maxi(corner_segments, 2))
	var top_y := thickness * 0.5
	var bottom_y := -thickness * 0.5

	var mesh := ArrayMesh.new()

	# --- Superficie 0: face -------------------------------------------------
	var st_front := SurfaceTool.new()
	st_front.begin(Mesh.PRIMITIVE_TRIANGLES)
	_fan_cap(st_front, outline, top_y, Vector3.UP, width, length, Rect2(0.0, 0.0, 1.0, 1.0), false)
	st_front.generate_tangents()
	st_front.commit(mesh)

	# --- Superficie 1: verso + borda ---------------------------------------
	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	_fan_cap(st_body, outline, bottom_y, Vector3.DOWN, width, length, back_uv, true)

	var n := outline.size()
	for i in n:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		var edge := (b - a).normalized()
		var nrm := Vector3(edge.y, 0.0, -edge.x)
		var u0 := rim_uv.position.x + rim_uv.size.x * (float(i) / float(n))
		var u1 := rim_uv.position.x + rim_uv.size.x * (float(i + 1) / float(n))
		var v0 := rim_uv.position.y
		var v1 := rim_uv.position.y + rim_uv.size.y
		var pa_top := Vector3(a.x, top_y, a.y)
		var pb_top := Vector3(b.x, top_y, b.y)
		var pa_bot := Vector3(a.x, bottom_y, a.y)
		var pb_bot := Vector3(b.x, bottom_y, b.y)
		_tri(st_body, pa_top, nrm, Vector2(u0, v0), pb_bot, nrm, Vector2(u1, v1), pa_bot, nrm, Vector2(u0, v1))
		_tri(st_body, pa_top, nrm, Vector2(u0, v0), pb_top, nrm, Vector2(u1, v0), pb_bot, nrm, Vector2(u1, v1))
	st_body.generate_tangents()
	st_body.commit(mesh)

	_cache[key] = mesh
	return mesh

## Contorno de um retangulo de cantos arredondados, no plano XZ, sentido horario
## visto de cima.
static func _rounded_rect_outline(width: float, length: float, radius: float, seg: int) -> PackedVector2Array:
	var hw: float = width * 0.5
	var hl: float = length * 0.5
	var r: float = minf(radius, minf(hw, hl) * 0.9)
	var pts := PackedVector2Array()
	var centres := PackedVector2Array([
		Vector2(hw - r, hl - r),
		Vector2(-(hw - r), hl - r),
		Vector2(-(hw - r), -(hl - r)),
		Vector2(hw - r, -(hl - r)),
	])
	var starts := [0.0, PI * 0.5, PI, PI * 1.5]
	for k in 4:
		var centre: Vector2 = centres[k]
		var a0: float = starts[k]
		for i in range(seg + 1):
			var ang: float = a0 + PI * 0.5 * float(i) / float(seg)
			pts.append(centre + Vector2(cos(ang), sin(ang)) * r)
	return pts

## Tampa em leque a partir do centro, com UV mapeado dentro de `uv_rect`.
static func _fan_cap(st: SurfaceTool, outline: PackedVector2Array, y: float, normal: Vector3,
		width: float, length: float, uv_rect: Rect2, mirror_u: bool) -> void:
	var n := outline.size()
	var centre := Vector3(0.0, y, 0.0)
	var uv_centre := uv_rect.position + uv_rect.size * 0.5
	for i in n:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		var ua := _cap_uv(a, width, length, uv_rect, mirror_u)
		var ub := _cap_uv(b, width, length, uv_rect, mirror_u)
		if normal.y > 0.0:
			_tri(st, centre, normal, uv_centre, Vector3(a.x, y, a.y), normal, ua,
				Vector3(b.x, y, b.y), normal, ub)
		else:
			_tri(st, centre, normal, uv_centre, Vector3(b.x, y, b.y), normal, ub,
				Vector3(a.x, y, a.y), normal, ua)

static func _cap_uv(p: Vector2, width: float, length: float, uv_rect: Rect2, mirror_u: bool) -> Vector2:
	var u: float = p.x / width + 0.5
	var v: float = p.y / length + 0.5
	if mirror_u:
		# O verso e visto pelo outro lado: sem espelhar, a trama sairia invertida.
		u = 1.0 - u
	return uv_rect.position + Vector2(u * uv_rect.size.x, v * uv_rect.size.y)

## Carta simples de uma superficie, para quando nao ha atlas (marcadores).
static func card(width: float = Tokens3D.CARD_WIDTH, length: float = Tokens3D.CARD_LENGTH,
		thickness: float = Tokens3D.CARD_THICKNESS) -> ArrayMesh:
	var key := "card_%.3f_%.3f_%.4f" % [width, length, thickness]
	if _cache.has(key):
		return _cache[key]
	var mesh := rounded_box(Vector3(width, thickness, length), thickness * 0.45, 2)
	_cache[key] = mesh
	return mesh

## Dado de cantos arredondados.
static func dice_cube(size: float = 0.5) -> ArrayMesh:
	var key := "dice_%.3f_%d" % [size, Quality3D.tier()]
	if _cache.has(key):
		return _cache[key]
	var mesh := rounded_box(Vector3(size, size, size), size * 0.14,
		3 if Quality3D.tier() == Quality3D.Tier.LOW else 5)
	_cache[key] = mesh
	return mesh

## Pino de marcacao (Batalha Naval).
static func peg_pin(height: float = 0.24, radius: float = 0.09) -> ArrayMesh:
	var key := "peg_%.3f_%.3f_%d" % [height, radius, Quality3D.tier()]
	if _cache.has(key):
		return _cache[key]
	var profile := PackedVector2Array([
		Vector2(radius * 0.75, 0.0),
		Vector2(radius * 0.80, height * 0.55),
		Vector2(radius, height * 0.78),
		Vector2(radius * 0.72, height),
	])
	var mesh := revolve(profile, Quality3D.radial_segments(16))
	_cache[key] = mesh
	return mesh

## Cova de Mancala: uma tigela rasa escavada na madeira.
static func bowl(radius: float = 0.34, depth: float = 0.14) -> ArrayMesh:
	var key := "bowl_%.3f_%.3f_%d" % [radius, depth, Quality3D.tier()]
	if _cache.has(key):
		return _cache[key]
	var profile := PackedVector2Array([
		Vector2(radius * 0.18, -depth),
		Vector2(radius * 0.45, -depth * 0.94),
		Vector2(radius * 0.78, -depth * 0.62),
		Vector2(radius * 0.95, -depth * 0.24),
		Vector2(radius, 0.0),
		Vector2(radius * 1.06, 0.012),
	])
	var mesh := revolve(profile, Quality3D.radial_segments(26))
	_cache[key] = mesh
	return mesh

static func board_slab(size_x: float, size_z: float, thickness: float = Tokens3D.BOARD_SLAB_THICKNESS) -> ArrayMesh:
	return rounded_box(Vector3(size_x, thickness, size_z), thickness * 0.22, 2)

# ---------------------------------------------------------------------------
# Compatibilidade com a API anterior
# ---------------------------------------------------------------------------

static func create_cylinder_token(radius: float = 0.36, height: float = Tokens3D.TOKEN_HEIGHT, _segments: int = 32) -> Mesh:
	return disc_token(radius, height)

static func create_sphere_token(radius: float = 0.30, _rings: int = 16, _segments: int = 32) -> Mesh:
	return sphere_token(radius)

static func create_pawn_meeple(height: float = 0.62, base_radius: float = 0.22, _top: float = 0.1) -> Mesh:
	return pawn(height, base_radius)

static func create_domino_tile(length: float = 0.94, width: float = 0.47, thickness: float = 0.14) -> Mesh:
	return domino_tile(length, width, thickness)

static func create_card_mesh(width: float = Tokens3D.CARD_WIDTH, length: float = Tokens3D.CARD_LENGTH,
		thickness: float = Tokens3D.CARD_THICKNESS) -> Mesh:
	return card(width, length, thickness)

static func create_dice_cube(size: float = 0.5) -> Mesh:
	return dice_cube(size)

static func create_peg_pin(height: float = 0.24, radius: float = 0.09) -> Mesh:
	return peg_pin(height, radius)

static func create_board_slab(size_x: float, size_z: float, thickness: float = Tokens3D.BOARD_SLAB_THICKNESS) -> Mesh:
	return board_slab(size_x, size_z, thickness)

static func clear_cache() -> void:
	_cache.clear()
