class_name AssetCatalog
extends RefCounted

## AssetCatalog: Acesso centralizado e programático para todos os assets e sprites fatiados.
## Fornece métodos estáticos seguros para obter texturas de UI, Peças, Cartas, Dados e Recompensas.

const UI_DIR := "res://shared/assets/ui/"
const PIECES_DIR := "res://shared/assets/pieces/"
const TOKENS_DIR := "res://shared/assets/tokens/"
const REWARDS_DIR := "res://shared/assets/rewards/"
const CARDS_DIR := "res://shared/assets/cards/"

# --- UI BUTTONS ---
static func get_ui_button(action: String, style_index: int = 1) -> Texture2D:
	var filename := "btn_%s_%02d.png" % [action.to_lower(), style_index]
	return _load_texture(UI_DIR + filename)

# --- PIECES ---
static func get_checker_piece(color: String = "red") -> Texture2D:
	var filename := "checker_%s.png" % color.to_lower()
	return _load_texture(PIECES_DIR + filename)

static func get_reversi_piece(color: String = "black") -> Texture2D:
	var filename := "reversi_%s.png" % color.to_lower()
	return _load_texture(PIECES_DIR + filename)

static func get_mancala_stone(color: String = "blue") -> Texture2D:
	var filename := "mancala_stone_%s.png" % color.to_lower()
	return _load_texture(PIECES_DIR + filename)

# --- TOKENS & DICE ---
static func get_dice(color: String = "red") -> Texture2D:
	var filename := "dice_%s.png" % color.to_lower()
	return _load_texture(TOKENS_DIR + filename)

static func get_pawn(color: String = "red") -> Texture2D:
	var filename := "pawn_%s.png" % color.to_lower()
	return _load_texture(TOKENS_DIR + filename)

# --- CARDS ---
static func get_card_back(color: String = "blue") -> Texture2D:
	var filename := "card_back_%s.png" % color.to_lower()
	return _load_texture(CARDS_DIR + filename)

# --- REWARDS, COINS & GEMS ---
static func get_coin(is_stack: bool = false) -> Texture2D:
	var filename := "coin_stack.png" if is_stack else "coin_gold.png"
	return _load_texture(REWARDS_DIR + filename)

static func get_gem(gem_type: String = "ruby") -> Texture2D:
	var filename := "gem_%s.png" % gem_type.to_lower()
	return _load_texture(REWARDS_DIR + filename)


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
