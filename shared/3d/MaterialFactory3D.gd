class_name MaterialFactory3D
extends RefCounted

## MaterialFactory3D: Gerador procedural de materiais PBR de alta fidelidade para Godot 4.3

static var _cached_materials: Dictionary = {}
static var _cached_card_textures: Dictionary = {}

# --- Materiais Básicos & Metais ---

static func get_wood_mahogany() -> StandardMaterial3D:
	if _cached_materials.has("wood_mahogany"):
		return _cached_materials["wood_mahogany"]
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.14, 0.08) # Mogno avermelhado nobre
	mat.roughness = 0.32
	mat.metallic = 0.05
	mat.clearcoat = 0.3
	mat.clearcoat_roughness = 0.2
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_cached_materials["wood_mahogany"] = mat
	return mat

static func get_wood_walnut() -> StandardMaterial3D:
	if _cached_materials.has("wood_walnut"):
		return _cached_materials["wood_walnut"]
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.12, 0.09) # Nogueira escura
	mat.roughness = 0.38
	mat.metallic = 0.02
	mat.clearcoat = 0.2
	_cached_materials["wood_walnut"] = mat
	return mat

static func get_wood_maple() -> StandardMaterial3D:
	if _cached_materials.has("wood_maple"):
		return _cached_materials["wood_maple"]
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.76, 0.58) # Madeira clara / bordo
	mat.roughness = 0.4
	mat.metallic = 0.0
	_cached_materials["wood_maple"] = mat
	return mat

static func get_felt_casino(color: Color = Color(0.08, 0.35, 0.22)) -> StandardMaterial3D:
	var key = "felt_%s" % color.to_html()
	if _cached_materials.has(key):
		return _cached_materials[key]
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	mat.rim_enabled = true
	mat.rim = 0.45
	mat.rim_tint = 0.5
	_cached_materials[key] = mat
	return mat

static func get_gold() -> StandardMaterial3D:
	if _cached_materials.has("gold"):
		return _cached_materials["gold"]
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.32)
	mat.metallic = 0.95
	mat.roughness = 0.18
	mat.clearcoat = 0.5
	_cached_materials["gold"] = mat
	return mat

static func get_silver() -> StandardMaterial3D:
	if _cached_materials.has("silver"):
		return _cached_materials["silver"]
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.94, 0.98)
	mat.metallic = 0.95
	mat.roughness = 0.22
	_cached_materials["silver"] = mat
	return mat

static func get_ivory() -> StandardMaterial3D:
	if _cached_materials.has("ivory"):
		return _cached_materials["ivory"]
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.94, 0.89)
	mat.roughness = 0.25
	mat.metallic = 0.05
	mat.clearcoat = 0.4
	mat.clearcoat_roughness = 0.15
	_cached_materials["ivory"] = mat
	return mat

static func get_obsidian() -> StandardMaterial3D:
	if _cached_materials.has("obsidian"):
		return _cached_materials["obsidian"]
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.09, 0.11)
	mat.roughness = 0.12
	mat.metallic = 0.1
	mat.clearcoat = 0.8
	mat.clearcoat_roughness = 0.1
	_cached_materials["obsidian"] = mat
	return mat

static func get_gemstone(color: Color) -> StandardMaterial3D:
	var key = "gem_%s" % color.to_html()
	if _cached_materials.has(key):
		return _cached_materials[key]
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.08
	mat.metallic = 0.2
	mat.clearcoat = 1.0
	mat.clearcoat_roughness = 0.05
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.rim_tint = 0.8
	_cached_materials[key] = mat
	return mat

static func get_plastic(color: Color, is_glossy: bool = true) -> StandardMaterial3D:
	var key = "plastic_%s_%s" % [color.to_html(), is_glossy]
	if _cached_materials.has(key):
		return _cached_materials[key]
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.18 if is_glossy else 0.5
	mat.metallic = 0.05
	mat.clearcoat = 0.6 if is_glossy else 0.0
	_cached_materials[key] = mat
	return mat

static func get_glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key = "glow_%s_%.1f" % [color.to_html(), energy]
	if _cached_materials.has(key):
		return _cached_materials[key]
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	_cached_materials[key] = mat
	return mat

# --- Texturas Procedurais de Cartas ---

static func create_card_front_texture(rank: String, suit: String, suit_color: Color) -> ImageTexture:
	var key = "%s_%s_%s" % [rank, suit, suit_color.to_html()]
	if _cached_card_textures.has(key):
		return _cached_card_textures[key]
	
	var width = 256
	var height = 384
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	# Fundo branco marfim com borda suave
	var bg_color = Color(0.98, 0.98, 0.97)
	var border_color = Color(0.85, 0.85, 0.82)
	var inner_border = Color(0.92, 0.92, 0.9)
	
	for y in range(height):
		for x in range(width):
			var is_border = (x < 6 or x >= width - 6 or y < 6 or y >= height - 6)
			var is_inner = (x >= 12 and x < width - 12 and (y == 12 or y == height - 13)) or \
						   (y >= 12 and y < height - 12 and (x == 12 or x == width - 13))
			
			if is_border:
				img.set_pixel(x, y, border_color)
			elif is_inner:
				img.set_pixel(x, y, inner_border)
			else:
				img.set_pixel(x, y, bg_color)
				
	var tex = ImageTexture.create_from_image(img)
	_cached_card_textures[key] = tex
	return tex

static func get_card_back_material() -> StandardMaterial3D:
	if _cached_materials.has("card_back"):
		return _cached_materials["card_back"]
		
	var width = 256
	var height = 384
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	var navy = Color(0.08, 0.14, 0.28)
	var gold = Color(0.88, 0.72, 0.28)
	var white = Color(0.96, 0.96, 0.96)
	
	for y in range(height):
		for x in range(width):
			var is_edge = (x < 8 or x >= width - 8 or y < 8 or y >= height - 8)
			var is_gold_border = (x >= 14 and x < width - 14 and (y == 14 or y == height - 15)) or \
								 (y >= 14 and y < height - 14 and (x == 14 or x == width - 15))
			var pattern = ((x + y) / 12) % 2 == 0
			
			if is_edge:
				img.set_pixel(x, y, white)
			elif is_gold_border:
				img.set_pixel(x, y, gold)
			else:
				var col = navy if pattern else Color(0.12, 0.2, 0.38)
				img.set_pixel(x, y, col)
				
	var tex = ImageTexture.create_from_image(img)
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.25
	mat.clearcoat = 0.5
	_cached_materials["card_back"] = mat
	return mat
