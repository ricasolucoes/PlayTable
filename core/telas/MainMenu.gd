extends Control

func _ready():
	var is_dark = SaveManager.get_setting("theme_dark", true)
	if not is_dark:
		$Background.color = Color(0.9, 0.9, 0.9)
		$Title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))

func _on_btn_tabuleiro_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")

func _on_btn_cartas_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")

func _on_btn_config_pressed():
	print("Botão Configurações pressionado (Em breve)")
