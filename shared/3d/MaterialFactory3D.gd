class_name MaterialFactory3D
extends RefCounted

## MaterialFactory3D: Materiais PBR compartilhados do PlayTable.
##
## Todo material sai daqui em cache: dois tabuleiros de madeira nogueira usam
## exatamente o mesmo StandardMaterial3D, o que mantem draw calls e VRAM baixos.
## Nunca instancie um StandardMaterial3D solto dentro de um jogo.
##
## As familias sao distintas de proposito -- madeira, feltro, pedra, metal,
## marfim, plastico e papel respondem a luz de formas diferentes. Trocar so a
## cor de um material generico nao e acabamento.

static var _cache: Dictionary = {}

# ---------------------------------------------------------------------------
# Madeiras
# ---------------------------------------------------------------------------

static func get_wood_mahogany() -> StandardMaterial3D:
	return _wood("mahogany", Color(0.34, 0.17, 0.10), 8.0, 0.22, 0.30)

static func get_wood_walnut() -> StandardMaterial3D:
	return _wood("walnut", Color(0.27, 0.175, 0.115), 10.0, 0.22, 0.42)

static func get_wood_maple() -> StandardMaterial3D:
	return _wood("maple", Color(0.83, 0.71, 0.53), 6.0, 0.11, 0.42)

static func get_wood_ebony() -> StandardMaterial3D:
	return _wood("ebony", Color(0.10, 0.09, 0.09), 13.0, 0.26, 0.35)

static func get_wood_olive() -> StandardMaterial3D:
	return _wood("olive", Color(0.58, 0.48, 0.29), 7.0, 0.18, 0.40)

static func _wood(key: String, base: Color, rings: float, contrast: float, uv: float) -> StandardMaterial3D:
	var cache_key := "wood_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]

	var tex := TextureFactory3D.wood(key, base, rings, contrast)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex["albedo"]
	mat.normal_enabled = true
	mat.normal_texture = tex["normal"]
	mat.normal_scale = 0.55
	mat.roughness_texture = tex["roughness"]
	mat.roughness = 1.0
	mat.metallic = 0.0
	# Verniz: uma camada fina de brilho por cima do poro, sem virar plastico.
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.35
	mat.clearcoat_roughness = 0.28
	# Triplanar em espaco de mundo: sem isso cada casa do tabuleiro repete
	# exatamente o mesmo pedaco de veio e a grade vira papel de parede.
	_use_world_triplanar(mat, uv)
	_cache[cache_key] = mat
	return mat

# ---------------------------------------------------------------------------
# Tecidos
# ---------------------------------------------------------------------------

static func get_felt_casino(color: Color = Color(0.07, 0.31, 0.19)) -> StandardMaterial3D:
	var key := "felt_" + color.to_html(false)
	if _cache.has(key):
		return _cache[key]

	var tex := TextureFactory3D.felt(color.to_html(false), color)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex["albedo"]
	mat.normal_enabled = true
	mat.normal_texture = tex["normal"]
	mat.normal_scale = 0.9
	mat.roughness_texture = tex["roughness"]
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Rim baixo: a fibra do feltro pega uma luz fraca nas bordas.
	mat.rim_enabled = true
	mat.rim = 0.22
	mat.rim_tint = 0.6
	_use_world_triplanar(mat, 0.9)
	_cache[key] = mat
	return mat

static func get_leather(color: Color = Color(0.28, 0.16, 0.11)) -> StandardMaterial3D:
	var key := "leather_" + color.to_html(false)
	if _cache.has(key):
		return _cache[key]

	var tex := TextureFactory3D.leather(color.to_html(false), color)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex["albedo"]
	mat.normal_enabled = true
	mat.normal_texture = tex["normal"]
	mat.normal_scale = 1.1
	mat.roughness_texture = tex["roughness"]
	mat.roughness = 1.0
	mat.metallic = 0.0
	_use_world_triplanar(mat, 0.7)
	_cache[key] = mat
	return mat

# ---------------------------------------------------------------------------
# Pedras
# ---------------------------------------------------------------------------

static func get_marble_white() -> StandardMaterial3D:
	return _marble("white", Color(0.91, 0.90, 0.87), Color(0.52, 0.53, 0.57))

static func get_marble_black() -> StandardMaterial3D:
	return _marble("black", Color(0.11, 0.11, 0.13), Color(0.34, 0.35, 0.40))

