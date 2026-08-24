extends GameMenu

## Menu de jogos de tabuleiro. O que ele acrescenta ao GameMenu é a categoria
## que lista e o caminho da própria cena.

func _ready() -> void:
	menu_scene_path = BaseGame.MENU_TABULEIRO
	super()


func list_games() -> Array[GameDefinition]:
	return GameCatalog.get_board_games()
