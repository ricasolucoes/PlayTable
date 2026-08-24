class_name Token3D
extends TableItem3D

## Token3D: Peca de tabuleiro -- disco, esfera ou peao.
##
## A origem da peca fica na BASE, nao no centro: `position.y` e a altura da
## superficie em que ela esta apoiada, o que torna impossivel deixar uma peca
## meio enterrada na casa por engano.
##
## Cada peca carrega a propria sombra de contato. O renderizador movel do Godot
## nao tem oclusao de ambiente em tela, entao o disco escuro sob a peca e o que
## impede o efeito "PNG colado sobre PNG".

signal token_clicked(token: Token3D)

@export var token_type: String = "cylinder" ## "cylinder", "sphere", "pawn"
@export var material_name: String = "ivory"
@export var token_radius: float = 0.36

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var crown_mesh: MeshInstance3D = $CrownMesh
@onready var contact_shadow: MeshInstance3D = $ContactShadow

var is_queen: bool = false
var grid_coord: Vector2i = Vector2i(-1, -1)

var _base_scale: Vector3 = Vector3.ONE
var _move_tween: Tween
var _lift_tween: Tween


func _init() -> void:
	# A peca e menor que a carta, entao treme menos ao recusar a jogada. Era a
	# unica diferenca entre os dois reject().
	reject_shake = 0.045
	reject_settle = 0.025

func _ready() -> void:
	_apply_shape_and_material()
	if crown_mesh:
		crown_mesh.visible = is_queen

func _apply_shape_and_material() -> void:
	if mesh_instance == null:
		return

	var height := Tokens3D.TOKEN_HEIGHT
	match token_type:
		"sphere":
			mesh_instance.mesh = MeshBuilder3D.sphere_token(token_radius * 0.86)
			# A esfera e gerada centrada; sobe metade para tocar a superficie.
			mesh_instance.position = Vector3(0.0, token_radius * 0.86, 0.0)
			height = token_radius * 1.72
		"pawn":
			mesh_instance.mesh = MeshBuilder3D.pawn(token_radius * 2.6, token_radius * 0.86)
			mesh_instance.position = Vector3.ZERO
			height = token_radius * 2.6
		_:
			mesh_instance.mesh = MeshBuilder3D.disc_token(token_radius, Tokens3D.TOKEN_HEIGHT)
			mesh_instance.position = Vector3.ZERO

	if crown_mesh:
		crown_mesh.mesh = MeshBuilder3D.crown(token_radius * 0.54, Tokens3D.TOKEN_HEIGHT * 0.8)
		crown_mesh.position = Vector3(0.0, height, 0.0)

	_setup_contact_shadow()
	apply_material(material_name)

func _setup_contact_shadow() -> void:
	var lado := token_radius * 2.0 * Tokens3D.CONTACT_SHADOW_GROW
	_apply_contact_shadow(contact_shadow, Vector2(lado, lado), 0.004)

func apply_material(mat_name: String) -> void:
	material_name = mat_name
	if mesh_instance:
		mesh_instance.material_override = MaterialFactory3D.by_name(mat_name)

# ---------------------------------------------------------------------------
# Movimento
# ---------------------------------------------------------------------------

## Assenta a peca em um destino. Usado quando ela apenas desliza para a casa
## vizinha -- sem arco, porque nao houve salto.
func slide_to(target: Vector3, duration: float = Tokens3D.DUR_NORMAL) -> void:
	_kill(_move_tween)
	var d := Quality3D.duration(duration)
	if d <= 0.0:
		position = target
		return
	_move_tween = create_tween()
	Tokens3D.ease_travel(_move_tween)
	_move_tween.tween_property(self, "position", target, d)

