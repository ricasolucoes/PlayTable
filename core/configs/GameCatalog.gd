## GameCatalog: Central registry of all available games.
##
## Provides a single source of truth for game definitions, replacing
## hardcoded scene paths scattered across menu scripts. To add a new game,
## simply add a new entry to the appropriate list below.
class_name GameCatalog
extends RefCounted

## Returns all board game definitions.
static func get_board_games() -> Array[GameDefinition]:
	return [
		GameDefinition.create("Quatro em Linha", "🔴", "res://games/quatro_em_linha/ConnectFourGame.tscn", &"board", "GAME_DESC_CONNECT_FOUR"),
		GameDefinition.create("Jogo da Velha", "❌", "res://games/jogo_da_velha/TicTacToeGame.tscn", &"board", "GAME_DESC_TIC_TAC_TOE"),
		GameDefinition.create("Damas", "⬛", "res://games/damas/CheckersGame.tscn", &"board", "GAME_DESC_CHECKERS"),
		GameDefinition.create("Batalha Naval", "🚢", "res://games/batalha_naval/BattleshipGame.tscn", &"board", "GAME_DESC_BATTLESHIP"),
		GameDefinition.create("Reversi", "⚫", "res://games/reversi/ReversiGame.tscn", &"board", "GAME_DESC_REVERSI"),
		GameDefinition.create("Mancala", "💎", "res://games/mancala/MancalaGame.tscn", &"board", "GAME_DESC_MANCALA"),
		GameDefinition.create("Ludo", "🎲", "res://games/ludo/LudoGame.tscn", &"board", "GAME_DESC_LUDO"),
		GameDefinition.create("Senet", "𓁹", "res://games/senet/SenetGame.tscn", &"board", "GAME_DESC_SENET"),
		GameDefinition.create("Resta Um", "🔘", "res://games/solitario/PegSolitaireGame.tscn", &"board", "GAME_DESC_PEG_SOLITAIRE"),
		GameDefinition.create("Campo Minado", "💣", "res://games/campo_minado/MinesweeperGame.tscn", &"board", "GAME_DESC_MINESWEEPER"),
		GameDefinition.create("Dominó", "🁣", "res://games/domino/DominoGame.tscn", &"board", "GAME_DESC_DOMINO"),
		GameDefinition.create("Torres de Hanói", "🗼", "res://games/hanoi/HanoiGame.tscn", &"board", "GAME_DESC_HANOI"),
		GameDefinition.create("Jogo de Nim", "🪙", "res://games/nim/NimGame.tscn", &"board", "GAME_DESC_NIM"),
		GameDefinition.create("Gamão", "🎲", "res://games/gamao/BackgammonGame.tscn", &"board", "GAME_DESC_BACKGAMMON"),
	]

## Returns all card game definitions.
static func get_card_games() -> Array[GameDefinition]:
	return [
		GameDefinition.create("Paciência (Klondike)", "🃏", "res://games/paciencia/KlondikeGame.tscn", &"cards", "GAME_DESC_KLONDIKE"),
		GameDefinition.create("Jogo da Memória", "🧠", "res://games/memoria/MemoryGame.tscn", &"cards", "GAME_DESC_MEMORY"),
		GameDefinition.create("21 (Blackjack)", "🂡", "res://games/blackjack/BlackjackGame.tscn", &"cards", "GAME_DESC_BLACKJACK"),
		GameDefinition.create("Jogo de Cores & Cartas", "🌈", "res://games/unolike/UnoLikeGame.tscn", &"cards", "GAME_DESC_UNO_LIKE"),
		GameDefinition.create("Poker Dice / Cartas", "♠", "res://games/poker/PokerGame.tscn", &"cards", "GAME_DESC_POKER"),
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
