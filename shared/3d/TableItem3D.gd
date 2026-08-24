class_name TableItem3D
extends Node3D

## Base do que fica sobre a mesa e a mão manipula: Card3D e Token3D.
##
## Os dois nasceram separados e convergiram sozinhos. `_kill`, `hover` e
## `select` eram idênticos; `reject` e `vanish` diferiam só em amplitude; e a
## sombra de contato era o mesmo bloco de sete linhas com outro tamanho de quad.
## Eram 64 linhas repetidas em oito métodos.
##
## O que de fato difere continua em cada um: como a carta se abre em leque e a
## peça salta (`set_lift`), a forma da malha, o material, o que acontece ao
## virar. Esta classe não guarda estado de jogo nem bandeira nenhuma para
## acomodar exceção.

## Amplitude do tremor lateral de jogada recusada, em metros. A carta treme um
## pouco mais que a peça porque é maior; cada um ajusta no próprio `_init`.
var reject_shake: float = 0.05

## Amplitude do terceiro tempo do tremor, menor, que assenta o objeto.
var reject_settle: float = 0.03

## Altura atual acima da superfície de apoio.
var _lift: float = 0.0


# ------------------------------------------------------------------ elevação

## Sobe ou desce o objeto. Cada tipo sobe do seu jeito — a carta abre em leque,
## a peça salta — então quem herda é obrigado a responder.
func set_lift(_amount: float, _duration: float = Tokens3D.DUR_FAST) -> void:
	pass


func hover(enable: bool) -> void:
	set_lift(Tokens3D.LIFT_HOVER if enable else 0.0, Tokens3D.DUR_INSTANT)


func select(enable: bool) -> void:
	set_lift(Tokens3D.LIFT_SELECTED if enable else 0.0, Tokens3D.DUR_FAST)


# ------------------------------------------------------------------ reações

## Tremor lateral de jogada recusada.
func reject() -> void:
	var d := Quality3D.duration(Tokens3D.DUR_FAST, false)
	if d <= 0.0:
		return
	var origin := position.x
	var tw := create_tween()
	tw.tween_property(self, "position:x", origin - reject_shake, d * 0.25)
	tw.tween_property(self, "position:x", origin + reject_shake, d * 0.25)
	tw.tween_property(self, "position:x", origin - reject_settle, d * 0.25)
	tw.tween_property(self, "position:x", origin, d * 0.25)


## Encolhe o objeto até sumir. Token3D acrescenta a queda e sobrescreve.
func vanish(then_free: bool = true) -> void:
	var d := Quality3D.duration(Tokens3D.DUR_FAST)
	if d <= 0.0:
		_finish_vanish(then_free)
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.02, 0.02, 0.02), d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free if then_free else hide)


## O que fazer quando não há animação a rodar — a qualidade zerou a duração.
func _finish_vanish(then_free: bool) -> void:
	if then_free:
		queue_free()
	else:
		hide()


# ------------------------------------------------------------------ auxiliares

## Monta a sombra de contato sob o objeto.
##
## O renderizador móvel do Godot não tem oclusão de ambiente em tela: esse disco
## escuro é o que impede o efeito "PNG colado sobre PNG".
func _apply_contact_shadow(shadow: MeshInstance3D, size: Vector2, offset_y: float) -> void:
	if shadow == null:
		return
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = size
	shadow.mesh = quad
	shadow.material_override = MaterialFactory3D.get_contact_shadow()
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = Vector3(0.0, offset_y, 0.0)


func _kill(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()
