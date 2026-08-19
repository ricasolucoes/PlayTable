class_name TabletopEnvironment3D
extends Node3D

## TabletopEnvironment3D: Cenário 3D de alta fidelidade para jogos de mesa e cartas

@export var felt_color: Color = Color(0.08, 0.35, 0.22) # Verde cassino padrão
@export var enable_camera_sway: bool = true
@export var camera_tilt_degrees: float = 58.0
@export var camera_distance: float = 6.0

@onready var camera: Camera3D = $Camera3D
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var spot_light: SpotLight3D = $SpotLight3D
@onready var table_top: MeshInstance3D = $TableRoot/TableTop
@onready var table_felt: MeshInstance3D = $TableRoot/TableFelt
@onready var dust_particles: CPUParticles3D = $DustParticles
@onready var win_particles: CPUParticles3D = $WinParticles

var _base_cam_pos: Vector3
var _time_elapsed: float = 0.0

func _ready() -> void:
	_setup_lighting_and_materials()
	_setup_camera()

func _setup_lighting_and_materials() -> void:
	# Configura materiais PBR da mesa
	if table_top:
		table_top.material_override = MaterialFactory3D.get_wood_mahogany()
	if table_felt:
		table_felt.material_override = MaterialFactory3D.get_felt_casino(felt_color)

func _setup_camera() -> void:
	if camera:
		var rad = deg_to_rad(camera_tilt_degrees)
		var cam_y = camera_distance * sin(rad)
		var cam_z = camera_distance * cos(rad)
		camera.position = Vector3(0, cam_y, cam_z)
		camera.look_at(Vector3(0, 0, 0), Vector3.UP)
		_base_cam_pos = camera.position

func set_felt_color(color: Color) -> void:
	felt_color = color
	if table_felt:
		table_felt.material_override = MaterialFactory3D.get_felt_casino(color)

func _process(delta: float) -> void:
	if enable_camera_sway and camera:
		_time_elapsed += delta * 0.5
		var offset_x = sin(_time_elapsed * 0.7) * 0.08
		var offset_y = cos(_time_elapsed * 0.5) * 0.05
		camera.position = _base_cam_pos + Vector3(offset_x, offset_y, 0)
		camera.look_at(Vector3(0, 0, 0), Vector3.UP)

func celebrate_win() -> void:
	if win_particles:
		win_particles.restart()
		win_particles.emitting = true
		
	# Pulso de luz dourada
	if spot_light:
		var orig_energy = spot_light.light_energy
		var tween = create_tween()
		tween.tween_property(spot_light, "light_energy", orig_energy * 2.5, 0.3)
		tween.tween_property(spot_light, "light_energy", orig_energy, 1.2)
