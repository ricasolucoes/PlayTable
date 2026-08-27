class_name TableZone3D
extends Node3D

## TableZone3D: a area demarcada no feltro que diz de quem e aquele monte.
##
## Numa mesa de verdade o feltro tem as marcas serigrafadas -- o arco do
## carteador, o retangulo da aposta -- e e por elas que o jogador sabe, sem
## ninguem explicar, o que e a mao dele e o que e a mesa. Sem isso o Blackjack e
## o Poker ficavam com duas fileiras de cartas iguais no meio do verde.
##
## E so marca: nao recebe toque, nao faz sombra e nao entra na fisica.

const RIM_THICKNESS := 0.02
const RIM_HEIGHT := 0.008

var _rim_material: StandardMaterial3D
var _label: Label3D


## Monta a zona. `size_xz` e a area demarcada em unidades de mundo, `caption` o
## rotulo serigrafado e `color` o tom da tinta.
func setup(size_xz: Vector2, caption: String, color: Color,
		caption_at_far_edge: bool = false) -> void:
	for c in get_children():
		c.queue_free()

	_rim_material = MaterialFactory3D.get_glow(color, 0.55)

	var half := size_xz * 0.5
	# Quatro tiras finas fecham o retangulo. Um quad com furo custaria uma malha
	# propria por zona e o resultado na tela e o mesmo.
	_rim(Vector3(0.0, RIM_HEIGHT, -half.y), Vector3(size_xz.x, RIM_HEIGHT, RIM_THICKNESS))
	_rim(Vector3(0.0, RIM_HEIGHT, half.y), Vector3(size_xz.x, RIM_HEIGHT, RIM_THICKNESS))
	_rim(Vector3(-half.x, RIM_HEIGHT, 0.0), Vector3(RIM_THICKNESS, RIM_HEIGHT, size_xz.y))
	_rim(Vector3(half.x, RIM_HEIGHT, 0.0), Vector3(RIM_THICKNESS, RIM_HEIGHT, size_xz.y))

	if caption == "":
		return

	_label = Label3D.new()
	_label.text = caption
	_label.font_size = 64
	# `pixel_size` converte o corpo da fonte em unidades de mundo: 64 px a
	# 0.0032 dao pouco mais de 0.2 unidade de altura, a mesma ordem da borda da
	# carta -- grande o bastante para ler, pequeno o bastante para nao competir.
	_label.pixel_size = 0.0032
	_label.modulate = color
	_label.outline_size = 16
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
	_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_label.shaded = false
	_label.no_depth_test = false
	_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Deitado no feltro, lendo de frente para a camera.
	_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var edge: float = -half.y - 0.18 if caption_at_far_edge else half.y + 0.18
	_label.position = Vector3(0.0, RIM_HEIGHT + 0.004, edge)
	add_child(_label)


func set_caption(caption: String) -> void:
	if _label:
		_label.text = caption


func _rim(pos: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = box
	inst.position = pos
	inst.material_override = _rim_material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


## Atalho: cria a zona ja montada e devolve pronta para o `add_child` do jogo.
static func create(size_xz: Vector2, center: Vector3, caption: String, color: Color,
		caption_at_far_edge: bool = false) -> TableZone3D:
	var zone := TableZone3D.new()
	zone.position = center
	zone.setup(size_xz, caption, color, caption_at_far_edge)
	return zone
