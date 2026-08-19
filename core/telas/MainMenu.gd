extends Control

## MainMenu: Menu Principal com Mesa 3D Dinâmica e HUD Glassmorphic

@onready var env_3d: TabletopEnvironment3D = $TabletopEnvironment3D
@onready var showcase_root: Node3D = $TabletopEnvironment3D/ShowcaseRoot
@onready var title = $UI/Title
@onready var subtitle = $UI/Subtitle
@onready var main_menu_vbox = $UI/VBoxContainer
@onready var config_panel = $UI/ConfigPanel
@onready var btn_toggle_theme = $UI/ConfigPanel/VBoxContainer/BtnToggleTheme

var dice_1: Dice3D
var dice_2: Dice3D
var _rot_timer: float = 0.0

func _ready():
	_setup_3d_showcase()
	_apply_theme()
	config_panel.hide()

func _setup_3d_showcase():
	# Instancia dados 3D decorativos na mesa
	dice_1 = preload("res://shared/3d/Dice3D.tscn").instantiate()
	dice_1.position = Vector3(-1.2, 0.3, 0.4)
	showcase_root.add_child(dice_1)
	dice_1.set_value_immediate(6)
	
	dice_2 = preload("res://shared/3d/Dice3D.tscn").instantiate()
	dice_2.position = Vector3(-0.6, 0.3, 0.9)
	showcase_root.add_child(dice_2)
	dice_2.set_value_immediate(5)
	
	# Instancia cartas 3D dispostas em leque na mesa
	var card_1 = preload("res://shared/3d/Card3D.tscn").instantiate()
	card_1.position = Vector3(1.0, 0.02, 0.2)
	card_1.rotation_degrees = Vector3(0, -15, 0)
	showcase_root.add_child(card_1)
	card_1.setup("A", "♠", true)
	
	var card_2 = preload("res://shared/3d/Card3D.tscn").instantiate()
	card_2.position = Vector3(1.5, 0.03, 0.4)
	card_2.rotation_degrees = Vector3(0, 10, 0)
	showcase_root.add_child(card_2)
	card_2.setup("K", "♥", true)
	
	# Instancia peças 3D de dama / fichas
	var token_w = preload("res://shared/3d/Token3D.tscn").instantiate()
	token_w.position = Vector3(0.0, 0.06, -0.8)
	token_w.material_name = "gold"
	showcase_root.add_child(token_w)
	token_w.promote_queen()
	
	var token_b = preload("res://shared/3d/Token3D.tscn").instantiate()
	token_b.position = Vector3(-0.8, 0.06, -0.6)
	token_b.material_name = "obsidian"
	showcase_root.add_child(token_b)

func _process(delta: float):
	_rot_timer += delta
	if dice_1:
		dice_1.rotation.y += delta * 0.4
	if dice_2:
		dice_2.rotation.x += delta * 0.3

func _apply_theme():
	var is_dark = SaveManager.get_setting("theme_dark", true)
	if env_3d:
		var felt_col = Color(0.06, 0.25, 0.16) if is_dark else Color(0.12, 0.38, 0.28)
		env_3d.set_felt_color(felt_col)
	btn_toggle_theme.text = "Tema: 🌙 Escuro" if is_dark else "Tema: ☀️ Claro"

func _on_btn_tabuleiro_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")

func _on_btn_cartas_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")

func _on_btn_config_pressed():
	main_menu_vbox.hide()
	config_panel.show()

func _on_btn_toggle_theme_pressed():
	var is_dark = SaveManager.get_setting("theme_dark", true)
	SaveManager.set_setting("theme_dark", not is_dark)
	_apply_theme()

func _on_btn_close_config_pressed():
	config_panel.hide()
	main_menu_vbox.show()
