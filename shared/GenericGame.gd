extends Control

## Placeholder scene displayed for games that are not yet implemented.

func _ready() -> void:
	var title: String = SaveManager.get_setting("generic_game_title", "COMING_SOON_TITLE") as String
	$VBoxContainer/CenterCard/VBox/Title.text = "🎲 " + tr(title)
	$VBoxContainer/CenterCard/VBox/Subtitle.text = tr("COMING_SOON_DESC")

func _on_btn_back_pressed() -> void:
	if AudioManager: AudioManager.play_click()
	var menu: String = SaveManager.get_setting("current_menu", "res://core/telas/MainMenu.tscn") as String
	SceneManager.goto_scene(menu)
