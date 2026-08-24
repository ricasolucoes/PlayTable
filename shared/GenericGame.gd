extends BaseGame

## Placeholder scene displayed for games that are not yet implemented.
##
## Nao e a classe-base de nada, apesar do nome: e a tela de "em breve" que os
## dois menus abrem quando um GameDefinition tem is_implemented = false. Herda
## de BaseGame pelo botao voltar, a decima quarta e ultima copia dele.

func _ready() -> void:
	# Qual menu abriu o placeholder, gravado por MenuTabuleiro/MenuCartas.
	menu_scene_path = SaveManager.get_setting("current_menu", "res://core/telas/MainMenu.tscn") as String
	var title: String = SaveManager.get_setting("generic_game_title", "COMING_SOON_TITLE") as String
	$VBoxContainer/CenterCard/VBox/Title.text = "🎲 " + tr(title)
	$VBoxContainer/CenterCard/VBox/Subtitle.text = tr("COMING_SOON_DESC")
