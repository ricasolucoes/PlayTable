class_name TabletopEnvironment3D
extends Node3D

## TabletopEnvironment3D: A mesa, a luz e a camera. Uma unica cena para os 16
## jogos; o que muda entre eles e o GameTheme3D aplicado.
##
## Iluminacao em tres direcionais em vez de um refletor: um SpotLight preso a
## uma altura fixa estoura o centro do tabuleiro e apaga as bordas assim que o
## tabuleiro cresce. Direcionais dao o mesmo resultado em qualquer tamanho de
## tabuleiro, custam menos no celular e nao criam ponto quente.

signal framing_changed(content_size: Vector2)

@export var theme: GameTheme3D
@export var felt_color: Color = Color(0.07, 0.31, 0.19)

@onready var camera: CameraRig3D = $CameraRig3D
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var fill_light: DirectionalLight3D = $FillLight
@onready var rim_light: DirectionalLight3D = $RimLight
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var table_top: MeshInstance3D = $TableRoot/TableTop
@onready var table_felt: MeshInstance3D = $TableRoot/TableFelt
@onready var win_particles: GPUParticles3D = $WinParticles

var _active_theme: GameTheme3D

func _ready() -> void:
	# Sem isto os Area3D dos tabuleiros nunca recebem toque nem clique: o
	# viewport raiz do Godot vem com a selecao por fisica desligada.
	var vp := get_viewport()
	if vp:
		vp.physics_object_picking = true
		vp.physics_object_picking_sort = true

	_active_theme = theme if theme != null else GameTheme3D.casino_green()
	if theme == null:
		_active_theme.surface_color = felt_color
	apply_theme(_active_theme)

## Troca toda a direcao de arte da cena de uma vez.
func apply_theme(new_theme: GameTheme3D) -> void:
	if new_theme == null:
		return
	_active_theme = new_theme
	theme = new_theme
	felt_color = new_theme.surface_color
	_apply_surfaces()
	_apply_lighting()
	_apply_environment()
	if camera:
		camera.tilt_degrees = new_theme.camera_tilt

func _apply_surfaces() -> void:
	if table_top:
		table_top.material_override = _active_theme.build_table_material()
	if table_felt:
		table_felt.material_override = _active_theme.build_surface_material()

func _apply_lighting() -> void:
	var t := _active_theme
	if key_light:
		key_light.light_color = t.key_color
		key_light.light_energy = t.key_energy
		key_light.rotation_degrees = Vector3(t.key_angle_deg.x, t.key_angle_deg.y, 0.0)
		key_light.shadow_enabled = true
		# Sombra apertada em volta da mesa: com alcance curto o mesmo mapa de
		# sombra cobre muito menos mundo, e a sombra deixa de serrilhar.
		key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		key_light.directional_shadow_max_distance = 26.0
		key_light.directional_shadow_fade_start = 0.9
		# bias pequeno + normal_bias alto: o bias antigo (0.04) descolava a
		# sombra da peca; o normal_bias tira o serrilhado sem descolar.
		key_light.shadow_bias = 0.012
		key_light.shadow_normal_bias = 1.6
		key_light.shadow_blur = 1.1
		# Sol com tamanho angular: penumbra que abre com a distancia.
		key_light.light_angular_distance = 1.4 if Quality3D.tier() >= Quality3D.Tier.MEDIUM else 0.0
		key_light.light_specular = 0.45

	if fill_light:
		fill_light.light_color = t.fill_color
		fill_light.light_energy = t.fill_energy
		fill_light.rotation_degrees = Vector3(-28.0, 132.0, 0.0)
		fill_light.shadow_enabled = false
		fill_light.light_specular = 0.1

	if rim_light:
		rim_light.light_color = t.rim_color
		rim_light.light_energy = t.rim_energy
		rim_light.rotation_degrees = Vector3(-14.0, 186.0, 0.0)
		rim_light.shadow_enabled = false
		rim_light.light_specular = 0.9

func _apply_environment() -> void:
	if world_env == null or world_env.environment == null:
		return
	var env := world_env.environment
	var t := _active_theme
	env.ambient_light_color = t.ambient_color
	env.ambient_light_energy = t.ambient_energy
	# O renderizador movel do Godot 4.3 nao suporta SSAO/SSIL/SSR nem nevoa
	# volumetrica: o que da profundidade aqui e a propria geometria (sombras
	# de contato, bevel) mais um glow contido.
	env.glow_enabled = t.glow_strength > 0.0 and Quality3D.tier() >= Quality3D.Tier.MEDIUM
	env.glow_intensity = t.glow_strength
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
		var horizon := t.ambient_color.darkened(0.55)
		sky_mat.sky_top_color = t.ambient_color.darkened(0.35)
		sky_mat.sky_horizon_color = horizon
		sky_mat.ground_horizon_color = horizon
		sky_mat.ground_bottom_color = horizon.darkened(0.4)

## Enquadra a camera em um conteudo de `size_xz` unidades centrado em `center`.
## Chame sempre que o tabuleiro for montado ou mudar de tamanho.
func frame_content(size_xz: Vector2, center: Vector3 = Vector3.ZERO) -> void:
	if camera:
		camera.frame_content(size_xz, center, _active_theme.camera_tilt)
	framing_changed.emit(size_xz)

## Informa a camera quanto da tela a HUD ocupa, em pixels do viewport logico.
func set_safe_area(top_px: float, bottom_px: float) -> void:
	if camera:
		camera.set_safe_area(top_px, bottom_px)

## Mantido para compatibilidade: troca so a cor da superficie.
func set_felt_color(color: Color) -> void:
	felt_color = color
	if _active_theme:
		_active_theme.surface_color = color
	if table_felt:
		table_felt.material_override = _active_theme.build_surface_material() if _active_theme \
			else MaterialFactory3D.get_felt_casino(color)

## Comemoracao de fim de partida. Proporcional: um pulso de luz e um punhado de
## confete, nao um espetaculo.
func celebrate_win() -> void:
	var budget := Quality3D.particle_budget(48)
	if win_particles and budget > 0:
		win_particles.amount = budget
		win_particles.restart()
		win_particles.emitting = true

	if key_light:
		var base_energy := key_light.light_energy
		var tw := create_tween()
		tw.tween_property(key_light, "light_energy", base_energy * 1.6, Tokens3D.DUR_NORMAL) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(key_light, "light_energy", base_energy, Tokens3D.DUR_CELEBRATE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Chama a atencao para um ponto do tabuleiro sem cortar o ritmo da partida.
func focus_on(world_point: Vector3) -> void:
	if camera:
		camera.nudge_toward(world_point)
