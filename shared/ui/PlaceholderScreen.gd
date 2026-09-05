extends Control

## Placeholder scene displayed for games that are not yet implemented.
##
## Nao e a classe-base de nada, apesar do nome: e a tela de "em breve" que os
## dois menus abrem quando um GameDefinition tem is_implemented = false.
## O nome nao sai do catalogo: o jogo ainda nao tem cena, e quem
## sabe qual e o menu que gravou o titulo antes de abrir esta tela.

var menu_scene_path: String = ""

func _ready() -> void:
	# Qual menu abriu o placeholder, gravado por MenuTabuleiro/MenuCartas.
	menu_scene_path = SaveManager.get_setting("current_menu", "res://core/telas/MainMenu.tscn") as String
	var title: String = SaveManager.get_setting("generic_game_title", "COMING_SOON_TITLE") as String
	var intro: String = SaveManager.get_setting("generic_game_intro", "") as String
	
	var top_bar = GameTopBar.new()
	top_bar.name = "TopBar"
	top_bar.game_title = tr(title)
	top_bar.back_pressed.connect(go_back_to_menu)
	add_child(top_bar)

	$VBoxContainer/CenterCard/VBox/Title.text = "🎲 " + tr(title)
	$VBoxContainer/CenterCard/VBox/Subtitle.text = tr("COMING_SOON_DESC")
	
	if intro != "" and ResourceLoader.exists(intro):
		var cover: TextureRect = $VBoxContainer/CenterCard/VBox.get_node_or_null("CoverImage")
		if cover == null:
			cover = TextureRect.new()
			cover.name = "CoverImage"
			cover.custom_minimum_size = Vector2(0, 180)
			cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			$VBoxContainer/CenterCard/VBox.add_child(cover)
			$VBoxContainer/CenterCard/VBox.move_child(cover, 0)
		cover.texture = load(intro)

func go_back_to_menu() -> void:
	if AudioManager:
		AudioManager.play_click()
	SceneManager.goto_scene(menu_scene_path)
