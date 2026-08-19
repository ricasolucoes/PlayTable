class_name Card3D
extends Node3D

## Card3D: Entidade de Carta 3D com espessura, física de virada, relevo e sombra

signal card_clicked(card: Card3D)

@export var rank: String = "A"
@export var suit: String = "♠"
@export var is_face_up: bool = false

@onready var front_mesh: MeshInstance3D = $FrontFace
@onready var back_mesh: MeshInstance3D = $BackFace
@onready var card_body: MeshInstance3D = $CardBody

var custom_data: Dictionary = {}

func _ready() -> void:
	_update_visuals()

func setup(p_rank: String, p_suit: String, p_face_up: bool = false) -> void:
	rank = p_rank
	suit = p_suit
	is_face_up = p_face_up
	_update_visuals()

func _update_visuals() -> void:
	var is_red = (suit == "♥" or suit == "♦" or suit == "red")
	var suit_col = Color(0.85, 0.15, 0.15) if is_red else Color(0.12, 0.14, 0.18)
	
	if front_mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = MaterialFactory3D.create_card_front_texture(rank, suit, suit_col)
		mat.roughness = 0.3
		mat.clearcoat = 0.3
		front_mesh.material_override = mat
		
	if back_mesh:
		back_mesh.material_override = MaterialFactory3D.get_card_back_material()
		
	if card_body:
		var body_mat = StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.95, 0.95, 0.94)
		body_mat.roughness = 0.4
		card_body.material_override = body_mat

	rotation_degrees.z = 0.0 if is_face_up else 180.0

func flip(face_up: bool, duration: float = 0.35) -> void:
	is_face_up = face_up
	var target_z = 0.0 if is_face_up else 180.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation_degrees:z", target_z, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Salto vertical ao virar
	var tween_y = create_tween().set_parallel(false)
	var orig_y = position.y
	tween_y.tween_property(self, "position:y", orig_y + 0.4, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(self, "position:y", orig_y, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func deal_to(target_pos: Vector3, target_rot_y: float = 0.0, duration: float = 0.45) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:x", target_pos.x, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:z", target_pos.z, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "rotation_degrees:y", target_rot_y, duration).set_trans(Tween.TRANS_SINE)
	
	var tween_y = create_tween().set_parallel(false)
	var peak_y = max(position.y, target_pos.y) + 0.5
	tween_y.tween_property(self, "position:y", peak_y, duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(self, "position:y", target_pos.y, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func hover(enable: bool) -> void:
	var tween = create_tween()
	var target_y = 0.25 if enable else 0.0
	tween.tween_property(self, "position:y", target_y, 0.15).set_trans(Tween.TRANS_SINE)
