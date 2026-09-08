class_name DiceTray3D
extends Node3D

## N dados lado a lado, com "segurar" por dado e rolagem em lote.
##
## O General rola cinco e segura alguns entre as rolagens; a Guerra rola tres
## contra dois. O `Dice3D` sabe rolar UM dado; o que e igual nos dois jogos --
## enfileirar, rolar os que nao estao presos, esperar todos pararem, marcar o
## que esta preso com o mesmo anel do resto do aplicativo -- mora aqui.
##
##     tray = DiceTray3D.new()
##     add_child(tray)
##     tray.setup(5)
##     tray.rolled.connect(_on_rolou)
##     tray.roll(DiceTray3D.random_values(5))
##
## O toque nos dados entra pelo `DragPicker3D` do jogo, com `positions()` como
## alvos: e o jogo que decide o que o toque significa (segurar, rolar).

## Todos os dados pararam. `values` e o valor de cada um, presos incluidos.
signal rolled(values: Array)

const DICE_SCENE := preload("res://shared/3d/Dice3D.tscn")

var dice: Array = []        # Array[Dice3D]
var held: Array[bool] = []
var values: Array[int] = []
var halos: CellHalo3D = null

var _spacing: float = 0.9
var _dice_size: float = 0.55
var _pending: int = 0


## Enfileira `count` dados centrados na origem do no, `spacing` entre eles.
func setup(count: int, spacing: float = 0.9, dice_size: float = 0.55) -> void:
	for d in dice:
		if is_instance_valid(d):
			d.queue_free()
	dice.clear()
	held.clear()
	values.clear()
	_spacing = spacing
	_dice_size = dice_size
	for i in count:
		var d: Dice3D = DICE_SCENE.instantiate()
		d.dice_size = dice_size
		d.position = _slot(i, count)
		add_child(d)
		dice.append(d)
		held.append(false)
		values.append(1)
	if halos == null:
		halos = CellHalo3D.new()
		add_child(halos)
	halos.setup(count, dice_size * 0.95)
	var alvos: Array = []
	for i in count:
		var p := _slot(i, count)
		alvos.append(Vector3(p.x, 0.0, p.z))
	halos.set_targets(alvos)
	halos.clear()


func _slot(i: int, total: int) -> Vector3:
	var x := (float(i) - float(total - 1) * 0.5) * _spacing
	return Vector3(x, _dice_size * 0.5, 0.0)


func count() -> int:
	return dice.size()


## Largura x comprimento da bandeja, para o enquadramento.
func content_size() -> Vector2:
	return Vector2(_spacing * float(maxi(dice.size() - 1, 0)) + _dice_size * 1.4, _dice_size * 1.6)


## As posicoes dos dados em coordenadas de MUNDO, para o picker do jogo.
func positions() -> Array:
	var saida: Array = []
	for d in dice:
		saida.append((d as Node3D).global_position)
	return saida


func is_rolling() -> bool:
	for d in dice:
		if (d as Dice3D).is_rolling:
			return true
	return false


## Rola os dados que nao estao presos para `new_values` (um por dado; os
## presos ignoram o valor deles). Emite `rolled` quando o ultimo parar.
func roll(new_values: Array, skip_held: bool = true) -> void:
	if is_rolling():
		return
	_pending = 0
	if AudioManager:
		AudioManager.play_dice()
	for i in dice.size():
		if skip_held and held[i]:
			continue
		var v := int(new_values[i]) if i < new_values.size() else 1
		values[i] = v
		_pending += 1
		var d: Dice3D = dice[i]
		d.roll_finished.connect(_on_um_parou, CONNECT_ONE_SHOT)
		d.roll(v, 0.8 + float(i) * 0.06)
	if _pending == 0:
		rolled.emit(values.duplicate())


func _on_um_parou(_value: int) -> void:
	_pending -= 1
	if _pending <= 0:
		rolled.emit(values.duplicate())


## Poe os valores sem animacao (recomecar, restaurar).
func set_values_immediate(new_values: Array) -> void:
	for i in dice.size():
		var v := int(new_values[i]) if i < new_values.size() else 1
		values[i] = v
		(dice[i] as Dice3D).set_value_immediate(v)


## Prende ou solta o dado `i`; preso ganha o anel de selecionado.
func set_held(i: int, on: bool) -> void:
	if i < 0 or i >= held.size():
		return
	held[i] = on
	if halos != null:
		if on:
			halos.light(i, Tokens3D.COLOR_SELECTED)
		else:
			halos.light(i, Color(0, 0, 0, 0))


func toggle_held(i: int) -> void:
	set_held(i, not held[i])


func release_all() -> void:
	for i in held.size():
		set_held(i, false)


func held_indices() -> Array[int]:
	var saida: Array[int] = []
	for i in held.size():
		if held[i]:
			saida.append(i)
	return saida


## Acende `indices` com uma cor (dica, dado que pode ser tocado).
func light(indices: Array, color: Color = Tokens3D.COLOR_VALID) -> void:
	if halos == null:
		return
	for i in dice.size():
		if held[i]:
			halos.light(i, Tokens3D.COLOR_SELECTED)
		elif indices.has(i):
			halos.light(i, color)
		else:
			halos.light(i, Color(0, 0, 0, 0))


## `n` valores de 1 a 6, com o gerador dado (o da partida, em rede) ou o global.
static func random_values(n: int, rng: RandomNumberGenerator = null) -> Array:
	var saida: Array = []
	for i in n:
		saida.append(rng.randi_range(1, 6) if rng != null else randi_range(1, 6))
	return saida
