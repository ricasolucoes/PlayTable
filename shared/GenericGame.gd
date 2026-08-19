extends Control

func _ready():
	var title = SaveManager.get_setting("generic_game_title", "COMING_SOON_TITLE")
	$VBoxContainer/CenterCard/VBox/Title.text = "🎲 " + tr(title)
	$VBoxContainer/CenterCard/VBox/Subtitle.text = tr("COMING_SOON_DESC")

func _on_btn_back_pressed():
	if AudioManager: AudioManager.play_click()
	var menu = SaveManager.get_setting("current_menu", "res://core/telas/MainMenu.tscn")
	SceneManager.goto_scene(menu)