## Salto com arco: captura, pulo por cima de outra peca, entrada em cena.
## O arco existe porque uma peca tem peso -- ela sobe, viaja e desce.
func jump_to(target: Vector3, height: float = Tokens3D.ARC_LONG, duration: float = Tokens3D.DUR_NORMAL) -> void:
	_kill(_move_tween)
	var d := Quality3D.duration(duration)
	if d <= 0.0:
		position = target
		return

	var start := position
	var peak: float = maxf(start.y, target.y) + height
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_move_tween.tween_property(self, "position:x", target.x, d).set_trans(Tween.TRANS_SINE)
	_move_tween.tween_property(self, "position:z", target.z, d).set_trans(Tween.TRANS_SINE)

	var vertical := create_tween()
	vertical.tween_property(self, "position:y", peak, d * 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	vertical.tween_property(self, "position:y", target.y, d * 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Queda vertical: pecas que sao soltas de cima (Quatro em Linha, semeadura).
func drop_to(target: Vector3, duration: float = Tokens3D.DUR_NORMAL) -> void:
	_kill(_move_tween)
	var d := Quality3D.duration(duration)
	if d <= 0.0:
		position = target
		return
	_move_tween = create_tween()
	# Quique curto no fim: a peca chega, bate e assenta.
	_move_tween.tween_property(self, "position", target, d) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

## Levanta a peca do tabuleiro. A sombra de contato fica no chao e cresce,
## que e o que faz a altura ser lida como altura e nao como escala.
func set_lift(amount: float, duration: float = Tokens3D.DUR_FAST) -> void:
	if is_equal_approx(_lift, amount):
		return
	_lift = amount
	_kill(_lift_tween)

	var d := Quality3D.duration(duration)
	var shadow_scale: float = 1.0 + amount * 2.4
	var shadow_alpha: float = clampf(1.0 - amount * 1.6, 0.35, 1.0)

	if d <= 0.0:
		if mesh_instance:
			mesh_instance.position.y = _mesh_base_y() + amount
		if crown_mesh:
			crown_mesh.position.y = _crown_base_y() + amount
		_apply_shadow(shadow_scale, shadow_alpha)
		return

	_lift_tween = create_tween()
	_lift_tween.set_parallel(true)
	Tokens3D.ease_lift(_lift_tween)
	if mesh_instance:
		_lift_tween.tween_property(mesh_instance, "position:y", _mesh_base_y() + amount, d)
	if crown_mesh:
		_lift_tween.tween_property(crown_mesh, "position:y", _crown_base_y() + amount, d)
	if contact_shadow:
		_lift_tween.tween_property(contact_shadow, "scale",
			Vector3(shadow_scale, 1.0, shadow_scale), d)
		_lift_tween.tween_property(contact_shadow, "transparency", 1.0 - shadow_alpha, d)

## Compatibilidade: destaque agora e altura, nao escala. Uma peca que incha
## quebra a escala do tabuleiro; uma que levanta continua do mesmo tamanho.
func highlight(enable: bool) -> void:
	select(enable)

## Vira a peca (Reversi). Meia volta em X, trocando o material no meio.
func flip_180(new_mat_name: String, duration: float = Tokens3D.DUR_NORMAL) -> void:
	var d := Quality3D.duration(duration)
	if d <= 0.0:
		apply_material(new_mat_name)
		return

	var target_rot := rotation.x + PI
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "rotation:x", target_rot, d) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	var hop := create_tween()
	var base_y := position.y
	hop.tween_property(self, "position:y", base_y + Tokens3D.ARC_SHORT, d * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(self, "position:y", base_y, d * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Troca no meio da volta, quando a peca esta de perfil e a troca nao aparece.
	var swap := create_tween()
	swap.tween_interval(d * 0.5)
	swap.tween_callback(apply_material.bind(new_mat_name))

func promote_queen() -> void:
	is_queen = true
	if crown_mesh == null:
		return
	crown_mesh.show()
	crown_mesh.material_override = MaterialFactory3D.get_gold()
	var d := Quality3D.duration(Tokens3D.DUR_NORMAL)
	if d <= 0.0:
		crown_mesh.scale = Vector3.ONE
		return
	crown_mesh.scale = Vector3(0.05, 0.05, 0.05)
	var tw := create_tween()
	tw.tween_property(crown_mesh, "scale", Vector3.ONE, d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Sai de cena: encolhe e afunda, em vez de sumir de um quadro para o outro.
func vanish(then_free: bool = true) -> void:
	var d := Quality3D.duration(Tokens3D.DUR_FAST)
	if d <= 0.0:
		_finish_vanish(then_free)
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y - 0.12, d)
	tw.chain().tween_callback(queue_free if then_free else hide)

# ---------------------------------------------------------------------------

func _mesh_base_y() -> float:
	if token_type == "sphere":
		return token_radius * 0.86
	return 0.0

func _crown_base_y() -> float:
	match token_type:
		"sphere":
			return token_radius * 1.72
		"pawn":
			return token_radius * 2.6
		_:
			return Tokens3D.TOKEN_HEIGHT

func _apply_shadow(scale_xz: float, alpha: float) -> void:
	if contact_shadow == null:
		return
	contact_shadow.scale = Vector3(scale_xz, 1.0, scale_xz)
	contact_shadow.transparency = 1.0 - alpha
