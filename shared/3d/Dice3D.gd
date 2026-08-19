class_name Dice3D
extends Node3D

## Dice3D: Dado 3D com rotação física, pontos embutidos e parada precisa no valor sorteado

signal roll_finished(value: int)

@export var dice_size: float = 0.55
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var current_value: int = 1
var is_rolling: bool = false

# Mapeamento de rotações em radianos para a face apontar para CIMA (Vector3.UP)
const FACE_ROTATIONS = {
	1: Vector3(0, 0, 0),
	6: Vector3(PI, 0, 0),
	2: Vector3(0, 0, PI * 0.5),
	5: Vector3(0, 0, -PI * 0.5),
	3: Vector3(-PI * 0.5, 0, 0),
	4: Vector3(PI * 0.5, 0, 0)
}

func _ready():
	_setup_materials()
	set_value_immediate(1)

func _setup_materials():
	if mesh_instance:
		mesh_instance.material_override = MaterialFactory3D.get_ivory()

func set_value_immediate(val: int):
	current_value = clamp(val, 1, 6)
	if FACE_ROTATIONS.has(current_value):
		rotation = FACE_ROTATIONS[current_value]

func roll(target_val: int, duration: float = 0.8):
	if is_rolling: return
	is_rolling = true
	target_val = clamp(target_val, 1, 6)
	current_value = target_val
	
	var target_rot = FACE_ROTATIONS[target_val]
	# Adiciona múltiplas voltas completas para o efeito de rolagem
	var spin_x = target_rot.x + (PI * 4.0 * (1 if randf() > 0.5 else -1))
	var spin_y = target_rot.y + (PI * 4.0 * (1 if randf() > 0.5 else -1))
	var spin_z = target_rot.z + (PI * 2.0 * (1 if randf() > 0.5 else -1))
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation", Vector3(spin_x, spin_y, spin_z), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Salto e quique do dado na mesa
	var tween_y = create_tween().set_parallel(false)
	var orig_y = position.y
	tween_y.tween_property(self, "position:y", orig_y + 1.2, duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(self, "position:y", orig_y, duration * 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	rotation = target_rot
	is_rolling = false
	roll_finished.emit(current_value)