static func _marble(key: String, base: Color, vein: Color) -> StandardMaterial3D:
	var cache_key := "marble_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]

	var tex := TextureFactory3D.marble(key, base, vein)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex["albedo"]
	mat.normal_enabled = true
	mat.normal_texture = tex["normal"]
	mat.normal_scale = 0.20
	mat.roughness_texture = tex["roughness"]
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.7
	mat.clearcoat_roughness = 0.10
	_use_world_triplanar(mat, 0.30)
	_cache[cache_key] = mat
	return mat

static func get_slate() -> StandardMaterial3D:
	if _cache.has("slate"):
		return _cache["slate"]
	var tex := TextureFactory3D.leather("slate", Color(0.20, 0.22, 0.26))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex["albedo"]
	mat.normal_enabled = true
	mat.normal_texture = tex["normal"]
	mat.normal_scale = 0.5
	mat.roughness = 0.72
	mat.metallic = 0.0
	_use_world_triplanar(mat, 0.5)
	_cache["slate"] = mat
	return mat

# ---------------------------------------------------------------------------
# Metais
# ---------------------------------------------------------------------------

static func get_gold() -> StandardMaterial3D:
	return _metal("gold", Color(0.96, 0.76, 0.32), 0.24)

static func get_silver() -> StandardMaterial3D:
	return _metal("silver", Color(0.90, 0.92, 0.95), 0.20)

static func get_bronze() -> StandardMaterial3D:
	return _metal("bronze", Color(0.66, 0.43, 0.22), 0.34)

static func _metal(key: String, color: Color, rough: float) -> StandardMaterial3D:
	var cache_key := "metal_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 1.0
	mat.metallic_specular = 0.5
	mat.roughness = rough
	_cache[cache_key] = mat
	return mat

# ---------------------------------------------------------------------------
# Marfim, ceramica, plastico, papel
# ---------------------------------------------------------------------------

static func get_ivory() -> StandardMaterial3D:
	return _ivory("ivory", Color(0.95, 0.92, 0.85))

static func get_obsidian() -> StandardMaterial3D:
	if _cache.has("obsidian"):
		return _cache["obsidian"]
	# Obsidiana e vidro vulcanico: escura, mas com reflexo nitido. Sem o
	# clearcoat ela some no tabuleiro e vira uma silhueta preta chapada.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.085, 0.088, 0.105)
	mat.roughness = 0.16
	mat.metallic = 0.0
	mat.metallic_specular = 0.65
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.9
	mat.clearcoat_roughness = 0.08
	mat.rim_enabled = true
	mat.rim = 0.45
	mat.rim_tint = 0.15
	_cache["obsidian"] = mat
	return mat

static func _ivory(key: String, base: Color) -> StandardMaterial3D:
	var cache_key := "ivory_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var tex := TextureFactory3D.ivory(key, base)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex["albedo"]
	mat.normal_enabled = true
	mat.normal_texture = tex["normal"]
	mat.normal_scale = 0.18
	mat.roughness_texture = tex["roughness"]
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.55
	mat.clearcoat_roughness = 0.16
	# Sem subsurface: o renderizador movel do Godot 4.3 nao o suporta e o
	# material seria compilado com um aviso e ignorado.
	mat.uv1_scale = Vector3(1.4, 1.4, 1.4)
	_cache[cache_key] = mat
	return mat

static func get_ceramic(color: Color) -> StandardMaterial3D:
	var key := "ceramic_" + color.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.22
	mat.metallic = 0.0
	mat.metallic_specular = 0.55
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.85
	mat.clearcoat_roughness = 0.06
	_cache[key] = mat
	return mat

static func get_plastic(color: Color, is_glossy: bool = true) -> StandardMaterial3D:
	var key := "plastic_%s_%s" % [color.to_html(false), is_glossy]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.30 if is_glossy else 0.62
	mat.metallic = 0.0
	mat.metallic_specular = 0.5
	if is_glossy:
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.5
		mat.clearcoat_roughness = 0.14
	_cache[key] = mat
	return mat

static func get_gemstone(color: Color) -> StandardMaterial3D:
	var key := "gem_" + color.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.12
	mat.metallic = 0.0
	mat.metallic_specular = 0.85
	mat.clearcoat_enabled = true
	mat.clearcoat = 1.0
	mat.clearcoat_roughness = 0.04
	mat.rim_enabled = true
	mat.rim = 0.55
	mat.rim_tint = 0.75
	_cache[key] = mat
	return mat

