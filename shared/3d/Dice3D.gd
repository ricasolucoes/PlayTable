class_name Dice3D
extends Node3D

## Dice3D: dado com pontos gravados, giro com voltas completas e parada precisa
## no valor sorteado.
##
## Os pontos vem do PipFactory3D e sao colocados no `_ready`, uma vez: sao 21
## calotas num unico MultiMesh, entao um dado inteiro custa duas chamadas de
## desenho (corpo e pontos). Antes daqui o dado era um cubo de marfim liso e o
## jogador nao tinha como saber o que tinha rolado.

signal roll_finished(value: int)

@export var dice_size: float = 0.55:
	set(value):
		dice_size = value
		if is_inside_tree():
			_rebuild()

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var current_value: int = 1
var is_rolling: bool = false

## Rotacao que deixa cada valor virado para cima. O arranjo dos pontos vem de
## PipFactory3D.DICE_FACES, que e o inverso desta tabela -- os dois andam juntos.
const FACE_ROTATIONS = {
	1: Vector3(0, 0, 0),
	6: Vector3(PI, 0, 0),
	2: Vector3(0, 0, PI * 0.5),
	5: Vector3(0, 0, -PI * 0.5),
	3: Vector3(-PI * 0.5, 0, 0),
	4: Vector3(PI * 0.5, 0, 0)
}

var _pips: MultiMeshInstance3D = null

func _ready() -> void:
	_rebuild()
	set_value_immediate(1)

## Corpo e pontos no tamanho corrente. Chamado de novo quando `dice_size` muda:
## a cena guarda um BoxMesh de 0.55 e o Gamao pede 0.50.
func _rebuild() -> void:
	if mesh_instance == null:
		return
	mesh_instance.mesh = MeshBuilder3D.create_dice_cube(dice_size)
	mesh_instance.material_override = MaterialFactory3D.get_ivory()

	if is_instance_valid(_pips):
		_pips.queue_free()
	_pips = PipFactory3D.dice_pips(dice_size)
	mesh_instance.add_child(_pips)

func set_value_immediate(val: int) -> void:
	current_value = clamp(val, 1, 6)
	if FACE_ROTATIONS.has(current_value):
		rotation = FACE_ROTATIONS[current_value]

func roll(target_val: int, duration: float = 0.8) -> void:
	# Rolagem pedida com o dado ainda no ar: sair calado deixava quem chamou
	# esperando um sinal que nunca vinha. O Ludo desabilita o botao ANTES de
	# chamar `roll()` e so o reabilita em `roll_finished` -- sem esta emissao o
	# botao do dado morria de vez, sem recuperacao possivel na partida.
	if is_rolling:
		roll_finished.emit(current_value)
		return
	is_rolling = true
	target_val = clamp(target_val, 1, 6)
	current_value = target_val

	var target_rot = FACE_ROTATIONS[target_val]
	# Adiciona múltiplas voltas completas para o efeito de rolagem
	var spin_x = target_rot.x + (PI * 4.0 * (1 if randf() > 0.5 else -1))
	var spin_y = target_rot.y + (PI * 4.0 * (1 if randf() > 0.5 else -1))
	var spin_z = target_rot.z + (PI * 2.0 * (1 if randf() > 0.5 else -1))

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "rotation", Vector3(spin_x, spin_y, spin_z), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Salto e quique do dado na mesa
	var tween_y := create_tween().set_parallel(false)
	var orig_y := position.y
	tween_y.tween_property(self, "position:y", orig_y + 1.2, duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(self, "position:y", orig_y, duration * 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	await tween.finished
	rotation = target_rot
	is_rolling = false
	roll_finished.emit(current_value)
