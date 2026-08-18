extends Control

func _ready():
	var title = SaveManager.get_setting("current_generic_game", "Jogo")
	$VBoxContainer/CenterContainer/Title.text = title + "\n(Vencedor Definido Pela Simulação!)"

func _on_btn_back_pressed():
	# Retorna ao menu correto
	var menu = SaveManager.get_setting("current_menu", "res://core/telas/MainMenu.tscn")
	SceneManager.goto_scene(menu)