static func get_paper(color: Color = Color(0.95, 0.94, 0.91)) -> StandardMaterial3D:
	var key := "paper_" + color.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.62
	mat.metallic = 0.0
	# Papel reflete pouco: baixa o specular em vez de desligar de vez, senao a
	# carta perde a leitura de volume na borda.
	mat.metallic_specular = 0.22
	_cache[key] = mat
	return mat

# ---------------------------------------------------------------------------
# Materiais de estado (destaque, selecao, erro)
# ---------------------------------------------------------------------------

## Material de destaque de casa: emissivo fraco e transparente, para pousar
## SOBRE a casa sem apagar o material dela.
static func get_state_overlay(color: Color, energy: float = 0.55) -> StandardMaterial3D:
	var key := "state_%s_%.2f" % [color.to_html(false), energy]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.42)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	# Sem escrita de profundidade: evita brigar com a casa logo abaixo.
	mat.no_depth_test = false
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_cache[key] = mat
	return mat

static func get_glow(color: Color, energy: float = 1.6) -> StandardMaterial3D:
	var key := "glow_%s_%.1f" % [color.to_html(false), energy]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	_cache[key] = mat
	return mat

## Sombra de contato: um disco escuro que ancora a peca na superficie.
## O renderizador movel do Godot 4.3 nao tem SSAO, entao o contato precisa ser
## geometria de verdade em vez de um efeito de tela.
static func get_contact_shadow() -> StandardMaterial3D:
	if _cache.has("contact_shadow"):
		return _cache["contact_shadow"]
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.0, 0.0, Tokens3D.CONTACT_SHADOW_OPACITY)
	mat.albedo_texture = _radial_falloff_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["contact_shadow"] = mat
	return mat

static func _radial_falloff_texture() -> ImageTexture:
	if _cache.has("_falloff_tex"):
		return _cache["_falloff_tex"]
	var size := 64
	var bytes := PackedByteArray()
	bytes.resize(size * size * 4)
	var centre := float(size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - centre, float(y) - centre).length() / centre
			# Queda quadratica: borda macia, nucleo denso.
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			var i := (y * size + x) * 4
			bytes[i] = 0
			bytes[i + 1] = 0
			bytes[i + 2] = 0
			bytes[i + 3] = int(a * 255.0)
	var img := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)
	var tex := ImageTexture.create_from_image(img)
	_cache["_falloff_tex"] = tex
	return tex

# ---------------------------------------------------------------------------

## Resolve um material pelo nome usado pelos jogos.
static func by_name(mat_name: String) -> StandardMaterial3D:
	match mat_name:
		"ivory": return get_ivory()
		"obsidian": return get_obsidian()
		"gold": return get_gold()
		"silver": return get_silver()
		"bronze": return get_bronze()
		"marble_white": return get_marble_white()
		"marble_black": return get_marble_black()
		"slate": return get_slate()
		"leather": return get_leather()
		"ruby": return get_gemstone(Color(0.88, 0.12, 0.22))
		"sapphire": return get_gemstone(Color(0.13, 0.38, 0.92))
		"emerald": return get_gemstone(Color(0.10, 0.74, 0.36))
		"amber": return get_gemstone(Color(0.94, 0.62, 0.12))
		"plastic_red": return get_plastic(Color(0.86, 0.17, 0.16))
		"plastic_yellow": return get_plastic(Color(0.94, 0.80, 0.16))
		"plastic_blue": return get_plastic(Color(0.16, 0.46, 0.88))
		"plastic_green": return get_plastic(Color(0.16, 0.70, 0.34))
		"ceramic_red": return get_ceramic(Color(0.78, 0.20, 0.18))
		"ceramic_cream": return get_ceramic(Color(0.94, 0.91, 0.83))
		"wood_light": return get_wood_maple()
		"wood_dark": return get_wood_walnut()
		"wood_mahogany": return get_wood_mahogany()
		"wood_ebony": return get_wood_ebony()
		"wood_olive": return get_wood_olive()
		"paper": return get_paper()
		_: return get_ivory()

## Aplica mapeamento triplanar em espaco de mundo. `scale` e a frequencia em
## repeticoes por unidade -- valores baixos deixam o veio grande e continuo.
static func _use_world_triplanar(mat: StandardMaterial3D, scale: float) -> void:
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(scale, scale, scale)
	mat.uv1_triplanar_sharpness = 2.0

static func clear_cache() -> void:
	_cache.clear()
	TextureFactory3D.clear_cache()
