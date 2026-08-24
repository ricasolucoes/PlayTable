class_name TextureFactory3D
extends RefCounted

## TextureFactory3D: Texturas procedurais (albedo + normal + rugosidade) para
## os materiais de mesa. Tudo e gerado uma unica vez e fica em cache estatico.
##
## As imagens sao montadas em PackedByteArray e enviadas de uma so vez para
## Image.create_from_data: escrever pixel a pixel com set_pixel custa caro em
## GDScript. Os mapas de normal saem de Image.bump_map_to_normal_map, que roda
## em C++.
##
## Resolucao modesta de proposito: estas texturas sao detalhe de superficie
## repetido via uv_scale, nao arte unica. 256x256 mantem VRAM baixa no celular.

const RES := 256

static var _cache: Dictionary = {}

# ---------------------------------------------------------------------------
# Madeira
# ---------------------------------------------------------------------------

## Aneis de crescimento deformados por ruido, no eixo Z do tabuleiro.
## `ring_scale` alto = veio fechado (nogueira); baixo = veio aberto (bordo).
static func wood(key: String, base: Color, ring_scale: float = 9.0, contrast: float = 0.20) -> Dictionary:
	var cache_key := "wood_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]

	var warp := FastNoiseLite.new()
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp.frequency = 0.006
	warp.seed = hash(key)

	var fibre := FastNoiseLite.new()
	fibre.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fibre.frequency = 0.09
	fibre.seed = hash(key) + 17

	var albedo := PackedByteArray()
	albedo.resize(RES * RES * 3)
	var height := PackedByteArray()
	height.resize(RES * RES)

	for y in RES:
		for x in RES:
			# Deforma a coordenada antes de gerar o anel: sem isso o veio fica
			# com listras retas de papel de parede.
			var wx := float(x) + warp.get_noise_2d(float(x) * 1.6, float(y) * 0.35) * 46.0
			var rings := sin(wx / float(RES) * ring_scale * TAU) * 0.5 + 0.5
			rings = pow(rings, 1.7)

			# Fibra fina alongada: comprime Y para alongar o grao no eixo X.
			var grain := fibre.get_noise_2d(float(x) * 3.4, float(y) * 0.22) * 0.5 + 0.5

			var t: float = rings * 0.72 + grain * 0.28
			var col := base.lerp(base.darkened(contrast * 2.2), t)
			col = col.lerp(base.lightened(contrast * 0.55), (1.0 - t) * 0.35)

			var i := (y * RES + x) * 3
			albedo[i] = int(clampf(col.r, 0.0, 1.0) * 255.0)
			albedo[i + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
			albedo[i + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
			# Poro da madeira: o anel escuro afunda.
			height[y * RES + x] = int((1.0 - t) * 255.0)

	var result := _pack(cache_key, albedo, height, 0.55, 0.86)
	return result

# ---------------------------------------------------------------------------
# Feltro / tecido
# ---------------------------------------------------------------------------

## Feltro de mesa: fibra curta e aleatoria, quase sem brilho.
static func felt(key: String, base: Color) -> Dictionary:
	var cache_key := "felt_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]

	var fuzz := FastNoiseLite.new()
	fuzz.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fuzz.frequency = 0.42
	fuzz.fractal_octaves = 3
	fuzz.seed = hash(key)

	var weave := FastNoiseLite.new()
	weave.noise_type = FastNoiseLite.TYPE_VALUE
	weave.frequency = 0.9
	weave.seed = hash(key) + 5

	var albedo := PackedByteArray()
	albedo.resize(RES * RES * 3)
	var height := PackedByteArray()
	height.resize(RES * RES)

	for y in RES:
		for x in RES:
			var f := fuzz.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var w := weave.get_noise_2d(float(x) * 2.0, float(y) * 2.0) * 0.5 + 0.5
			var t: float = f * 0.68 + w * 0.32
			# Variacao curta: feltro nao tem manchas grandes, so poeira de fibra.
			var col := base.lerp(base.lightened(0.055), t)
			col = col.lerp(base.darkened(0.075), (1.0 - t) * 0.5)

			var i := (y * RES + x) * 3
			albedo[i] = int(clampf(col.r, 0.0, 1.0) * 255.0)
			albedo[i + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
			albedo[i + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
			height[y * RES + x] = int(t * 255.0)

	return _pack(cache_key, albedo, height, 0.92, 1.0, 1.1)

# ---------------------------------------------------------------------------
# Pedra polida
# ---------------------------------------------------------------------------

## Marmore: veios finos e claros cortando uma base fria.
static func marble(key: String, base: Color, vein: Color, vein_scale: float = 3.2) -> Dictionary:
	var cache_key := "marble_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]

	var turb := FastNoiseLite.new()
	turb.noise_type = FastNoiseLite.TYPE_SIMPLEX
	turb.frequency = 0.012
	turb.fractal_octaves = 5
	turb.seed = hash(key)

	var albedo := PackedByteArray()
	albedo.resize(RES * RES * 3)
	var height := PackedByteArray()
	height.resize(RES * RES)

	for y in RES:
		for x in RES:
			var n := turb.get_noise_2d(float(x), float(y))
			# Turbulencia dentro do seno: e o que quebra a listra em veio.
			var v := sin((float(x) + float(y)) / float(RES) * vein_scale * TAU + n * 7.5)
			var t: float = pow(absf(v), 0.42)
			var col := vein.lerp(base, t)

			var i := (y * RES + x) * 3
			albedo[i] = int(clampf(col.r, 0.0, 1.0) * 255.0)
			albedo[i + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
			albedo[i + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
			height[y * RES + x] = int(t * 255.0)

	return _pack(cache_key, albedo, height, 0.10, 0.30)

# ---------------------------------------------------------------------------
# Couro
# ---------------------------------------------------------------------------

static func leather(key: String, base: Color) -> Dictionary:
	var cache_key := "leather_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]

	var cell := FastNoiseLite.new()
	cell.noise_type = FastNoiseLite.TYPE_CELLULAR
	cell.frequency = 0.11
	cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cell.seed = hash(key)

	var albedo := PackedByteArray()
	albedo.resize(RES * RES * 3)
	var height := PackedByteArray()
	height.resize(RES * RES)

	for y in RES:
		for x in RES:
			var c := cell.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var t: float = pow(clampf(c, 0.0, 1.0), 0.75)
			var col := base.darkened(0.22).lerp(base.lightened(0.10), t)

			var i := (y * RES + x) * 3
			albedo[i] = int(clampf(col.r, 0.0, 1.0) * 255.0)
			albedo[i + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
			albedo[i + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
			height[y * RES + x] = int(t * 255.0)

	return _pack(cache_key, albedo, height, 0.52, 0.82)

# ---------------------------------------------------------------------------
# Marfim / osso: quase liso, com veio muito leve.
# ---------------------------------------------------------------------------

static func ivory(key: String, base: Color) -> Dictionary:
	var cache_key := "ivory_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]

	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.035
	n.fractal_octaves = 2
	n.seed = hash(key)

	var albedo := PackedByteArray()
	albedo.resize(RES * RES * 3)
	var height := PackedByteArray()
	height.resize(RES * RES)

	for y in RES:
		for x in RES:
			# Y muito comprimido: o veio do marfim corre em uma direcao so.
			var t: float = n.get_noise_2d(float(x) * 0.5, float(y) * 5.0) * 0.5 + 0.5
			var col := base.lerp(base.darkened(0.10), t)

			var i := (y * RES + x) * 3
			albedo[i] = int(clampf(col.r, 0.0, 1.0) * 255.0)
			albedo[i + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
			albedo[i + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
			height[y * RES + x] = int(t * 255.0)

	return _pack(cache_key, albedo, height, 0.16, 0.34)

# ---------------------------------------------------------------------------

## Monta as texturas finais e guarda em cache.
## `rough_min`/`rough_max` viram um mapa de rugosidade derivado da altura, o que
## da variacao de brilho sem custar um segundo ruido.
static func _pack(cache_key: String, albedo_bytes: PackedByteArray, height_bytes: PackedByteArray,
		rough_min: float, rough_max: float, bump_strength: float = 2.6) -> Dictionary:
	var albedo_img := Image.create_from_data(RES, RES, false, Image.FORMAT_RGB8, albedo_bytes)
	albedo_img.generate_mipmaps()

	var height_img := Image.create_from_data(RES, RES, false, Image.FORMAT_L8, height_bytes)

	var normal_img := height_img.duplicate() as Image
	normal_img.bump_map_to_normal_map(bump_strength)
	normal_img.generate_mipmaps()

	var rough_bytes := PackedByteArray()
	rough_bytes.resize(RES * RES)
	for i in height_bytes.size():
		var h := float(height_bytes[i]) / 255.0
		rough_bytes[i] = int(clampf(lerpf(rough_min, rough_max, h), 0.0, 1.0) * 255.0)
	var rough_img := Image.create_from_data(RES, RES, false, Image.FORMAT_L8, rough_bytes)
	rough_img.generate_mipmaps()

	var result := {
		"albedo": ImageTexture.create_from_image(albedo_img),
		"normal": ImageTexture.create_from_image(normal_img),
		"roughness": ImageTexture.create_from_image(rough_img),
	}
	_cache[cache_key] = result
	return result

## Libera todas as texturas em cache. Usado ao trocar de nivel de qualidade.
static func clear_cache() -> void:
	_cache.clear()
