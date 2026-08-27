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
		"res://games/hanoi/HanoiGame.tscn":
			return "Lógica • Solo"
		"res://games/nim/NimGame.tscn":
			return "Estratégia • IA"
		"res://games/gamao/BackgammonGame.tscn":
			return "Estratégia • IA • 2J"
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


static func get_game_intro_path(game: GameDefinition) -> String:
	if game.scene_path.begins_with("res://games/"):
		var parts := game.scene_path.split("/")
		if parts.size() >= 4:
			var folder := parts[3]
			var intro := "res://games/%s/intro.jpg" % folder
			if ResourceLoader.exists(intro):
				return intro
	return ""


func _create_game_card(game: GameDefinition) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 238)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	btn.add_theme_stylebox_override("normal", _card_style(game, false, false))
	btn.add_theme_stylebox_override("hover", _card_style(game, true, false))
	btn.add_theme_stylebox_override("pressed", _card_style(game, false, true))
	btn.add_theme_stylebox_override("focus", _card_style(game, true, false))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 14.0
	vbox.offset_top = 14.0
	vbox.offset_right = -14.0
	vbox.offset_bottom = -12.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var intro_path := get_game_intro_path(game)
	if intro_path != "":
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(intro_path)
		tex_rect.custom_minimum_size = Vector2(0, 145)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tex_rect)
	else:
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
	title_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
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


func _card_style(game: GameDefinition, highlighted: bool, pressed: bool) -> StyleBoxFlat:
	var accent := _game_accent(game)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.88 if not pressed else 0.98)
	style.border_color = Color(accent.lightened(0.28 if highlighted else 0.08), 0.98)
	style.set_border_width_all(2 if not highlighted else 3)
	style.set_corner_radius_all(24)
	style.shadow_color = Color(accent, 0.32 if highlighted else 0.22)
	style.shadow_size = 14 if highlighted else 9
	style.shadow_offset = Vector2(0, 5 if not pressed else 2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 12
	return style


func _game_accent(game: GameDefinition) -> Color:
	match game.scene_path:
		"res://games/quatro_em_linha/ConnectFourGame.tscn": return Color("#1f66b8")
		"res://games/jogo_da_velha/TicTacToeGame.tscn": return Color("#203b66")
		"res://games/reversi/ReversiGame.tscn": return Color("#25864f")
		"res://games/batalha_naval/BattleshipGame.tscn": return Color("#183149")
		"res://games/damas/CheckersGame.tscn": return Color("#552d32")
		"res://games/mancala/MancalaGame.tscn": return Color("#8d4d22")
		_: return Color("#263b56")



func _on_game_pressed(game: GameDefinition) -> void:
	play_click()
	if game.is_implemented and ResourceLoader.exists(game.scene_path):
		SceneManager.goto_scene(game.scene_path)
	else:
		SaveManager.set_setting("generic_game_title", game.title)
		SaveManager.set_setting("generic_game_intro", get_game_intro_path(game))
		SaveManager.set_setting("current_menu", menu_scene_path)
		SceneManager.goto_scene(GENERIC_GAME)



## Ligado no `.tscn` dos dois menus.
func _on_btn_voltar_pressed() -> void:
	play_click()
	SceneManager.goto_scene(MAIN_MENU)


func play_click() -> void:
	if AudioManager:
		AudioManager.play_click()
