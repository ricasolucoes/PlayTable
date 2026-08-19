extends Control

## Menu de jogos de tabuleiro gerado dinamicamente a partir do GameCatalog.

func _ready() -> void:
	_build_game_buttons()

func _build_game_buttons() -> void:
	var container: VBoxContainer = $VBoxContainer/ScrollContainer/VBoxContainer
	for game: GameDefinition in GameCatalog.get_board_games():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 80)
		btn.add_theme_font_size_override("font_size", 24)
		btn.text = "%s  %s" % [game.icon, game.title]
		btn.pressed.connect(_on_game_pressed.bind(game))
		container.add_child(btn)

func _on_game_pressed(game: GameDefinition) -> void:
	if AudioManager:
		AudioManager.play_click()
	if game.is_implemented and ResourceLoader.exists(game.scene_path):
		SceneManager.goto_scene(game.scene_path)
	else:
		SaveManager.set_setting("generic_game_title", game.title)
		SaveManager.set_setting("current_menu", "res://core/telas/MenuTabuleiro.tscn")
		SceneManager.goto_scene("res://shared/GenericGame.tscn")

func _on_btn_voltar_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	SceneManager.goto_scene("res://core/telas/MainMenu.tscn")
