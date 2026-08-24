class_name Card3D
extends TableItem3D

## Card3D: Carta de baralho com espessura, face impressa e peso no movimento.
##
## A carta e uma malha de duas superficies compartilhada por todo o baralho; o
## que muda de uma carta para outra e apenas o material da face, que aponta
## para uma celula do CardAtlas3D. Ver CardAtlas3D para o porque do atlas.
##
## De frente para cima a face olha para +Y. Virar e girar 180 graus em Z, o que
## mantem o eixo maior da carta parado -- girar em X faria a carta "rolar" para
## a frente, que nao e como se vira uma carta na mao.

signal card_clicked(card: Card3D)

@export var rank: String = "A"
@export var suit: String = CardArt2D.SUIT_SPADE
@export var is_face_up: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var contact_shadow: MeshInstance3D = $ContactShadow
@onready var picker: Area3D = $Picker
@onready var picker_shape: CollisionShape3D = $Picker/CollisionShape3D

var custom_data: Dictionary = {}

var _move_tween: Tween
var _ready_done: bool = false

func _ready() -> void:
	_setup_collision()
	_setup_contact_shadow()
	await CardAtlas3D.ensure_built(self)
	if not is_instance_valid(self):
		return
	_ready_done = true
	_update_visuals()

func setup(p_rank: String, p_suit: String, p_face_up: bool = false) -> void:
	rank = p_rank
	suit = p_suit
	is_face_up = p_face_up
	if _ready_done:
		_update_visuals()
	else:
		rotation_degrees.z = 0.0 if is_face_up else 180.0

func _update_visuals() -> void:
	if mesh_instance == null or not CardAtlas3D.is_ready():
		return
	mesh_instance.mesh = MeshBuilder3D.card_mesh(
		Tokens3D.CARD_WIDTH, Tokens3D.CARD_LENGTH, Tokens3D.CARD_THICKNESS,
		CardAtlas3D.back_uv(), CardAtlas3D.rim_uv())
	mesh_instance.set_surface_override_material(0, CardAtlas3D.face_material(rank, suit))
	mesh_instance.set_surface_override_material(1, CardAtlas3D.body_material())
	rotation_degrees.z = 0.0 if is_face_up else 180.0

func _setup_collision() -> void:
	if picker_shape == null:
		return
	var box := BoxShape3D.new()
	box.size = Vector3(Tokens3D.CARD_WIDTH, maxf(Tokens3D.CARD_THICKNESS, 0.05), Tokens3D.CARD_LENGTH)
	picker_shape.shape = box

func _setup_contact_shadow() -> void:
	_apply_contact_shadow(contact_shadow,
		Vector2(Tokens3D.CARD_WIDTH * 1.30, Tokens3D.CARD_LENGTH * 1.22),
		-Tokens3D.CARD_THICKNESS * 0.5 - 0.002)

# ---------------------------------------------------------------------------
# Movimento
# ---------------------------------------------------------------------------

## Vira a carta. O pequeno salto no meio existe porque virar uma carta na mesa
## exige levanta-la da superficie -- sem ele a carta atravessa a mesa.
func flip(face_up: bool, duration: float = Tokens3D.DUR_NORMAL) -> void:
	if is_face_up == face_up:
		return
	is_face_up = face_up
	var target_z: float = 0.0 if is_face_up else 180.0
	var d := Quality3D.duration(duration)
	if d <= 0.0:
		rotation_degrees.z = target_z
		return

	var spin := create_tween()
	spin.tween_property(self, "rotation_degrees:z", target_z, d) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	var base_y := position.y
	var hop := create_tween()
	hop.tween_property(self, "position:y", base_y + Tokens3D.ARC_SHORT * 0.5, d * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(self, "position:y", base_y, d * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Distribuicao: a carta viaja da mao do carteador ate o lugar dela, com um
## arco baixo e uma leve inclinacao -- nao teleporta nem desliza reta.
func deal_to(target_pos: Vector3, target_rot_y: float = 0.0,
		duration: float = Tokens3D.DUR_SLOW) -> void:
	_kill(_move_tween)
	var d := Quality3D.duration(duration)
	if d <= 0.0:
		position = target_pos
		rotation_degrees.y = target_rot_y
		return

	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_move_tween.tween_property(self, "position:x", target_pos.x, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position:z", target_pos.z, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "rotation_degrees:y", target_rot_y, d).set_trans(Tween.TRANS_SINE)

	var peak: float = maxf(position.y, target_pos.y) + Tokens3D.ARC_SHORT
	var arc := create_tween()
	arc.tween_property(self, "position:y", peak, d * 0.42) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(self, "position:y", target_pos.y, d * 0.58) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Deslocamento sem arco: reorganizar a mao, empilhar, encaixar na fundacao.
func move_to(target_pos: Vector3, duration: float = Tokens3D.DUR_NORMAL) -> void:
	_kill(_move_tween)
	var d := Quality3D.duration(duration)
	if d <= 0.0:
		position = target_pos
		return
	_move_tween = create_tween()
	Tokens3D.ease_travel(_move_tween)
	_move_tween.tween_property(self, "position", target_pos, d)

# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

## Levanta a carta da mesa. Quem sobe e a malha, nao o no raiz: assim a sombra
## de contato fica no lugar onde a carta estava, cresce e clareia -- que e o que
## comunica altura. Se a raiz subisse, a sombra subiria junto e a carta pareceria
## apenas maior.
func set_lift(amount: float, duration: float = Tokens3D.DUR_FAST) -> void:
	if is_equal_approx(_lift, amount):
		return
	_lift = amount
	var spread: float = 1.0 + amount * 1.8
	var d := Quality3D.duration(duration)

	if d <= 0.0:
		if mesh_instance:
			mesh_instance.position.y = amount
		if contact_shadow:
			contact_shadow.scale = Vector3(spread, 1.0, spread)
			contact_shadow.transparency = clampf(amount * 1.4, 0.0, 0.6)
		return

	var tw := create_tween()
	tw.set_parallel(true)
	Tokens3D.ease_lift(tw)
	if mesh_instance:
		tw.tween_property(mesh_instance, "position:y", amount, d)
	if contact_shadow:
		tw.tween_property(contact_shadow, "scale", Vector3(spread, 1.0, spread), d)
		tw.tween_property(contact_shadow, "transparency", clampf(amount * 1.4, 0.0, 0.6), d)

func _on_picker_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		card_clicked.emit(self)
