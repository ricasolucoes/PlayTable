class_name Token3D
extends Node3D

## Token3D: Ficha / Peça / Peca 3D multifuncional para jogos de tabuleiro

@export var token_type: String = "cylinder" # "cylinder", "sphere", "pawn"
@export var material_name: String = "ivory"

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var crown_mesh: MeshInstance3D = $CrownMesh

var is_queen: bool = false
var grid_coord: Vector2i = Vector2i(-1, -1)

func _ready():
	_apply_shape_and_material()
	if crown_mesh:
		crown_mesh.visible = is_queen

func _apply_shape_and_material():
	if not mesh_instance: return
	
	match token_type:
		"sphere":
			mesh_instance.mesh = MeshBuilder3D.create_sphere_token(0.32)
		"pawn":
			mesh_instance.mesh = MeshBuilder3D.create_pawn_meeple(0.65, 0.22, 0.1)
		_:
			mesh_instance.mesh = MeshBuilder3D.create_cylinder_token(0.38, 0.12)
			
	apply_material(material_name)

func apply_material(mat_name: String):
	material_name = mat_name
	if not mesh_instance: return
	
	match mat_name:
		"ivory":
			mesh_instance.material_override = MaterialFactory3D.get_ivory()
		"obsidian":
			mesh_instance.material_override = MaterialFactory3D.get_obsidian()
		"gold":
			mesh_instance.material_override = MaterialFactory3D.get_gold()
		"silver":
			mesh_instance.material_override = MaterialFactory3D.get_silver()
		"ruby":
			mesh_instance.material_override = MaterialFactory3D.get_gemstone(Color(0.9, 0.1, 0.2))
		"sapphire":
			mesh_instance.material_override = MaterialFactory3D.get_gemstone(Color(0.1, 0.4, 0.95))
		"emerald":
			mesh_instance.material_override = MaterialFactory3D.get_gemstone(Color(0.1, 0.8, 0.3))
		"amber":
			mesh_instance.material_override = MaterialFactory3D.get_gemstone(Color(0.95, 0.65, 0.1))
		"plastic_red":
			mesh_instance.material_override = MaterialFactory3D.get_plastic(Color(0.92, 0.15, 0.15))
		"plastic_yellow":
			mesh_instance.material_override = MaterialFactory3D.get_plastic(Color(0.95, 0.85, 0.12))
		"plastic_blue":
			mesh_instance.material_override = MaterialFactory3D.get_plastic(Color(0.15, 0.5, 0.95))
		"plastic_green":
			mesh_instance.material_override = MaterialFactory3D.get_plastic(Color(0.15, 0.8, 0.35))
		"wood_light":
			mesh_instance.material_override = MaterialFactory3D.get_wood_maple()
		"wood_dark":
			mesh_instance.material_override = MaterialFactory3D.get_wood_walnut()

func drop_to(target_pos: Vector3, duration: float = 0.4):
	var tween = create_tween().set_parallel(false)
	tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func jump_to(target_pos: Vector3, height: float = 0.6, duration: float = 0.35):
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:x", target_pos.x, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:z", target_pos.z, duration).set_trans(Tween.TRANS_SINE)
	
	# Arco em Y
	var tween_y = create_tween().set_parallel(false)
	var peak_y = max(position.y, target_pos.y) + height
	tween_y.tween_property(self, "position:y", peak_y, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(self, "position:y", target_pos.y, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func flip_180(new_mat_name: String, duration: float = 0.35):
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation:x", rotation.x + PI, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# Salto sutil ao virar
	var tween_y = create_tween().set_parallel(false)
	var orig_y = position.y
	tween_y.tween_property(self, "position:y", orig_y + 0.3, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(self, "position:y", orig_y, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	get_tree().create_timer(duration * 0.5).timeout.connect(func(): apply_material(new_mat_name))

func promote_queen():
	is_queen = true
	if crown_mesh:
		crown_mesh.show()
		crown_mesh.material_override = MaterialFactory3D.get_gold()
		crown_mesh.scale = Vector3(0.01, 0.01, 0.01)
		var tween = create_tween()
		tween.tween_property(crown_mesh, "scale", Vector3(1, 1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func highlight(enable: bool):
	var tween = create_tween()
	var target_scale = Vector3(1.15, 1.15, 1.15) if enable else Vector3(1.0, 1.0, 1.0)
	tween.tween_property(self, "scale", target_scale, 0.15).set_trans(Tween.TRANS_SINE)
