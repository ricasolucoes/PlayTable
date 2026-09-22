extends Node3D

## Sonda de materiais para o aparelho: desenha um material por vez e escreve o
## nome antes, para que um "Failed to compile Metal library" no log caia logo
## abaixo do material culpado. So roda pelo `DeviceShots` com o gatilho "probe".

func _ready() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 2.2)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var luz := DirectionalLight3D.new()
	luz.shadow_enabled = true
	luz.rotation_degrees = Vector3(-50, 30, 0)
	add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.glow_enabled = true
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	add_child(env)


func casos() -> Array:
	var tex := ImageTexture.create_from_image(Image.create(64, 64, true, Image.FORMAT_RGBA8))
	var carta := StandardMaterial3D.new()
	carta.albedo_texture = tex
	carta.roughness = 0.44
	carta.metallic_specular = 0.38
	carta.clearcoat_enabled = true
	carta.clearcoat = 0.30
	carta.clearcoat_roughness = 0.35
	carta.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var carta_sem_cc := carta.duplicate() as StandardMaterial3D
	carta_sem_cc.clearcoat_enabled = false
	var carta_sem_aniso := carta.duplicate() as StandardMaterial3D
	carta_sem_aniso.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return [
		["wood_mahogany", MaterialFactory3D.get_wood_mahogany()],
		["wood_walnut", MaterialFactory3D.get_wood_walnut()],
		["felt", MaterialFactory3D.get_felt_casino()],
		["leather", MaterialFactory3D.get_leather()],
		["marble_white", MaterialFactory3D.get_marble_white()],
		["slate", MaterialFactory3D.get_slate()],
		["gold", MaterialFactory3D.get_gold()],
		["ivory", MaterialFactory3D.get_ivory()],
		["obsidian", MaterialFactory3D.get_obsidian()],
		["ceramic", MaterialFactory3D.get_ceramic(Color.RED)],
		["plastic", MaterialFactory3D.get_plastic(Color.BLUE)],
		["gemstone", MaterialFactory3D.get_gemstone(Color.GREEN)],
		["paper", MaterialFactory3D.get_paper()],
		["state_overlay", MaterialFactory3D.get_state_overlay(Color.GREEN)],
		["glow", MaterialFactory3D.get_glow(Color.YELLOW)],
		["contact_shadow", MaterialFactory3D.get_contact_shadow()],
		["checkers_white", MaterialFactory3D.checkers_piece(1)],
		["checkers_black", MaterialFactory3D.checkers_piece(-1)],
		["card", carta],
		["card_no_clearcoat", carta_sem_cc],
		["card_no_aniso", carta_sem_aniso],
		["state_shader", StateShader3D.marker()],
	]


func mostrar(material: Material) -> void:
	for filho in get_children():
		if filho is MeshInstance3D:
			filho.queue_free()
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	m.material_override = material
	add_child(m)
