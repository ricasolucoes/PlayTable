extends Control

func _ready():
	var title = SaveManager.get_setting("generic_game_title", "Jogo")
	$VBoxContainer/CenterCard/VBox/Title.text = "🎲 " + title
	$VBoxContainer/CenterCard/VBox/Subtitle.text = "Em breve nesta coleção!\nFocado em jogabilidade offline e visual realista."

func _on_btn_back_pressed():
	if AudioManager: AudioManager.play_click()
	var menu = SaveManager.get_setting("current_menu", "res://core/telas/MainMenu.tscn")
	SceneManager.goto_scene(menu)
