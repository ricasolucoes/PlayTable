class_name GameMenu
extends Control

## Tela que lista os jogos de uma categoria a partir do GameCatalog.
##
## MenuTabuleiro e MenuCartas eram o mesmo arquivo com duas linhas trocadas: a
## consulta ao catálogo e o caminho gravado para o placeholder saber de onde o
## jogador veio. Todo o resto — montar os botões, tocar o clique, decidir entre
## a cena do jogo e a tela de "em breve", voltar ao menu principal — era cópia.
##
## Contrato para quem herda: responder `list_games()` e apontar
## `menu_scene_path` para a própria cena.

const GENERIC_GAME := "res://shared/GenericGame.tscn"
const MAIN_MENU := "res://core/telas/MainMenu.tscn"

## Caminho da própria cena. O GenericGame o lê para montar o botão de voltar.
var menu_scene_path: String = ""


func _ready() -> void:
	_build_game_buttons()


## Os jogos que esta tela lista. Cada menu responde com a sua categoria.
func list_games() -> Array[GameDefinition]:
	return [] as Array[GameDefinition]


func _build_game_buttons() -> void:
	var container: VBoxContainer = $VBoxContainer/ScrollContainer/VBoxContainer
	for game: GameDefinition in list_games():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 80)
		btn.add_theme_font_size_override("font_size", 24)
		btn.text = "%s  %s" % [game.icon, game.title]
		btn.pressed.connect(_on_game_pressed.bind(game))
		container.add_child(btn)


func _on_game_pressed(game: GameDefinition) -> void:
	play_click()
	if game.is_implemented and ResourceLoader.exists(game.scene_path):
		SceneManager.goto_scene(game.scene_path)
	else:
		SaveManager.set_setting("generic_game_title", game.title)
		SaveManager.set_setting("current_menu", menu_scene_path)
		SceneManager.goto_scene(GENERIC_GAME)


## Ligado no `.tscn` dos dois menus.
func _on_btn_voltar_pressed() -> void:
	play_click()
	SceneManager.goto_scene(MAIN_MENU)


func play_click() -> void:
	if AudioManager:
		AudioManager.play_click()
