class_name Explosion3D
extends Node3D

## Explosion3D: o estouro em volta de uma peca destruida.
##
## Nasceu para a Batalha Naval -- o navio afundado nao tinha reacao nenhuma, so
## um pino vermelho a mais na casa -- mas nao sabe nada de navio: recebe o
## centro e o tamanho da peca e estoura em volta dela.
##
## Tres camadas, porque uma so nao le: o clarao (uma luz que acende e apaga em
## um quarto de segundo, e o que da o susto), os destrocos (particulas partindo
## do contorno da peca para fora, e o que da a direcao) e a onda (um anel que
## abre rente ao chao, e o que da a escala). Some sozinha quando termina.

const FLASH_IN := 0.06
const FLASH_OUT := 0.34
const DEBRIS_LIFETIME := 1.5
const RING_TIME := 0.55

var _lifetime := 0.0


## Estoura em volta de uma peca de `extents` (meias-medidas, em unidades de
## mundo) centrada em `center`, dentro de `parent`.
static func burst(parent: Node3D, center: Vector3, extents: Vector3,
		tint: Color = Color(1.0, 0.55, 0.15)) -> Explosion3D:
	var fx := Explosion3D.new()
	fx.position = center
	parent.add_child(fx)
	fx._play(extents, tint)
	return fx


func _play(extents: Vector3, tint: Color) -> void:
	_lifetime = DEBRIS_LIFETIME + 0.4
	var reach: float = maxf(maxf(extents.x, extents.z), 0.2)

	_spawn_flash(reach, tint)
	_spawn_debris(extents, reach, tint)
	_spawn_ring(reach, tint)

	# Sem particulas nem tween (Quality3D em modo reduzido) nao ha o que esperar.
	var timer := get_tree().create_timer(_lifetime)
	timer.timeout.connect(queue_free)


## O clarao. Uma OmniLight3D e nao um material emissivo: e a luz batendo nas
## pecas vizinhas que faz o estouro parecer estar na mesa, e nao colado na tela.
func _spawn_flash(reach: float, tint: Color) -> void:
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 0.0
	light.omni_range = reach * 6.0
	light.shadow_enabled = false
	light.position = Vector3(0.0, reach * 0.6, 0.0)
	add_child(light)

	var peak: float = 7.0 if Quality3D.tier() >= Quality3D.Tier.MEDIUM else 4.5
	var tw := create_tween()
	tw.tween_property(light, "light_energy", peak, FLASH_IN) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(light, "light_energy", 0.0, FLASH_OUT) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


## Os destrocos. A caixa de emissao e o contorno da peca, entao as faiscas
## partem de cima do casco inteiro -- e isso que faz o estouro acontecer EM
## VOLTA do navio, e nao num ponto no meio dele.
func _spawn_debris(extents: Vector3, reach: float, tint: Color) -> void:
	var amount := Quality3D.particle_budget(56)
	if amount <= 0:
		return

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(maxf(extents.x, 0.08), 0.05, maxf(extents.z, 0.08))
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 78.0
	mat.initial_velocity_min = reach * 2.6
	mat.initial_velocity_max = reach * 6.2
	mat.gravity = Vector3(0.0, -9.0, 0.0)
	mat.angular_velocity_min = -720.0
	mat.angular_velocity_max = 720.0
	mat.scale_min = 0.5
	mat.scale_max = 1.4
	mat.damping_min = 0.6
	mat.damping_max = 1.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.72, 1.0))
	ramp.set_color(1, Color(tint.r * 0.35, tint.g * 0.18, tint.b * 0.14, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex

	var shard := BoxMesh.new()
	shard.size = Vector3(0.05, 0.05, 0.09)
	var shard_mat := StandardMaterial3D.new()
	shard_mat.vertex_color_use_as_albedo = true
	shard_mat.albedo_color = tint
	shard_mat.emission_enabled = true
	shard_mat.emission = tint
	shard_mat.emission_energy_multiplier = 2.4
	shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shard.material = shard_mat

	var parts := GPUParticles3D.new()
	parts.amount = amount
	parts.lifetime = DEBRIS_LIFETIME
	parts.one_shot = true
	parts.explosiveness = 1.0
	parts.process_material = mat
	parts.draw_pass_1 = shard
	parts.position = Vector3(0.0, extents.y, 0.0)
	add_child(parts)
	parts.restart()


## A onda de choque: um anel achatado que abre rente a agua e some.
func _spawn_ring(reach: float, tint: Color) -> void:
	if Quality3D.reduced_motion():
		return
	var torus := TorusMesh.new()
	torus.inner_radius = reach * 0.62
	torus.outer_radius = reach * 0.72
	# `rings` sao as fatias em volta do anel e `ring_segments` as arestas da
	# secao do tubo -- nessa ordem. Trocados, o anel de choque sai como um
	# triangulo gigante em cima da mesa.
	torus.rings = 28 if Quality3D.tier() >= Quality3D.Tier.MEDIUM else 14
	torus.ring_segments = 6

	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = MaterialFactory3D.get_glow(tint, 1.6)
	ring.position = Vector3(0.0, 0.05, 0.0)
	ring.scale = Vector3(0.30, 0.30, 0.30)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.35, 0.35, 1.35), RING_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "transparency", 1.0, RING_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
