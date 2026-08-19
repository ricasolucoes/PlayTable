extends Control

@onready var background = $Background
@onready var title = $Title
@onready var subtitle = $Subtitle
@onready var main_menu_vbox = $VBoxContainer
@onready var config_panel = $ConfigPanel
@onready var btn_toggle_theme = $ConfigPanel/VBoxContainer/BtnToggleTheme

func _ready():
	_apply_theme()
	config_panel.hide()

func _apply_theme():
	var is_dark = SaveManager.get_setting("theme_dark", true)
	if is_dark:
		background.color = Color(0.08, 0.09, 0.11, 1)
		title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		subtitle.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7, 1))
		btn_toggle_theme.text = "Tema: 🌙 Escuro"
	else:
		background.color = Color(0.92, 0.93, 0.95, 1)
		title.add_theme_color_override("font_color", Color(0.1, 0.12, 0.15, 1))
		subtitle.add_theme_color_override("font_color", Color(0.3, 0.35, 0.4, 1))
		btn_toggle_theme.text = "Tema: ☀️ Claro"

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
