## GameCatalog: Central registry of all available games.
##
## Provides a single source of truth for game definitions, replacing
## hardcoded scene paths scattered across menu scripts. To add a new game,
## simply add a new entry to the appropriate list below.
class_name GameCatalog
extends RefCounted

## Modos de partida, encurtados para o catálogo caber numa linha por jogo.
##
## Cada jogo é marcado pelo que o seu código realmente faz hoje. Os jogos com
## `DUPLA` exibem uma alternância local na própria mesa, enquanto os demais
## continuam restritos ao modo indicado.
const SOLO := GameDefinition.Mode.SOLO
const IA := GameDefinition.Mode.AI
const DUPLA := GameDefinition.Mode.VERSUS


## Returns all board game definitions.
static func get_board_games() -> Array[GameDefinition]:
	return [
		GameDefinition.create("GAME_CONNECT4", "🔴", "res://games/quatro_em_linha/ConnectFourGame.tscn", &"board", "GAME_DESC_CONNECT_FOUR")
			.tagged("GENRE_STRATEGY", IA | DUPLA),
		GameDefinition.create("GAME_TICTACTOE", "❌", "res://games/jogo_da_velha/TicTacToeGame.tscn", &"board", "GAME_DESC_TIC_TAC_TOE")
			.tagged("GENRE_CLASSIC", IA | DUPLA),
		GameDefinition.create("GAME_CHECKERS", "⬛", "res://games/damas/CheckersGame.tscn", &"board", "GAME_DESC_CHECKERS")
			.tagged("GENRE_CLASSIC", IA),
		GameDefinition.create("GAME_BATTLESHIP", "🚢", "res://games/batalha_naval/BattleshipGame.tscn", &"board", "GAME_DESC_BATTLESHIP")
			.tagged("GENRE_STRATEGY", IA),
		GameDefinition.create("GAME_REVERSI", "⚫", "res://games/reversi/ReversiGame.tscn", &"board", "GAME_DESC_REVERSI")
			.tagged("GENRE_STRATEGY", IA),
		GameDefinition.create("GAME_MANCALA", "💎", "res://games/mancala/MancalaGame.tscn", &"board", "GAME_DESC_MANCALA")
			.tagged("GENRE_ANCESTRAL", IA),
		GameDefinition.create("GAME_LUDO", "🎲", "res://games/ludo/LudoGame.tscn", &"board", "GAME_DESC_LUDO")
			.tagged("GENRE_RACE", IA),
		GameDefinition.create("GAME_SENET", "𓁹", "res://games/senet/SenetGame.tscn", &"board", "GAME_DESC_SENET")
			.tagged("GENRE_EGYPT", IA),
		GameDefinition.create("GAME_SOLITAIRE", "🔘", "res://games/solitario/PegSolitaireGame.tscn", &"board", "GAME_DESC_PEG_SOLITAIRE")
			.tagged("GENRE_PUZZLE", SOLO),
		GameDefinition.create("GAME_MINESWEEPER", "💣", "res://games/campo_minado/MinesweeperGame.tscn", &"board", "GAME_DESC_MINESWEEPER")
			.tagged("GENRE_LOGIC", SOLO),
		GameDefinition.create("GAME_DOMINO", "🁣", "res://games/domino/DominoGame.tscn", &"board", "GAME_DESC_DOMINO")
			.tagged("GENRE_CLASSIC", IA),
		GameDefinition.create("GAME_HANOI", "🗼", "res://games/hanoi/HanoiGame.tscn", &"board", "GAME_DESC_HANOI")
			.tagged("GENRE_LOGIC", SOLO),
		GameDefinition.create("GAME_NIM", "🪙", "res://games/nim/NimGame.tscn", &"board", "GAME_DESC_NIM")
			.tagged("GENRE_STRATEGY", IA | DUPLA),
		GameDefinition.create("GAME_GAMAO", "🎲", "res://games/gamao/BackgammonGame.tscn", &"board", "GAME_DESC_BACKGAMMON")
			.tagged("GENRE_STRATEGY", IA | DUPLA),
	]


## Returns all card game definitions.
static func get_card_games() -> Array[GameDefinition]:
	return [
		GameDefinition.create("GAME_KLONDIKE", "🃏", "res://games/paciencia/KlondikeGame.tscn", &"cards", "GAME_DESC_KLONDIKE")
			.tagged("GENRE_PATIENCE", SOLO),
		GameDefinition.create("GAME_SPIDER", "🕷️", "res://games/paciencia_spider/SpiderGame.tscn", &"cards", "GAME_DESC_SPIDER")
			.tagged("GENRE_PATIENCE", SOLO),
		GameDefinition.create("GAME_MEMORY", "🧠", "res://games/memoria/MemoryGame.tscn", &"cards", "GAME_DESC_MEMORY")
			.tagged("GENRE_MEMORY", SOLO | DUPLA),
		GameDefinition.create("GAME_BLACKJACK", "🂡", "res://games/blackjack/BlackjackGame.tscn", &"cards", "GAME_DESC_BLACKJACK")
			.tagged("GENRE_CASINO", IA),
		GameDefinition.create("GAME_UNOLIKE", "🌈", "res://games/unolike/UnoLikeGame.tscn", &"cards", "GAME_DESC_UNO_LIKE")
			.tagged("GENRE_SHEDDING", IA),
		GameDefinition.create("GAME_POKER", "♠", "res://games/poker/PokerGame.tscn", &"cards", "GAME_DESC_POKER")
			.tagged("GENRE_VIDEO_POKER", SOLO),
	]


## Returns all games across all categories.
static func get_all_games() -> Array[GameDefinition]:
	var all: Array[GameDefinition] = []
	all.append_array(get_board_games())
	all.append_array(get_card_games())
	return all


## Identificador do jogo no barramento de eventos e no perfil, tirado da pasta
## da cena (`res://games/gamao/BackgammonGame.tscn` -> `gamao`). O mesmo
## calculo que `BaseGame._derive_game_id()` faz, para os dois lados falarem o
## mesmo id sem uma tabela de tradução no meio.
static func game_id_of(def: GameDefinition) -> String:
	return id_from_scene_path(def.scene_path)


static func id_from_scene_path(scene_path: String) -> String:
	if scene_path.begins_with("res://games/"):
		var parts := scene_path.split("/")
		if parts.size() >= 4:
			return parts[3]
	return "playtable"


## Categoria do jogo (`board` ou `cards`) a partir do id. Vazio quando o id não
## corresponde a nenhum jogo do catálogo.
static func categoria(game_id: String) -> StringName:
	var def := find_by_id(game_id)
	return def.category if def != null else &""


static func find_by_id(game_id: String) -> GameDefinition:
	for def in get_all_games():
		if game_id_of(def) == game_id:
			return def
	return null


## Ids de todos os jogos, na ordem em que aparecem nos menus.
static func all_game_ids() -> Array[String]:
	var ids: Array[String] = []
	for def in get_all_games():
		ids.append(game_id_of(def))
	return ids


## Nome do jogo na barra de cima, no idioma de agora.
##
## O catálogo é a única fonte do nome: até agora a tela dizia "Damas 3D" e o
## catálogo dizia "Damas", duas verdades para a mesma coisa. Nenhum título
## precisa encurtar -- o mais comprido, "Jogo de Cores & Cartas", cabe nos 720 px
## do viewport lógico ao lado do voltar e do placar, e o que passar disso o
## próprio rótulo corta com reticências.
static func bar_title(game_id: String) -> String:
	var def := find_by_id(game_id)
	return def.display_name() if def != null else ""
