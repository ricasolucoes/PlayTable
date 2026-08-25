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


static func get_game_subtitle(game: GameDefinition) -> String:
	match game.scene_path:
		"res://games/quatro_em_linha/ConnectFourGame.tscn":
			return "2 Jogadores • IA"
		"res://games/jogo_da_velha/TicTacToeGame.tscn":
			return "2 Jogadores • IA"
		"res://games/damas/CheckersGame.tscn":
			return "2 Jogadores • IA"
		"res://games/batalha_naval/BattleshipGame.tscn":
			return "Estratégia • IA"
		"res://games/reversi/ReversiGame.tscn":
			return "Estratégia • IA"
		"res://games/mancala/MancalaGame.tscn":
			return "Ancestral • IA"
		"res://games/ludo/LudoGame.tscn":
			return "2-4 Jogadores"
		"res://games/senet/SenetGame.tscn":
			return "Egito Antigo • IA"
		"res://games/solitario/PegSolitaireGame.tscn":
			return "Desafio Solo"
		"res://games/campo_minado/MinesweeperGame.tscn":
			return "Lógica • Solo"
		"res://games/domino/DominoGame.tscn":
			return "Clássico • IA"
		"res://games/paciencia/KlondikeGame.tscn":
			return "Klondike • Solo"
		"res://games/memoria/MemoryGame.tscn":
			return "Memória • Solo"
		"res://games/blackjack/BlackjackGame.tscn":
			return "Cassino • IA"
		"res://games/unolike/UnoLikeGame.tscn":
			return "Mau-Mau • IA"
		"res://games/poker/PokerGame.tscn":
			return "Video Poker • Solo"
		_:
			return "Clássico"


func _build_game_buttons() -> void:
	var scroll: ScrollContainer = get_node_or_null("VBoxContainer/ScrollContainer")
	if scroll == null:
		return
	var container: Container = scroll.get_node_or_null("GridContainer")
	if container == null:
		container = scroll.get_node_or_null("VBoxContainer")
	if container == null:
		return

	for child in container.get_children():
		child.queue_free()

	for game: GameDefinition in list_games():
		var card := _create_game_card(game)
		container.add_child(card)


func _create_game_card(game: GameDefinition) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 150)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12.0
	vbox.offset_top = 16.0
	vbox.offset_right = -12.0
	vbox.offset_bottom = -16.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_label := Label.new()
	icon_label.text = game.icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 38)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_label)

	var title_label := Label.new()
	title_label.text = game.title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)

	var tag_label := Label.new()
	tag_label.text = get_game_subtitle(game)
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.add_theme_font_size_override("font_size", 13)
	tag_label.add_theme_color_override("font_color", Color(0.82, 0.72, 0.52, 0.85))
	tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tag_label)

	btn.add_child(vbox)
	btn.pressed.connect(_on_game_pressed.bind(game))
	return btn


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
